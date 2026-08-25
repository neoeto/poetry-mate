"""上游下载器（任务 1.3）。

职责：
- 把 ref（master/标签/分支）解析为具体 commit sha —— 数据快照的唯一标识；
- 经 codeload tarball 浅拉取快照，**只解压**管道关心的目录；
- 按作品集注册表发现数据文件（自然排序，保证卷序跨机器稳定）。

仓库布局事实（2026-08 对 master 实测，勿凭记忆修改）：
    全唐诗/poet.tang.N.json        唐诗
    全唐诗/poet.song.N.json        宋诗 ← 目录名叫"全唐诗"，但含宋诗！
    全唐诗/authors.*.json          作者小传（v1 不消费）
    宋词/ci.song.N.json            宋词
    rank/poet/poet.{tang,song}.rank.N.json   热度（任务 1.5 关联）
    rank/ci/ci.song.rank.N.json              热度（字段: baidu/bing/bing_en/so360/google）

注意：GitHub API 匿名限额 60 次/小时；生产构建应显式传入 commit，
resolve_commit 仅用于交互式场景。
"""
from __future__ import annotations

import logging
import re
import shutil
import tarfile
import time
from dataclasses import dataclass
from pathlib import Path

import requests

logger = logging.getLogger(__name__)

GITHUB_REPO = "chinese-poetry/chinese-poetry"
_API_COMMIT = "https://api.github.com/repos/{repo}/commits/{ref}"
_CODELOAD = "https://codeload.github.com/{repo}/tar.gz/{commit}"

_TIMEOUT = (15, 900)


@dataclass(frozen=True)
class CollectionSpec:
    """一个作品集的静态描述。新增集子 = 在此追加条目。"""

    id: str          # 稳定标识，进入 API 路径与存储布局
    title: str       # 面向用户的作品集名
    subdir: str      # 上游仓库内所在目录
    pattern: str     # 文件名 glob
    dynasty: str     # 元数据：朝代
    type: str        # 元数据：体裁大类(shi/ci)


V1_COLLECTIONS: tuple[CollectionSpec, ...] = (
    CollectionSpec("tangshi", "全唐诗", "全唐诗", "poet.tang.*.json", "唐", "shi"),
    CollectionSpec("songshi", "全宋诗", "全唐诗", "poet.song.*.json", "宋", "shi"),
    CollectionSpec("songci", "全宋词", "宋词", "ci.song.*.json", "宋", "ci"),
)

COLLECTIONS_BY_ID: dict[str, CollectionSpec] = {c.id: c for c in V1_COLLECTIONS}

# 需要从 tarball 中解压的上游目录(images 等一律跳过)
# 注意必须包含 rank 目录,否则热度关联全部落空(曾真实发生过)
RANK_SUBDIR: dict[str, str] = {
    "tangshi": "rank/poet",
    "songshi": "rank/poet",
    "songci": "rank/ci",
}

_WANTED_SUBDIRS: frozenset[str] = frozenset(
    [c.subdir for c in V1_COLLECTIONS] + list(RANK_SUBDIR.values())
)

_DIGITS = re.compile(r"(\d+)")


def natural_key(path: Path) -> tuple:
    """自然排序键：poet.tang.2 < poet.tang.10（纯字典序会得到 1,10,2）。"""

    def atom(text: str) -> tuple[int, int] | tuple[int, str]:
        return (0, int(text)) if text.isdigit() else (1, text)

    return tuple(atom(t) for t in _DIGITS.split(path.name))


def resolve_commit(ref: str = "master", *, token: str | None = None) -> str:
    """把 ref 解析为 commit sha。匿名调用受 GitHub API 限流约束。"""
    headers = {"Accept": "application/vnd.github+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    resp = requests.get(_API_COMMIT.format(repo=GITHUB_REPO, ref=ref), headers=headers, timeout=30)
    resp.raise_for_status()
    return resp.json()["sha"]


def _wanted(rel_path: str) -> bool:
    """按相对路径前缀判断是否解压。

    白名单含两级路径(如 rank/poet),故不能用首层组件做集合成员判断——
    曾因此把整个 rank 目录拦在快照之外(真实事故,勿回退)。
    """
    if not rel_path.endswith(".json"):
        return False
    return any(rel_path.startswith(f"{sub}/") for sub in _WANTED_SUBDIRS)


def _extract_tarball(tarball: Path, snapshot_dir: Path) -> None:
    """选择性解压：剥离 tarball 首层目录，仅保留注册表涉及的子目录中的 json。"""
    snapshot_dir.mkdir(parents=True, exist_ok=True)
    with tarfile.open(tarball, "r:gz") as tar:
        members = tar.getmembers()
        prefix = next(
            (m.name.split("/", 1)[0] for m in members if "/" in m.name), None
        )
        if prefix is None:
            raise RuntimeError("tarball 结构异常：找不到顶层目录")
        plen = len(prefix) + 1
        selected = [
            m
            for m in members
            if m.isfile() and _wanted(m.name[plen:])
        ]
        logger.info("解压 %d/%d 个成员到 %s", len(selected), len(members), snapshot_dir)
        for member in selected:
            member.name = member.name[plen:]  # 剥离首层目录
            tar.extract(member, snapshot_dir, filter="data")


def download_snapshot(
    commit: str,
    dest_root: Path,
    *,
    retries: int = 3,
) -> Path:
    """拉取指定 commit 的快照并选择性解压，返回快照根目录。

    幂等：若目标快照已存在完成标记则直接返回。
    """
    snapshot_dir = dest_root / f"snapshot-{commit[:12]}"
    marker = snapshot_dir / ".snapshot-ok"
    if marker.exists():
        logger.info("快照已存在，跳过下载: %s", snapshot_dir)
        return snapshot_dir

    url = _CODELOAD.format(repo=GITHUB_REPO, commit=commit)
    dest_root.mkdir(parents=True, exist_ok=True)
    tarball = dest_root / f"chinese-poetry-{commit[:12]}.tar.gz"

    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            logger.info("下载 %s (第 %d/%d 次)", url, attempt, retries)
            started = time.monotonic()
            with requests.get(url, stream=True, timeout=_TIMEOUT) as resp:
                resp.raise_for_status()
                total = 0
                with tarball.open("wb") as fh:
                    for chunk in resp.iter_content(chunk_size=1 << 20):
                        fh.write(chunk)
                        total += len(chunk)
                        if total % (64 << 20) < (1 << 20):
                            logger.info("已下载 %.0f MB...", total / (1 << 20))
            elapsed = time.monotonic() - started
            logger.info("下载完成: %.0f MB, 耗时 %.0fs", total / (1 << 20), elapsed)
            break
        except requests.RequestException as exc:
            last_error = exc
            tarball.unlink(missing_ok=True)
            if attempt == retries:
                raise RuntimeError(f"下载失败（已重试 {retries} 次）: {url}") from exc
            backoff = 5 * attempt
            logger.warning("下载失败(%s)，%ds 后重试", exc, backoff)
            time.sleep(backoff)

    try:
        _extract_tarball(tarball, snapshot_dir)
    except Exception:
        shutil.rmtree(snapshot_dir, ignore_errors=True)
        raise
    finally:
        tarball.unlink(missing_ok=True)  # 解压完即删，磁盘友好

    marker.write_text(commit, encoding="utf-8")
    return snapshot_dir


def discover(snapshot_dir: Path) -> dict[str, list[Path]]:
    """按注册表发现各作品集的数据文件。

    返回 {collection_id: 自然排序后的文件列表}。
    任一注册集中的集子一个文件都没找到即抛错（上游结构变更的哨兵）。
    """
    result: dict[str, list[Path]] = {}
    missing: list[str] = []
    for spec in V1_COLLECTIONS:
        base = snapshot_dir / spec.subdir
        files = sorted(base.glob(spec.pattern), key=natural_key) if base.is_dir() else []
        if not files:
            missing.append(f"{spec.id}({spec.subdir}/{spec.pattern})")
        result[spec.id] = [f.resolve() for f in files]
    if missing:
        raise RuntimeError(f"以下作品集未发现任何数据文件，上游结构可能已变更: {', '.join(missing)}")
    return result
