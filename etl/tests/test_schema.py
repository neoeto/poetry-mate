"""schema 统一器测试(离线)。"""
import pytest

from poetry_etl.download import COLLECTIONS_BY_ID
from poetry_etl.normalize import compute_poem_id
from poetry_etl.schema import (
    UNIFIED_KEYS,
    SchemaError,
    deserialize_record,
    iter_unified,
    serialize_record,
    unify_record,
)

TANG = COLLECTIONS_BY_ID["tangshi"]
SONGCI = COLLECTIONS_BY_ID["songci"]


def _raw_tang() -> dict:
    return {
        "author": "太宗皇帝",
        "title": "帝京篇十首 一",
        "paragraphs": ["秦川雄帝宅，函谷壯皇居。", "綺殿千尋起，離宮百雉餘。"],
        "id": "upstream-id-ignored",
        "tags": ["唐诗三百首"],
    }


def test_tang_record_unified():
    rec = unify_record(_raw_tang(), TANG)
    assert tuple(rec.keys()) == UNIFIED_KEYS
    assert rec["author"] == "太宗皇帝"
    assert rec["title"] == "帝京篇十首 一"
    assert rec["dynasty"] == "唐" and rec["type"] == "shi"
    assert rec["paragraphs"] == ["秦川雄帝宅，函谷壮皇居。", "绮殿千寻起，离宫百雉余。"]
    assert rec["raw_text"] == ["秦川雄帝宅，函谷壯皇居。", "綺殿千尋起，離宮百雉餘。"]
    assert len(rec["paragraphs"]) == len(rec["raw_text"])
    assert rec["tags"] == ["唐诗三百首"]
    assert rec["preface"] is None and rec["popularity"] is None
    assert rec["source_collection"] == "tangshi"
    # ID 基于原始段落计算
    assert rec["id"] == compute_poem_id(_raw_tang()["paragraphs"])


def test_id_invariant_under_traditional_vs_simplified_input():
    """同一作品繁/简两种上游输入 → 同一 ID。"""
    simp_raw = {
        "author": "太宗皇帝",
        "title": "帝京篇",
        "paragraphs": ["秦川雄帝宅，函谷壮皇居。", "绮殿千寻起，离宫百雉余。"],
    }
    a, b = unify_record(_raw_tang(), TANG), unify_record(simp_raw, TANG)
    assert a["id"] == b["id"]
    assert a["paragraphs"] == b["paragraphs"]
    assert a["raw_text"] != b["raw_text"]  # 留档不同


def test_ci_record_title_null_rhythmic_kept():
    raw = {
        "author": "和岘",
        "paragraphs": ["气和玉烛，睿化著鸿明。"],
        "rhythmic": "导引",
    }
    rec = unify_record(raw, SONGCI)
    assert rec["title"] is None          # 词无题,显式 null 而非缺失
    assert rec["rhythmic"] == "导引"
    assert rec["dynasty"] == "宋" and rec["type"] == "ci"
    assert rec["source_collection"] == "songci"


def test_missing_author_raises():
    with pytest.raises(SchemaError, match="author"):
        unify_record({"title": "无名氏", "paragraphs": ["内容。"]}, TANG)


def test_empty_paragraphs_raises():
    with pytest.raises(SchemaError, match="paragraphs"):
        unify_record({"author": "李白", "paragraphs": []}, TANG)
    with pytest.raises(SchemaError):
        unify_record({"author": "李白", "paragraphs": ["  "]}, TANG)


def test_tags_edge_cases():
    assert unify_record({"author": "甲", "paragraphs": ["诗。"]}, TANG)["tags"] is None
    bad = {"author": "甲", "paragraphs": ["诗。"], "tags": "边塞"}
    assert unify_record(bad, TANG)["tags"] is None


def test_serialize_roundtrip_preserves_key_order():
    rec = unify_record(_raw_tang(), TANG)
    line = serialize_record(rec)
    assert deserialize_record(line) == rec


def test_deserialize_rejects_wrong_key_order():
    import json

    rec = unify_record(_raw_tang(), TANG)
    shuffled = dict(sorted(rec.items()))
    with pytest.raises(SchemaError, match="键序"):
        deserialize_record(json.dumps(shuffled, ensure_ascii=False))


def test_iter_unified_fail_fast_on_broken_file(tmp_path):
    good = tmp_path / "poet.tang.0.json"
    good.write_text('[{"author":"李白","paragraphs":["床前明月光，"]}]', encoding="utf-8")
    bad = tmp_path / "poet.tang.1.json"
    bad.write_text('{"not": "a list"}', encoding="utf-8")

    it = iter_unified([good, bad], TANG)
    assert next(it)["author"] == "李白"
    with pytest.raises(SchemaError, match="poet.tang.1.json"):
        next(it)
