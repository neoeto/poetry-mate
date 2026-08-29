## Context

阅读页已经能渲染 L2 `WordNote` 和用户选词解释的点状下划线，但 L1 `KeywordNote` 只有 term/explain，且 `LineNoteSheet` 的结果不会通知父级阅读页。L1 生成物已经按诗句行号缓存于 `notebook_entries`，因此只需扩展 JSON 与 UI 状态，不需要 schema 迁移。

## Goals / Non-Goals

**Goals:**

- L1 关键词注显示带声调拼音。
- L1 请求完成或读取缓存后，正文对应范围立即出现标记。
- 点击标记展示同一条关键词的词语、拼音和解释。
- 旧 L1 缓存可解析，未提供拼音时不显示错误占位。

**Non-Goals:**

- 不改变 L1 一句一行和整行点击行为。
- 不为模型未返回的词语自动编造解释或拼音。

## Decisions

### 1. KeywordNote 增加可选 pinyin，转换为渲染层 WordNote

`KeywordNote` 保持 L1 内容结构，在 term/explain 旁增加可选 pinyin。阅读页收到 `LineNoteContent` 后，将每个有效关键词转换为带 lineIndex 的 `WordNote`，复用现有精确命中和解释面板，避免维护两套高亮组件。

旧 JSON 缺少 pinyin 时默认为空；term/explain 仍然按原逻辑展示。

### 2. LineNoteSheet 通过回调通知阅读页

`LineNoteSheet` 在 Future 成功完成后调用可选 `onNoteReady`，ReaderPage 将对应行的关键词加入状态。ReaderPage 初始化时同时从已有 line_note 缓存恢复关键词，确保重启后仍有标记。回调只传结构化结果，不传供应商原始响应。

### 3. 关键词标记使用现有 WordNote 渲染

关键词转换后的 WordNote 使用 automatic 来源和当前行号；渲染器精确查找 term，点击回调打开现有词语解释面板。用户点击非标记区域仍调用原有整行 L1 抽屉。

## Risks / Trade-offs

- [同一关键词在一句中出现多次] → 沿用现有精确 term 命中策略，为所有实际命中显示同一解释，不修改原文。
- [旧模型不返回拼音] → pinyin 可选，抽屉和面板只在非空时显示拼音。
- [L1 结果在抽屉打开期间更新正文] → 只更新标记状态，抽屉保持打开；关闭后标记仍保留。
- [缓存读取失败] → 忽略无法解析的关键词，不阻塞诗句阅读和 L1 抽屉。

## Migration Plan

无需数据库迁移。新 L1 JSON 写入 pinyin，旧 JSON 按空字符串读取；回滚后未知字段会被忽略。已有 line_note 条目在阅读页打开时重新解析即可恢复标记。

## Open Questions

- 关键词标记颜色与 L2 标记保持一致，暂不区分来源颜色。
