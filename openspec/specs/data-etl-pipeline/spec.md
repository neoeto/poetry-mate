# data-etl-pipeline 规格说明

## Purpose

将 chinese-poetry 上游原始 JSON 转换为标准化压缩分卷的构建流程。

# 数据 ETL 流水线（data-etl-pipeline）

## Requirements

### Requirement: 消费上游原始数据并产出标准化分卷
流水线 SHALL 以 chinese-poetry 仓库指定 commit 为唯一输入，产出按作品集组织的 zstd 压缩 JSON 分卷，每卷记录数 MUST NOT 超过 1000。

#### Scenario: 处理一卷唐诗原始数据
- **WHEN** 流水线处理 poet.tang.0.json
- **THEN** 输出简体、统一 schema 的分卷文件，且可通过 zstd 正常解压

#### Scenario: 分卷大小上限
- **WHEN** 任一输出分卷的记录数超过 1000
- **THEN** 流水线构建失败

### Requirement: 统一输出 schema
每条诗词记录 SHALL 包含字段：`id`（poem-id 规范生成）、`author`、`title`、`dynasty`、`type`（shi/ci 等大类）、`paragraphs`（简体正文段落数组）、`raw_text`（繁体原文留档）、`tags`（上游稀疏题材标签，无则为 null）、`preface`、`rhythmic`（仅词）、`popularity`、`source_collection`；词类记录 SHALL 额外保留 `rhythmic`；存在序文的记录 SHALL 将序文归位至 `preface` 字段；无对应值的字段 MUST 显式为 null 而非缺失。

#### Scenario: 宋词记录补齐缺失的 id
- **WHEN** 上游宋词记录不含 id 字段
- **THEN** 输出记录携带按 poem-id 规范生成的 32 位十六进制 id

#### Scenario: 热度数据缺失时显式置空
- **WHEN** 处理无 rank 对应数据的集子（如诗经）
- **THEN** 输出记录的 popularity 字段为 null，而非字段缺失

#### Scenario: 题材标签透传保留
- **WHEN** 上游记录携带 tags 数组（如 ["宋词三百首"]）
- **THEN** 输出记录原样保留 tags；上游未携带时输出 tags 为 null

### Requirement: 繁体转简体
流水线 SHALL 使用锁定版本的 OpenCC t2s 将全部正文转换为简体中文，并在 `rawText` 中保留转换前的原文。

#### Scenario: 繁体诗句转出简体
- **WHEN** 输入诗句为"綺殿千尋起"
- **THEN** 输出 paragraphs 中该句为"绮殿千寻起"，且 rawText 保留原句

### Requirement: 关联热度数据
对存在 rank 对应关系的集子（唐诗/宋词），流水线 SHALL 按 README 自述的文件级与数组下标级一一对应规则合并搜索热度，计算归一化的 popularity 数值（各引擎结果数 log10(1+n) 求和）。

#### Scenario: 有热度数据的名篇获得非零 popularity
- **WHEN** 某宋词在 rank/ci 中登记了百度等引擎结果数
- **THEN** 输出记录的 popularity 为正数，且热度越高数值越大

#### Scenario: 对应关系校验失败则构建失败
- **WHEN** rank 文件与诗词文件的数组长度不一致
- **THEN** 流水线构建失败，不发布任何产物

### Requirement: 构建门禁与产物清单
流水线 SHALL 在发布前执行 schema 校验（必填字段、id 格式、编码合法），任何校验失败 MUST 导致构建失败；全部通过后生成 manifest.json（版本号 = 构建日期 + 上游 commit、来源 commit、逐卷 sha256 与字节数、记录数）及 aliases.json / pending-review.json。

#### Scenario: 必填字段缺失阻断发布
- **WHEN** 某条输出记录缺少 author 字段
- **THEN** 构建以非零码失败，R2 上不出现新版本目录

#### Scenario: 成功构建产出可校验的 manifest
- **WHEN** 流水线成功完成
- **THEN** manifest.json 中每个卷条目的 sha256 与实际文件一致

### Requirement: 与上一版产物比对生成别名与复核报告
每次成功构建 SHALL 与上一版产物 diff：检测到 `(author,title)` 完全相等且正文编辑距离小于阈值的 ID 变更时写入 aliases.json；其余 ID 变更写入 pending-review.json。首次构建（无上一版产物）SHALL 跳过比对并生成空 aliases.json。

#### Scenario: 首次构建不产生别名
- **WHEN** 流水线第一次运行，不存在上一版产物
- **THEN** 构建成功且 aliases.json 内容为空数组

#### Scenario: 上游错字修正产生别名映射
- **WHEN** 上一版某诗 id=A，本次构建因上游修正一个字得到 id=B，且 author/title 相等、差异在阈值内
- **THEN** aliases.json 包含 {"from": "A", "to": "B"}

### Requirement: 产出种子集数据包
流水线 SHALL 额外产出一个种子集包：取全局 popularity 最高的前 300 首（popularity 为 null 的记录 MUST NOT 参与排序；题名为《句》的碎片条目 MUST 被排除，因搜索引擎热度系统性偏爱此类残句），打包格式与普通分卷完全一致（统一 schema、zstd 压缩），供 APP 作为内置资产随安装包分发。

#### Scenario: 种子集为热度最高的名篇集合
- **WHEN** 流水线成功完成构建
- **THEN** 种子包恰好包含全局 popularity 前 300 的诗，且不含 popularity 为 null 的记录，也不含题名为《句》的碎片条目

#### Scenario: 种子包与全量库 ID 天然一致
- **WHEN** 解压种子包并与同版本全量产物比对
- **THEN** 记录结构符合统一 schema，且每首诗的 ID 与全量库中对应记录相同
