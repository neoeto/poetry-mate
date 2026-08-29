# Poetry Mate 📜

面向普通诗词爱好者的**中国古典诗词阅读与 AI 赏析**手机应用。
产品角色是"图书馆员"——帮你找到诗、读懂诗；不评判、不代笔。

> 规格与决策的唯一来源：[`openspec/`](openspec/)（spec-driven 工作流）
> 产品共识与数据归属见 [`openspec/config.yaml`](openspec/config.yaml)

## 项目结构

```
├── openspec/            规格、变更提案、任务(唯一事实来源)
├── etl/                 数据管道(Python): chinese-poetry → 标准化分卷
│   ├── poetry_etl/      download/schema/rank/pack/alias/gate/seed…
│   ├── spotcheck.json   20 篇名篇繁简转换回归清单
│   └── tests/           79 个单元测试
├── server/              分发服务(Cloudflare Worker + R2, TypeScript)
│   └── scripts/         发布 / 验收脚本
└── .github/workflows/   构建发布 CI(每周定时 + 手动)
```

核心设定：**local-first**(诗库全量在手机 SQLite) · **BYOK**(用户自配 LLM Key 直连，
流量不经服务端) · 服务端只存公共品，对"用户"一无所知。

在「分类」页点击右上角搜索图标，可按诗名、作者、词牌、诗句或题材标签搜索本地诗库。
搜索不依赖网络或 LLM，输入结果后点击诗篇即可进入阅读页。

## 快速开始

```bash
# 数据管道
cd etl && make install && make test
.venv/bin/python -m poetry_etl build --commit <sha> --out dist-full

# 分发服务(本地)
cd server && npm install && npm run dev
./scripts/acceptance.sh http://127.0.0.1:8799     # 端到端验收
```

### 阅读中的 AI 选词解释

在阅读页原文中长按或拖动选中一个字、词或短语，从系统文本菜单选择 **AI 解释**。
应用会把全诗、所在句和选区发送给用户自己配置的 OpenAI 兼容模型；成功解释后，
结果仅保存于手机本地个人注本，并在对应原文位置显示点状下划线。再次点击标记可查看、
编辑或重新生成解释。新生成的词语信息会同时展示带声调拼音，方便学习生字；没有 API Key 时仍可正常阅读，AI 入口会引导前往 LLM 配置页。

用户的选词解释、整篇赏析和个人批注不会上传到 Worker/R2；API Key 只保存在系统安全存储。

### AI 寻诗与扩展诗词库

在「我的」中打开 **AI 寻诗**，可以通过多轮对话描述想读的主题、情绪、场景或体裁，
让用户自己配置的模型从更广的中文文学中寻找一首已有作品。范围不局限于本地古诗词库，
也可包含《诗经》、古文和近现代诗歌；此功能不提供 AI 原创作诗、仿写或续写。

结果可以复用阅读页的逐句解释、整篇赏析和追问。用户可将作品保存到独立的「扩展诗词库」
（仅存本机），也可以选择仅本次查看；后者连同会话和 AI 解析都不会保存。AI 返回作品的
作者、出处、年代和文本版本可能需要核验，应用会显示相应提示。

---

## 运维手册

### Android 发布签名

GitHub Actions 的 Android release 构建必须使用固定的 release keystore；未配置签名密钥时流水线会直接失败，禁止生成无法持续更新的 debug 签名包。

完整的生成、Secrets 配置和签名排查步骤见 [`docs/android-signing.md`](docs/android-signing.md)。

在仓库 Settings → Secrets and variables → Actions 中配置：

- `ANDROID_KEYSTORE_BASE64`：keystore 文件的 base64 内容
- `ANDROID_KEYSTORE_PASSWORD`：store password
- `ANDROID_KEY_ALIAS`：key alias
- `ANDROID_KEY_PASSWORD`：key password

keystore 私钥不得提交到仓库。所有后续 APK/AAB 必须继续使用同一 keystore，否则 Android 会将其视为不同签名的应用，无法覆盖更新。若旧版本使用的签名私钥已经丢失，只能卸载旧版本后重新安装，或恢复原 keystore。

### ① 触发构建发布

| 方式 | 操作 |
|---|---|
| 自动 | 每周一 UTC 03:00 定时跑(`.github/workflows/etl.yml`) |
| 手动指定上游版本 | `gh workflow run etl.yml -f upstream_commit=<sha40>` |
| 只构建不发布 | `gh workflow run etl.yml -f publish=false` |

本地等价流程：

```bash
cd etl
.venv/bin/python -m poetry_etl download --commit <sha> --dest work
.venv/bin/python -m poetry_etl build --commit <sha> --out dist-full \
    [--prev dist-full/<上一版目录>]     # 有上一版才做别名比对
# build 内含自动门禁 + spotcheck 另行执行:
.venv/bin/python -m poetry_etl.spotcheck --dir dist-full/<version>
```

### ② 回滚

R2 版本目录永不删除(保留最近 ≥3 个)。回滚 = 改指针，无需重新部署 Worker：

```bash
printf '{"version":"<旧版本号>"}' > current.json
npx wrangler r2 object put "$BUCKET/current" --file current.json --remote
```

catalog 分钟级缓存过期后全体客户端自动回到旧版。

### ③ pending-review.json 复核流程

每次构建的别名判定中，无法确认对应关系的 ID 变更会进入
`<version>/pending-review.json`。复核节奏：

1. CI Summary 会显示条数；非零时点开该版本的文件人工审阅；
2. 每条含 `{id, author, title, reason}`：
   - `no_prev_candidate_with_matching_author_title` → 大概率是新作品或作者归属变更，确认后无需动作；
   - `beyond_distance_threshold(dist=N)` → 疑似大改版/张冠李戴，对照上游 diff 判断是否需要手工补 alias；
3. 需要手工补映射时，把 `{"from":…,"to":…}` 追加进该版本 `aliases.json` 并重新 put。

`build-issues.json`(rank 错位置空卷 / 跳过的脏记录) 同样按需审阅；
被置空热度的卷会在下次上游修复后自动恢复。

### ④ 免费额度监控

| 资源 | 免费额度 | 本项目用量级 |
|---|---|---|
| Worker 请求 | 10 万次/天 | 导入型低频，富余 |
| R2 存储 | 10 GB/月 | 每版本 ~65MB × 保留 3 版 ≈ 200MB |
| R2 A 类操作(写) | 100 万次/月 | 每次发布 ~340 put |
| GitHub Actions | 公共仓库无限 / 私有 2000 分钟/月 | 每次 ~8 分钟 |

监控入口：Cloudflare Dashboard → Workers & R2 → Metrics；
GitHub → Settings → Billing。阈值告警建议在 Cloudflare Notifications 配置
(Worker errors / R2 storage 超 50% 时邮件)。

### ⑤ 上线待办(需要账号操作)

1. Cloudflare 控制台创建 R2 bucket `poetry-mate-data`（或改 `server/wrangler.toml`）
2. `cd server && npx wrangler login && npm run deploy`
3. `./scripts/upload-version.sh ../etl/dist-full/v20260825.b8594f81`
4. **绑定自定义域名**（workers.dev 国内可达性差）并 curl 三接口复验
5. GitHub 仓库配置 secrets：`CLOUDFLARE_API_TOKEN`、`CLOUDFLARE_ACCOUNT_ID`

---

## 许可

代码许可待定；诗词数据源自 [chinese-poetry](https://github.com/chinese-poetry/chinese-poetry)(MIT)。
