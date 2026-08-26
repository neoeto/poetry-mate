// 字体注册冒烟: 以文楷族渲染文本,确保资产加载与绘制链路无异常。
// (字形是否真的来自文楷需真机目检 —— 自动化只验证"不崩且完成绘制")
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/ui/app_theme.dart';

void main() {
  testWidgets('文楷字体族渲染不崩溃', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Text(
            '床前看月光，疑是地上霜。龜靄籲', // 含繁体与生僻字形
            style: const TextStyle(fontFamily: PoetryFonts.content),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('床前看月光'), findsOneWidget);
  });
}
