# seed-library 规格说明

## Purpose

内置种子集装载(幂等+版本标记)与本地诗库表结构。

# 种子集诗库（seed-library）

## Requirements

### Requirement: 内置种子集随安装包分发
安装包 SHALL 内置种子集数据资产（`assets/seed/seed.json.zst`，zstd 压缩 JSON，格式与 build-data-pipeline 的分卷产物同构）；首次启动 SHALL 自动完成装载，全程无需网络与用户操作。

#### Scenario: 全新安装离线装载
- **WHEN** 全新安装应用且设备无网络，用户首次启动
- **THEN** 本地诗库包含约 300 首种子集诗，可直接打开阅读

#### Scenario: 装载耗时不可感知
- **WHEN** 首次启动触发种子装载
- **THEN** 装载在后台完成后即就绪，不阻塞首帧渲染超过可感知时长

### Requirement: 装载幂等与版本标记
应用 SHALL 记录已装载的种子版本号；同一版本重复启动 MUST NOT 重复写入数据；当资产内种子版本高于已装载版本时 SHALL 重新执行装载。

#### Scenario: 二次启动零重复写入
- **WHEN** 种子已装载后再次启动应用
- **THEN** 不发生任何数据写入，启动路径不含解压逻辑

#### Scenario: 种子版本升级触发重灌
- **WHEN** 应用升级带来更高版本的种子资产
- **THEN** 首次启动重新装载并以 upsert 方式更新诗库，不产生主键冲突与重复记录

### Requirement: 本地诗库表结构
SQLite SHALL 建立 poems 表，字段至少包含：`id`（TEXT 主键，来自数据包）、`author`、`title`、`dynasty`、`type`、`paragraphs`（JSON 数组文本）、`preface`、`rhythmic`、`popularity`、`raw_text`、`source_collection`；允许 null 的字段 MUST 以显式 null 存储。schema 变更 MUST 通过迁移框架进行。

#### Scenario: 字段完整入库可查
- **WHEN** 种子装载完成
- **THEN** 任取一条记录，上述字段均可查询且与种子包源数据一致（paragraphs 除外，其为序列化形式）

#### Scenario: 迁移基线确立
- **WHEN** 查看 drift 迁移定义
- **THEN** poems 表作为 schema v1 存在于迁移序列中，可供后续版本追加步骤

### Requirement: 诗实体经仓库访问
应用 SHALL 通过诗仓库（PoemRepository）提供按 id 获取、按朝代/类型列出、全量计数等最小查询能力；本阶段 MUST NOT 实现关键词检索（属 search 变更）。

#### Scenario: 按 id 获取单首诗
- **WHEN** 以某首种子诗的 id 调用仓库获取接口
- **THEN** 返回字段完整的诗实体

#### Scenario: 检索能力明确缺席
- **WHEN** 审视仓库公开接口
- **THEN** 不存在任何关键词搜索方法
