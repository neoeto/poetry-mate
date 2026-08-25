"""rank 关联器测试(离线)。"""
import logging

import pytest

from poetry_etl.download import COLLECTIONS_BY_ID
from poetry_etl.rank import (
    RankPairingError,
    popularity_of,
    rank_counterpart,
    unify_with_rank,
)
from poetry_etl.schema import serialize_record

TANG = COLLECTIONS_BY_ID["tangshi"]
SONGCI = COLLECTIONS_BY_ID["songci"]


# ---------- popularity 计算 ----------


def test_popularity_hand_computed():
    # log10(1+9999)=4.0, log10(1+99)=2.0 → 6.0
    rec = {"baidu": 9999, "google": 99}
    assert popularity_of(rec) == 6.0


def test_popularity_rounds_to_3_decimals():
    assert popularity_of({"baidu": 1}) == round(__import__("math").log10(2), 3)


def test_popularity_empty_or_invalid_returns_none():
    assert popularity_of({}) is None
    assert popularity_of({"baidu": -5, "google": "many"}) is None  # 负数/非数忽略


def test_popularity_partial_engines():
    assert popularity_of({"so360": 9}) == 1.0  # log10(10)


# ---------- 配对路径解析 ----------


def _make_snapshot(tmp_path):
    root = tmp_path / "snapshot"
    (root / "全唐诗").mkdir(parents=True)
    (root / "宋词").mkdir(parents=True)
    (root / "rank" / "poet").mkdir(parents=True)
    (root / "rank" / "ci").mkdir(parents=True)
    return root


def test_counterpart_resolves_by_volume_number(tmp_path):
    root = _make_snapshot(tmp_path)
    poem = root / "全唐诗" / "poet.tang.7.json"
    expected = root / "rank" / "poet" / "poet.tang.rank.7.json"
    expected.write_text("[]", encoding="utf-8")
    assert rank_counterpart(poem, TANG, root) == expected


def test_counterpart_missing_returns_none(tmp_path):
    root = _make_snapshot(tmp_path)
    poem = root / "全唐诗" / "poet.tang.999.json"
    assert rank_counterpart(poem, TANG, root) is None


def test_counterpart_non_numbered_volume_returns_none(tmp_path):
    """2019y 这类特殊卷无 rank 对应,属合法状态。"""
    root = _make_snapshot(tmp_path)
    poem = root / "宋词" / "ci.song.2019y.json"
    poem.write_text("[]", encoding="utf-8")
    assert rank_counterpart(poem, SONGCI, root) is None


# ---------- 组合流 ----------


def _write_pair(root, vol_records, rank_records):
    poem = root / "全唐诗" / "poet.tang.0.json"
    poem.write_text(
        __import__("json").dumps(vol_records, ensure_ascii=False), encoding="utf-8"
    )
    rank = root / "rank" / "poet" / "poet.tang.rank.0.json"
    rank.write_text(
        __import__("json").dumps(rank_records, ensure_ascii=False), encoding="utf-8"
    )
    return poem


def test_unify_fills_popularity_in_index_order(tmp_path):
    root = _make_snapshot(tmp_path)
    _write_pair(
        root,
        [
            {"author": "李白", "title": "静夜思", "paragraphs": ["床前明月光。"]},
            {"author": "杜甫", "title": "春望", "paragraphs": ["国破山河在。"]},
        ],
        [
            {"author": "李白", "baidu": 9999},           # → 4.0
            {"author": "杜甫", "baidu": 99, "bing": 9},  # → 2+1 = 3.0
        ],
    )
    out = list(unify_with_rank([root / "全唐诗" / "poet.tang.0.json"], TANG, root))
    assert [r["popularity"] for r in out] == [4.0, 3.0]


def test_unify_unpaired_volume_keeps_null(tmp_path):
    root = _make_snapshot(tmp_path)
    poem = root / "全唐诗" / "poet.tang.42.json"
    poem.write_text('[{"author":"王维","paragraphs":["空山新雨后。"]}]', encoding="utf-8")
    out = list(unify_with_rank([poem], TANG, root))
    assert out[0]["popularity"] is None


def test_unify_poems_exceed_rank_raises(tmp_path):
    root = _make_snapshot(tmp_path)
    _write_pair(
        root,
        [
            {"author": "李白", "paragraphs": ["床前明月光。"]},
            {"author": "杜甫", "paragraphs":["国破山河在。"]},  # rank 只有1条
        ],
        [{"author": "李白", "baidu": 100}],
    )
    with pytest.raises(RankPairingError, match="长度不一致"):
        list(unify_with_rank([root / "全唐诗" / "poet.tang.0.json"], TANG, root))


def test_unify_length_mismatch_empties_volume_when_issues_collected(tmp_path):
    """宽松模式(传 issues): 长度不等的卷热度置空并登记,构建继续。"""
    root = _make_snapshot(tmp_path)
    _write_pair(
        root,
        [
            {"author": "李白", "paragraphs": ["床前明月光。"]},
            {"author": "杜甫", "paragraphs": ["国破山河在。"]},
        ],
        [{"author": "李白", "baidu": 100}, {"author": "杜甫", "baidu": 200},
         {"author": "多出", "baidu": 5}],
    )
    issues: list[dict] = []
    out = list(
        unify_with_rank(
            [root / "全唐诗" / "poet.tang.0.json"], TANG, root, issues=issues
        )
    )
    assert len(out) == 2
    assert all(r["popularity"] is None for r in out)  # 宁缺毋滥
    assert len(issues) == 1
    assert issues[0]["collection"] == "tangshi"
    assert issues[0]["rank_count"] == 3 and issues[0]["poem_count"] == 2


def test_unify_rank_longer_than_poems_raises(tmp_path):
    root = _make_snapshot(tmp_path)
    _write_pair(
        root,
        [{"author": "李白", "paragraphs": ["床前明月光。"]}],
        [
            {"author": "李白", "baidu": 100},
            {"author": "多余", "baidu": 100},  # rank 多出一条
        ],
    )
    with pytest.raises(RankPairingError, match="长度不一致"):
        list(unify_with_rank([root / "全唐诗" / "poet.tang.0.json"], TANG, root))


def test_author_mismatch_warns_but_does_not_block(tmp_path, caplog):
    root = _make_snapshot(tmp_path)
    _write_pair(
        root,
        [{"author": "李白", "paragraphs": ["床前明月光。"]}],
        [{"author": "李太白", "baidu": 100}],  # 别名写法
    )
    with caplog.at_level(logging.WARNING):
        out = list(unify_with_rank([root / "全唐诗" / "poet.tang.0.json"], TANG, root))
    assert out[0]["popularity"] == 2.004  # log10(1+100)≈2.004
    assert any("作者名不一致" in r.message for r in caplog.records)


def test_output_serializable_after_rank_fill(tmp_path):
    """回填后的记录必须仍满足统一 schema 的序列化契约。"""
    root = _make_snapshot(tmp_path)
    _write_pair(
        root,
        [{"author": "李白", "paragraphs": ["床前明月光。"]}],
        [{"author": "李白", "baidu": 100}],
    )
    out = list(unify_with_rank([root / "全唐诗" / "poet.tang.0.json"], TANG, root))
    import json

    assert json.loads(serialize_record(out[0]))["popularity"] == 2.004
