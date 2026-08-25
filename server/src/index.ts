/**
 * Poetry Mate 数据分发服务 —— Worker 入口。
 *
 * 职责边界(契约: specs/data-distribution-api):
 *   - 只读公开接口,无鉴权,无写操作;
 *   - 绝不代理 LLM 流量(BYOK 直连);
 *   - 对"用户"一无所知。
 *
 * 存储布局(design D5):
 *   DATA binding(R2)
 *     /current                          → {"version": "vYYYYMMDD.aaaaaaaa"}
 *     /<version>/manifest.json
 *     /<version>/aliases.json
 *     /<version>/pending-review.json
 *     /<version>/build-issues.json
 *     /<version>/volumes/<collection>/<cid>.NNNN.json.zst
 */

export interface Env {
  /** R2 bucket,存放版本化数据包与 current 指针 */
  DATA: R2Bucket;
}

const JSON_HEADERS = { "content-type": "application/json; charset=utf-8" } as const;

/** catalog 允许短缓存(分钟级),便于版本切换及时可见 */
const CATALOG_CACHE = "public, max-age=60";
/** 卷内容按版本目录隔离永不原地修改 → 一年 immutable */
const VOLUME_CACHE = "public, max-age=31536000, immutable";

function json(body: unknown, status: number, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...JSON_HEADERS, ...headers },
  });
}

function notFound(): Response {
  return json({ error: "not_found" }, 404);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // 方法守卫: 只读服务(spec 场景: POST/PUT/DELETE → 405)
    if (request.method !== "GET" && request.method !== "HEAD") {
      return json({ error: "method_not_allowed" }, 405, { allow: "GET, HEAD" });
    }

    // 健康检查(部署验证用)
    if (url.pathname === "/health") {
      return json({ ok: true, service: "poetry-mate-data" }, 200);
    }

    // GET /api/v1/catalog —— 作品集目录 + 当前版本(任务 3.2)
    if (url.pathname === "/api/v1/catalog") {
      return handleCatalog(env);
    }

    // GET /api/v1/collections/:id/manifest —— 分卷清单(任务 3.3)
    const manifestMatch = /^\/api\/v1\/collections\/([a-z0-9]+)\/manifest$/.exec(
      url.pathname,
    );
    if (manifestMatch) {
      return handleCollectionManifest(env, manifestMatch[1] as string);
    }

    // GET|HEAD /volumes/:collection/:file —— 分卷下载(任务 3.3)
    const volumeMatch = /^\/volumes\/([a-z0-9]+)\/([a-z0-9.\-]+\.json\.zst)$/.exec(
      url.pathname,
    );
    if (volumeMatch) {
      return handleVolume(request, env, volumeMatch[1] as string, volumeMatch[2] as string);
    }

    return notFound();
  },
};

// ---------------------------------------------------------------------------
// 端点实现
// ---------------------------------------------------------------------------

const VERSION_RE = /^v\d{8}\.[0-9a-f]{8}$/;

type ManifestVolume = {
  file: string;
  sha256: string;
  bytes: number;
  records: number;
};

type ManifestCollection = {
  title: string;
  dynasty: string | null;
  type: string;
  record_count: number;
  volume_count: number;
  volumes: ManifestVolume[];
  builtin?: boolean;
};

type Manifest = {
  version: string;
  source_commit: string;
  collections: Record<string, ManifestCollection>;
};

async function readCurrentVersion(env: Env): Promise<string | null> {
  const pointer = await env.DATA.get("current");
  if (!pointer) return null;
  try {
    const body = (await pointer.json()) as { version?: unknown };
    if (typeof body.version !== "string") return null;
    // 指针内容参与对象键拼接,严格白名单防注入
    return VERSION_RE.test(body.version) ? body.version : null;
  } catch {
    return null;
  }
}

async function fetchManifest(
  env: Env,
  version: string,
): Promise<Manifest | null> {
  const obj = await env.DATA.get(`${version}/manifest.json`);
  if (!obj) return null;
  try {
    const manifest = (await obj.json()) as Manifest;
    if (!manifest || typeof manifest !== "object" || !manifest.collections) {
      return null;
    }
    return manifest;
  } catch {
    return null;
  }
}

async function handleCatalog(env: Env): Promise<Response> {
  const version = await readCurrentVersion(env);
  if (!version) return json({ error: "no_version_published" }, 503);

  const manifest = await fetchManifest(env, version);
  if (!manifest) return notFound();

  const collections = Object.entries(manifest.collections).map(
    ([id, entry]) => ({
      id,
      title: entry.title,
      dynasty: entry.dynasty,
      type: entry.type,
      record_count: entry.record_count,
      volume_count: entry.volume_count,
      total_bytes: entry.volumes.reduce((sum, v) => sum + v.bytes, 0),
      ...(entry.builtin ? { builtin: true } : {}),
    }),
  );
  return json(
    { version, source_commit: manifest.source_commit, collections },
    200,
    { "cache-control": CATALOG_CACHE },
  );
}

async function handleCollectionManifest(
  env: Env,
  collectionId: string,
): Promise<Response> {
  const version = await readCurrentVersion(env);
  if (!version) return json({ error: "no_version_published" }, 503);

  const manifest = await fetchManifest(env, version);
  const entry = manifest?.collections[collectionId];
  if (!manifest || !entry) return notFound();

  return json(
    { version, collection: { id: collectionId, ...entry } },
    200,
    { "cache-control": CATALOG_CACHE },
  );
}

async function handleVolume(
  request: Request,
  env: Env,
  collectionId: string,
  file: string,
): Promise<Response> {
  const version = await readCurrentVersion(env);
  if (!version) return json({ error: "no_version_published" }, 503);

  // 直接按键取对象: 未登记的路径自然 miss → 404,不泄露存储内部结构。
  // 键的两段均已由路由正则白名单约束([a-z0-9]+ 与 [a-z0-9.\-]+\.json\.zst)。
  const key = `${version}/volumes/${collectionId}/${file}`;

  if (request.method === "HEAD") {
    const head = await env.DATA.head(key);
    if (!head) return notFound();
    return new Response(null, {
      status: 200,
      headers: {
        "content-type": "application/octet-stream",
        "content-length": String(head.size),
        etag: head.httpEtag,
        "cache-control": VOLUME_CACHE,
      },
    });
  }

  const object = await env.DATA.get(key);
  if (!object) return notFound();

  return new Response(object.body, {
    status: 200,
    headers: {
      "content-type": "application/octet-stream",
      "content-length": String(object.size),
      etag: object.httpEtag,
      "cache-control": VOLUME_CACHE,
    },
  });
}
