## Why

诗库已经保存在手机本地，但用户目前只能按朝代和类型逐层浏览，无法直接通过诗名、作者或熟悉的诗句找到目标作品。增加本地搜索可以让种子集和导入书架都具备即时、离线可用的查找能力。

## What Changes

- 为 `PoemRepository` 增加本地关键词搜索接口。
- 在「分类」页增加搜索入口和搜索结果页。
- 支持按诗名、作者、词牌、正文和题材标签匹配。
- 展示搜索加载态、空结果态和结果列表；点击结果进入现有阅读页。
- 对用户输入进行通配符转义，避免 `%`、`_` 等字符改变查询语义。

## Non-goals

- 不实现联网搜索或 AI 兜底搜索。
- 不修改诗库 schema、诗词数据或 FTS 索引结构。
- 不增加搜索历史、热词推荐或跨设备同步。
- 不改变现有朝代/类型筛选和阅读路由。

## Capabilities

### New Capabilities

- `poem-search`: 本地诗词关键词搜索及搜索界面。

### Modified Capabilities

- `seed-library`: 诗仓库从最小浏览接口扩展为提供本地关键词搜索。

## Impact

- Flutter `PoemRepository` 与 Drift 查询实现。
- 分类页 AppBar 和新的搜索 delegate/UI。
- 新增仓库单元测试、搜索 Widget/集成测试。
- 搜索只读取 APP 本地 SQLite，不涉及 Worker、R2 或 LLM。
