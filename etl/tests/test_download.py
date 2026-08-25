"""下载器单元测试（离线，不访问网络）。

真实网络拉取由 POETRY_ETL_LIVE=1 门控的集成测试覆盖，
日常 CI 只跑离线部分；布局假设变更时先跑 live 测试哨兵。
"""
import os

import pytest

from poetry_etl.download import V1_COLLECTIONS, discover, natural_key


def _make_fake_snapshot(tmp_path):
    """构造一个迷你快照树，模拟上游目录结构。"""
    root = tmp_path / "snapshot"
    (root / "全唐诗").mkdir(parents=True)
    (root / "宋词").mkdir(parents=True)
    (root / "images").mkdir(parents=True)

    def touch(rel: str, content: str = "[]") -> None:
        f = root / rel
        f.write_text(content, encoding="utf-8")

    # 唐诗: 故意乱序创建,验证自然排序
    touch("全唐诗/poet.tang.0.json", '[{"author":"太宗皇帝","title":"帝京篇十首 一","paragraphs":["秦川雄帝宅，"],"id":"x"}]')
    touch("全唐诗/poet.tang.10.json")
    touch("全唐诗/poet.tang.2.json")
    # 宋诗与唐诗同目录!(实测事实)
    touch("全唐诗/poet.song.0.json")
    # 作者文件必须被 pattern 排除
    touch("全唐诗/authors.tang.json")
    # 宋词
    touch("宋词/ci.song.0.json")
    # 无关目录必须被忽略
    touch("images/logo.png")
    return root


def test_natural_sort_numeric_aware(tmp_path):
    d = tmp_path / "d"
    d.mkdir()
    names = ["poet.tang.10.json", "poet.tang.2.json", "poet.tang.0.json"]
    for n in names:
        (d / n).write_text("[]", encoding="utf-8")
    keys = [p.name for p in sorted(d.iterdir(), key=natural_key)]
    assert keys == ["poet.tang.0.json", "poet.tang.2.json", "poet.tang.10.json"]


def test_discover_maps_collections_and_excludes_noise(tmp_path):
    root = _make_fake_snapshot(tmp_path)
    found = discover(root)

    assert [p.name for p in found["tangshi"]] == [
        "poet.tang.0.json",
        "poet.tang.2.json",
        "poet.tang.10.json",
    ]
    assert [p.name for p in found["songshi"]] == ["poet.song.0.json"]
    assert [p.name for p in found["songci"]] == ["ci.song.0.json"]


def test_wanted_selective_extraction_rules():
    """解压白名单必须同时覆盖集子目录与 rank 目录(回归测试)。"""
    from poetry_etl.download import _wanted

    assert _wanted("全唐诗/poet.tang.0.json")
    assert _wanted("全唐诗/poet.song.0.json")
    assert _wanted("宋词/ci.song.0.json")
    assert _wanted("rank/poet/poet.tang.rank.0.json")     # ← 曾被拦截的事故点
    assert _wanted("rank/ci/ci.song.rank.0.json")
    assert not _wanted("images/logo.json")               # 无关目录即使 json 也不要
    assert not _wanted("README.md")


def test_registry_v1_scope():
    """v1 注册表冻结为三个 rank 覆盖的集子;改动需走变更流程。"""
    assert {c.id for c in V1_COLLECTIONS} == {"tangshi", "songshi", "songci"}
    by_id = {c.id: c for c in V1_COLLECTIONS}
    # 宋诗与唐诗同目录的历史包袱必须显式记录在注册表里
    assert by_id["songshi"].subdir == by_id["tangshi"].subdir == "全唐诗"
    assert by_id["songci"].type == "ci"


def test_discover_missing_collection_raises_clearly(tmp_path):
    root = tmp_path / "broken"
    (root / "全唐诗").mkdir(parents=True)
    (root / "全唐诗" / "poet.tang.0.json").write_text("[]", encoding="utf-8")
    with pytest.raises(RuntimeError, match="songci"):
        discover(root)  # songci 缺失必须点名报错


# ---------------------------------------------------------------------------
# 真实网络集成测试 —— 仅在 POETRY_ETL_LIVE=1 时运行
# ---------------------------------------------------------------------------

@pytest.mark.skipif(
    os.environ.get("POETRY_ETL_LIVE") != "1",
    reason="真实下载耗时且依赖外网;设置 POETRY_ETL_LIVE=1 启用",
)
def test_live_resolve_and_download(tmp_path):
    from poetry_etl.download import download_snapshot, resolve_commit

    # CI/限流场景应显式 pin commit,绕过受限额约束的 API 解析
    commit = os.environ.get("POETRY_ETL_COMMIT") or resolve_commit("master")
    print(f"\n快照 commit: {commit}")
    snapshot = download_snapshot(commit, tmp_path)
    found = discover(snapshot)
    assert len(found["tangshi"]) > 500   # 全唐诗 5.5 万首 / 每卷千首
    assert len(found["songshi"]) > 200   # 宋诗 26 万首(与唐诗同目录!)
    assert len(found["songci"]) >= 21    # 宋词 2.1 万首
