# 阅读页 AI 赏析与个人注本

## Why

骨架版阅读页只有"看"——而本产品的灵魂是「似懂非懂 → 一戳即解 → 沉淀为个人注本」。
BYOK 架构（用户自配 OpenAI 兼容供应商）让这层能力**零服务器成本**：LLM 流量由 APP 直连用户自己的账号，
服务端继续对用户一无所知。同时补齐阅读体验的两块基石：收藏与白文/字号偏好。

## What Changes

- **LLM 客户端**：OpenAI 兼容 Chat Completions 调用（JSON 结构化输出 + SSE 流式），baseUrl/API Key/model 三元组由用户配置，Key 存系统安全存储；
- **三层渐进披露**（specs 核心体验）：
  - L1 点句即释 —— 点击任意诗句，行内浮出该句白话直译 + 关键词注；
  - L2 结构化赏析 —— 「赏析」页签呈现 分节赏析（大意/炼字/意境），一次生成永久缓存；
  - L3 追问对话 —— 带全文与已生成赏析上下文的自由追问；
- **个人注本**：所有生成内容持久化为用户资产，可编辑、编辑后不受 AI 覆盖；
- **人格初版**：先生 / 知音 / 词客 三套 prompt 模板（随安装包分发），作用于全部 AI 内容；
- **幻觉护栏**：prompt 强制分区 —— 文本内艺术分析为主，创作背景类史实断言必须带不确定性措辞；
- **收藏**：阅读页点心 ↔ 收藏页列表真实化；
- **阅读偏好**：白文模式（去标点展示开关）、正文字号设置（持久化）。

## Capabilities

### New Capabilities

- `llm-client`: BYOK 配置的安全存储与 OpenAI 兼容调用契约
- `poem-annotation`: 三层渐进披露、结构化赏析与个人注本的持久化/编辑
- `favorites`: 收藏的标记、取消与列表
- `reading-preferences`: 白文模式与正文字号的持久化偏好

### Modified Capabilities

（无 —— 现有能力的需求不变）

## Non-goals

- 多轮长对话记忆管理（L3 仅带当前诗上下文的轻量会话）
- 注本云备份 / 导出（v2）
- 共享注本社区（v3）
- Android/iOS 之外的桌面端适配
- 语音朗读、字体切换（仅保留文楷）

## Impact

- 新增依赖：`dio` 或沿用 `http`（SSE 需流式读取）、`flutter_secure_storage` 已就位
- 数据库新增表：`notebook_entries`、`favorites`（schema v2 迁移）
- 设置页从占位真实化；阅读页重构为三层结构
- 人格 prompt 模板进入 `assets/personas/`
