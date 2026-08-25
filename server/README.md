# Poetry Mate 数据分发服务

Cloudflare Worker + R2。只读公开接口，把 ETL 产物稳定地送到用户手机上。
**绝不代理 LLM 流量**（BYOK 直连），对“用户”一无所知。

> 📖 **完整部署操作手册**: [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)
> —— 含登录/R2建桶/部署/上传数据包/自定义域名/CI secrets/回滚/故障排查的逐步说明。
> 本 README 只保留命令速查。

契约来源：`../openspec/changes/build-data-pipeline/specs/data-distribution-api/`

## 命令

```bash
npm install
npm run typecheck   # tsc --noEmit
npm test            # vitest
npm run dev         # 本地 miniflare(含 R2 模拟)
npm run deploy      # 部署(需 wrangler 登录)
```

## 存储布局（R2, binding=DATA）

```
/current                              {"version":"vYYYYMMDD.aaaaaaaa"}
/<version>/manifest.json              ← 构建产物原样上传
/<version>/aliases.json
/<version>/pending-review.json
/<version>/build-issues.json
/<version>/volumes/<cid>/<cid>.NNNN.json.zst
```

回滚 = 重写 `/current` 指针指向旧版本目录；保留最近 ≥3 个版本。

## 部署清单（首次）—— 详细步骤见 docs/DEPLOYMENT.md §1–§6

1. [ ] Cloudflare 控制台创建 R2 bucket（名称与 `wrangler.toml` 的 `bucket_name` 一致）
2. [ ] `npx wrangler login`（或设 `CLOUDFLARE_API_TOKEN`）
3. [ ] **绑定自定义域名**——`workers.dev` 默认域名在国内可达性差，仅作备份通道；
       在 dashboard → Workers → poetry-mate-data → Domains 添加自定义域
4. [ ] 上传首个版本：`./scripts/upload-version.sh ../etl/dist-full/<版本目录>`
5. [ ] 写入 `/current` 指针（脚本已含）
6. [ ] curl 三接口端到端验证：`./scripts/acceptance.sh https://<你的域名>`

## 缓存策略

| 端点 | Cache-Control | 理由 |
|---|---|---|
| /api/v1/catalog | max-age=60 | 分钟级，版本切换及时可见 |
| /api/v1/collections/:id/manifest | max-age=60 | 同上 |
| /volumes/** | max-age=31536000, immutable | 卷内容永不原地修改 |
