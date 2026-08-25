"""校验门禁测试(离线)。"""
import json

import pytest

from poetry_etl.download import COLLECTIONS_BY_ID
from poetry_etl.gate import run_gate, validate_record
from poetry_etl.pack import BuildParams, build_distribution

TANG = COLLECTIONS_BY_ID["tangshi"]
COMMIT = "c" * 40


def _build_min_distribution(tmp_path):
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
    params = BuildParams(version="v20260101.gate0001", source_commit=COMMIT)
    dest = tmp_path / "dist"
    build_distribution(
        params,
        {"tangshi": [root / "全唐诗" / "poet.tang.0.json"]},
        root,
        dest,
        collections=(TANG,),
    )
    return dest / params.version


# ---------- 记录级(validate_record 直接断言) ----------


def _errors_of(rec):
    errors: list[str] = []
    validate_record(rec, "t#0", errors)
    return errors


def test_valid_record_passes_silently():
    from poetry_etl.normalize import compute_poem_id

    body = ["床前明月光，疑是地上霜。"]
    rec = {
        "id": compute_poem_id(body),
        "author": "李白",
        "title": None,
        "dynasty": "唐",
        "type": "shi",
        "paragraphs": body,
        "preface": None,
        "rhythmic": None,
        "popularity": None,
        "raw_text": body,
        "tags": None,
        "source_collection": "tangshi",
    }
    assert _errors_of(rec) == []


@pytest.mark.parametrize(
    "field_name",
    ["id", "author", "dynasty", "type", "paragraphs", "raw_text", "source_collection"],
)
def test_required_fields_flagged_when_null(field_name):
    base = {
        "id": "0bca75304901c0dd8abb1c3e98a5a3c7",
        "author": "李白",
        "title": None,
        "dynasty": "唐",
        "type": "shi",
        "paragraphs": ["床前明月光。"],
        "preface": None,
        "rhythmic": None,
        "popularity": None,
        "raw_text": ["床前明月光。"],
        "tags": None,
        "source_collection": "tangshi",
    }
    base[field_name] = None
    assert any(field_name in e for e in _errors_of(base))


def test_id_format_enforced():
    rec = {
        "id": "NOT-A-HASH",
        "author": "李白",
        "title": None,
        "dynasty": "唐",
        "type": "shi",
        "paragraphs": ["床前明月光。"],
        "preface": None,
        "rhythmic": None,
        "popularity": None,
        "raw_text": ["床前明月光。"],
        "tags": None,
        "source_collection": "tangshi",
    }
    assert any("id 格式非法" in e for e in _errors_of(rec))


def test_id_recomputation_mismatch_detected():
    """变换链完整性: 正文被篡改而 id 未同步时必须暴露。"""
    wrong_id = "0" * 32
    rec = {
        "id": wrong_id,
        "author": "李白",
        "title": None,
        "dynasty": "唐",
        "type": "shi",
        "paragraphs": ["床前明月光。"],
        "preface": None,
        "rhythmic": None,
        "popularity": None,
        "raw_text": ["床前明月光。"],
        "tags": None,
        "source_collection": "tangshi",
    }
    errors = _errors_of(rec)
    assert any("id 与正文不符" in e for e in errors)


def test_raw_text_length_mismatch():
    rec = {
        "id": "0" * 32,
        "author": "李白",
        "title": None,
        "dynasty": "唐",
        "type": "shi",
        "paragraphs": ["a。", "b。"],
        "preface": None,
        "rhythmic": None,
        "popularity": None,
        "raw_text": ["a。"],
        "tags": None,
        "source_collection": "tangshi",
    }
    assert any("长度不一致" in e for e in _errors_of(rec))


def test_surrogate_and_nul_detected():
    rec = {
        "author": "李\ud800白",
        "paragraphs": ["text\x00evil。"],
        "title": None,
        "dynasty": "唐",
        "type": "shi",
        "raw_text": ["text evil。"],
        "id": None,
        "preface": None,
        "rhythmic": None,
        "popularity": None,
        "tags": None,
        "source_collection": "tangshi",
    }
    errors = _errors_of(rec)
    assert any("非法字符" in e for e in errors)


# ---------- 目录级(run_gate 集成) ----------


def test_happy_distribution_passes_gate(tmp_path):
    version_root = _build_min_distribution(tmp_path)
    assert run_gate(version_root) == []


def test_missing_manifest_fails_fast(tmp_path):
    (tmp_path / "vEmpty").mkdir()
    errors = run_gate(tmp_path / "vEmpty")
    assert any("manifest.json" in e for e in errors)


def test_tampered_volume_detected(tmp_path):
    version_root = _build_min_distribution(tmp_path)
    volume = next((version_root / "volumes").glob("*/*.json.zst"))
    blob = bytearray(volume.read_bytes())
    blob[-3] ^= 0xFF  # 翻转压缩流尾部字节
    volume.write_bytes(bytes(blob))
    errors = run_gate(version_root)
    assert any("sha256" in e or "解压" in e for e in errors)


def test_missing_alias_artifact_detected(tmp_path):
    version_root = _build_min_distribution(tmp_path)
    (version_root / "aliases.json").unlink()
    errors = run_gate(version_root)
    assert any("aliases.json" in e for e in errors)
