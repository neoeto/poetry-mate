# AI 解析流式输出

## Why

L1 逐句注 / L2 整篇赏析是结构化 JSON 输出，当前走非流式 `complete()`：用户点句或切到赏析页签后，
要盯着转圈/骨架屏干等模型吐完整个 JSON（弱网下 30s+），而 L3 追问对话早已流式——同一首诗里两种 AI
体验割裂。流式基础设施（SSE 传输、解析、chat 的增量 UI）均已就绪，解析流式化只是把它接进结构化路径。

## What Changes

- **LlmClient**：`streamChat()` 增加 `jsonMode` 参数，支持 SSE 流式 + `response_format: json_object` 组合
  （不支持 response_format 的供应商沿用现有"第二次去 jsonMode 重试"路径）；
- **AnnotationService**：L1/L2 生成路径改为流式编排——逐 chunk 累积并做**部分 JSON 解析**，
  以增量事件向 UI 暴露"已完整闭合的字段"；流结束后一次性执行完整解析、护栏校验（诗文外词过滤、
  选区一致性）与注本 upsert，落库语义与现在完全一致；
- **新增纯函数**：增量 JSON 前缀解析器（把不完整 JSON 修复为可解析对象，只产出已闭合字段），独立单测；
- **UI 渐进渲染**：`EssayTab` 与 `LineNoteSheet` 从 `FutureBuilder` 改为流式消费——首字节前保留现有
  骨架屏/加载态，首字节后按字段渐进呈现（大意先出先读、白话直译先显示、关键词注逐条出现）；
- **传输层补超时**：`postStream` 增加首字节超时与帧间 idle 超时（当前流式响应体无任何超时，停滞即永久挂起）；
- **取消语义**：用户中途关闭浮层即取消订阅（停止渲染与读取）；重试/重新生成 = 重开新流。

## Capabilities

### New Capabilities

（无 —— 流式是既有赏析能力的传输方式变化，不引入新能力域）

### Modified Capabilities

- `llm-client`: 流式模式扩展为支持 json_object 组合；流式响应增加首字节/帧间超时要求
- `poem-annotation`: L1/L2 首次生成 SHALL 以流式方式渐进呈现（缓存命中仍直读不发请求）；
  流式失败 MUST 降级到非流式补全，最终落库/护栏/用户资产语义不变

## Non-goals

- **选词解释（`getOrCreateSelectedWordNote`）不流式**——单词条短文本，生成通常 <5s，收益不抵改动面
- L3 追问对话保持现状（已流式）
- 不做"半截 JSON 激进渲染"（不显示未闭合字段的残缺文本，只渲染已完整闭合的字段）
- 不改变缓存策略、幻觉护栏、注本 user_edited 保护等任何持久化语义
- 不涉及服务端/R2（解析流量本就 APP 直连 LLM）

## Impact

- 代码：`app/lib/core/llm/llm_client.dart`、`llm_transport.dart`、`annotation_service.dart`、
  `app/lib/domain/entities/annotations.dart`（新增部分解析纯函数与流式事件类型）、
  `app/lib/features/reader/essay_tab.dart`、`line_note_sheet.dart`、`reader_page.dart`（回调触发时机）
- 测试：`test/llm/`（SSE+jsonMode、跨帧 JSON、partial 解析、降级）、`test/ui/essay_tab_test.dart`、
  `line_note_test.dart` 改为流式 fake 驱动；fakes 增加流式脚本能力
- 数据存储：无新增——注本 schema、API Key 存储均不变（数据归属不变，全部在 APP 端）
- 依赖：无新增
