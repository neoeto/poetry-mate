# 设计：阅读页 AI 赏析与个人注本

## Context

APP 骨架、种子集、基线版式已就绪（app-shell-and-seed 已归档）。本变更给阅读页装上灵魂：
BYOK 直连用户自己的 LLM，把「似懂非懂」变成「一戳即解」，并把一切生成物沉淀为可编辑的个人注本。

关键既有事实：
- `flutter_secure_storage` / `shared_preferences` 已接入；
- drift schema v1 基线已确立（迁移只追加）；
- `ReaderPage` 为纯展示组件，正文走 `AppTheme.contentTextStyle`；
- 产品共识（config.yaml）：人格三选一默认知音；幻觉护栏重文本内分析；个人注本不可被静默覆盖。

## Goals / Non-Goals

**Goals:**
- BYOK 配置体验：填 base URL + API Key + model 三元组即可用，连接测试一键验证；
- 三层渐进披露完整落地（点句即释 / 结构化赏析 / 追问对话）;
- 个人注本：生成即缓存、可编辑、编辑后受保护;
- 人格系统初版与幻觉护栏;
- 收藏、白文模式、字号设置。

**Non-Goals:** 多轮长会话记忆、注本导出/云备份、共享社区、语音、字体切换。

## Decisions

### D1. 机密与非机密分离存储
API Key → `flutter_secure_storage`（钥匙串/Keystore）；baseUrl / model / 人格选择 / 白文开关 / 字号 → `shared_preferences`。
**红线**：Key 永不进日志、永不进数据库、永不经由任何非 LLM 请求头之外的方式外发。

### D2. 自研轻量 OpenAI 兼容客户端（不引 SDK）
`POST {baseUrl}/chat/completions`，支持两种消费模式：
- `response_format: {"type":"json_object"}` —— 结构化赏析/逐句注；
- SSE 流式 —— L3 对话逐字渲染。
错误映射为产品语言：`no_key / 网络不通 / 密钥无效 / 触发限流 / 服务异常 / 返回格式异常`。
**备选否决**：官方 openai dart SDK 维护滞后且塞进不需要的多模态依赖。

### D3. 生成粒度：逐句按需（L1）、整篇一次（L2）
- L1 点句即释：请求携带全文 + 目标句索引，返回该句 `{直译, 关键词注[]}`——首响快、token 省；
- L2 整篇赏析一次生成五节结构化 JSON，永久缓存。
两者都以「全文简体正文」为上下文，人格 system prompt 注入。

### D4. 注本数据模型（schema v2）
```sql
CREATE TABLE notebook_entries (
  id TEXT PRIMARY KEY,          -- sha256(poem_id|kind|target)
  poem_id TEXT NOT NULL,
  kind TEXT NOT NULL,           -- line_note / essay / chat_turn
  target TEXT,                  -- 行索引(line_note) 或问题摘要(chat_turn)
  content_json TEXT NOT NULL,   -- 结构化内容
  persona TEXT NOT NULL,        -- 生成时的人格
  user_edited INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE favorites (
  poem_id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL
);
```
**保护规则**：`user_edited = 1` 的条目，任何再生成流程 MUST 先弹确认；
删除一律二次确认。注本列表按 updated_at 倒序。

### D5. 人格 = system prompt 模板资产
`assets/personas/{xiansheng,zhiyin,cike}.md`，随安装包分发。
模板内含角色语气指令 + 幻觉护栏条款 + 输出格式要求；运行期仅拼接，不改写。
切换人格不影响已缓存条目（条目记录生成时的 persona）。

### D6. 幻觉护栏（prompt 层 + 结构层双层）
- prompt 层：明示「只基于给定文本做艺术分析；背景与典故必须以『相传/一般认为』措辞，
  无把握则留空」；
- 结构层：background 字段带 `uncertain` 布尔；解析失败即报"返回格式异常"并保留旧值。

### D7. 白文模式 = 展示层过滤
正则剔除中文标点后渲染，不动存储与检索。开关在阅读页 AppBar 一键切换。

### D8. 字号偏好
范围 20–32sp，默认 24（基线值）；持久化于 shared_prefs；阅读页即时生效。
基线版式契约（≥22sp 默认值）不受用户显式调低影响——用户主权优先，文档注明。

## Risks / Trade-offs

- [用户配错 baseUrl/模型名] → 设置页内置「连接测试」按钮，返回供应商原文错误便于自诊
- [SSE 在部分国产供应商实现不规范] → 流式失败自动降级为一次性接收
- [JSON 结构化输出不被某些兼容端支持] → 解析失败重试一次(附格式纠正提示)，仍失败则降级为纯文本展示
- [逐句点击的命中区域过小] → 行高 2.0 保证触达；整行 InkWell 而非字词级
- [注本被误删] → 删除二次确认 + 最近删除暂不做(v2)

## Migration Plan

schema v1 → v2 仅新增两张表（onUpgrade 追加 step），无破坏性变更。
设置页真实化后，「我的」占位项同步替换。

## Open Questions

- L1 是否提供「整篇预取逐句注」的批量按钮？（倾向 v1.1 观察 usage 再定）
- chat_turn 是否计入注本列表主视图？（倾向：独立对话抽屉，不入注本时间线）
