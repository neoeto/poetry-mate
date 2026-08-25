"""Schema 统一器（任务 1.4）。

把上游各集子的原始记录统一为本管道的标准结构。输出字段：

    id                 str           内容寻址 ID(见 normalize.compute_poem_id)
    author             str|None
    title              str|None      ← 宋词上游无 title,显式 null(UI 层用词牌呈现)
    dynasty            str           来自作品集注册表
    type               str           shi/ci,来自注册表
    paragraphs         list[str]     ★简体正文
    preface            None          上游实测丢弃一切小序(水调歌头/扬州慢/琵琶引
                                     三例均无序),v1 恒为 null;字段保留作契约
    rhythmic           str|None      仅词有
    popularity         None          本模块不填,由 rank.py(任务1.5)回填
    raw_text           list[str]     转换前原文留档(唐诗=繁体),与 paragraphs 等长
    tags               list[str]|None 上游稀疏题材标签(边塞/送别/宋词三百首...)
                                     ※ 实施中发现的数据红利,已申请并入 schema 契约
    source_collection  str           作品集 id

ID 计算输入是【原始】段落——规范化契约内部先剥离后转简,
故繁体原文与简体转换文本计算出相同 ID(有测试钉死此性质)。
"""
from __future__ import annotations

import json
import logging
from collections.abc import Iterator
from pathlib import Path

from opencc import OpenCC

from poetry_etl.download import CollectionSpec
from poetry_etl.normalize import compute_poem_id

logger = logging.getLogger(__name__)

_T2S = OpenCC("t2s")

# 统一记录的全部键,顺序即输出顺序
UNIFIED_KEYS: tuple[str, ...] = (
    "id",
    "author",
    "title",
    "dynasty",
    "type",
    "paragraphs",
    "preface",
    "rhythmic",
    "popularity",
    "raw_text",
    "tags",
    "source_collection",
)


class SchemaError(ValueError):
    """上游记录结构性缺陷(缺字段/类型错),构建应失败。"""


def unify_record(raw: dict, spec: CollectionSpec) -> dict:
    """单条原始记录 → 统一结构 dict(键序固定)。"""
    author = raw.get("author")
    if not isinstance(author, str) or not author.strip():
        raise SchemaError(f"[{spec.id}] 缺少 author: {raw.get('title', '?')!r}")

    raw_paragraphs = raw.get("paragraphs")
    if (
        not isinstance(raw_paragraphs, list)
        or not raw_paragraphs
        or not all(isinstance(p, str) and p.strip() for p in raw_paragraphs)
    ):
        raise SchemaError(f"[{spec.id}] {author}: paragraphs 为空或类型非法")

    title = raw.get("title")
    if title is not None and not isinstance(title, str):
        raise SchemaError(f"[{spec.id}] {author}: title 类型非法")

    tags = raw.get("tags") or None
    if tags is not None and (
        not isinstance(tags, list) or not all(isinstance(t, str) for t in tags)
    ):
        logger.warning("[%s] %s: tags 类型异常,置空", spec.id, author)
        tags = None

    return {
        "id": compute_poem_id(raw_paragraphs),
        "author": author,
        "title": title,
        "dynasty": spec.dynasty,
        "type": spec.type,
        "paragraphs": [_T2S.convert(p) for p in raw_paragraphs],
        "preface": None,  # 上游无小序数据,见模块 docstring
        "rhythmic": raw.get("rhythmic"),
        "popularity": None,  # 由 rank.py 回填
        "raw_text": list(raw_paragraphs),
        "tags": tags,
        "source_collection": spec.id,
    }


def iter_unified(
    files: list[Path], spec: CollectionSpec, *, skipped: list[dict] | None = None
) -> Iterator[dict]:
    """流式转换一组同集子文件。

    - 文件级损坏(解析失败/顶层非数组)立即抛错 —— 结构性故障不硬扛;
    - 记录级缺陷(空段落等上游垃圾, 实测全唐仅4条)跳过并登记进 skipped,
      不为个别脏数据中止整库构建; 产物侧零缺陷由门禁保证。
    """
    total = 0
    for path in files:
        try:
            records = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            raise SchemaError(f"[{spec.id}] 文件解析失败: {path.name} ({exc})") from exc
        if not isinstance(records, list):
            raise SchemaError(f"[{spec.id}] 文件顶层不是数组: {path.name}")
        for index, raw in enumerate(records):
            try:
                unified = unify_record(raw, spec)
            except SchemaError as exc:
                if skipped is None:
                    raise
                logger.warning("[%s] %s#%d 跳过坏记录: %s", spec.id, path.name, index, exc)
                skipped.append(
                    {
                        "kind": "schema_skipped",
                        "collection": spec.id,
                        "file": path.name,
                        "record_index": index,
                        "author": raw.get("author")
                        if isinstance(raw, dict)
                        else None,
                        "title": raw.get("title") if isinstance(raw, dict) else None,
                        "reason": str(exc),
                    }
                )
                continue
            yield unified
            total += 1
    logger.info("[%s] 统一完成: %d 条", spec.id, total)


def serialize_record(record: dict) -> str:
    """单行序列化(供中间 JSONL 使用);键序由 UNIFIED_KEYS 钉死。"""
    ordered = {k: record[k] for k in UNIFIED_KEYS}
    return json.dumps(ordered, ensure_ascii=False, separators=(",", ":"))


def deserialize_record(line: str) -> dict:
    """serialize_record 的逆操作。"""
    record = json.loads(line)
    if tuple(record.keys()) != UNIFIED_KEYS:
        raise SchemaError(f"记录键序与契约不符: {tuple(record.keys())}")
    return record
