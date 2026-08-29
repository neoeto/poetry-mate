# 设计 —— AI 解析流式输出

## Context

三层赏析的调用链现状：

- L3 追问：`AnnotationService.streamQuestion` → `LlmClient.streamChat` → `extractSseContent`（SSE）→ `ChatSheet` 逐增量渲染。**已流式**。
- L1/L2/选词：`_completeAndParse` → `LlmClient.complete`（非流式 + json_object）→ 全文到手才 `tryParse` → UI 拿 `Future<T>`（FutureBuilder + 骨架屏/转圈）。

可复用的既有设施：`LlmTransport.postStream`（字节流）、`extractSseContent`（帧解析，静默跳过噪声行）、
`ChatDelta(replace: true)`（降级替换语义）、`stripJsonFences/tryDecodeJsonObject`（全文解析）、
`_completeAndParse` 的两段式重试（attempt 0 带 jsonMode，attempt 1 纯提示词约束）与
`AnnotationParseException` 纯文本降级。

约束：结构化 JSON 无法直接渲染半截文本；BYOK 下供应商能力参差（response_format 支持度不一）；
注本落库与护栏语义不可变。

## Goals / Non-Goals

**Goals:**

- L1/L2 首次生成（含手动重新生成）以流式渐进呈现，弱网下首屏等待从"全文完成"缩短到"首字段闭合"
- 流式失败自动降级为非流式补全，解析失败沿用现有重试/纯文本降级路径，对外错误契约不变
- 落库、护栏（诗文外词过滤、选区校验）、user_edited 保护语义与现状完全一致
- 补齐流式传输的超时保护（首字节/帧间），chat 同步受益
- 中途关闭浮层即取消订阅

**Non-Goals:**

- 选词解释（`getOrCreateSelectedWordNote`）不流式（短文本，见 proposal）
- 不渲染未闭合字段的残缺文本（不做流式 JSON "打字机"裸输出）
- 不改变缓存命中路径（命中仍同步直读、零请求）
- 服务端零改动

## Decisions

### D1: 事件模型 —— partial 快照 + 终态事件，单 Stream

新签名（service 层）：

```
Stream<AnnotationEvent<T>> streamAnnotation(...)
// 事件:
//   AnnotationReset            —— 新的重试轮次开始，UI 清空已显示的 partial
//   AnnotationPartial(T partial, Set<String> closedKeys) —— 已闭合字段的快照
//   AnnotationDone(T content)  —— 终态：完整解析+护栏校验+落库后的最终结果
// 失败: Stream 抛 LlmException（含 AnnotationParseException），契约与现在一致
```

- 选择"每次增量后重算 partial 快照"而非"字段级 diff 事件"：实现简单、UI 无需自行累积，
  JSON 体量（KB 级）下每帧重解析成本可忽略。
- 终态用事件而非 Stream 返回值（Dart Stream 无法同时给 T 与进度）：`AnnotationDone` 携带最终值。
- `closedKeys` 用于区分"还没生成到"与"模型没给"（现有 UI 对空串显示"模型未提供此部分内容"，
  流式中会闪现，必须以此区分）。
- 现有 `getOrCreateEssay` / `getOrCreateLineNote` 保留为薄包装（内部收集 Stream 直到 Done），
  非 UI 调用方与既有测试零改动。

### D2: 部分 JSON 解析 —— 前缀修复纯函数

新增纯函数 `tryDecodePartialJsonObject(String raw) → ({Map<String,dynamic> json, Set<String> closedKeys})?`：

- 扫描字符流，跟踪字符串/转义/括号深度；把开放状态逐一闭合（字符串加 `"`、数组/对象加对应闭括号）后 `jsonDecode`；
- 只取从首个 `{` 起的前缀（天然容忍 ` ```json ` 围栏前导文本）；仅产出**已完整闭合**的 key 与数组元素
  （未闭合的尾元素舍弃，下一帧自然补全）；
- 解析失败返回 null，调用方静默沿用上一次成功快照；
- 流结束后的全文解析仍走现有 `stripJsonFences + tryDecodeJsonObject`，两套职责不混。

备选被否方案：每字段独立流式协议（让模型按行输出 NDJSON）——改变了 prompt 契约与所有供应商兼容性假设，得不偿失。

### D3: 重试与降级编排

```
attempt 0: streamChat(jsonMode: true)
  ├─ 传输/HTTP 错误 ──────────→ fallback: complete(jsonMode: true)，成功则进入解析，失败按 attempt 1 继续
  ├─ SSE 正常但内容为空 ──────→ 同上（对齐 streamQuestion 的"流式返回为空"处理）
  └─ 完成 → 全文解析
        ├─ 成功 → 护栏校验 → upsert → AnnotationDone
        └─ 失败 → attempt 1（附纠正提示、不带 jsonMode）：同样先流式；
                  二次失败 → AnnotationParseException(rawText)
```

- 每次新 attempt 先发 `AnnotationReset`，避免第二轮 partial 与第一轮残片混排（复用 ChatDelta.replace 的经验教训）。
- `_completeAndParse` 的重试骨架保留，流式只是"取 raw"这一步的另一种实现。

### D4: 传输超时 —— 首字节 + 帧间

`postStream` 对响应体施加两段超时：首字节（复用 receiveTimeout 语义）与帧间 idle（默认 30s，可配），
超时映射为 `LlmException(network)`。用 `Stream.timeout` 逐事件实现，chat 的 `streamQuestion` 自动受益。
备选被否方案：只在 UI 层做看门狗定时器——错误会被吞成 UI 态，service 层无法感知并降级。

### D5: UI 消费 —— 手动订阅 + 状态机

- `EssayTab` / `LineNoteSheet`：State 内持 `StreamSubscription`；状态机
  `loading(骨架/转圈) → streaming(partial 渲染) → done(现有 EssayContentView/_LineNoteResult) → error(现有错误态)`。
- 首个 Partial 到达前保持现有骨架屏；streaming 态复用现有内容组件，仅按 `closedKeys` 显隐各节，
  未闭合节显示轻量"生成中…"占位；编辑/重新生成按钮仅在 done 态出现。
- `dispose` 与重试/重新生成都先 `cancel()` 旧订阅再重开（取消即停止读取下游 token 流）。
- `onContentReady` / `onNoteReady`（原文下划线标记依赖）仅在 `AnnotationDone` 触发一次，时机语义不变。

### D6: SSE 供应商噪声容忍

沿用 `extractSseContent` 现行为：无 content 的帧（finish_reason、心跳、注释行）静默跳过；
流早终止导致内容为空 → 按 D3 降级，不新增对 error 帧的主动解析（保持最小改动）。

## Risks / Trade-offs

- [部分供应商不支持 json_object+stream 组合，返回纯文本] → attempt 0 解析失败自然落入 attempt 1
  （纯提示词约束）路径；与现有非流式的降级逻辑同构，不新增分支
- [partial 快照每帧全量重算] → JSON 体量 KB 级、SSE 帧频有限，成本可忽略；如实测卡顿再引入"仅帧内含
  结构字符才重算"的短路优化
- [降级时 partial 已显示半截内容] → `AnnotationReset`/替换语义保证不重复不残留（ChatDelta.replace 先例）
- [帧间超时误伤深度思考型模型的静默间隔] → idle 阈值取 30s（显著大于常规 token 间隔）且可配；
  超时后仍走非流式降级而非直接报错
- [UTF-8 多字节字符被 SSE 帧边界劈开] → `extractSseContent` 已用 `Utf8Decoder(allowMalformed)` +
  行缓冲处理；partial 解析只作用于已解码字符串，不受影响
- [测试面扩大] → fakes 的流式脚本能力（分帧序列、跨帧 JSON、中途断流）是本变更的交付物之一，先行落地

## Migration Plan

纯客户端行为增强，无 schema/数据迁移。实现按 tasks 分阶段合入：传输超时（独立可先行）→
客户端 jsonMode+stream → partial 解析纯函数 → service 编排 → UI。任一阶段回滚 = revert 对应提交，
对数据与缓存零影响。

## Open Questions

（无 —— 选词解释不流式、展示粒度采用 partial 快照渲染两点已与需求方确认）
