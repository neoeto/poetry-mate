# 构建诗词数据管道

## Why

poetry-mate 的所有功能（检索、阅读、AI 赏析、推荐）都以一个干净的本地诗词库为地基。原始数据源 chinese-poetry 存在三个必须在上游解决的问题：

1. **繁简混杂**：全唐诗为繁体、宋词为简体，直接入库会让 FTS 检索失效（"春风"搜不到"春風"），阅读体验割裂；
2. **Schema 不统一**：唐诗带 `id` 字段而宋词没有；缺少朝代/体裁/热度等元数据；
3. **国内直连 GitHub raw 不稳定**：APP 内置导入向导若直连 `raw.githubusercontent.com`，导入成功率无法保证。

同时，收藏、笔记、AI 赏析缓存全部以诗词 ID 为锚点——**ID 方案必须先于任何一行 APP 代码定死**，否则日后迁移成本极高。

## What Changes

建立一条云端构建流水线 + 一个数据分发服务（本变更不涉及 Flutter 端实现）：

- **ETL 构建流水线**（GitHub Actions 定时/手动触发）：拉取 chinese-poetry 原始 JSON → OpenCC 繁转简 → 统一 schema → 按规范化契约生成稳定 ID → 关联 rank 知名度数据 → 补充朝代/体裁元数据 → zstd 压缩分包 → 发布到 R2；
- **诗词 ID 规范**：内容寻址 ID = `sha256(规范化正文)` 前 128bit（32 位 hex）；配套别名表机制吸收上游文本修订导致的漂移；
- **Cloudflare Worker 分发 API**：提供作品集清单、分卷 manifest、分卷下载三类只读接口；R2 存储；绑定自定义域名保障国内可达性；
- **数据版本管理**：数据包带全局版本号 + manifest 内含每卷 sha256 校验，为后续增量更新预留钩子；
- **种子集包**：流水线额外产出 rank 热度全局 top ~300 的种子集，供 APP 内置实现开箱可读（冷启动零网络依赖）。

## Capabilities

### New Capabilities

- `poem-id`: 诗词稳定 ID 的生成规范（规范化算法契约）与别名解析规则
- `data-etl-pipeline`: 将上游原始 JSON 转换为标准化压缩分卷的构建流程
- `data-distribution-api`: APP 获取作品集清单与数据卷的 HTTP 只读接口

### Modified Capabilities

（无 —— 项目首个变更，尚无既有能力）

## Non-goals

- Flutter APP 本身的任何实现（导入向导、检索、阅读页等由后续变更承接）
- LLM 相关的一切：赏析生成、对话推荐、人格系统（APP 直连用户自配供应商，不经本管道）
- 账号体系、多设备同步、注本云备份（v2 再议）
- rank 热度数据的覆盖扩展（诗经/元曲等无热度数据集，元数据留空即可）
- 数据在线浏览界面（Worker 只提供机器接口）

## Impact

- **新增系统**：GitHub Actions workflow、ETL 脚本（Node.js 或 Python）、Cloudflare Worker 项目（TypeScript）、R2 bucket 与自定义域名配置
- **外部依赖**：chinese-poetry 仓库（上游数据）、OpenCC、zstd；均为构建期依赖，不进入 APP 运行时
- **对后续变更的契约**：下游一切功能通过 `poem-id` 引用诗词；APP 导入向导消费 `data-distribution-api`
