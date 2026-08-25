# Tasks：APP 骨架与种子集

## 1. 工程骨架

- [ ] 1.1 初始化 Flutter 工程（确定仓库布局：根目录 or `app/` 子目录），配置 lint 规则与目录结构（core/domain/data/features）
- [ ] 1.2 接入依赖：flutter_riverpod、drift + sqlite3_flutter_libs、go_router、es_compression、flutter_secure_storage、shared_preferences
- [ ] 1.3 建立 Riverpod ProviderScope、go_router 路由表与 Material 3 主题桥（亮/暗双色板）

## 2. 数据地基

- [ ] 2.1 drift 定义 poems 表（schema v1 迁移基线）与诗实体类，字段对齐 seed-library spec
- [ ] 2.2 实现 PoemRepository：按 id 获取 / 按朝代类型列出 / 全量计数；配内存数据库单元测试
- [ ] 2.3 集成 zstd 解压能力并在 Android/iOS 双端真机验证（design D4 风险前置）
- [ ] 2.4 实现种子装载器：读资产 → 解压 → 单事务 upsert → 写 seed_version 标记；含"同版本跳过""高版本重灌"两条路径的测试

## 3. 字体与排版基线

- [ ] 3.1 打包霞鹜文楷 GB 版到 assets，配置字体栈（文楷 → 思源宋体 → 系统），验证生僻字回退无豆腐块
- [ ] 3.2 建立双轨 TextTheme：内容族文楷 / 界面族系统黑体，全应用生效
- [ ] 3.3 简读页基线版式：一句一行左对齐、≥22sp、行距≥1.9、标题居中、落款偏右弱化

## 4. 导航壳与页面

- [ ] 4.1 底部四 Tab 导航壳，Tab 状态保持
- [ ] 4.2 分类页：朝代 × 类型两级浏览种子集列表，点击进简读页
- [ ] 4.3 收藏/我的占位页（友好空状态文案）；今日占位（本地随机一首卡片 + "策展功能即将到来"提示）
- [ ] 4.4 简读页接入词的长短句呈现（逐行渲染 paragraphs，序文暂按正文样式，降级呈现归 reading-page）

## 5. 验收

- [ ] 5.1 断网端到端验收：飞行模式下全新安装 → 冷启动 → 浏览 → 打开《静夜思》简读页，全程零网络请求、≤10 秒
- [ ] 5.2 二次启动路径验证：无重复写入、无解压发生（日志/断点确认）
- [ ] 5.3 双端真机过一遍全部 Scenario（app-foundation + seed-library），记录问题清单
