# Tasks：阅读页 AI 赏析与个人注本

## 1. LLM 基础设施

- [ ] 1.1 配置数据层：三元组读写（Key→secure_storage，baseUrl/model→shared_prefs），含"已配置"判定与测试
- [ ] 1.2 设置页真实化：三元组表单 + 连接测试按钮 + 保存反馈；「我的」占位项替换
- [ ] 1.3 OpenAI 兼容客户端：chatCompletion(json 模式) 与 streamChat(SSE)，错误映射六类；用假 HTTP 层写单测(成功/401/429/超时/坏JSON)
- [ ] 1.4 人格模板资产：三份 prompt 模板入 assets/personas/，PersonaService 加载与选择持久化

## 2. 数据库 v2 与偏好

- [ ] 2.1 schema v2 迁移：新增 notebook_entries / favorites 两表(字段见 design D4)；迁移测试
- [ ] 2.2 NotebookRepository：upsert/byPoem/listAll/userEdited 保护语义；单测
- [ ] 2.3 FavoritesRepository：toggle/isFavorite/listByRecent；单测
- [ ] 2.4 阅读偏好存取：白文开关 + 字号(20–32,默认24)；shared_prefs 读写单测

## 3. 阅读页三层披露

- [ ] 3.1 阅读页重构: 接收藏心形/白文开关(AppBar)/字号偏好; 现有版式测试保持全绿
- [ ] 3.2 L1 点句即释: 行 InkWell 包裹→底部浮层(直译+关键词注)→缓存命中不发请求; widget 测试(fake client)
- [ ] 3.3 L2 赏析页签: Tab切换(原文/赏析)→结构化渲染五节→生成中骨架屏→缓存命中即显; 含 uncertain 背景标识; widget 测试
- [ ] 3.4 L3 追问对话: 底部抽屉会话UI→SSE逐字渲染→失败降级一次性; 带 poem 上下文; widget 测试
- [ ] 3.5 注本编辑与保护: 条目编辑器→user_edited 标记→再生成双重确认; 删除二次确认; widget 测试
- [ ] 3.6 幻觉护栏: 三人格模板均含护栏条款; 结构解析失败重试一次后降级纯文本; 单测覆盖

## 4. 收藏与偏好接线

- [ ] 4.1 收藏页列表真实化(按时间倒序+点击进阅读); 空态保留; widget 测试
- [ ] 4.2 白文模式渲染管线(展示层正则去标点,存储不动); 单测
- [ ] 4.3 字号滑杆接入设置页并即时生效; widget 测试

## 5. 验收

- [ ] 5.1 无Key全流程回归: 阅读/收藏/白文/字号 全部可用, AI入口引导态; widget 测试
- [ ] 5.2 iOS 模拟器手测清单: 配置真实供应商→静夜思点句→赏析→追问→编辑注本→杀进程重启缓存仍在
- [ ] 5.3 幻觉抽检: 对 10 首诗生成赏析,人工审阅背景节措辞与典故把握度,记录问题
