# Poetry Mate ETL —— 诗词数据管道

把 [chinese-poetry](https://github.com/chinese-poetry/chinese-poetry) 上游原始 JSON
转换为**简体、统一 schema、带稳定 ID 与热度、zstd 压缩分卷**的标准数据包。

> 契约唯一来源：[`../openspec/changes/build-data-pipeline/`](../openspec/changes/build-data-pipeline/)
> （proposal / design / specs 定义"做什么与为什么"，本目录实现"怎么做"）

## 环境要求

- **Python >= 3.14**（使用标准库 `compression.zstd`，PEP 784；无需第三方 zstandard 包）
- make

## 快速开始

```bash
make install   # 创建 .venv 并安装锁定依赖(含 dev)
make test      # pytest
make info      # 环境自检: Python 版本 / OpenCC t2s / stdlib zstd 往返
```

## 模块地图（随任务逐步填充）

| 模块 | 任务 | 职责 |
|---|---|---|
| `normalize.py` | 1.2 | 规范化契约 + 内容寻址 ID（poem-id spec） |
| `download.py` | 1.3 | 上游按 commit 浅拉取、目录→作品集映射 |
| `schema.py` | 1.4 | 统一记录结构、小序归位 preface |
| `rank.py` | 1.5 | rank 文件级+下标级关联 → popularity |
| `pack.py` | 1.6 | ≤1000 首/卷、zstd-19 打包、manifest |
| `alias.py` | 1.7 | 与上一版 diff → aliases.json / pending-review.json |
| `gate.py` | 1.8 | 发布前校验门禁 |
| `seed.py` | 1.9 | popularity 全局 top300 种子集包 |

## 依赖锁定策略

所有第三方依赖在 `pyproject.toml` 中**精确锁版本**。特别注意：
`opencc-python-reimplemented` 的版本是诗词 ID 契约的一部分
——升级它意味着全库 ID 可能漂移，必须走 OpenSpec 变更流程，禁止顺手 `pip install -U`。
