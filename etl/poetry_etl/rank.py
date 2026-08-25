"""rank 热度关联器（任务 1.5）。

上游事实（2026-08 实测）：
- rank/poet/poet.tang.rank.N.json ↔ 全唐诗/poet.tang.N.json   （tangshi）
- rank/poet/poet.song.rank.N.json ↔ 全唐诗/poet.song.N.json   （songshi）
- rank/ci/ci.song.rank.N.json     ↔ 宋词/ci.song.N.json       （songci）
- 例外：宋词/ci.song.2019y.json 无 rank 对应文件 —— 属合法状态，
  该卷记录 popularity 显式 null（spec: 无对应值必须显式 null 而非缺失）

配对规则：文件级 = 卷号 N 完全一致；下标级 = 数组下标一一对应（上游 README 契约）。
已配对文件内数组长度不一致 → 抛错终止构建（spec 门禁）。
作者名交叉核对仅告警不阻断——上游存在别名写法差异，硬失败会误伤；
但会汇总输出告警数供人工审查。

popularity = Σ log10(1 + 引擎结果数)，保留 3 位小数（量化消除跨平台浮点尾差，
保证构建可复现）。引擎字段: baidu / bing / bing_en / so360 / google。
"""
from __future__ import annotations

import json
import logging
import math
import re
from collections.abc import Iterator
from pathlib import Path

from poetry_etl.download import RANK_SUBDIR, CollectionSpec
from poetry_etl.schema import SchemaError, iter_unified

logger = logging.getLogger(__name__)

# RANK_SUBDIR 已上移至 download.py(与解压白名单同源,防止两处定义漂移)
ENGINE_FIELDS: tuple[str, ...] = ("baidu", "bing", "bing_en", "so360", "google")

_TRAILING_NUMBER = re.compile(r"^(?P<stem>.+)\.(?P<vol>\d+)$")


class RankPairingError(RuntimeError):
    """rank 与诗词文件的对应关系断裂。"""


def popularity_of(rank_record: dict) -> float | None:
    """单条 rank 记录 → 归一热度。无任何有效引擎数据时返回 None。"""
    total = 0.0
    hit = False
    for field in ENGINE_FIELDS:
        value = rank_record.get(field)
        if isinstance(value, (int, float)) and value >= 0:
            total += math.log10(1 + value)
            hit = True
    return round(total, 3) if hit else None


def rank_counterpart(
    poem_file: Path, spec: CollectionSpec, snapshot_dir: Path
) -> Path | None:
    """诗词文件 → 对应 rank 文件路径；无编号后缀(如 2019y 卷)返回 None。"""
    match = _TRAILING_NUMBER.match(poem_file.stem)
    if match is None:
        logger.warning("[%s] 卷 %s 无数字卷号,视为无热度数据", spec.id, poem_file.name)
        return None
    subdir = RANK_SUBDIR.get(spec.id)
    if subdir is None:
        return None
    candidate = (
        snapshot_dir
        / subdir
        / f"{match.group('stem')}.rank.{match.group('vol')}.json"
    )
    return candidate if candidate.is_file() else None


def _load_rank_list(rank_file: Path, poem_file: Path) -> list[dict]:
    try:
        payload = json.loads(rank_file.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise RankPairingError(
            f"rank 文件解析失败: {rank_file.name} (配对 {poem_file.name}): {exc}"
        ) from exc
    if not isinstance(payload, list):
        raise RankPairingError(f"rank 文件顶层不是数组: {rank_file.name}")
    return payload


def unify_with_rank(
    files: list[Path],
    spec: CollectionSpec,
    snapshot_dir: Path,
    *,
    issues: list[dict] | None = None,
    skipped: list[dict] | None = None,
) -> Iterator[dict]:
    """统一 + 回填热度的组合流。逐文件、逐条产出统一记录。

    长度不一致的处理(2026-08 实盘修订,原为无条件抛错):
    - 配对卷内诗词数 != rank 数 => 该卷热度【整体置空】并登记进 issues
      (实测 poet.tang.48000: rank 中部多一条,继续按序回填会造成静默错位;
       填错的数据比缺的数据糟糕得多 —— "可证明对齐才填充");
      issues 为 None 时保持严格模式直接抛错(供单测与未来严格模式使用);
    - 无 rank 配对的卷: popularity 保持 null。
    """
    paired, unpaired, emptied = 0, 0, 0
    warned_mismatch = 0
    for poem_file in files:
        rank_file = rank_counterpart(poem_file, spec, snapshot_dir)
        rank_list = (
            _load_rank_list(rank_file, poem_file) if rank_file is not None else None
        )
        records = list(iter_unified([poem_file], spec, skipped=skipped))

        if rank_list is not None and len(rank_list) != len(records):
            detail = (
                f"[{spec.id}] {poem_file.name}: 诗词 {len(records)} 条 vs "
                f"{rank_file.name} {len(rank_list)} 条"
            )
            if issues is None:
                raise RankPairingError(detail + ",长度不一致")
            logger.warning("%s,该卷热度整体置空并登记待审查", detail)
            issues.append(
                {
                    "kind": "rank_length_mismatch",
                    "collection": spec.id,
                    "volume": poem_file.name,
                    "poem_count": len(records),
                    "rank_count": len(rank_list),
                }
            )
            for record in records:
                record["popularity"] = None
                yield record
            emptied += 1
            continue

        if rank_list is not None:
            for index, record in enumerate(records):
                rank_record = rank_list[index]
                rank_author = rank_record.get("author")
                if (
                    isinstance(rank_author, str)
                    and rank_author != record["author"]
                    and warned_mismatch < 20
                ):
                    logger.warning(
                        "[%s] %s#%d 作者名不一致: rank=%r vs poem=%r",
                        spec.id,
                        poem_file.name,
                        index,
                        rank_author,
                        record["author"],
                    )
                    warned_mismatch += 1
                record["popularity"] = popularity_of(rank_record)

        yield from records
        if rank_list is not None:
            paired += 1
        else:
            unpaired += 1

    if paired == 0 and unpaired > 0:
        # 哨兵: 整集零配对几乎必然是快照缺 rank 目录之类的结构性问题,
        # 而非零星数据缺失(合法未配对不会把计数归零)。曾真实发生过。
        logger.warning(
            "[%s] 全部 %d 卷均无 rank 配对! 疑似快照缺少 %s 目录,热度将全部为 null",
            spec.id,
            unpaired,
            RANK_SUBDIR.get(spec.id),
        )
    logger.info(
        "[%s] rank 关联完成: 配对 %d 卷, 未配对 %d 卷, 置空 %d 卷, 作者告警 %d 次",
        spec.id,
        paired,
        unpaired,
        emptied,
        warned_mismatch,
    )


__all__ = [
    "RankPairingError",
    "popularity_of",
    "rank_counterpart",
    "unify_with_rank",
    "SchemaError",
]
