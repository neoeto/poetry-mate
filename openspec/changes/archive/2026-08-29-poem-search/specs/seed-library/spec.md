## MODIFIED Requirements

### Requirement: 诗实体经仓库访问
应用 SHALL 通过诗仓库（PoemRepository）提供按 id 获取、按朝代/类型列出、关键词搜索、全量计数等查询能力；关键词搜索 SHALL 只访问本地 SQLite，覆盖诗名、作者、词牌、正文和题材标签。应用 MUST NOT 为搜索请求依赖网络或 LLM。

#### Scenario: 按 id 获取单首诗
- **WHEN** 以某首种子诗的 id 调用仓库获取接口
- **THEN** 返回字段完整的诗实体

#### Scenario: 本地关键词搜索
- **WHEN** 以诗名、作者或正文关键词调用仓库搜索接口
- **THEN** 返回本地诗库中匹配的诗实体，并按稳定顺序和结果上限返回

#### Scenario: 离线仓库查询
- **WHEN** 设备无网络时调用诗仓库搜索
- **THEN** 搜索仍可读取本地结果且不发起网络请求
