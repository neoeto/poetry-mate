// 部分 JSON 解析器测试(流式渐进渲染的协议层):
// 截断修复 / 只产出已闭合字段 / 数组元素逐个出现 / 围栏与噪声前缀。
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/domain/entities/annotations.dart';

void main() {
  group('tryDecodePartialJsonObject', () {
    test('空输入与无对象起始 → null', () {
      expect(tryDecodePartialJsonObject(''), isNull);
      expect(tryDecodePartialJsonObject('模型正在思考…'), isNull);
      expect(tryDecodePartialJsonObject('```json\n'), isNull);
    });

    test('完整输入: 全部字段闭合,无 open 状态', () {
      final snapshot = tryDecodePartialJsonObject(
        '{"summary":"游子思乡","mood":"静"}',
      )!;

      expect(snapshot.closedValues['summary'], '游子思乡');
      expect(snapshot.closedValues['mood'], '静');
      expect(snapshot.openKeys, isEmpty);
      expect(snapshot.openArrayItems, isEmpty);
    });

    test('字符串值中途截断: 该字段不产出', () {
      final snapshot = tryDecodePartialJsonObject(
        '{"summary":"游子思乡","mood":"静夜意',
      )!;

      expect(snapshot.closedValues['summary'], '游子思乡');
      expect(snapshot.closedValues.containsKey('mood'), isFalse);
      expect(snapshot.openKeys, contains('mood'));
    });

    test('key 本身中途截断: 已完成字段保留', () {
      final snapshot = tryDecodePartialJsonObject('{"summary":"游子思乡","cr')!;

      expect(snapshot.closedValues['summary'], '游子思乡');
      expect(snapshot.closedValues, hasLength(1));
    });

    test('值写了一半的 key(有冒号无值): 标记为 open', () {
      final snapshot = tryDecodePartialJsonObject('{"summary"')!;

      expect(snapshot.closedValues, isEmpty);
      expect(snapshot.openKeys, contains('summary'));
    });

    test('数组元素逐个出现: 未闭合数组仅返回已闭合元素', () {
      final json =
          '{"notes":[{"term":"疑","explain":"好像"},'
          '{"term":"霜","explain":"霜露"},';
      final snapshot = tryDecodePartialJsonObject(json)!;

      expect(snapshot.openKeys, contains('notes'));
      final items = snapshot.openArrayItems['notes']!;
      expect(items, hasLength(2));
      expect(items.first['term'], '疑');
      expect(items.last['term'], '霜');
    });

    test('数组元素中途截断: 尾元素舍弃', () {
      final json = '{"notes":[{"term":"疑","explain":"好像"},{"term":"霜","expl';
      final snapshot = tryDecodePartialJsonObject(json)!;

      final items = snapshot.openArrayItems['notes']!;
      expect(items, hasLength(1));
      expect(items.single['term'], '疑');
    });

    test('完整闭合的数组进入 closedValues', () {
      final snapshot = tryDecodePartialJsonObject(
        '{"notes":[{"term":"疑"}],"mood":"静"}',
      )!;

      expect(snapshot.closedValues['notes'], hasLength(1));
      expect(snapshot.openKeys, isEmpty);
    });

    test('嵌套对象中途截断: 不污染顶层字段', () {
      final snapshot = tryDecodePartialJsonObject(
        '{"summary":"思乡","background":{"text":"相传作于',
      )!;

      expect(snapshot.closedValues['summary'], '思乡');
      expect(snapshot.closedValues.containsKey('background'), isFalse);
      expect(snapshot.openKeys, contains('background'));
    });

    test('嵌套对象完整闭合: 顶层字段产出整个对象', () {
      final snapshot = tryDecodePartialJsonObject(
        '{"background":{"text":"相传出蜀","uncertain":true}}',
      )!;

      final background = snapshot.closedValues['background'] as Map;
      expect(background['text'], '相传出蜀');
      expect(background['uncertain'], isTrue);
    });

    test('布尔/数字原始值', () {
      final snapshot = tryDecodePartialJsonObject(
        '{"uncertain":true,"line_index":2,"broken":fals',
      )!;

      expect(snapshot.closedValues['uncertain'], isTrue);
      expect(snapshot.closedValues['line_index'], 2);
      expect(snapshot.openKeys, contains('broken'));
    });

    test('数字前缀不算闭合: 12 可能是 123', () {
      final snapshot = tryDecodePartialJsonObject('{"line_index":12')!;

      expect(snapshot.closedValues.containsKey('line_index'), isFalse);
      expect(snapshot.openKeys, contains('line_index'));
    });

    test('围栏与说明文字前导自动容忍', () {
      final snapshot = tryDecodePartialJsonObject(
        '好的，这是赏析：\n```json\n{"summary":"思乡"}\n```',
      )!;

      expect(snapshot.closedValues['summary'], '思乡');
    });

    test('转义字符: 闭合引号/换行/半截 \\u', () {
      final snapshot = tryDecodePartialJsonObject(
        r'{"summary":"引号\"内\"换行\n"}',
      )!;
      expect(snapshot.closedValues['summary'], '引号"内"换行\n');

      final truncated = tryDecodePartialJsonObject(r'{"summary":"\u4e2')!;
      expect(truncated.closedValues, isEmpty);
      expect(truncated.openKeys, contains('summary'));
    });

    test('流式累积过程: 快照单调长出', () {
      const full =
          '{"translation":"月光洒在床前","notes":[{"term":"疑","pinyin":"yí"}]}';
      final seen = <int>[];
      for (var end = 1; end <= full.length; end++) {
        final snapshot = tryDecodePartialJsonObject(full.substring(0, end));
        if (snapshot == null || snapshot.isEmpty) continue;
        final noteCount =
            snapshot.openArrayItems['notes']?.length ??
            (snapshot.closedValues['notes'] as List?)?.length ??
            0;
        // 单调不减
        if (seen.isNotEmpty) expect(noteCount, greaterThanOrEqualTo(seen.last));
        seen.add(noteCount);
      }
      expect(seen.last, 1); // 最终 note 出现
    });
  });

  group('partial 快照 → 领域模型', () {
    test('EssayContent.fromPartialSnapshot: 缺字段留空,闭合字段呈现', () {
      final snapshot = tryDecodePartialJsonObject(
        '{"summary":"游子思乡","craft":[{"point":"疑字","detail":"以幻写真"},{"point":"未',
      )!;

      final essay = EssayContent.fromPartialSnapshot(snapshot);

      expect(essay.summary, '游子思乡');
      expect(essay.mood, isEmpty);
      expect(essay.emotion, isEmpty);
      expect(essay.craft, hasLength(1)); // 已闭合条目保留
      expect(essay.craft.single.point, '疑字');
      expect(essay.background.uncertain, isTrue); // 缺省背景
      expect(essay.wordNotes, isEmpty);
    });

    test('LineNoteContent.fromPartialSnapshot: notes 逐条出现', () {
      final snapshot = tryDecodePartialJsonObject(
        '{"translation":"月光洒在床前","notes":[{"term":"疑","pinyin":"yí","explain":"好像"},',
      )!;

      final note = LineNoteContent.fromPartialSnapshot(snapshot);

      expect(note.translation, '月光洒在床前');
      expect(note.notes, hasLength(1));
      expect(note.notes.single.term, '疑');
    });

    test('closed 空数组与 open 空数组可区分(模型没给 vs 还没到)', () {
      final closedEmpty = EssayContent.fromPartialSnapshot(
        tryDecodePartialJsonObject('{"summary":"x","craft":[]}')!,
      );
      final notYet = EssayContent.fromPartialSnapshot(
        tryDecodePartialJsonObject('{"summary":"x","cra')!,
      );

      // closed 空: craft 键在 closedValues → UI 显示"模型未提供"
      expect(
        tryDecodePartialJsonObject(
          '{"summary":"x","craft":[]}',
        )!.closedValues.containsKey('craft'),
        isTrue,
      );
      // open: 只在 openKeys
      expect(
        tryDecodePartialJsonObject('{"summary":"x","cra')!.openKeys,
        isEmpty, // key 未写完,连 open 都不算
      );
      expect(closedEmpty.craft, isEmpty);
      expect(notYet.craft, isEmpty);
    });
  });
}
