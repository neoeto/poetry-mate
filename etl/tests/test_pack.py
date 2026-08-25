"""分卷打包器测试(离线)。"""
import compression.zstd as zstd
import json
import pytest

from poetry_etl.download import COLLECTIONS_BY_ID
from poetry_etl.pack import (
    BuildParams,
    make_version,
    package_collection,
    build_distribution,
)
from poetry_etl.schema import deserialize_record

TANG = COLLECTIONS_BY_ID["tangshi"]
COMMIT = "b8594f81a89752241442f2ce267d6f66f96704ee"


def _make_snapshot(tmp_path, n_records: int):
    """构造含 rank 配对的迷你快照:n_records 首诗。"""
    root = tmp_path / "snapshot"
    (root / "全唐诗").mkdir(parents=True)
    (root / "rank" / "poet").mkdir(parents=True)

    poems = [
        {"author": f"诗人{i}", "title": f"诗{i}", "paragraphs": [f"诗句{i}，平平仄仄。"]}
        for i in range(n_records)
    ]
    ranks = [{"author": p["author"], "baidu": 100 + i} for i, p in enumerate(poems)]
    (root / "全唐诗" / "poet.tang.0.json").write_text(
        json.dumps(poems, ensure_ascii=False), encoding="utf-8"
    )
    (root / "rank" / "poet" / "poet.tang.rank.0.json").write_text(
        json.dumps(ranks, ensure_ascii=False), encoding="utf-8"
    )
    return root


def test_make_version_format():
    import datetime

    v = make_version(COMMIT, day=datetime.date(2026, 8, 25))
    assert v == "v20260825.b8594f81"


def test_package_splits_by_cap_and_roundtrips(tmp_path):
    root = _make_snapshot(tmp_path, n_records=5)
    version_root = tmp_path / "dist" / "vX"
    summary = package_collection(
        [root / "全唐诗" / "poet.tang.0.json"], TANG, root, version_root,
        max_records=2,
    )
    assert summary["record_count"] == 5
    assert summary["volume_count"] == 3
    assert [v["records"] for v in summary["volumes"]] == [2, 2, 1]

    # 解压回读: 内容与键序逐字节符合契约
    first = summary["volumes"][0]
    blob = (version_root / first["file"]).read_bytes()
    records = json.loads(zstd.decompress(blob).decode("utf-8"))
    assert len(records) == 2
    from poetry_etl.schema import UNIFIED_KEYS

    assert all(tuple(r.keys()) == UNIFIED_KEYS for r in records)
    assert records[0]["popularity"] is not None


def test_manifest_shape_and_hash_consistency(tmp_path):
    root = _make_snapshot(tmp_path, n_records=5)
    params = BuildParams(version="v20260101.deadbeef", source_commit="deadbeef" + "0" * 32)
    manifest = build_distribution(
        params,
        {"tangshi": [root / "全唐诗" / "poet.tang.0.json"]},
        root,
        tmp_path / "dist",
        collections=(TANG,),
    )

    assert manifest["version"] == "v20260101.deadbeef"
    assert manifest["collections"]["tangshi"]["record_count"] == 5
    vol = manifest["collections"]["tangshi"]["volumes"][0]
    disk = (tmp_path / "dist" / "v20260101.deadbeef" / vol["file"]).read_bytes()
    import hashlib

    assert hashlib.sha256(disk).hexdigest() == vol["sha256"]
    assert len(disk) == vol["bytes"]
    # 落盘的 manifest 与返回值一致
    on_disk = json.loads((tmp_path / "dist" / "v20260101.deadbeef" / "manifest.json").read_text(encoding="utf-8"))
    assert on_disk == manifest


def test_rebuild_is_byte_identical(tmp_path):
    """确定性构建预演(任务 2.4 的单测版): 同输入两次构建产物完全一致。"""
    root = _make_snapshot(tmp_path, n_records=7)
    files = [root / "全唐诗" / "poet.tang.0.json"]

    def build_once(tag: str):
        out = tmp_path / tag
        params = BuildParams(version="v20260101.deadbeef", source_commit="deadbeef" + "0" * 32, max_records_per_volume=3)
        m = build_distribution(
            params, {"tangshi": list(files)}, root, out, collections=(TANG,)
        )
        return m, {v["file"]: v["sha256"] for v in m["collections"]["tangshi"]["volumes"]}

    m1, h1 = build_once("a")
    m2, h2 = build_once("b")
    assert h1 == h2
    assert m1["collections"]["tangshi"] == m2["collections"]["tangshi"]


def test_refuses_existing_version_dir(tmp_path):
    root = _make_snapshot(tmp_path, n_records=1)
    params = BuildParams(version="vX", source_commit=COMMIT)
    args = dict(
        discovered={"tangshi": [root / "全唐诗" / "poet.tang.0.json"]},
        snapshot_dir=root,
        dest_root=tmp_path / "d",
        collections=(TANG,),
    )
    build_distribution(params, **args)
    with pytest.raises(FileExistsError):
        build_distribution(params, **args)


def test_empty_input_refused(tmp_path):
    params = BuildParams(version="vY", source_commit=COMMIT)
    with pytest.raises(RuntimeError, match="无输入文件"):
        build_distribution(params, {"tangshi": []}, tmp_path, tmp_path / "out")
