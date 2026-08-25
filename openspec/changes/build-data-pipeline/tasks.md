# Tasks：构建诗词数据管道

## 1. ETL 核心（本地可跑通）

- [x] 1.1 建立 `etl/` 脚手架：Python 项目、依赖锁定（opencc 固定版本、zstandard）、`make`/脚本入口与 README 说明
  - 实施备注: Python 3.14 标准库自带 compression.zstd (PEP 784)，未引入第三方 zstandard 包；OpenCC 锁定 0.1.7
- [x] 1.2 实现规范化契约模块：NFC → 去标点（枚举集合）→ 去空白 → t2s → sha256 前 128bit；配套单元测试，用《静夜思》等固定样本断言 ID 可逐字节复现
  - 黄金向量: 静夜思 = 0bca75304901c0dd8abb1c3e98a5a3c7;16 个回归测试全绿
  - 实施中修复两个 bug: str.translate 键必须是码点整数而非字符串(曾致标点全部漏剥);
    空格 U+0020 落在两区间夹缝(已并入控制字符区间)
- [x] 1.3 实现上游下载器：按 commit 浅拉取 chinese-poetry，解析目录→作品集映射（全唐诗/全宋词等）
  - 实施前实测纠正了两个假设: 宋诗 poet.song.* 与唐诗同在 全唐诗/ 目录; rank 文件名是 *.rank.* 而非 *.rang.*
  - 真实拉取验证通过(commit b8594f81): 唐诗58卷/宋诗255卷/宋词23卷; v1 注册表冻结为这三个集子
- [x] 1.4 实现 schema 统一器：唐诗/宋词/其他集子 → 统一记录结构（id/author/title/dynasty/type/paragraphs/rawText/rhythmic/preface/popularity），缺省字段显式 null；核查并归位各集子小序到 preface
  - 小序核查结论(实测水调歌头/扬州慢/琵琶引): 上游丢弃一切小序, v1 preface 恒为 null, 字段保留作契约
  - 实施发现数据红利: 上游稀疏携带题材标签(tags: 边塞/送别/宋词三百首...), 已并入 schema 并修订 spec
  - 实测 ci.song.2019y.json 无 rank 配对 → 配对规则定为"有配对才回填 popularity, 无则 null"
- [x] 1.5 实现 rank 关联器：文件级+下标级一一对应合并，计算 popularity=log10(1+n) 之和；长度不一致即抛错终止
  - 配对规则实测落地: 卷号一致才配对; ci.song.2019y 等无编号/无配对卷 popularity=null(合法状态)
  - 作者名交叉核对为软校验(告警不阻断,上游存在别名差异); 双向长度不等长硬失败(spec 门禁)
  - popularity 量化到 3 位小数消除跨平台浮点尾差,保障构建可复现
- [x] 1.6 实现分卷打包器：≤1000 首/卷、zstd level-19 压缩、生成逐卷 sha256 的 manifest.json（版本号=日期.commit）
  - 确定性构建: manifest 无墙钟时间戳(日期在版本号内), 同输入两次构建字节级一致(单测钉死)
  - 实盘冒烟抓到并修复重大 bug: 选择性解压用首层路径做白名单,把两级路径的 rank/ 目录整个拦在快照外
    → 热度全为 null; 已改为前缀匹配 + 回归单测(_wanted) + 零配对哨兵告警三重防护
  - 小样本试跑通过: 三集子各1000条,热度填充率 100%
  - 数据观察(待任务1.9处理): 搜索引擎热度偏爱《句》类碎片条目, 种子集选样时可能需过滤
- [x] 1.7 实现别名比对器：diff 上一版产物 → aliases.json / pending-review.json；首次运行产出空 aliases
  - 判定契约: (author,title) 完全相等 + 规范化 payload 编辑距离 ≤ max(2, 5%·L) + 老 id 必须已消失且一对一消费
  - 阈值平局按旧 id 字典序决胜(确定性); 老 id 仍存活时拒绝认领(防重复收录误判)
  - 已接入 build_distribution(--prev) 与 CLI; 同输入二次构建 → 空别名(实盘验证)
- [x] 1.8 实现校验门禁：必填字段、id 正则、编码合法性检查，任一失败以非零码退出
  - 三层体检: L1 清单层(manifest/别名工件在位) → L2 卷层(sha256/字节数/记录数与登记一致) → L3 记录层
  - L3 亮点: id 可由存储的简体正文重算得出(变换链完整性), 能抓任意环节的静默篡改
  - 已接入 build 尾部自动执行(--no-gate 可跳过) + 独立 gate 子命令; 实盘通过
  - 花絮: 测试文件曾混入真实 NUL 字节导致 SyntaxError——恰好证明门禁里 NUL 检测的必要性
- [x] 1.9 实现种子集生成器：rank 全局 popularity top 300（null 不参与）→ 复用分卷打包器产出 seed 包
  - 质量规则: 排除题名《句》的碎片条目(实测样本 top300 占 2%且榜首即残句), 已同步修订 spec
  - 确定性: 排序键 (-popularity, id), 并列按 id 字典序决胜
  - 记录原样复用 → ID 与全量库天然一致(集成测试验证子集关系); manifest 新增 seed 条目(builtin=true)
  - 实盘: 300 条零碎片, 自动门禁含 seed 全绿; Stage 1 全部完成

## 2. 本地端到端验证

- [x] 2.1 小样本试跑：单卷唐诗+单卷宋词走完全流程，人工核验输出 JSON 结构符合 spec
  - 核验清单脚本化: 键序/必填非空/id 格式与可重算/raw_text 平行/词类特征(题 null 牌在)/繁体留档
  - 三集子各 1000 条零问题; tags 稀疏度实测: 唐67‰ 卷/宋29‰ 卷/词65‰ 卷
- [x] 2.2 全量构建一次（唐诗/宋词优先），记录耗时与体积，确认 Actions 免费额度可行
  - 实测: 333,179 条(唐57603/宋诗254223/宋词21053+seed300), 全程 120s, 本机即可, Actions 免费额度无忧
  - 实盘暴露并修复契约级问题: OpenCC t2s 不幂等(宫徵调语境保护字二次转换漂移, 约50条ID不符)
    → 契约修订为两阶段规范化(t2s 在哈希管道之外), spec/design 已同步; 黄金向量恰好不变
  - 数据缺陷登记机制落地: build-issues.json 共 41 处(rank错位12卷热度置空 + 脏记录跳过29条), 宁缺毋滥
- [x] 2.3 建立抽检清单：固定 20 首名篇核对繁简转换正确性（含"綺殿千尋起→绮殿千寻起"类样本），写入仓库文档供后续回归
  - spotcheck.json(20条数据驱动) + poetry_etl/spotcheck.py 独立命令; 匹配前标题/作者先转简(上游繁体存储)
  - 过程中发现两处正版异文并修正预期: 静夜思用宋版'看月光/望山月', 黄鹤楼首句'白云去'; 李煜属南唐不在v1范围,换辛弃疾青玉案
- [x] 2.4 幂等性验证：同一输入连续两次构建，除版本号外产物 sha256 完全一致
  - 实测: 两次独立全量构建 340 个文件字节级零差异(manifest 一致)
- [x] 2.5 校验种子包：数量恰为 300、schema 与 ID 和全量产物一致、可正常解压
  - 实盘六项全过: 300条/无null热度/无句碎片/id⊆主库/格式合法/schema键序; 热度区间 29.5~36.1

## 3. 分发服务（Cloudflare）

- [x] 3.1 创建 R2 bucket 与 Worker 项目脚手架（TypeScript + wrangler 配置入库）
  - server/ 工程: wrangler.toml(bucket绑定+observability)/tsconfig strict/vitest; tsc 零错误
  - 注: bucket 实际创建需用户 Cloudflare 账号, 本地开发走 miniflare 模拟不受阻
- [x] 3.2 实现 `/api/v1/catalog`：读 `/current` 版本指针返回集子清单与全局版本号，分钟级 Cache-Control
  - 指针内容做严格格式白名单(防注入); seed 条目带 builtin 标记供 APP 过滤
- [x] 3.3 实现 `/api/v1/collections/:id/manifest` 与 `/volumes/:collection/:file`（R2 直读流式返回）；404 处理不泄露内部路径；卷响应 `max-age=1y, immutable`
- [x] 3.4 方法守卫：非 GET/HEAD 一律 405；确认无任何写接口与 LLM 相关路由
  - 12 个单测全绿(FakeR2 替身): 守卫/目录/清单/下载/HEAD无体/路径白名单拒绝
- [ ] 3.5 绑定自定义域名并配置回退说明（workers.dev 仅作备份通道），写入部署文档
- [x] 3.6 上传本地 v1 数据包至版本目录，切换 `/current` 指针
  - 本地 miniflare 端到端已验证: 真实产物灌入模拟 R2 → 三接口全通 → 卷下载 sha256 与源一致
  - ⚠️ 远程上传需用户执行: `cd server && ./scripts/upload-version.sh ../etl/dist-full/v20260825.b8594f81`
    (前置: wrangler login 或 CLOUDFLARE_API_TOKEN; bucket 名与 wrangler.toml 一致)

## 4. CI 构建流水线

- [x] 4.1 编写 GitHub Actions workflow：手动触发 + 每周定时；步骤=拉上游指定 commit → ETL → 门禁 → 产物上传 artifact
  - .github/workflows/etl.yml: build(含 spotcheck/gate/摘要/artifact) + publish 两作业; concurrency 防重叠
  - 别名比对: 发布模式自动从 R2 拉回线上当前版本做 --prev(无线上版本则首次语义)
- [x] 4.2 增加"发布"作业：校验通过后将新版本目录写入 R2 并原子切换 `/current` 指针（配 Cloudflare API Token secret）
  - 复用 server/scripts/upload-version.sh; 需要 secrets: CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID
  - 触发器默认发布=true, 手动输入可关; YAML 合法 + 全部 run 块过 bash -n
- [x] 4.3 失败通知与日志留存：门禁失败时 issue 评论或通知，确保 pending-review 不被静默吞掉
  - failure() 时自动建/评论 issue(去重); artifact 总是上传(含失败现场, 7天保留)
  - Step Summary 输出构建统计(etl/summarize.py, 本地可复用)

## 5. 端到端验收与运维收尾

- [x] 5.1 编写验收脚本：curl 三接口，校验 catalog 版本、manifest sha256 与实际下载内容一致（覆盖 poem-id/data-etl/data-distribution 全部 Scenario）
  - server/scripts/acceptance.sh: 14 项检查全过(健康/守卫/目录结构与缓存/清单结构/下载sha一致/immutable/404不泄露/HEAD)
- [x] 5.2 回滚演练：发布 v2 后将指针切回 v1，验证 catalog 即时反映旧版本
  - 本地演练: 指针切至合成旧版 → catalog 即时显示旧版; 切回 → 恢复 333179 条; 无需重新部署 Worker
- [x] 5.3 别名链路演练：人为修改一卷样本正文模拟上游修订，重跑构建，确认 aliases.json 生成 from→to 映射
  - 实盘: 修改静夜思(实测原文为 牀前看月光 异体字版,位于 poet.tang.8000 卷)一字 → aliases.json
    恰好一条 from=bd27d0e4(原版ID)→to=新ID; pending-review 空; 门禁通过
  - 附带发现: 原文含异体字'牀'(非繁简关系), t2s 阶段正确归一为'床'
- [x] 5.4 沉淀运维手册 README：如何触发构建、如何回滚、pending-review 复核流程、免费额度监控方法
  - 根 README.md: 项目导览 + 运维手册(构建发布/回滚/pending-review复核/额度监控/上线待办五节)
