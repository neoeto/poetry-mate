# Poetry Mate · Cloudflare 部署操作手册

> 适用对象：首次上线 + 日常运维。
> 契约来源：[`openspec/changes/build-data-pipeline/specs/data-distribution-api/`](../../openspec/changes/build-data-pipeline/specs/data-distribution-api/)
> 简版清单见 [`../README.md`](../README.md)；本文是逐步操作级细节。

---

## 0. 前置条件

| 项 | 要求 | 说明 |
|---|---|---|
| Cloudflare 账号 | 免费版足够 | [dash.cloudflare.com](https://dash.cloudflare.com) 注册 |
| Node.js | ≥ 22 | 含 npm 与 npx |
| 数据包 | `etl/dist-full/vYYYYMMDD.xxxxxxxx/` | 构建方法见「附录 A」 |
| 自定义域名(可选但强烈建议) | 托管在 Cloudflare 的域名 | 见 §6；workers.dev 在国内可达性差 |

公司内网/代理环境注意：若终端走了 HTTP 代理（表现为 localhost 请求被 Squid 拦截），curl 本地服务时加 `--noproxy '*'`；wrangler 需要外网时确认 `HTTPS_PROXY` 指向可用代理。

---

## 1. 登录 Cloudflare

### 方式 A：浏览器 OAuth（本地开发推荐）

```bash
cd server
npx wrangler login
```

会打开浏览器授权。成功后验证：

```bash
npx wrangler whoami
# 预期输出包含你的账号邮箱与 Account ID
```

### 方式 B：API Token（无头环境 / CI）

1. Dashboard → 右上角头像 → **My Profile** → **API Tokens** → *Create Token*
2. 权限配置（最小权限原则）：
   - `Account → Workers R2 Storage → Edit`
   - `Account → Workers Scripts → Edit`
   - （仅当用 routes 方式绑域名时另加 `Zone → Workers Routes → Edit`）
3. 记下两个值：
   - Token 本身 → 之后作为 `CLOUDFLARE_API_TOKEN`
   - 账号页右侧的 **Account ID** → 作为 `CLOUDFLARE_ACCOUNT_ID`

```bash
export CLOUDFLARE_API_TOKEN="你的token"
export CLOUDFLARE_ACCOUNT_ID="你的账号ID"
npx wrangler whoami   # 验证
```

---

## 2. 创建 R2 Bucket

名称必须与 `server/wrangler.toml` 中 `bucket_name` 一致（默认 `poetry-mate-data`，改哪边都行，保持一致即可）。

```bash
npx wrangler r2 bucket create poetry-mate-data
```

或 Dashboard 操作：**Storage & Databases → R2 → Create bucket**，位置选 **APAC**（对国内用户更友好）。

> 免费额度：10 GB 存储 / 每月 100 万次写 / 读无限。本项目每版本约 65MB × 保留 3 版，远在额度内。

---

## 3. 部署 Worker

```bash
cd server
npm install          # 首次
npm run deploy       # = npx wrangler deploy
```

成功输出形如：

```
Uploaded poetry-mate-data (x.xx sec)
Published poetry-mate-data (x.xx sec)
  https://poetry-mate-data.<你的子域>.workers.dev
```

**立即冒烟**（此时还没数据，应返回 503 而不是报错）：

```bash
curl https://poetry-mate-data.<子域>.workers.dev/health
# {"ok":true,"service":"poetry-mate-data"}

curl https://poetry-mate-data.<子域>.workers.dev/api/v1/catalog
# {"error":"no_version_published"} ← 正确语义
```

---

## 4. 上传数据包并切换版本指针

一键脚本（逐文件上传 → **最后**原子重写 `/current` 指针）：

```bash
./scripts/upload-version.sh ../etl/dist-full/v20260825.b8594f81
```

脚本内部等价于：

```bash
V=v20260825.b8594f81
npx wrangler r2 object put "poetry-mate-data/$V/manifest.json" --file "$DIST/manifest.json" --remote
# …逐卷、aliases/pending-review/build-issues 同理…
printf '{"version":"%s"}' "$V" > current.json
npx wrangler r2 object put "poetry-mate-data/current" --file current.json --remote
```

**要点**：指针永远最后写——在此之前所有客户端看到的仍是旧版本；
这就是回滚不需要动 Worker 代码的原因。

上传后跑一遍线上验收：

```bash
./scripts/acceptance.sh https://poetry-mate-data.<子域>.workers.dev
# 预期: 通过 14, 失败 0
```

---

## 5. 接口速查

| 端点 | 说明 | 缓存 |
|---|---|---|
| `GET /health` | 存活探针 | 无 |
| `GET /api/v1/catalog` | 版本号 + 全部作品集清单(seed 带 builtin 标记) | max-age=60 |
| `GET /api/v1/collections/:id/manifest` | 单集分卷清单(file/sha256/bytes/records) | max-age=60 |
| `GET|HEAD /volumes/:collection/:file.zst` | 分卷下载 | max-age=1y, immutable |

非 GET/HEAD 一律 405。任何路径 miss 都是统一 404 JSON，不泄露存储结构。

---

## 6. 绑定自定义域名 ⭐（国内可达性关键步骤）

`*.workers.dev` 在大陆时通时断，**正式使用必须绑自定义域名**。

### 前提

一个 DNS 托管在 Cloudflare 的域名（没有就把现有域名 NS 切过来，免费计划够用）。

### 操作（Dashboard 方式，自动签发证书）

1. Dashboard → **Workers & Pages** → `poetry-mate-data` → **Settings**
2. **Domains & Routes** → **Add** → **Custom domain**
3. 输入如 `data.你的域名.com` → Confirm
4. 等待证书签发（通常 <2 分钟）

### 验证

```bash
curl https://data.你的域名.com/health
./scripts/acceptance.sh https://data.你的域名.com     # 远程全量复验
```

### 回退策略

APP 端数据源 base URL 支持多候选时：自定义域为主，workers.dev 为备。
两者指向同一 Worker，数据完全一致。

---

## 7. 配置 GitHub CI（自动构建发布）

仓库 → Settings → Secrets and variables → Actions → New repository secret：

| Secret | 值 |
|---|---|
| `CLOUDFLARE_API_TOKEN` | §1 方式 B 创建的 token |
| `CLOUDFLARE_ACCOUNT_ID` | §1 记下的 Account ID |

触发验证：

```bash
gh workflow run etl.yml -f publish=true
gh run watch        # 或去 Actions 页面看
```

流水线行为：拉上游最新 → ETL 构建 → 门禁+抽检 → 自动发布到 R2 并切指针 →
失败自动建 issue（含现场 artifact）。每周一 UTC 03:00 自动执行。

---

## 8. 日常运维

### 发布新版本

正常情况 CI 自动完成。手动发布见 §4；只构建不发布的 CI：
`gh workflow run etl.yml -f publish=false`。

### 回滚

R2 保留最近 ≥3 个版本目录，回滚 = 重写指针（秒级生效于缓存过期后）：

```bash
printf '{"version":"<旧版本号>"}' > current.json
npx wrangler r2 object put "poetry-mate-data/current" --file current.json --remote
```

### 审阅数据质量工件

每个版本目录下三个 JSON 工件（也是 APP 包外随附的运维接口）：

| 文件 | 内容 | 处理 |
|---|---|---|
| `aliases.json` | 文本修订导致的 ID 映射(from→to) | 无需动作，客户端自动归一 |
| `pending-review.json` | 无法自动判定的 ID 变更 | **人工审阅**：对照上游 diff 决定是否手工补 alias |
| `build-issues.json` | rank 错位置空卷 + 跳过的脏记录 | 关注数量趋势；置空热度会在上游修复后自愈 |

### 监控与额度

Dashboard → Workers & Pages → poetry-mate-data → **Metrics**（请求/错误/CPU）；
R2 页面看存储量。建议 Notifications 里配 Worker error > 0 与 R2 存储 > 5GB 邮件告警。
CI 时长：每次约 8 分钟，私有仓库月度 2000 分钟额度可覆盖每周频率。

---

## 9. 故障排查

| 症状 | 可能原因 | 处理 |
|---|---|---|
| `/health` 都打不开(workers.dev) | 国内网络波动 | 绑定并改用自定义域名(§6) |
| catalog 返回 `no_version_published`(503) | 忘了传 `/current` 指针，或 bucket 名不一致 | 核对 §2/§4；`wrangler r2 object get poetry-mate-data/current --remote` 验证 |
| catalog 版本迟迟不更新 | 60s 缓存 + 边缘缓存未过期 | 等 1 分钟或加查询参数 `?t=$(date +%s)` 强制穿透 |
| 上传单个对象 403 | Token 权限不含 R2 Edit | 按 §1 方式 B 重建 token |
| 某卷下载后 sha256 不符 | 上传中断留下半截文件 | 重新 put 该卷，再跑 acceptance 复验 |
| `wrangler login` 浏览器打不开/卡住 | 内网代理拦截 | 设 `HTTPS_PROXY` 后重试；或改走 §1 方式 B |
| GitHub Action publish 报 403 | secrets 未配或 token 过期 | 核对 §7 表格两项 |

---

## 附录 A：获取数据包

```bash
cd etl
make install
.venv/bin/python -m poetry_etl build --commit <上游sha> --out dist-full
# 产物: dist-full/<version>/ ；构建内含自动门禁，失败即退出
```

不指定 commit 时用 `--ref master`（受 GitHub API 匿名限流约束，生产建议显式给 sha，
或直接依赖 CI 的自动解析——CI 内有 GITHUB_TOKEN，限额充足）。

## 附录 B：目录与对象布局

```
R2 bucket
├── current                              {"version":"vYYYYMMDD.aaaaaaaa"}  ← 唯一的发布开关
└── vYYYYMMDD.aaaaaaaa/
    ├── manifest.json                    版本全局清单(逐卷 sha256/bytes/records)
    ├── aliases.json                     ID 漂移映射(客户端自动归一)
    ├── pending-review.json              待人工复核的 ID 变更
    ├── build-issues.json                rank错位/脏记录登记
    └── volumes/
        ├── tangshi/tangshi.NNNN.json.zst
        ├── songshi/songshi.NNNN.json.zst
        ├── songci/songci.NNNN.json.zst
        └── seed/seed.0001.json.zst      APP 内置种子集同源产物
```
