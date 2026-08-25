/**
 * 路由与端点单元测试 —— 用手写 FakeR2 替身,不依赖 miniflare。
 */
import { describe, expect, it } from "vitest";
import worker, { type Env } from "../src/index";

type StoredObject = { json?: unknown; bytes?: Uint8Array };

class FakeR2 implements Partial<R2Bucket> {
  private objects = new Map<string, StoredObject>();

  putJson(key: string, value: unknown): void {
    this.objects.set(key, { json: value });
  }

  putBytes(key: string, bytes: Uint8Array): void {
    this.objects.set(key, { bytes });
  }

  private encode(stored: StoredObject): Uint8Array {
    if (stored.json !== undefined) {
      return new TextEncoder().encode(JSON.stringify(stored.json));
    }
    return stored.bytes as Uint8Array;
  }

  private _makeBody(data: Uint8Array): ReadableStream {
    const copy = data.slice();
    return new ReadableStream({
      start(controller) {
        controller.enqueue(copy);
        controller.close();
      },
    }) as unknown as ReadableStream;
  }

  async get(
    key: string,
  ): Promise<(R2ObjectBody & { body: ReadableStream }) | null> {
    const stored = this.objects.get(key);
    if (!stored) return null;
    const data = this.encode(stored);
    const decoder = new TextDecoder();
    return {
      body: this._makeBody(data),
      size: data.length,
      httpEtag: "fake-etag",
      arrayBuffer: async () => data.slice().buffer,
      text: async () => decoder.decode(data),
      json: async () => JSON.parse(decoder.decode(data)),
    } as unknown as R2ObjectBody & { body: ReadableStream };
  }

  async head(key: string): Promise<Pick<R2Object, "size" | "httpEtag"> | null> {
    const stored = this.objects.get(key);
    if (!stored) return null;
    const size =
      stored.json !== undefined
        ? new TextEncoder().encode(JSON.stringify(stored.json)).length
        : (stored.bytes as Uint8Array).length;
    return { size, httpEtag: "fake-etag" };
  }
}

function makeEnv(): Env {
  const r2 = new FakeR2();
  const manifest = {
    version: "v20260825.b8594f81",
    source_commit: "b".repeat(40),
    collections: {
      tangshi: {
        title: "全唐诗",
        dynasty: "唐",
        type: "shi",
        record_count: 57603,
        volume_count: 1,
        volumes: [
          {
            file: "volumes/tangshi/tangshi.0001.json.zst",
            sha256: "abc",
            bytes: 123456,
            records: 1000,
          },
        ],
      },
      seed: {
        title: "种子精选",
        dynasty: null,
        type: "mixed",
        record_count: 300,
        volume_count: 1,
        builtin: true,
        volumes: [
          {
            file: "volumes/seed/seed.0001.json.zst",
            sha256: "def",
            bytes: 789,
            records: 300,
          },
        ],
      },
    },
  };
  r2.putJson("current", { version: "v20260825.b8594f81" });
  r2.putJson("v20260825.b8594f81/manifest.json", manifest);
  r2.putBytes("v20260825.b8594f81/volumes/tangshi/tangshi.0001.json.zst", new Uint8Array([1, 2, 3]));
  return { DATA: r2 as unknown as R2Bucket };
}

const BASE = "https://data.poetry-mate.example";

describe("方法守卫", () => {
  it.each(["POST", "PUT", "DELETE"])("%s → 405", async (method) => {
    const res = await worker.fetch(new Request(`${BASE}/api/v1/catalog`, { method }), makeEnv());
    expect(res.status).toBe(405);
    expect(res.headers.get("allow")).toContain("GET");
  });

  it("HEAD 允许", async () => {
    const res = await worker.fetch(new Request(`${BASE}/health`, { method: "HEAD" }), makeEnv());
    expect(res.status).toBe(200);
  });
});

describe("catalog", () => {
  it("返回版本、集子清单与 builtin 标记,短缓存", async () => {
    const res = await worker.fetch(new Request(`${BASE}/api/v1/catalog`), makeEnv());
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toContain("max-age=60");
    const body = (await res.json()) as {
      version: string;
      collections: Array<Record<string, unknown>>;
    };
    expect(body.version).toBe("v20260825.b8594f81");
    const ids = body.collections.map((c) => c["id"]);
    expect(ids).toEqual(["tangshi", "seed"]);
    const seedEntry = body.collections.find((c) => c["id"] === "seed");
    expect(seedEntry?.["builtin"]).toBe(true);
    expect(seedEntry?.["total_bytes"]).toBe(789);
  });

  it("无 current 指针 → 503", async () => {
    const env = { DATA: new FakeR2() as unknown as R2Bucket };
    const res = await worker.fetch(new Request(`${BASE}/api/v1/catalog`), env);
    expect(res.status).toBe(503);
  });
});

describe("collection manifest", () => {
  it("返回指定集子的卷清单", async () => {
    const res = await worker.fetch(
      new Request(`${BASE}/api/v1/collections/tangshi/manifest`),
      makeEnv(),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      collection: { id: string; volume_count: number };
    };
    expect(body.collection.id).toBe("tangshi");
    expect(body.collection.volume_count).toBe(1);
  });

  it("未知集子 → 404", async () => {
    const res = await worker.fetch(
      new Request(`${BASE}/api/v1/collections/notexist/manifest`),
      makeEnv(),
    );
    expect(res.status).toBe(404);
  });
});

describe("volume download", () => {
  it("返回字节与 immutable 缓存头", async () => {
    const res = await worker.fetch(
      new Request(`${BASE}/volumes/tangshi/tangshi.0001.json.zst`),
      makeEnv(),
    );
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toContain("immutable");
    const bytes = new Uint8Array(await res.arrayBuffer());
    expect(Array.from(bytes)).toEqual([1, 2, 3]);
  });

  it("HEAD 无响应体但有 content-length", async () => {
    const res = await worker.fetch(
      new Request(`${BASE}/volumes/tangshi/tangshi.0001.json.zst`, { method: "HEAD" }),
      makeEnv(),
    );
    expect(res.status).toBe(200);
    expect(res.headers.get("content-length")).toBe("3");
    expect((await res.arrayBuffer()).byteLength).toBe(0);
  });

  it("未登记路径 → 404", async () => {
    const res = await worker.fetch(
      new Request(`${BASE}/volumes/secret/private.json.zst`),
      makeEnv(),
    );
    expect(res.status).toBe(404);
  });

  it("非法文件名被路由白名单拒绝 → 404", async () => {
    const res = await worker.fetch(
      new Request(`${BASE}/volumes/tangshi/EVIL%2F..%2Fcurrent`),
      makeEnv(),
    );
    expect(res.status).toBe(404);
  });
});
