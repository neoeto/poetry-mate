# favorites Specification

## Purpose
TBD - created by archiving change reader-ai-annotation. Update Purpose after archive.
## Requirements
### Requirement: 阅读页收藏与取消
阅读页 SHALL 提供收藏切换控件：未收藏时点击加入收藏，已收藏时点击取消。状态变化 SHALL 立即持久化并即时反映在控件上。

#### Scenario: 收藏后立即持久化
- **WHEN** 用户在阅读页点亮收藏
- **THEN** favorites 表新增该诗记录，进程被杀后重开仍为已收藏

#### Scenario: 取消收藏移除记录
- **WHEN** 用户对已收藏的诗再次点击收藏控件
- **THEN** favorites 表移除该诗记录，控件回到未收藏态

### Requirement: 收藏页列表真实化
收藏页 SHALL 列出全部已收藏诗词（展示标题回退词牌、作者·朝代），点击进入对应阅读页；空态 SHALL 呈现引导文案。列表 SHOULD 按收藏时间倒序。

#### Scenario: 收藏页列出已收藏诗并可进入
- **WHEN** 用户收藏两首诗后打开收藏页
- **THEN** 两首都出现于列表，点击任意一首进入其阅读页

#### Scenario: 空收藏的引导文案
- **WHEN** 未收藏任何诗时打开收藏页
- **THEN** 展示引导空态而非报错或空白
