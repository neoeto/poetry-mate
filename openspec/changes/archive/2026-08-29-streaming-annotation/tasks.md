# 任务 —— AI 解析流式输出

## 1. 传输层：流式超时与 jsonMode（独立可先行验证）

- [x] 1.1 `llm_transport.dart`：`postStream` 响应体施加首字节超时与帧间 idle 超时（可配，默认 30s），超时映射为 `LlmException(network)`；`streamQuestion` 同步受益
- [x] 1.2 `test/llm/llm_transport_test.dart`：新增 帧间停滞超时终止流 / 正常流不受影响 两类用例（fake socket 脚本）
- [x] 1.3 `llm_client.dart`：`streamChat` 增加 `jsonMode` 参数，组合发送 `response_format: {type: json_object}` 与 `stream: true`
- [x] 1.4 `test/llm/llm_client_test.dart`：新增 SSE+jsonMode 组合用例（请求体断言 + 分帧拼接可解析）

## 2. 部分 JSON 解析纯函数

- [x] 2.1 `annotations.dart`（或新文件）实现 `tryDecodePartialJsonObject`：字符扫描 + 开放括号/字符串闭合修复，返回已闭合 key 集合与快照；容错围栏前导、未闭合尾元素舍弃
- [x] 2.2 单测覆盖：字符串中途截断（含转义 `\"`）、数组元素中途截断、嵌套对象截断、纯文本噪声前缀、空输入、合法完整输入
- [x] 2.3 验证 `EssayContent`/`LineNoteContent` 的 `fromJson` 对部分快照的宽容读取（缺字段给默认值）不抛异常

## 3. AnnotationService 流式编排

- [x] 3.1 定义事件模型 `AnnotationEvent<T>`（`AnnotationReset` / `AnnotationPartial(partial, closedKeys)` / `AnnotationDone(content)`）
- [x] 3.2 `_completeAndParse` 改造为流式编排：attempt 0 流式（jsonMode）逐帧发 partial；传输失败/空流 → 降级非流式补全；解析失败 → attempt 1（纠正提示、无 jsonMode）同样先流式；两次失败 → `AnnotationParseException`
- [x] 3.3 新 attempt 前发 `AnnotationReset`；护栏校验（`_validWordNotes`/选区一致性）与注本 upsert 仅在流结束后执行一次
- [x] 3.4 `getOrCreateEssay` / `getOrCreateLineNote` 改为收集 Stream 直到 `AnnotationDone` 的薄包装，`getOrCreateSelectedWordNote` 保持非流式不变
- [x] 3.5 `test/llm/annotation_service_test.dart`：新增 流式成功分帧产出 partial / JSON 跨帧截断 / 流中断降级非流式 / 空流降级 / 二次解析失败抛 AnnotationParseException / 落库内容等于完整结果 用例

## 4. UI 渐进渲染

- [x] 4.1 `essay_tab.dart`：FutureBuilder → 手动订阅状态机（loading 骨架 → streaming 按 `closedKeys` 显隐各节 + 生成中占位 → done 现有视图与编辑/重新生成入口 → error 现有错误态）；`onContentReady` 仅 Done 触发一次
- [x] 4.2 `line_note_sheet.dart`：同上；白话直译先出、关键词注逐条出现，`onNoteReady` 仅 Done 触发
- [x] 4.3 取消语义：dispose 与重试/重新生成先 cancel 旧订阅再重开；验证关闭浮层后无增量继续发布、注本未写入
- [x] 4.4 `test/ui/essay_tab_test.dart`、`line_note_test.dart`：fakes 增加流式脚本能力（分帧序列、中途断流），改造既有用例为流式驱动，新增渐进渲染与取消用例
- [x] 4.5 手动回归：无 Key 引导态、401/429 错误态、缓存命中直读（不发请求）三条路径不受影响

## 5. 验证与收尾

- [x] 5.1 `cd app && make test`（或 flutter test）全量通过；`flutter analyze` 无新告警
- [x] 5.2 对照 openspec/specs/poem-annotation 与 llm-client 全部 Scenario 逐条核对实现
