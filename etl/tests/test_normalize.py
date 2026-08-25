"""poem-id 规范化契约的回归测试。

黄金向量是 ID 契约的一部分: 若以下任何断言失败,说明规范化算法被意外改动,
全库 ID 将发生漂移。修改算法必须先走 OpenSpec 变更流程,再有意更新本文件。
"""
import re

from poetry_etl.normalize import compute_poem_id, normalize_string

# 《静夜思》黄金向量 —— 2026-08 由契约实现 v1 生成并经人工复核
JINGYESI_SIMP = ["床前明月光，", "疑是地上霜。", "举头望明月，", "低头思故乡。"]
JINGYESI_TRAD = ["床前明月光，", "疑是地上霜。", "舉頭望明月，", "低頭思故鄉。"]
GOLDEN_ID = "0bca75304901c0dd8abb1c3e98a5a3c7"

HEX32 = re.compile(r"^[0-9a-f]{32}$")


# ---------- 剥离行为(曾出过 bug 的地方必须有直接断言) ----------


def test_punctuation_actually_stripped():
    """直接断言标点消失,而非仅依赖哈希间接验证。"""
    out = normalize_string("春風又綠江南岸。")
    assert out == "春风又绿江南岸"
    for punct in "，。！？；：、（）「」《》":
        assert punct not in normalize_string(f"甲{punct}乙")


def test_ascii_and_fullwidth_forms_stripped():
    assert "/" not in normalize_string("a/b")
    assert "！" not in normalize_string("甲！乙")
    assert "~" not in normalize_string("甲~乙")


def test_all_whitespace_stripped():
    assert normalize_string("床前 明月\u3000光") == "床前明月光"
    assert normalize_string("床前\t明\n月\r\u00a0光") == "床前明月光"
    assert normalize_string("床\u200b前明\ufeff月光") == "床前明月光"  # 零宽字符


def test_traditional_converted_to_simplified():
    assert normalize_string("綺殿千尋起") == "绮殿千寻起"


def test_nfc_composition_equivalence():
    composed = "e\u0301"  # e + 组合锐音符
    assert normalize_string(composed) == normalize_string("\u00e9")


def test_hanzi_and_digits_survive():
    assert normalize_string("春曉二十三") == "春晓二十三"


# ---------- ID 计算 ----------


def test_golden_vector_jingyesi():
    assert compute_poem_id(JINGYESI_SIMP) == GOLDEN_ID


def test_traditional_variant_same_id():
    """同一作品繁简两版必须同 ID(去重能力的根基)。"""
    assert compute_poem_id(JINGYESI_SIMP) == compute_poem_id(JINGYESI_TRAD)


def test_id_format_is_32_lowercase_hex():
    assert HEX32.match(compute_poem_id(JINGYESI_SIMP))


def test_single_char_difference_changes_id():
    a = compute_poem_id(["远上寒山石径斜，白云生处有人家。"])
    b = compute_poem_id(["远上寒山石径斜，白云深处有人家。"])
    assert a != b  # 异文"生处/深处"


def test_paragraph_boundaries_preserved():
    assert compute_poem_id(["明月出天山"]) != compute_poem_id(["明月", "出天山"])


def test_preface_participates():
    body = ["明月几时有？把酒问青天。"]
    without = compute_poem_id(body)
    with_pre = compute_poem_id(body, preface="丙辰中秋，欢饮达旦。")
    assert with_pre != without
    # 序文的标点差异不影响(已被剥离)
    assert compute_poem_id(body, preface="丙辰中秋欢饮达旦") == with_pre


def test_empty_input_is_deterministic():
    assert compute_poem_id([]) == compute_poem_id([])
    assert HEX32.match(compute_poem_id([]))
