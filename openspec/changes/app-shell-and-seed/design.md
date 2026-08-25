# 设计：APP 骨架与种子集

## Context

这是 APP 侧的第一个变更。上游契约已由 `build-data-pipeline` 钉死：诗词 ID 内容寻址、seed 包与分卷同构（统一 schema + zstd）。本变更是后续五个 APP 变更（阅读/导入/检索/AI 赏析/今日推荐）共同的地基，核心任务是定架构接缝，而非堆功能。

关键约束：
- 冷启动零网络依赖（断网安装打开即读）
- 排版工艺的产品设定已入册 config.yaml（字体双轨、大字宽行距、一句一行左对齐）——本变更实现其基线子集
- 单人开发，拒绝过度工程

## Goals / Non-Goals

**Goals:**
- Flutter 工程骨架与分层约定，五个后续变更可直接生长
- 种子集自动装载：幂等、带版本标记、离线可用
- 简读页呈现排版基线（文楷正文 / 一句一行 / 大字宽行距）
- 四 Tab 导航壳与空状态占位

**Non-Goals:**
- 收藏/白文模式/字号设置/序文降级等完整工艺；FTS 检索；导入向导；LLM 一切
- 今日 Tab 的真实策展（占位页即可）
- 字体语料级精调子集（v1 直接用现成 GB 子集版）

## Decisions

### D1. 特性优先薄分层 + Riverpod
目录按 `core/domain/data/features` 组织；特性内部自包含 UI+Controller（Riverpod Notifier），不设全局 UseCase 层。
**备选**：Bloc（样板代码重）、Provider（维护停滞）、GetX（反模式多）——均弃。

### D2. drift + sqlite3_flutter_libs
**关键理由**：移动系统自带 SQLite 不保证编译 FTS5，且版本不可控；`sqlite3_flutter_libs` 打包现代 SQLite（FTS5 就绪，search 变更直接受益）。drift 提供类型安全查询、虚拟表支持与内置迁移框架——poems 表从本变更起进入正式迁移序列。
**备选**：sqflite（裸 SQL 字符串、底层 SQLite 版本失控）——弃。

### D3. 种子装载策略
首启动检测 `seed_version` 标记 → 无标记或资产版本更新则：读 assets 解压 zstd → 单事务 upsert 全量 300 首 → 写入新标记。二次启动零 IO 成本。
**注意**：upsert 而非 insert，保证未来"种子升级重灌"不炸主键。

### D4. zstd 解码走 es_compression（FFI）
管道产物是 zstd 格式，spec 规定 seed 包与其同构——APP 迟早要解 zstd（import-wizard 复用），本变更就建立该能力。
**备选**：seed 用纯 JSON 资产绕开解码——被否：与管道产物格式不一致，且③要重做一遍。

### D5. 字体：直接内置霞鹜文楷 GB 子集版
霞鹜文楷有现成 GB 字符集版本（约覆盖通用规范汉字表），v1 直接打包，免自制子集流程；生僻字缺失由字体栈回退系统字体兜底。
**未来线头**：若实测体积超标或生僻字回退刺眼，再做"语料字符集 ∪ 规范汉字表"的精准子集化（构建脚本归 APP 仓库）。

### D6. APP 从不计算诗词 ID
ID 由管道构建期生成并随包下发，Dart 侧只消费。别名归一（查主表 miss → 查 alias 表）在 import-wizard 引入 aliases 后才需要，本变更预留仓库层接口但不实现。

### D7. 存储分离接线
API Key 类机密 → flutter_secure_storage；其余偏好（字号、白文开关、人格选择）→ shared_preferences。本变更只搭两层存储的门面，不存放任何真实机密。

## Risks / Trade-offs

- [es_compression 在 iOS 真机的 FFI 兼容性] → 本变更早期即在双端真机验证解压链路，失败则降级为纯 JSON seed 并记录偏差（需同步修订 data-etl-pipeline 的同构性条款）
- [文楷 GB 版缺字导致回退字体视觉跳变] → 抽样 300 首种子集渲染检查；回退栈配置为思源宋体→系统字体
- [drift 学习成本 vs 项目简单性] → 仅用其基础能力（表/查询/迁移），不上代码生成高级特性也可退化为手写 SQL 常量
- [今日占位页被误认为缺陷] → 占位文案明示"策展功能将在后续版本到来"

## Migration Plan

工程初始化即入库仓库；数据库 schema v1 从本变更建立迁移基线，后续变更只追加 migration step 不改历史。种子装载逻辑自带单元测试（内存 DB 驱动）。

## Open Questions

- 工程位于仓库根目录还是 `app/` 子目录（与既有 openspec 目录共存方式）——实现首日决定
- "分类"Tab 的浏览维度初版给到多细（建议：朝代 × 类型两级，不做标签体系）
- 今日占位是否临时展示"随机一首"卡片（倾向：是，纯本地随机，零成本提升活感）
