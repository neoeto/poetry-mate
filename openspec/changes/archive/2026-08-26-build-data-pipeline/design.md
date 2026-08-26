# 设计：诗词数据管道

## Context

项目处于零代码起点。所有产品能力都依赖本地诗词库，而数据地基有三个已确认的问题：繁简混杂（全唐诗繁体、宋词简体）、schema 不一致（唐诗有 id、宋词没有）、国内直连 GitHub raw 不稳定。本设计覆盖从上游开源数据到可供 APP 消费的分发 API 的整条链路；Flutter 端如何消费不在本变更范围内。

上游事实（已实地核查）：
- chinese-poetry：5.5 万首唐诗、26 万首宋诗、2.1 万首宋词及诗经/元曲等，MIT 协议；
- 唐诗字段 `author/paragraphs/title/id`，宋词多 `rhythmic` 少 `id`；
- `rank/` 目录提供百度/必应/360/谷歌搜索结果数，与诗词文件一一文件、一下标对应（README 自述）；
- 组诗在数据源中以独立记录存储；《水调歌头》类小序的存储形态需实现时逐集核查。

## Goals / Non-Goals

**Goals:**
- 一条可重复执行的云端构建流水线：原始 JSON → 简体、schema 统一、带稳定 ID 与热度的压缩分卷
- 钉死诗词 ID 规范化契约，并用别名机制吸收上游文本修订漂移
- 一个只读、免鉴权、国内可达的分发 API（Worker + R2）
- 版本化发布与回滚能力，为增量更新预留钩子

**Non-Goals:**
- Flutter APP、LLM 赏析/推荐/人格系统（后续变更）
- 账号体系与同步；rank 数据覆盖扩展；在线浏览界面
- 增量下载的客户端逻辑（本变更只发布 alias 与 manifest，客户端消费归后续变更）

## Decisions

### D1. ETL 放在云端构建期，手机端零转换
**选择**：GitHub Actions 定期构建成品数据包。
**备选**：APP 内置 ETL（下载原始 JSON 后本地转换）——被否：耗电耗时、OpenCC 等依赖难以在双端维护、每个转换 bug 要求全部用户重跑。
**推论**：转换逻辑只需一份实现，修 bug 后发新版本即全体生效。

### D2. 诗词 ID = 内容寻址 + 规范化契约 + 别名网
**选择**：两阶段规范化 —— ① OpenCC t2s 转换（锁定版本）；② 对转换结果做 NFC+去标点+去空白的纯函数剥离；`poem_id = sha256(canonical_payload)[0..16字节]`，32 位小写 hex；序文归位到 `preface` 字段并参与哈希（拼于正文之前）；title/author 不参与。配套：
- **t2s 刻意置于哈希管道之外**（2026-08 实盘修订）：t2s 不幂等（「宮徵調」语境保护字在简体二次转换时漂移，实测约 50 条不符），ID 只取决于出货的简体阅读文本，门禁才能纯函数复算、永不漂移；
- 阶段②作为公共契约写死（含 OpenCC 版本锁定），任何重实现必须逐字节复现；
- 构建时 diff 上一版产物：`(author,title)` 完全相等且正文编辑距离小于阈值 → 发布 `aliases.json` 映射旧→新；否则进 `pending-review.json` 人工复核。
**为什么不是其他方案**：自增主键/UUID 无法跨数据集去重且重建不稳定；纯自然键 `(author,title)` 撞车严重（《无题》多首）；simhash 类模糊指纹过度设计。内容寻址天然解决重复收录归并，别名网弥补其唯一弱点（文本漂移断链）。

### D3. 分卷格式：zstd 压缩 JSON，而非预构建 SQLite
**选择**：JSON 分卷（≤1000 首/卷）+ zstd；APP 下载后自行入库。
**备选**：直接分发 SQLite 分片供 ATTACH——被否：移动端 ATTACH/WAL 兼容性坑多，且剥夺 APP 端建 FTS 索引策略的自由。
**参数**：zstd level 19（静态资产追求压缩率，解压速度仍远超网络速率）。
**种子集**：复用同一打包器额外产出 `seed` 包（popularity 全局 top 300），作为 APP 内置资产。内容寻址 ID 保证种子集与后续导入的全量库天然一致，冷启动产生的收藏/笔记在导入后无缝续接。

### D4. Worker 只做数据面，永不代理 LLM
BYOK 模式下 LLM 流量由 APP 直连用户供应商。Worker 仅提供 catalog/manifest 两个动态接口 + R2 卷直读。收益：Worker 挂了不影响读诗赏析；无密钥托管责任面。

### D5. 版本目录布局与回滚
```
R2:
  /v{date}.{commit}/volumes/{collection}/{file}.json.zst
  /v{date}.{commit}/manifest.json
  /v{date}.{commit}/aliases.json
  /current  → 指向当前版本目录（Worker 读此指针）
```
回滚 = 改指针，无需重新部署 Worker；保留最近 ≥3 个版本。

### D6. 国内可达性
绑定自定义域名；catalog 设分钟级缓存，卷设 `max-age=1y, immutable`（卷内容按版本目录隔离，永不原地修改）。workers.dev 默认域名仅作备份通道。

## Risks / Trade-offs

- [上游改数据结构] → ETL 入口做 schema 校验，任何异常 fail 整个构建，绝不发布坏包
- [OpenCC 转换错误（专名/异体字）] → 锁定 OpenCC 版本；保留 rawText 可回滚；人工抽检固定样本清单
- [rank 对应关系假设失效] → 构建时校验文件级与下标级长度一致，不一致即失败
- [别名误合并同名异作] → 判定条件从严（author+title 完全相等 且 编辑距离阈值），存疑一律进人工复核
- [26 万宋诗构建时长] → 分卷并行处理；Actions 免费额度按月评估
- [Cloudflare 国内波动] → 自定义域名 + 数据包体积控制；必要时未来增加镜像源（APP 端支持多 base URL 即可，属后续变更）

## Migration Plan

首次上线顺序：创建 R2 bucket 与 Worker 并绑域名 → 本地跑通 ETL 产出 v1 数据包 → 手动上传 R2 → curl 端到端验证三个接口 → 启用 Actions 定时任务（每周检查上游更新）。回滚：切换 `/current` 指针至历史版本。

## Open Questions

- ~~各集子小序的实际存储形态~~ → 已核查(2026-08): 上游丢弃一切小序(水调歌头/扬州慢/琵琶引三例验证), v1 preface 恒为 null, 字段保留作契约
- rank/poet 是否覆盖全部唐诗分卷——首次构建时验证数量一致性
- 五言/七言等体裁细标是否进入 v1——倾向不做，type 只到 shi/ci 粒度
- 实施新发现待定: 上游 tags 稀疏题材标签已并入 schema(见 tasks 1.4 备注), 其覆盖范围与质量在首次全量构建时评估
