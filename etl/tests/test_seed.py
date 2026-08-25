"""种子集生成器测试(离线)。"""
import json

import compression.zstd as zstd

from poetry_etl.download import COLLECTIONS_BY_ID
from poetry_etl.gate import run_gate
from poetry_etl.pack import BuildParams, build_distribution
from poetry_etl.schema import unify_record
from poetry_etl.seed import select_seed_records

TANG = COLLECTIONS_BY_ID["tangshi"]
COMMIT = "d" * 40


def _rec(author: str, paragraphs: list[str], popularity, title=None):
    rec = unify_record(
        {"author": author, "title": title or "诗题", "paragraphs": paragraphs}, TANG
    )
    rec["popularity"] = popularity
    return rec


def _write_version(root_path, records):
    vdir = root_path / "volumes" / "tangshi"
    vdir.mkdir(parents=True, exist_ok=True)
    blob = zstd.compress(json.dumps(records, ensure_ascii=False).encode("utf-8"))
    (vdir / "tangshi.0001.json.zst").write_bytes(blob)
    return root_path


def test_select_orders_desc_and_excludes_null_and_fragments(tmp_path):
    records = [
        _rec("甲", ["甲之诗。"], None),                  # null 不参与
        _rec("乙", ["乙之诗。"], 3.0),
        _rec("丙", ["残句。"], 99.0, title="句"),          # 碎片剔除(哪怕热度最高)
        _rec("丁", ["丁之诗。"], 7.0),
        _rec("戊", ["戊之诗。"], 1.0),
    ]
    version = _write_version(tmp_path / "v", records)
    picked = select_seed_records(version, size=10)
    assert [r["popularity"] for r in picked] == [7.0, 3.0, 1.0]
    assert all(r["title"] != "句" for r in picked)


def test_tie_break_deterministic_by_id(tmp_path):
    a = _rec("甲", ["甲诗。"], 5.0)
    b = _rec("乙", ["乙诗。"], 5.0)
    assert a["id"] != b["id"]
    first_id = min(a["id"], b["id"])
    version = _write_version(tmp_path / "v", [a, b])
    picked = select_seed_records(version, size=1)
    assert picked[0]["id"] == first_id


def test_size_cap(tmp_path):
    records = [_rec(f"诗人{i}", [f"诗句{i}。"], float(i)) for i in range(10)]
    version = _write_version(tmp_path / "v", records)
    assert len(select_seed_records(version, size=3)) == 3


# ---------- 与构建管线集成 ----------


def test_build_publishes_seed_consistent_with_full_library(tmp_path):
    root = tmp_path / "snapshot"
    (root / "全唐诗").mkdir(parents=True)
    (root / "rank" / "poet").mkdir(parents=True)
    poem = [{"author": "李白", "title": "静夜思", "paragraphs": ["床前明月光，疑是地上霜。"]}]
    rank = [{"author": "李白", "baidu": 100}]
    (root / "全唐诗" / "poet.tang.0.json").write_text(
        json.dumps(poem, ensure_ascii=False), encoding="utf-8"
    )
    (root / "rank" / "poet" / "poet.tang.rank.0.json").write_text(
        json.dumps(rank, ensure_ascii=False), encoding="utf-8"
    )

    params = BuildParams(version="v20260101.seed0001", source_commit=COMMIT)
    dest = tmp_path / "dist"
    manifest = build_distribution(
        params,
        {"tangshi": [root / "全唐诗" / "poet.tang.0.json"]},
        root,
        dest,
        collections=(TANG,),
    )
    version_root = dest / params.version

    # manifest 含 seed 条目
    seed_entry = manifest["collections"]["seed"]
    assert seed_entry["record_count"] >= 1
    assert seed_entry.get("builtin") is True

    # 种子里的 id 必须能在主库中找到(同文同 ID 契约)
    main_ids = {
        r["id"] for r in json.loads(
            zstd.decompress(
                next((version_root / "volumes" / "tangshi").glob("*.json.zst")).read_bytes()
            ).decode("utf-8")
        )
    }
    seed_blob = zstd.decompress(
        next((version_root / "volumes" / "seed").glob("*.json.zst")).read_bytes()
    ).decode("utf-8")
    seed_ids = {r["id"] for r in json.loads(seed_blob)}
    assert seed_ids <= main_ids

    # 整个产物目录(含 seed)通过门禁
    assert run_gate(version_root) == []
