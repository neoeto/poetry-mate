# poem-id 规格说明

## Purpose

诗词稳定 ID 的生成规范(内容寻址+规范化契约)与别名解析机制。

# 诗词稳定 ID 规范（poem-id）

## Requirements

### Requirement: 诗词 ID 采用内容寻址生成
系统 SHALL 以诗词的**转换后简体正文**的规范化形式的 SHA-256 哈希前 128 位（32 个小写十六进制字符）作为唯一 ID。

规范化分两阶段（2026-08 修订，原单管道顺序在实盘中被证伪——OpenCC t2s 不幂等，繁体词组语境保护字如「宮徵調」之「徵」在简体文本二次转换时漂移）：

- 阶段一（生成期）：`converted = OpenCC.t2s(原文)`，OpenCC 版本锁定；
- 阶段二（纯函数）：对转换后文本逐串执行 Unicode NFC 归一化 → 移除全部标点（显式枚举字符集）→ 移除全部空白；
- `id = sha256("|".join(canonical_strip(各段)))[0:32]`，段落边界以分隔符保留。

阶段二为纯函数，门禁 MUST 能仅凭存储正文复算 ID（变换链完整性校验），不得重复执行繁转简。

#### Scenario: 同一作品在不同集子重复收录得到相同 ID
- **WHEN** 同一首诗（正文完全一致）分别出现在两个不同的作品集中
- **THEN** 两条记录生成的 poem_id 完全相同

#### Scenario: 正文存在任意文字差异则 ID 不同
- **WHEN** 两条记录的正文存在至少一个字的差异（如异文"生处/深处"）
- **THEN** 两条记录生成不同的 poem_id

#### Scenario: ID 格式为 32 位小写十六进制
- **WHEN** 系统生成任意一个 poem_id
- **THEN** 该 ID 匹配正则 `^[0-9a-f]{32}$`

### Requirement: title 与 author 不参与 ID 计算
ID 计算的输入 MUST 仅包含序文（若有）与正文段落，MUST NOT 包含 title、author 或任何元数据字段。

#### Scenario: 作者归属修正不影响 ID
- **WHEN** 上游数据修正了某首诗的 author 字段而正文未变
- **THEN** 该诗的 poem_id 保持不变

### Requirement: 保持数据源的作品记录粒度
ETL MUST 按数据源的既有记录逐条生成 ID，MUST NOT 合并或拆分记录（组诗如《帝京篇十首》的每一首是独立记录、独立 ID）。

#### Scenario: 组诗逐首获得独立 ID
- **WHEN** 数据源中《帝京篇十首》以十条独立记录存储
- **THEN** ETL 产出十条独立记录，各自拥有不同的 poem_id

### Requirement: 别名机制吸收上游文本修订
当构建时检测到某条记录与上一版产物中 `(author, title)` 完全相等、且正文差异在编辑距离阈值内的另一条记录对应时，系统 SHALL 生成别名映射 `{from: 旧id, to: 新id}` 并随数据包发布 `aliases.json`；无法满足判定条件的 ID 变更 MUST NOT 生成别名，MUST 记入待人工复核报告。

#### Scenario: 上游修订错字后旧收藏可归一到新 ID
- **WHEN** 上游修正某诗的一个错字导致其 poem_id 变化，且 author/title 未变、差异在阈值内
- **THEN** aliases.json 中新增一条 from=旧ID、to=新ID 的映射

#### Scenario: 无法确认对应关系的变更进入人工复核
- **WHEN** 某诗的 poem_id 发生变化但 (author, title) 匹配不上任何上一版记录
- **THEN** 不生成别名映射，该变更出现在待复核报告中
