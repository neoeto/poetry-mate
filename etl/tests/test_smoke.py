"""冒烟测试：包可导入、ID 契约的关键依赖在位且行为正确。"""


def test_package_importable():
    import poetry_etl

    assert poetry_etl.__version__


def test_opencc_t2s_available():
    """OpenCC 是 ID 契约的一部分，转换结果必须稳定正确。"""
    import opencc

    converter = opencc.OpenCC("t2s")
    assert converter.convert("風") == "风"
    assert converter.convert("綺殿千尋起") == "绮殿千寻起"


def test_stdlib_zstd_roundtrip():
    """Python 3.14 标准库 zstd（PEP 784），level 19 可用。"""
    import compression.zstd

    data = "春風又綠江南岸".encode("utf-8")
    compressed = compression.zstd.compress(data, level=19)
    assert compression.zstd.decompress(compressed) == data
