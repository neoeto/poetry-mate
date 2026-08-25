"""发布前校验门禁（任务 1.8）。

对产物目录做全面体检,任何一项不合格即判构建失败(spec 门禁):

    L1 清单层   manifest 存在且可解析; version 与目录名一致; 别名工件在位
    L2 卷层     文件存在; sha256/字节数与 manifest 登记一致; 记录数一致
    L3 记录层   必填字段非空; id 符合 ^[0-9a-f]{32}$;
                id 可由存储的简体正文重算得出(变换链完整性);
                raw_text 与 paragraphs 等长; 文本无代理字符/NUL

用法:
    poetry-etl gate --dir dist/v20260825.b8594f81     # 退出码 0=通过 1=失败

build 子命令在构建完成后自动执行本门禁(--no-gate 可跳过),
从结构上保证"校验不过的数据包不可能被发布到 R2"。
"""
from __future__ import annotations

import json
import logging
import re
from pathlib import Path

import compression.zstd as zstd

from poetry_etl.normalize import poem_id_from_simplified
from poetry_etl.pack import sha256_of_file

logger = logging.getLogger(__name__)

ID_RE = re.compile(r"^[0-9a-f]{32}$")

# 非 null 即必须存在的字段(title/preface/rhythmic/popularity/tags 允许 null)
REQUIRED_FIELDS: tuple[str, ...] = (
    "id",
    "author",
    "dynasty",
    "type",
    "paragraphs",
    "raw_text",
    "source_collection",
)

# 代理对半字符或 NUL —— 编码合法性哨兵
_BAD_CHARS = re.compile("[\ud800-\udfff\u0000]")


def _check_text(value: object, where: str, errors: list[str]) -> None:
    if not isinstance(value, str):
        errors.append(f"{where}: 期望字符串,实际 {type(value).__name__}")
        return
    hit = _BAD_CHARS.search(value)
    if hit:
        errors.append(f"{where}: 含非法字符 U+{ord(hit.group()):04X}")


def validate_record(rec: object, where: str, errors: list[str]) -> None:
    """L3 单条记录校验,错误追加进 errors。"""
    if not isinstance(rec, dict):
        errors.append(f"{where}: 记录不是对象")
        return

    for field_name in REQUIRED_FIELDS:
        value = rec.get(field_name)
        if value is None:
            errors.append(f"{where}: 必填字段 {field_name} 缺失或为 null")

    poem_id = rec.get("id")
    if isinstance(poem_id, str) and not ID_RE.match(poem_id):
        errors.append(f"{where}: id 格式非法: {poem_id!r}")

    paragraphs = rec.get("paragraphs")
    raw_text = rec.get("raw_text")

    if isinstance(paragraphs, list) and paragraphs:
        if not all(isinstance(p, str) and p.strip() for p in paragraphs):
            errors.append(f"{where}: paragraphs 存在空项或非字符串项")
        if not isinstance(raw_text, list) or len(raw_text) != len(paragraphs):
            errors.append(
                f"{where}: raw_text({len(raw_text) if isinstance(raw_text, list) else '非数组'})"
                f" 与 paragraphs({len(paragraphs)}) 长度不一致"
            )
        else:
            # 变换链完整性: 用纯函数从存储的简体正文复算 ID(无 t2s,永不漂移)
            recomputed = poem_id_from_simplified(paragraphs, rec.get("preface"))
            if poem_id is not None and recomputed != poem_id:
                errors.append(
                    f"{where}: id 与正文不符(存量={poem_id}, 重算={recomputed})"
                )
    elif paragraphs == []:
        errors.append(f"{where}: paragraphs 为空数组")

    for text_field in ("author", "title", "rhythmic", "preface"):
        value = rec.get(text_field)
        if value is not None:
            _check_text(value, f"{where}.{text_field}", errors)

    if isinstance(paragraphs, list):
        for i, paragraph in enumerate(paragraphs):
            if isinstance(paragraph, str):
                _check_text(paragraph, f"{where}.paragraphs[{i}]", errors)


def _load_json(path: Path, errors: list[str]) -> object | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        errors.append(f"缺少文件: {path.name}")
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        errors.append(f"{path.name} 解析失败: {exc}")
    return None


def run_gate(version_root: Path, *, max_reported: int = 50) -> list[str]:
    """全量体检。返回错误列表;空列表 = 通过。"""
    errors: list[str] = []

    manifest_path = version_root / "manifest.json"
    manifest = _load_json(manifest_path, errors)
    if manifest is None:
        return errors[:max_reported]
    if not isinstance(manifest, dict):
        return [f"{manifest_path.name}: 顶层不是对象"]

    if manifest.get("version") != version_root.name:
        errors.append(
            f"manifest.version({manifest.get('version')!r}) 与目录名({version_root.name})不一致"
        )
    if not manifest.get("source_commit"):
        errors.append("manifest 缺少 source_commit")

    collections = manifest.get("collections")
    if not isinstance(collections, dict) or not collections:
        errors.append("manifest.collections 为空或缺失")

    for artifact in ("aliases.json", "pending-review.json", "build-issues.json"):
        payload = _load_json(version_root / artifact, errors)
        if payload is not None and not isinstance(payload, list):
            errors.append(f"{artifact} 顶层不是数组")

    total_records = 0
    total_volumes = 0

    if isinstance(collections, dict):
        for cid, summary in collections.items():
            if not isinstance(summary, dict):
                errors.append(f"[{cid}] manifest 片段不是对象")
                continue
            volumes = summary.get("volumes")
            if not isinstance(volumes, list) or not volumes:
                errors.append(f"[{cid}] 无卷条目")
                continue
            for entry in volumes:
                if not isinstance(entry, dict):
                    errors.append(f"[{cid}] 卷条目不是对象")
                    continue
                rel = entry.get("file", "?")
                volume_path = version_root / str(rel)
                if not volume_path.is_file():
                    errors.append(f"[{cid}] 卷文件缺失: {rel}")
                    continue
                total_volumes += 1

                actual_sha = sha256_of_file(volume_path)
                if actual_sha != entry.get("sha256"):
                    errors.append(f"[{cid}] {rel}: sha256 与 manifest 不符")
                actual_bytes = volume_path.stat().st_size
                if actual_bytes != entry.get("bytes"):
                    errors.append(f"[{cid}] {rel}: 字节数与 manifest 不符")

                try:
                    records = json.loads(
                        zstd.decompress(volume_path.read_bytes()).decode("utf-8")
                    )
                except Exception as exc:  # noqa: BLE001 - 解压失败即门禁失败
                    errors.append(f"[{cid}] {rel}: 解压/解析失败 ({exc})")
                    continue
                if not isinstance(records, list):
                    errors.append(f"[{cid}] {rel}: 卷内顶层不是数组")
                    continue
                if len(records) != entry.get("records"):
                    errors.append(
                        f"[{cid}] {rel}: 记录数与 manifest 不符"
                        f"(实际 {len(records)} vs 登记 {entry.get('records')})"
                    )
                if len(records) > 1000:
                    errors.append(f"[{cid}] {rel}: 超过单卷 1000 条上限")

                for index, record in enumerate(records):
                    total_records += 1
                    if len(errors) < max_reported * 10:  # 防止错误刷屏失控
                        validate_record(record, f"{rel}#{index}", errors)

    logger.info(
        "门禁扫描完成: %d 集 / %d 卷 / %d 条记录, %d 处问题",
        len(collections) if isinstance(collections, dict) else 0,
        total_volumes,
        total_records,
        len(errors),
    )
    return errors[:max_reported]


def format_gate_report(errors: list[str], *, max_show: int = 20) -> str:
    lines = [f"门禁未通过,共 {len(errors)} 处问题:"]
    lines.extend(f"  - {e}" for e in errors[:max_show])
    if len(errors) > max_show:
        lines.append(f"  ...(其余 {len(errors) - max_show} 处省略)")
    return "\n".join(lines)
