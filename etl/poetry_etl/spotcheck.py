"""繁简转换质量抽检(任务 2.3)。

对照 etl/spotcheck.json 的固定清单,在构建产物中定位每首名篇并断言
关键简体短语存在。任何失败都意味着 OpenCC 行为漂移或 ETL 回归。

用法:
    .venv/bin/python -m poetry_etl.spotcheck --dir dist-full/v20260825.b8594f81

退出码 0 = 全部通过。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import compression.zstd as zstd

from poetry_etl.normalize import to_simplified


def _load_records(version_root: Path) -> list[dict]:
    records: list[dict] = []
    for path in sorted((version_root / "volumes").glob("*/*.json.zst")):
        payload = zstd.decompress(path.read_bytes()).decode("utf-8")
        records.extend(json.loads(payload))
    return records


def _find(records: list[dict], author: str, title: str) -> list[dict]:
    """先精确匹配(author,title);词类退化为 (author,rhythmic);再退化标题包含。

    上游标题/作者是繁体原文存储,比对前必须先转简(曾因此 12/20 误报未找到)。
    """
    rec_author = [to_simplified(r["author"]) for r in records]
    rec_title = [
        to_simplified(r["title"] or "") + "|" + to_simplified(r["rhythmic"] or "")
        for r in records
    ]
    exact = [
        r
        for r, ra, rt in zip(records, rec_author, rec_title)
        if ra == author and rt.split("|")[0] == title
    ]
    if exact:
        return exact
    by_rhythmic = [
        r for r, ra, rt in zip(records, rec_author, rec_title) if ra == author and rt == title
    ]
    if by_rhythmic:
        return by_rhythmic
    return [
        r for r, ra, rt in zip(records, rec_author, rec_title) if ra == author and title in rt
    ]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="spotcheck")
    parser.add_argument("--dir", required=True, help="版本目录")
    parser.add_argument("--checklist", default=str(Path(__file__).parent.parent / "spotcheck.json"))
    args = parser.parse_args(argv)

    checklist = json.loads(Path(args.checklist).read_text(encoding="utf-8"))
    records = _load_records(Path(args.dir))
    print(f"抽检清单 {len(checklist)} 条,产物记录 {len(records)} 条\n")

    failed = 0
    for case in checklist:
        author, title = case["author"], case["title"]
        hits = _find(records, author, title)
        if not hits:
            print(f"✗ {author}《{title}》: 产物中未找到")
            failed += 1
            continue
        body = "".join("".join(r["paragraphs"]) for r in hits)
        missing = [p for p in case["expect"] if p not in body]
        if missing:
            print(f"✗ {author}《{title}》: 缺少预期短语 {missing}")
            failed += 1
        else:
            print(f"✓ {author}《{title}》 ({case['note']})")

    print()
    if failed:
        print(f"抽检未通过: {failed}/{len(checklist)} 条失败")
        return 1
    print(f"抽检全部通过: {len(checklist)}/{len(checklist)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
