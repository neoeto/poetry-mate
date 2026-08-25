# APP 骨架与种子集

## Why

数据管道产出的是"死"的数据包，产品的价值必须由手机上的应用来兑现。本项目需要一个 Flutter 工程骨架，并且它有一个苛刻的冷启动要求：**断网安装后打开即读**——这依赖种子集装载、本地诗库和基础阅读界面在最简形态下全部就位。这一变更同时钉死整个 APP 的架构接缝（状态管理、数据库、路由、主题字体双轨），后续所有特性变更都在这个骨架上生长。

## What Changes

- **Flutter 工程骨架**：特性优先薄分层目录结构、Riverpod 状态管理、drift 数据库接入、go_router 路由；
- **本地诗库**：SQLite poems 表（含迁移框架）、诗实体与仓库层；
- **种子集装载器**：解压安装包内置的 `seed.json.zst` → 事务入库，带版本标记保证幂等；
- **导航壳**：底部四 Tab（今日占位 / 分类 / 收藏 / 我的）与空状态占位页；
- **浏览与简读页**：按朝代/类型浏览种子集；简读页呈现排版基线（一句一行、大字号、宽行距、霞鹜文楷正文）；
- **字体双轨制落地**：内容层霞鹜文楷（内置子集版）、界面层系统黑体。

## Capabilities

### New Capabilities

- `app-foundation`: 导航壳、主题与字体双轨、分层架构约束等应用级地基
- `seed-library`: 种子集装载、本地诗库表结构与断网可用性

### Modified Capabilities

（无 —— 本变更不触碰既有能力）

## Non-goals

- 完整排版工艺（收藏、白文模式、字号设置、序文降级呈现等归 `reading-page` 变更）
- 导入向导与云端 catalog 交互（`import-wizard` 变更）
- 检索（FTS/bigram 归 `search` 变更）
- 一切 LLM 能力与 BYOK 配置（`ai-annotation` 变更）
- 今日推荐的真实策展逻辑（`today-feed` 变更；本变更中"今日"Tab 为占位）
- 古籍直排、注本导出等 v2 特性

## Impact

- 新增 Flutter 工程（仓库根目录 `app/` 或根目录即工程，随实现定），引入依赖：flutter_riverpod、drift + sqlite3_flutter_libs、go_router、es_compression（zstd 解码，后续 import-wizard 复用）、flutter_secure_storage（本变更仅接线）
- 消费 `build-data-pipeline` 的 seed 包产物（该变更未实现前，可用手工构造的样例种子包先行开发，字段契约以 spec 为准）
- 为后续全部 APP 变更确立目录结构与分层约定
