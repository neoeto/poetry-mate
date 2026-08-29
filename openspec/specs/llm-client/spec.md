# llm-client Specification

## Purpose
TBD - created by archiving change reader-ai-annotation. Update Purpose after archive.
## Requirements
### Requirement: BYOK 配置的三元组存储
应用 SHALL 提供配置界面收集 `baseUrl`、`API Key`、`model` 三元组。API Key MUST 存储于系统安全存储（钥匙串/Keystore），MUST NOT 出现在 shared_preferences、数据库、日志或任何非 LLM 请求头中；baseUrl 与 model 可存于普通偏好存储。三元组任一缺失时，AI 功能入口 SHALL 呈现温和的引导态而非报错。

#### Scenario: 保存配置后 Key 不落明文可扫位置
- **WHEN** 用户保存完整三元组后检查 shared_preferences 与数据库内容
- **THEN** API Key 不以明文出现在其中，且能从安全存储读回原值

#### Scenario: 未配置时 AI 入口为引导态
- **WHEN** 用户未配置任何三元组并点击「问 AI」
- **THEN** 展示跳转设置页的引导卡片，不展示错误弹窗

### Requirement: OpenAI 兼容 Chat Completions 调用
客户端 SHALL 以 `POST {baseUrl}/chat/completions` 发起调用，携带 `Authorization: Bearer <key>`，支持两种模式：`json_object` 结构化输出模式与 SSE 流式模式，且两种模式 SHALL 可在同一次请求中组合使用（请求同时携带 `response_format` 与 `stream: true`）。非 2xx 响应 SHALL 映射为带类型的产品化错误（网络不通 / 密钥无效 / 触发限流 / 服务异常），MUST NOT 向用户暴露原始堆栈。

#### Scenario: JSON 模式返回可解析结构
- **WHEN** 以 json_object 模式请求合法供应商
- **THEN** 返回体可被 JSON 解析且通过调用方声明的字段校验

#### Scenario: 流式模式逐段产出
- **WHEN** 以流式模式请求且供应商支持 SSE
- **THEN** 客户端按增量产出文本片段而非一次性等待全文

#### Scenario: 流式与 json_object 组合
- **WHEN** 以流式模式请求且同时声明 `response_format: {type: json_object}`
- **THEN** SSE 各帧增量 content 拼接后的完整文本可被 JSON 解析

#### Scenario: 401 映射为密钥无效
- **WHEN** 供应商返回 401
- **THEN** 抛出的错误类型为"密钥无效"，消息含供应商原文摘要

### Requirement: 连接测试
配置页 SHALL 提供一键「连接测试」：以最小请求验证三元组，并把结果（成功/具体失败原因）反馈给用户。

#### Scenario: 连接测试给出可行动的失败原因
- **WHEN** 用户填入错误 Key 并点击连接测试
- **THEN** 界面显示"密钥无效"及供应商返回的错误摘要

### Requirement: 无 Key 时功能降级
未配置三元组时，阅读/检索/收藏 SHALL 全部可用；全部 AI 入口呈引导态。MUST NOT 因无 Key 崩溃或阻塞任何非 AI 功能。

#### Scenario: 无 Key 阅读体验完整
- **WHEN** 全新安装且从未配置 LLM
- **THEN** 浏览与阅读全流程可用，AI 按钮呈现引导态

### Requirement: 流式响应超时保护
客户端 SHALL 对流式响应体施加首字节超时与帧间空闲超时，超时 MUST 映射为「网络不通」类产品化错误，MUST NOT 使流无限挂起。超时阈值 SHALL 可配置。

#### Scenario: 帧间停滞超时终止流
- **WHEN** 供应商建立连接后长时间不发送任何数据帧，或帧间停滞超过空闲阈值
- **THEN** 客户端以「网络不通」类错误终止流，调用方可执行降级或向 UI 呈现可重试错误

#### Scenario: 正常流式不受超时影响
- **WHEN** 供应商持续按正常间隔发送 SSE 帧
- **THEN** 全程不触发超时，流完整消费至 [DONE]
