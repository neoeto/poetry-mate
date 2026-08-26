/// zstd 解压默认实现(es_compression FFI)。
///
/// 注意: 真实 codec 依赖原生库,**宿主单元测试环境可能无法加载**;
/// 因此 SeedLoader 的解压函数设计为可注入,测试注入恒等函数。

library;
import 'dart:typed_data';

import 'package:es_compression/zstd.dart';

typedef Decompressor = Uint8List Function(Uint8List data);

Uint8List esZstdDecompress(Uint8List data) =>
    Uint8List.fromList(ZstdDecoder().convert(data));
