"""别名比对器（任务 1.7）。

上游修订文本会导致内容寻址 ID 漂移;本模块在两次构建之间做 diff,
产出两个随数据包发布的工件(specs/poem-id):

    aliases.json         [{"from": 旧id, "to": 新id}, ...]
    pending-review.json  [{"id","author","title","reason"}, ...] 待人工复核

判定契约:
- 新 ID(不在上一版 id 集中) 且 (author, title) 与上一版某条完全相等,
  且正文(规范化 payload)编辑距离 ≤ max(2, 5%·L) → 记别名;
- 老记录必须真的消失(旧 id 不在当前集中)才可被认领,且一对一消费;
- 其余一切 ID 变更 → 进 pending-review,绝不猜测。

首次构建(无上一版目录) → 空 aliases 照常发布,保持下游处理逻辑统一。
"""
from __future__ import annotations

import json
import logging
from collections.abc import Iterator
from dataclasses import dataclass, field
from pathlib import Path

import compression.zstd as zstd

from poetry_etl.normalize import normalized_payload

logger = logging.getLogger(__name__)

DISTANCE_RATIO = 0.05
DISTANCE_FLOOR = 2


def levenshtein(a: str, b: str) -> int:
    """经典两行 DP 编辑距离。"""
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, start=1):
        cur = [i]
        for j, cb in enumerate(b, start=1):
            cur.append(
                min(
                    prev[j] + 1,        # 删除
                    cur[j - 1] + 1,     # 插入
                    prev[j - 1] + (ca != cb),  # 替换/一致
                )
            )
        prev = cur
    return prev[-1]


def _threshold(a: str, b: str) -> int:
    return max(DISTANCE_FLOOR, int(DISTANCE_RATIO * max(len(a), len(b))))


def payload_of(record: dict) -> str:
    """统一记录 → 规范化哈希输入串(与 ID 同源)。"""
    return normalized_payload(record["paragraphs"], record.get("preface"))


def iter_volume_records(version_root: Path) -> Iterator[dict]:
    volumes_dir = version_root / "volumes"
    if not volumes_dir.is_dir():
        return
    for path in sorted(volumes_dir.glob("*/*.json.zst")):
        payload = zstd.decompress(path.read_bytes()).decode("utf-8")
        yield from json.loads(payload)


@dataclass
class AliasReport:
    aliases: list[dict] = field(default_factory=list)
    pending: list[dict] = field(default_factory=list)
    stats: dict = field(default_factory=dict)

    @property
    def is_empty(self) -> bool:
        return not self.aliases and not self.pending


def diff_aliases(previous_root: Path | None, current_root: Path) -> AliasReport:
    """上一版产物 vs 当前产物 → 别名与待复核报告。"""
    report = AliasReport()
    if previous_root is None or not (previous_root / "volumes").is_dir():
        logger.info("无上一版产物,跳过比对(首次构建)")
        report.stats = {"mode": "first_run", "aliases": 0, "pending": 0}
        return report

    # --- 载入上一版索引 ---
    prev_ids: set[str] = set()
    prev_index: dict[tuple[str, str], list[tuple[str, str]]] = {}
    for rec in iter_volume_records(previous_root):
        prev_ids.add(rec["id"])
        key = (rec["author"], rec["title"] or "")
        prev_index.setdefault(key, []).append((rec["id"], payload_of(rec)))

    # --- 扫描当前版,收集"新增"记录(id 不在上一版);种子集与主库同 id,去重防重复报告 ---
    current_ids: set[str] = set()
    seen_current: set[str] = set()
    newcomers: list[tuple[str, str, str, str]] = []  # id, author, title, payload
    total_current = 0
    for rec in iter_volume_records(current_root):
        total_current += 1
        current_ids.add(rec["id"])
        if rec["id"] in prev_ids or rec["id"] in seen_current:
            continue
        seen_current.add(rec["id"])
        newcomers.append(
            (rec["id"], rec["author"], rec["title"] or "", payload_of(rec))
        )

    # --- 为每个新增记录寻找可认领的老 id ---
    consumed_old: set[str] = set()
    vanished = len(prev_ids - current_ids)
    for new_id, author, title, payload in newcomers:
        candidates = [
            (old_id, old_payload)
            for old_id, old_payload in prev_index.get((author, title), [])
            if old_id not in current_ids and old_id not in consumed_old
        ]
        if not candidates:
            report.pending.append(
                {
                    "id": new_id,
                    "author": author,
                    "title": title or None,
                    "reason": "no_prev_candidate_with_matching_author_title",
                }
            )
            continue
        best_old, best_dist = min(
            ((oid, levenshtein(payload, op)) for oid, op in candidates),
            key=lambda t: (t[1], t[0]),  # 距离最小者;平局按旧 id 字典序保证确定性
        )
        if best_dist <= _threshold(payload, best_old):
            report.aliases.append({"from": best_old, "to": new_id})
            consumed_old.add(best_old)
        else:
            report.pending.append(
                {
                    "id": new_id,
                    "author": author,
                    "title": title or None,
                    "reason": f"beyond_distance_threshold(dist={best_dist})",
                }
            )

    report.stats = {
        "mode": "diff",
        "prev_records": len(prev_ids),
        "current_records": total_current,
        "newcomers": len(newcomers),
        "vanished": vanished,
        "aliases": len(report.aliases),
        "pending": len(report.pending),
    }
    logger.info("别名比对: %s", report.stats)
    return report


def write_alias_artifacts(report: AliasReport, version_root: Path) -> None:
    """把报告落盘为随包发布的两个工件。"""
    version_root.mkdir(parents=True, exist_ok=True)
    _atomic_json(version_root / "aliases.json", report.aliases)
    _atomic_json(version_root / "pending-review.json", report.pending)


def _atomic_json(path: Path, payload: list) -> None:
    blob = (json.dumps(payload, ensure_ascii=False, indent=1) + "\n").encode("utf-8")
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_bytes(blob)
    tmp.replace(path)
