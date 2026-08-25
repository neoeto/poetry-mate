"""ETL 命令行入口。

当前仅提供环境自检子命令；构建相关子命令随任务 1.3~1.9 逐步加入。
"""
from __future__ import annotations

import argparse
import sys


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="poetry-etl", description="Poetry Mate 数据管道"
    )
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("info", help="环境自检（Python 版本 / OpenCC / stdlib zstd）")

    dl = sub.add_parser("download", help="拉取上游快照并报告各集子卷数")
    dl.add_argument("--commit", help="显式指定 commit sha(生产构建推荐)")
    dl.add_argument("--ref", default="master", help="分支/标签名(默认 master,受 API 限流约束)")
    dl.add_argument("--dest", default="work", help="工作目录(默认 ./work)")

    b = sub.add_parser("build", help="统一+rank关联+分卷打包,产出数据包目录")
    b.add_argument("--commit", help="显式指定 commit sha(生产构建推荐)")
    b.add_argument("--ref", default="master")
    b.add_argument("--dest", default="work")
    b.add_argument("--out", default="dist")
    b.add_argument("--max-records", type=int, default=None,
                   help="单卷记录数上限(默认 1000,即 spec 契约值)")
    b.add_argument("--limit-files", type=int, default=None,
                   help="每集子仅处理前 N 卷(小样本试跑用,勿用于生产)")
    b.add_argument("--prev", default=None,
                   help="上一版产物目录(diff 出别名);缺省视为首次构建")
    b.add_argument("--no-gate", action="store_true",
                   help="跳过构建后的自动门禁(不推荐)")

    g = sub.add_parser("gate", help="对产物目录执行发布前校验门禁")
    g.add_argument("--dir", required=True, help="版本目录路径")

    args = parser.parse_args(argv)
    if args.command == "info":
        _run_info()
    elif args.command == "download":
        _run_download(args)
    elif args.command == "build":
        _run_build(args)
    elif args.command == "gate":
        _run_gate(args)
    return 0


def _run_gate(args: argparse.Namespace) -> None:
    import sys
    from pathlib import Path

    from poetry_etl.gate import format_gate_report, run_gate

    errors = run_gate(Path(args.dir))
    if errors:
        print(format_gate_report(errors), file=sys.stderr)
        raise SystemExit(1)
    print(f"门禁通过: {args.dir}")


def _run_download(args: argparse.Namespace) -> None:
    from pathlib import Path

    from poetry_etl.download import discover, download_snapshot, resolve_commit

    commit = args.commit or resolve_commit(args.ref)
    print(f"快照 commit: {commit}")
    snapshot = download_snapshot(commit, Path(args.dest))
    found = discover(snapshot)
    for collection_id in sorted(found):
        print(f"  {collection_id:<8} {len(found[collection_id]):>4} 卷")


def _run_build(args: argparse.Namespace) -> None:
    from pathlib import Path

    from poetry_etl.download import (
        V1_COLLECTIONS,
        discover,
        download_snapshot,
        resolve_commit,
    )
    from poetry_etl.pack import RECORDS_PER_VOLUME, BuildParams, build_distribution, make_version

    commit = args.commit or resolve_commit(args.ref)
    print(f"构建版本 commit: {commit}")
    snapshot = download_snapshot(commit, Path(args.dest))
    found = discover(snapshot)
    if args.limit_files:
        found = {cid: files[: args.limit_files] for cid, files in found.items()}
        print(f"[试跑模式] 每集子仅处理前 {args.limit_files} 卷")

    params = BuildParams(
        version=make_version(commit),
        source_commit=commit,
        max_records_per_volume=args.max_records or RECORDS_PER_VOLUME,
    )
    try:
        manifest = build_distribution(
            params,
            found,
            snapshot,
            Path(args.out),
            previous_version_root=Path(args.prev) if args.prev else None,
        )
    except FileExistsError as exc:
        raise SystemExit(f"错误: {exc}")

    version_root = Path(args.out) / params.version
    total = sum(c["record_count"] for c in manifest["collections"].values())
    for cid, c in manifest["collections"].items():
        print(f"  {cid:<8} {c['record_count']:>7} 条 -> {c['volume_count']:>3} 卷")
    print(f"合计 {total} 条; 产物目录: {version_root}")

    if not args.no_gate:
        from poetry_etl.gate import format_gate_report, run_gate

        gate_errors = run_gate(version_root)
        if gate_errors:
            print(format_gate_report(gate_errors), file=sys.stderr)
            raise SystemExit(1)
        print("自动门禁通过 ✓")


def _run_info() -> None:
    print(f"python={sys.version.split()[0]}")

    import opencc

    converter = opencc.OpenCC("t2s")
    sample = "綺殿千尋起，離宮百雉餘。"
    print(f"[opencc t2s ] {sample} -> {converter.convert(sample)}")

    import compression.zstd as zstd  # PEP 784, Python 3.14+

    payload = "床前明月光，疑是地上霜。".encode("utf-8")
    compressed = zstd.compress(payload, level=19)
    restored = zstd.decompress(compressed).decode("utf-8")
    print(
        f"[stdlib zstd ] level=19 往返成功: {restored!r} "
        f"(原始 {len(payload)}B -> 压缩 {len(compressed)}B)"
    )


if __name__ == "__main__":
    raise SystemExit(main())
