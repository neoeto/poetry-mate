"""分卷打包器（任务 1.6）。

产出布局（与分发 API 契约对齐，见 specs/data-distribution-api）：

    <dist>/<version>/
      manifest.json                       ← 全局清单(逐卷 sha256/bytes/records)
      volumes/<collection>/<cid>.NNNN.json.zst

关键性质：
- **确定性**：同样的输入快照 + 同一版本号 ⇒ 字节级相同的产物。
  为此 manifest 不含任何墙钟时间戳（日期已编码在版本号里），
  记录键序由 schema.UNIFIED_KEYS 钉死，浮点已量化(rank.py)。
- **原子写**：先写 .tmp 再 rename，杜绝半截文件被发布。
- 单卷记录数 ≤ 上限(spec: 1000)，超出自动切卷。
"""
from __future__ import annotations

import hashlib
import logging
from collections.abc import Iterator
from dataclasses import dataclass
from datetime import UTC, datetime
from itertools import islice
from pathlib import Path

import compression.zstd as zstd

from poetry_etl.download import CollectionSpec, V1_COLLECTIONS
from poetry_etl.rank import unify_with_rank
from poetry_etl.schema import serialize_record

logger = logging.getLogger(__name__)

ZSTD_LEVEL = 19
RECORDS_PER_VOLUME = 1000


@dataclass(frozen=True)
class BuildParams:
    version: str          # 形如 v20260825.b8594f81
    source_commit: str    # 完整 40 位 sha
    max_records_per_volume: int = RECORDS_PER_VOLUME


def make_version(source_commit: str, *, day=None) -> str:
    """版本号 = 构建日期(UTC) + 上游 commit 前 8 位。"""
    day = day or datetime.now(UTC).date()
    return f"v{day:%Y%m%d}.{source_commit[:8]}"


def _volume_blob(records: list[dict]) -> bytes:
    lines = ",".join(serialize_record(r) for r in records)
    return zstd.compress(f"[{lines}]".encode("utf-8"), level=ZSTD_LEVEL)


def _atomic_write(target: Path, blob: bytes) -> None:
    tmp = target.with_name(target.name + ".tmp")
    tmp.write_bytes(blob)
    tmp.replace(target)


def write_volume(
    records: list[dict], target: Path, rel_path: str
) -> dict:
    """写单个分卷并返回 manifest 条目。"""
    blob = _volume_blob(records)
    _atomic_write(target, blob)
    return {
        "file": rel_path,
        "sha256": hashlib.sha256(blob).hexdigest(),
        "bytes": len(blob),
        "records": len(records),
    }


def _chunked(stream: Iterator[dict], size: int) -> Iterator[list[dict]]:
    while chunk := list(islice(stream, size)):
        yield chunk


def package_collection(
    poem_files: list[Path],
    spec: CollectionSpec,
    snapshot_dir: Path,
    version_root: Path,
    *,
    max_records: int = RECORDS_PER_VOLUME,
    build_issues: list[dict] | None = None,
) -> dict:
    """处理单个作品集：统一+关联热度+切卷压缩，返回 manifest 片段。"""
    volumes_dir = version_root / "volumes" / spec.id
    volumes_dir.mkdir(parents=True, exist_ok=True)

    stream = unify_with_rank(
        poem_files, spec, snapshot_dir, issues=build_issues, skipped=build_issues
    )
    volumes: list[dict] = []
    total = 0
    for seq, chunk in enumerate(_chunked(stream, max_records), start=1):
        name = f"{spec.id}.{seq:04d}.json.zst"
        rel = f"volumes/{spec.id}/{name}"
        volumes.append(write_volume(chunk, volumes_dir / name, rel))
        total += len(chunk)

    if total == 0:
        raise RuntimeError(f"[{spec.id}] 处理后为零条记录，疑似输入异常")

    logger.info("[%s] 打包完成: %d 条 -> %d 卷", spec.id, total, len(volumes))
    return {
        "title": spec.title,
        "dynasty": spec.dynasty,
        "type": spec.type,
        "record_count": total,
        "volume_count": len(volumes),
        "volumes": volumes,
    }


def build_distribution(
    params: BuildParams,
    discovered: dict[str, list[Path]],
    snapshot_dir: Path,
    dest_root: Path,
    *,
    collections: tuple[CollectionSpec, ...] = V1_COLLECTIONS,
    previous_version_root: Path | None = None,
) -> dict:
    """构建完整数据包目录并落盘 manifest.json，返回 manifest 内容。"""
    build_issues: list[dict] = []  # 构建期数据缺陷登记处(宁缺毋滥)
    version_root = dest_root / params.version
    if version_root.exists():
        raise FileExistsError(
            f"版本目录已存在: {version_root} (确定性构建下同版本应只构建一次;"
            "如确需重建请先删除)"
        )
    version_root.mkdir(parents=True)

    manifest: dict = {
        "version": params.version,
        "source_commit": params.source_commit,
        "collections": {},
    }
    for spec in collections:
        files = discovered.get(spec.id, [])
        if not files:
            raise RuntimeError(f"[{spec.id}] 无输入文件,拒绝打包空集子")
        manifest["collections"][spec.id] = package_collection(
            files, spec, snapshot_dir, version_root,
            max_records=params.max_records_per_volume,
            build_issues=build_issues,
        )

    # 别名比对(任务 1.7): 与上一版 diff,发布 aliases.json / pending-review.json
    from poetry_etl.alias import diff_aliases, write_alias_artifacts

    report = diff_aliases(previous_version_root, version_root)
    write_alias_artifacts(report, version_root)

    # 构建期数据缺陷登记表(与 aliases/pending 同级的运维工件)
    import json as _json

    _atomic_write(
        version_root / "build-issues.json",
        (
            _json.dumps(build_issues, ensure_ascii=False, indent=1) + "\n"
        ).encode("utf-8"),
    )
    if build_issues:
        kinds = {}
        for issue in build_issues:
            kinds[issue["kind"]] = kinds.get(issue["kind"], 0) + 1
        logger.warning("构建期登记 %d 处数据缺陷: %s", len(build_issues), kinds)

    # 种子集(任务 1.9): 全局热度 top-N,记录原样复用,ID 与全量库天然一致
    from poetry_etl.seed import package_seed, select_seed_records

    manifest["collections"]["seed"] = package_seed(
        select_seed_records(version_root), version_root
    )

    _atomic_write(version_root / "manifest.json", _manifest_json(manifest))

    logger.info("manifest 已写入 %s", version_root / "manifest.json")
    return manifest


def _manifest_json(manifest: dict) -> bytes:
    import json

    return (
        json.dumps(manifest, ensure_ascii=False, indent=1, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def sha256_of_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()
