"""别名比对器测试(离线)。"""
import json

import compression.zstd as zstd
import pytest

from poetry_etl.alias import diff_aliases, levenshtein, write_alias_artifacts
from poetry_etl.download import COLLECTIONS_BY_ID
from poetry_etl.normalize import compute_poem_id
from poetry_etl.pack import BuildParams, build_distribution
from poetry_etl.schema import unify_record

TANG = COLLECTIONS_BY_ID["tangshi"]
COMMIT = "b" * 40


# ---------- levenshtein ----------


def test_levenshtein_classic():
    assert levenshtein("kitten", "sitting") == 3
    assert levenshtein("", "abc") == 3
    assert levenshtein("abc", "") == 3
    assert levenshtein("same", "same") == 0
    assert levenshtein("床前明月光", "床前明月光啊") == 1


def test_threshold_floor_and_ratio():
    from poetry_etl.alias import _threshold

    short_a, short_b = "abcd", "abxy"
    assert _threshold(short_a, short_b) == 2          # 地板值 2
    long_text = "一" * 200
    assert _threshold(long_text, "二" * 200) == 10    # 5% · L


# ---------- 夹具工具 ----------


def _record(author: str, title: str, paragraphs: list[str]) -> dict:
    rec = unify_record(
        {"author": author, "title": title, "paragraphs": paragraphs}, TANG
    )
    return rec


def _write_version(root_path, collections_records: dict[str, list[dict]]):
    """直接手写一个'产物目录'(volumes/*.json.zst),供 diff 使用。"""
    for cid, records in collections_records.items():
        vdir = root_path / "volumes" / cid
        vdir.mkdir(parents=True, exist_ok=True)
        blob = zstd.compress(json.dumps(records, ensure_ascii=False).encode("utf-8"))
        (vdir / f"{cid}.0001.json.zst").write_bytes(blob)
    return root_path


# ---------- diff 行为 ----------


def test_first_run_yields_empty_artifacts(tmp_path):
    current = tmp_path / "cur"
    report = diff_aliases(None, current)
    assert report.aliases == [] and report.pending == []
    assert report.stats["mode"] == "first_run"

    write_alias_artifacts(report, tmp_path / "out")
    assert json.loads((tmp_path / "out" / "aliases.json").read_text()) == []
    assert json.loads((tmp_path / "out" / "pending-review.json").read_text()) == []


def test_one_char_upstream_fix_produces_alias(tmp_path):
    prev_rec = _record("李白", "静夜思", ["床前明月光，", "疑是地上霜。"])
    # 上游修订: 多了一个字 → 新 ID
    cur_rec = _record("李白", "静夜思", ["床前明月光，", "疑是地上霜了。"])

    prev = _write_version(tmp_path / "prev", {"tangshi": [prev_rec]})
    cur = _write_version(tmp_path / "cur", {"tangshi": [cur_rec]})

    report = diff_aliases(prev, cur)
    assert report.aliases == [
        {"from": compute_poem_id(prev_rec["paragraphs"]), "to": cur_rec["id"]}
    ]
    assert report.pending == []


def test_beyond_threshold_goes_to_pending(tmp_path):
    prev_rec = _record("李白", "静夜思", ["床前明月光，疑是地上霜。"])
    # 完全不同的文本(同作者同题——模拟上游张冠李戴式重写)
    cur_rec = _record("李白", "静夜思", ["朝辞白帝彩云间，千里江陵一日还。"])

    prev = _write_version(tmp_path / "prev", {"tangshi": [prev_rec]})
    cur = _write_version(tmp_path / "cur", {"tangshi": [cur_rec]})

    report = diff_aliases(prev, cur)
    assert report.aliases == []
    assert len(report.pending) == 1
    assert "beyond_distance_threshold" in report.pending[0]["reason"]


def test_author_title_mismatch_goes_to_pending(tmp_path):
    prev_rec = _record("李白", "静夜思", ["床前明月光，疑是地上霜。"])
    cur_rec = _record("杜甫", "春望", ["国破山河在，城春草木深。"])

    prev = _write_version(tmp_path / "prev", {"tangshi": [prev_rec]})
    cur = _write_version(tmp_path / "cur", {"tangshi": [cur_rec]})

    report = diff_aliases(prev, cur)
    assert report.aliases == []
    assert report.pending[0]["reason"] == "no_prev_candidate_with_matching_author_title"


def test_old_id_still_alive_is_not_claimed(tmp_path):
    """上游新增重复收录而非改字: 老 id 仍在当前版 → 不得被认领为别名。"""
    original = _record("李白", "静夜思", ["床前明月光，疑是地上霜。"])
    dup = _record("李白", "静夜思", ["床前明月光，疑是地上霜呀。"])

    prev = _write_version(tmp_path / "prev", {"tangshi": [original]})
    cur = _write_version(tmp_path / "cur", {"tangshi": [original, dup]})

    report = diff_aliases(prev, cur)
    assert report.aliases == []          # 原 id 还活着,新条目不构成别名
    assert len(report.pending) == 1      # 但新 id 仍需人工确认


def test_alias_one_to_one_consumption(tmp_path):
    """两个新增记录竞争同一个老 id 时,只有距离最小者胜出且仅消费一次。"""
    base = ["床前明月光，疑是地上霜。"]
    prev_rec = _record("李白", "无题", base)
    variant_a = _record("李白", "无题", ["床前明月光，疑是地上霜呀。"])   # 距离1
    variant_b = _record("李白", "无题", ["床前明月光，疑是地上霜了吗。"])  # 距离2

    prev = _write_version(tmp_path / "prev", {"tangshi": [prev_rec]})
    cur = _write_version(tmp_path / "cur", {"tangshi": [variant_a, variant_b]})

    report = diff_aliases(prev, cur)
    assert report.aliases == [{"from": prev_rec["id"], "to": variant_a["id"]}]
    assert len(report.pending) == 1      # variant_b 进待复核
    assert "beyond_distance_threshold" not in report.pending[0]["reason"]
    assert report.pending[0]["reason"].startswith("no_prev_candidate")


# ---------- 与 build_distribution 的集成 ----------


def _make_snapshot_pair(tmp_path, paragraphs):
    root = tmp_path / "snapshot"
    (root / "全唐诗").mkdir(parents=True)
    (root / "rank" / "poet").mkdir(parents=True)
    poem = [{"author": "李白", "title": "静夜思", "paragraphs": paragraphs}]
    rank = [{"author": "李白", "baidu": 100}]
    (root / "全唐诗" / "poet.tang.0.json").write_text(
        json.dumps(poem, ensure_ascii=False), encoding="utf-8"
    )
    (root / "rank" / "poet" / "poet.tang.rank.0.json").write_text(
        json.dumps(rank, ensure_ascii=False), encoding="utf-8"
    )
    return root


def test_build_distribution_publishes_alias_artifacts(tmp_path):
    params_v1 = BuildParams(version="v20260101.aaaaaaaa", source_commit="a" * 40)
    snapshot_old = _make_snapshot_pair(tmp_path / "s1", ["床前明月光，疑是地上霜。"])
    build_distribution(
        params_v1,
        {"tangshi": [snapshot_old / "全唐诗" / "poet.tang.0.json"]},
        snapshot_old,
        tmp_path / "dist",
        collections=(TANG,),
    )

    # 上游改一个字 → 第二次构建带 --prev
    params_v2 = BuildParams(version="v20260102.bbbbbbbb", source_commit="b" * 40)
    snapshot_new = _make_snapshot_pair(tmp_path / "s2", ["床前明月光，疑是地上霜了。"])
    build_distribution(
        params_v2,
        {"tangshi": [snapshot_new / "全唐诗" / "poet.tang.0.json"]},
        snapshot_new,
        tmp_path / "dist",
        collections=(TANG,),
        previous_version_root=tmp_path / "dist" / "v20260101.aaaaaaaa",
    )

    aliases = json.loads(
        (tmp_path / "dist" / "v20260102.bbbbbbbb" / "aliases.json").read_text()
    )
    assert len(aliases) == 1
    assert aliases[0]["from"] == compute_poem_id(["床前明月光，疑是地上霜。"])
    assert isinstance(aliases[0]["to"], str) and len(aliases[0]["to"]) == 32
