"""构建摘要输出(供 CI Step Summary 与本地检查)。

用法: summarize.py <version_dir>
"""
from __future__ import annotations

import json
import pathlib
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("用法: summarize.py <version_dir>", file=sys.stderr)
        return 2
    root = pathlib.Path(sys.argv[1])
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))

    total = sum(c["record_count"] for c in manifest["collections"].values())
    name = root.name
    print(f"## ETL 构建 {name}")
    print(f"- 合计 {total} 条,来源 commit {manifest['source_commit'][:12]}")
    for cid, entry in manifest["collections"].items():
        print(f"  - {cid}: {entry['record_count']} 条 / {entry['volume_count']} 卷")

    issues = json.loads((root / "build-issues.json").read_text(encoding="utf-8"))
    print(f"- 数据缺陷登记: {len(issues)} 处")
    pending = json.loads((root / "pending-review.json").read_text(encoding="utf-8"))
    print(f"- 别名待复核: {len(pending)} 条")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
