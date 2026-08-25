"""诗词规范化契约与内容寻址 ID。

契约来源: specs/poem-id —— 本模块是全系统唯一实现，任何重实现必须逐字节复现。

规范化两阶段(2026-08 修订 —— 原'先剥后转'顺序在实盘中被证伪):

    阶段一(生成期): 繁转简  converted = OpenCC.t2s(原文)
    阶段二(纯函数):  对【转换后的简体文本】逐串执行:
        1. Unicode NFC 归一化
        2. 移除全部标点(显式枚举字符集)
        3. 移除全部空白(含零宽)

    ID 计算:
        payload = "|".join(canonical_strip(各简体段))
        poem_id = sha256(payload)[:128bit]

    为什么这样定: t2s 不幂等(繁体词组语境保护如 宮徵調 的 徵,
    简体再转时语境消失会二次漂移)。把 t2s 放在哈希管道之外、
    让 ID 只取决于【出货的简体阅读文本】的剥离形式,
    门禁即可用纯函数从存储正文复算 ID,永不漂移。
    繁/简同文同 ID 性质依然成立(繁体经阶段一收敛到同一简体文本)。

设计要点：
- 分隔符 "|" 在逐段剥离之后才参与拼接，因此段落边界信息得以保留
  （["明月出天山"] 与 ["明月", "出天山"] 必然产生不同 ID）；
- preface 参与哈希且拼于正文之前；title/author 永不参与；
- 组诗保持数据源记录粒度，由调用方保证不合并/拆分 paragraphs。
"""
from __future__ import annotations

import hashlib
import unicodedata

import opencc

# ---------------------------------------------------------------------------
# 剥离字符集 —— 显式枚举，属于 ID 契约的一部分。
# 修改此集合 = 全库 ID 大迁徙，必须走 OpenSpec 变更流程。
# ---------------------------------------------------------------------------

# (起始码点, 结束码点) 闭区间列表
_PUNCT_RANGES: tuple[tuple[int, int], ...] = (
    (0x0021, 0x002F),  # ASCII: ! " # $ % & ' ( ) * + , - . /
    (0x003A, 0x0040),  # ASCII: : ; < = > ? @
    (0x005B, 0x0060),  # ASCII: [ \\ ] ^ _ `
    (0x007B, 0x007E),  # ASCII: { | } ~   ← 注意: 0x7C '|' 在集合内,
    #                      但分隔符在逐段剥离之后才拼接, 不受影响
    (0x2000, 0x206F),  # General Punctuation: – — ' ' " " … ‧ 等
    (0x3000, 0x303F),  # CJK Symbols and Punctuation: 　 、 。 〈 〉 《 》 「 」 『 』 【 】 〜 〰
    (0xFF01, 0xFF0F),  # 全角: ！＂＃…／
    (0xFF1A, 0xFF20),  # 全角: ：；＜＝＞？＠
    (0xFF3B, 0xFF40),  # 全角: ［＼］＾＿｀
    (0xFF5B, 0xFF65),  # 全角: ｛｜｝～ 与半角片假名中点 ・
    (0xFE10, 0xFE19),  # 竖排标点
    (0xFE30, 0xFE4F),  # CJK 兼容形式(括号注音点等)
)

# 散落各处的补充符号
_EXTRA_PUNCT: tuple[str, ...] = (
    "\u00b7",  # · MIDDLE DOT
    "\u2027",  # ‧ HYPHENATION POINT
    "\u30fb",  # ・ KATAKANA MIDDLE DOT (冗余,双保险)
)

# 控制字符与非常规空白
_CONTROL_RANGES: tuple[tuple[int, int], ...] = (
    (0x0000, 0x0020),  # 控制字符 + 空格 U+0020(勿拆开,否则空格漏网)
    (0x007F, 0x009F),
    (0x00A0, 0x00A0),  # NBSP
    (0x1680, 0x1680),  # OGHAM SPACE MARK
    (0x2028, 0x2029),  # 行/段分隔符(已在 2000-206F 内,双保险)
    (0x202F, 0x205F),  # NARROW NBSP / MEDIUM MATH SPACE
    (0x200B, 0x200B),  # ZERO WIDTH SPACE
    (0x200E, 0x200F),  # LRM / RLM
    (0xFEFF, 0xFEFF),  # BOM / ZERO WIDTH NO-BREAK SPACE
)


def _build_strip_table() -> dict[int, None]:
    """构建 str.translate 所需的映射。

    注意: str.translate 要求键为**码点整数**(ordinal), 而非单字符字符串;
    字符串键会被静默忽略(查不到即保留), 这是曾真实发生过的 bug。
    """
    codes: set[int] = set()
    for start, end in (*_PUNCT_RANGES, *_CONTROL_RANGES):
        codes.update(range(start, end + 1))
    codes.update(ord(ch) for ch in _EXTRA_PUNCT)
    return {code: None for code in codes}


_STRIP_TABLE: dict[int, None] = _build_strip_table()

_T2S = opencc.OpenCC("t2s")


def strip_canonical(text: str) -> str:
    """纯函数规范化: NFC → 去标点/控制/空白。不含任何转换步骤。"""
    return unicodedata.normalize("NFC", text).translate(_STRIP_TABLE)


def to_simplified(text: str) -> str:
    """繁转简(生成期使用;非幂等,勿对输出重复调用)。"""
    return _T2S.convert(text)


def normalize_string(text: str) -> str:
    """便捷组合: 先转简再规范剥离。等价于对转换结果调用 strip_canonical。"""
    return strip_canonical(to_simplified(text))


def canonical_payload(
    simplified_paragraphs: list[str], preface: str | None = None
) -> str:
    """【纯函数】从简体段落构建哈希输入串(段落边界以 "|" 保留)。

    这是 ID 的唯一真源: 门禁凭本函数从存储正文复算 ID。
    """
    parts: list[str] = []
    if preface:
        parts.append(strip_canonical(preface))
    parts.extend(strip_canonical(p) for p in simplified_paragraphs)
    return "|".join(parts)


def normalized_payload(
    paragraphs: list[str], preface: str | None = None
) -> str:
    """规范化哈希输入串(入参应为简体;别名比对在已转换记录上操作)。"""
    return canonical_payload(paragraphs, preface)


def compute_poem_id(
    paragraphs: list[str], preface: str | None = None
) -> str:
    """按 poem-id 规范计算内容寻址 ID(输入允许繁体或简体)。

    内部先繁转简再做规范剥离;返回 sha256 前 128 bit 的 32 位小写十六进制串。
    """
    simplified = [to_simplified(p) for p in paragraphs]
    preface_simplified = to_simplified(preface) if preface else None
    payload = canonical_payload(simplified, preface_simplified)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:32]


def poem_id_from_simplified(
    simplified_paragraphs: list[str], preface: str | None = None
) -> str:
    """【门禁专用】从已转换的简体段落复算 ID(不再经过 t2s,纯函数无漂移)。"""
    payload = canonical_payload(simplified_paragraphs, preface)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:32]
