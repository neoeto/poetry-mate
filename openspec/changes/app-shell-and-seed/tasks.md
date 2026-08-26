# Tasks：APP 骨架与种子集

## 1. 工程骨架

- [x] 1.1 初始化 Flutter 工程（确定仓库布局：根目录 or `app/` 子目录），配置 lint 规则与目录结构（core/domain/data/features）
  - 布局决策: `app/` 子目录(与 etl/server 并列的 monorepo); flutter create --platforms android,ios
  - 依赖已解析: riverpod/drift/sqlite3_flutter_libs/go_router/secure_storage/shared_prefs/es_compression
  - 环境坑固化: 公司代理劫持 tester WebSocket → app/Makefile 统一卸代理跑 test/run
- [x] 1.2 接入依赖：flutter_riverpod、drift + sqlite3_flutter_libs、go_router、es_compression、flutter_secure_storage、shared_preferences
  - 另加 path_provider(数据库文件路径); 版本经 pub add 自动解析(drift 2.34.3 / go_router 17.5 等)
  - 踩坑: 批量 replace 把 dev_dependencies 搅碎 → pubspec 整体重写修复;
    drift_dev 与 sqlparser 0.44.6 不兼容(DartPlaceholder.when 移除) → dependency_overrides 钉回 0.44.5
- [x] 1.3 建立 Riverpod ProviderScope、go_router 路由表与 Material 3 主题桥（亮/暗双色板）
  - StatefulShellRoute.indexedStack 四 Tab(状态保持) + 阅读页顶层深链 /poem/:id
  - M3 双色板(宣纸白/墨黑,种子色黛绿) + 字体双轨常量 PoetryFonts.content(文楷,3.x 打包后生效)
  - themeModeProvider 就位(设置页持久化归后续); 3 个导航壳冒烟测试

## 2. 数据地基

- [x] 2.1 drift 定义 poems 表（schema v1 迁移基线）与诗实体类，字段对齐 seed-library spec
  - Poems 表 12 字段(id主键/JSON数组列/可空列显式null) + AppDatabase(schemaVersion=1, 构造器注入内存库可测)
  - 领域实体 Poem(纯净值对象): fromPackageJson(种子装载路径)/displayTitle 回退词牌/isCi
  - PoemMapper 行↔实体映射(build_runner codegen 已跑通)
  - 6 个 schema 基线测试: 往返含null/主键冲突/upsert重灌/词类null语义/Companion.absent; analyze 零问题
- [x] 2.2 实现 PoemRepository：按 id 获取 / 按朝代类型列出 / 全量计数；配内存数据库单元测试
  - 接口刻意最小(spec 明令不含关键词检索,FTS 归 search 变更)
  - 列表排序: 热度降序 + id 升序兜底(null 热度自然殿后); 4 个仓库测试全绿
- [ ] 2.3 集成 zstd 解压能力并在 Android/iOS 双端真机验证（design D4 风险前置）
  - 进度: es_compression 已接入(ZstdDecoder.convert), 解压函数可注入设计;
    宿主探测确认 mac 缺 eszstd-mac64.dylib(测试优雅跳过); 真实资产就位
  - ⬜ 待办: Android/iOS 真机各跑一次装载冒烟, 确认 FFI 加载成功
- [x] 2.4 实现种子装载器：读资产 → 解压 → 单事务 upsert → 写 seed_version 标记；含"同版本跳过""高版本重灌"两条路径的测试
  - SeedLoader: version.txt 对账 → 解压(可注入) → 单事务 insertOnConflictUpdate → 成功后才写标记
  - 6 个路径测试: 首装/同版跳过(零解压)/升级upsert/事务失败回滚/无资产静默跳过/1000条性能
  - 真实资产已内置: assets/seed/{seed.json.zst=54KB, version.txt=v20260825.b8594f81}(来自 dist-full)

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
