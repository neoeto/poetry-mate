# 阅读偏好（reading-preferences）

## ADDED Requirements

### Requirement: 白文模式开关
阅读页 SHALL 提供白文模式开关：开启后正文按「移除全部标点」渲染（句读自练），关闭后恢复现代标点。开关状态 MUST 持久化，且仅影响展示层——存储文本与检索 MUST NOT 受影响。

#### Scenario: 白文模式去除标点显示
- **WHEN** 开启白文模式后查看正文
- **THEN** 诗句中的标点符号不再显示，文字内容本身不变

#### Scenario: 开关状态跨启动保持
- **WHEN** 开启白文模式后杀掉应用重新打开
- **THEN** 阅读页仍以白文模式渲染

### Requirement: 正文字号偏好
设置页 SHALL 提供正文字号滑杆（20–32sp，默认 24）。调整结果 SHALL 即时作用于阅读页并持久化。

#### Scenario: 字号调整即时生效并持久化
- **WHEN** 用户将字号从 24 调至 28 并返回阅读页
- **THEN** 正文以 28sp 渲染；杀掉应用重开后仍为 28sp

#### Scenario: 默认值满足基线契约
- **WHEN** 用户从未调整字号
- **THEN** 正文以默认 24sp 渲染（满足基线 ≥22sp）
