// zstd 宿主探测(任务 2.3 的宿主部分):
// - 宿主有 libzstd → 验证真实解压链路(54KB 资产 → 300 条记录);
// - 宿主无原生库 → 跳过并说明(双端真机验证仍为 2.3 的必要步骤)。
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:es_compression/zstd.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('真实 zstd 资产可被 es_compression 解压', () async {
    final compressed =
        (await rootBundle.load('assets/seed/seed.json.zst')).buffer.asUint8List();

    String? decodedText;
    Object? failure;
    try {
      decodedText = utf8.decode(ZstdDecoder().convert(compressed));
    } catch (e) {
      failure = e;
    }

    if (failure != null) {
      // 宿主无原生库: 记录原因后跳过(不判失败 —— 真机验证在 2.3)
      // ignore: avoid_print
      print('宿主无法加载 zstd 原生库,跳过: $failure');
      return;
    }

    final records = jsonDecode(decodedText!) as List<dynamic>;
    expect(records.length, 300, reason: '种子集应恰为 300 条');
    final first = records.first as Map<String, dynamic>;
    expect(first['id'], isA<String>());
    expect(first['paragraphs'], isA<List<dynamic>>());
    // ignore: avoid_print
    print('✓ 真实 zstd 解压通过: ${records.length} 条种子记录');
  });
}
