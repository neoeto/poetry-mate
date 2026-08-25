"""种子集生成器（任务 1.9）。

从当前构建产物中选出全局热度 top-N 作为 APP 内置种子集。

选择契约(specs/data-etl-pipeline):
- 仅 popularity 非 null 的记录参与排序;
- **排除题名为《句》的碎片条目**: 上游把孤立残句单独成卷,搜索引擎热度
  系统性偏爱这类碎片(实测样本 top300 中占 2%,且榜首即《句》),
  但残句不适合"开箱即读的名篇"定位;
- 排序键 (-popularity, id): 热度并列时按 id 字典序决胜,保证确定性;
- 记录原样复用(不做任何改写),因此 ID 与全量库天然一致。
"""
from __future__ import annotations

import logging
from pathlib import Path

from poetry_etl.alias import iter_volume_records
from poetry_etl.pack import write_volume

logger = logging.getLogger(__name__)

SEED_SIZE = 300
SEED_COLLECTION_ID = "seed"
EXCLUDED_TITLES = frozenset({"句"})


def select_seed_records(version_root: Path, *, size: int = SEED_SIZE) -> list[dict]:
    """从产物目录选出种子记录(引用,非拷贝)。"""
    seen_ids: set[str] = set()
    candidates: list[dict] = []
    skipped_fragments = 0
    for record in iter_volume_records(version_root):
        if record["id"] in seen_ids:
            continue
        seen_ids.add(record["id"])
        popularity = record.get("popularity")
        if popularity is None:
            continue  # spec: null 不参与排序
        if record.get("title") in EXCLUDED_TITLES:
            skipped_fragments += 1
            continue
        candidates.append(record)

    candidates.sort(key=lambda r: (-r["popularity"], r["id"]))
    selected = candidates[:size]
    logger.info(
        "种子集选定 %d 条(候选 %d, 剔除碎片《句》%d 条, 无热度跳过其余)",
        len(selected), len(candidates), skipped_fragments,
    )
    return selected


def package_seed(selected: list[dict], version_root: Path) -> dict:
    """把种子记录打包为单卷(manifest 片段),复用分卷打包器。"""
    seed_dir = version_root / "volumes" / SEED_COLLECTION_ID
    seed_dir.mkdir(parents=True, exist_ok=True)
    name = f"{SEED_COLLECTION_ID}.0001.json.zst"
    rel = f"volumes/{SEED_COLLECTION_ID}/{name}"
    entry = write_volume(selected, seed_dir / name, rel)
    return {
        "title": "种子精选",
        "dynasty": None,      # 跨朝代混合
        "type": "mixed",
        "record_count": len(selected),
        "volume_count": 1,
        "volumes": [entry],
        "builtin": True,      # 标记: 该集随 APP 安装包内置,目录页可隐藏下载入口
    }
