// LLM 设置页 widget 测试(任务 1.2):
// 预填 / 保存落库 / 连接测试成功与失败。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/llm_providers.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';
import 'package:poetry_mate/features/settings/llm_settings_page.dart';

import '../fakes/scripted_transport.dart';

void main() {
  late InMemorySecureKeyStore secure;
  late InMemoryPrefsStore prefsStore;
  late ScriptedTransport transport;
  late LlmConfigStore configStore;

  Widget page() {
    return ProviderScope(
      overrides: [
        llmConfigStoreProvider.overrideWithValue(configStore),
        llmTransportProvider.overrideWithValue(transport),
        llmClientProvider.overrideWithValue(
          LlmClient(configStore: configStore, transport: transport),
        ),
      ],
      child: const MaterialApp(home: LlmSettingsPage()),
    );
  }

  setUp(() {
    secure = InMemorySecureKeyStore();
    prefsStore = InMemoryPrefsStore();
    configStore =
        LlmConfigStoreImpl(secureKeyStore: secure, prefs: prefsStore);
    transport = ScriptedTransport(
      jsonResult: {
        'choices': [
          {'message': {'content': '连通'}}
        ],
      },
    );
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
  }

  TextField fieldAt(WidgetTester tester, int index) =>
      tester.widget<TextField>(find.byType(TextField).at(index));

  testWidgets('已有配置 → 表单预填', (tester) async {
    await secure.write('llm_api_key', 'sk-old');
    await prefsStore.setString('llm_base_url', 'https://api.old.com/v1');
    await prefsStore.setString('llm_model', 'old-model');

    await pumpPage(tester);

    expect(fieldAt(tester, 0).controller!.text, 'https://api.old.com/v1');
    expect(fieldAt(tester, 1).controller!.text, 'old-model');
    expect(fieldAt(tester, 2).controller!.text, 'sk-old');
  });

  testWidgets('保存: 字段写入存储并提示已保存', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextField).at(0), 'https://api.new.com/v1');
    await tester.enterText(find.byType(TextField).at(1), 'new-model');
    await tester.enterText(find.byType(TextField).at(2), 'sk-new');

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(await secure.read('llm_api_key'), 'sk-new');
    expect(await prefsStore.getString('llm_base_url'), 'https://api.new.com/v1');
    expect(await prefsStore.getString('llm_model'), 'new-model');
    expect(find.text('已保存'), findsOneWidget);
  });

  testWidgets('测试连接成功: 显示模型回复与鉴权头', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextField).at(0), 'https://api.x.com/v1');
    await tester.enterText(find.byType(TextField).at(1), 'm');
    await tester.enterText(find.byType(TextField).at(2), 'sk');

    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(find.textContaining('连接成功'), findsOneWidget);
    expect(transport.lastHeaders['authorization'], 'Bearer sk');
  });

  testWidgets('测试连接失败: 显示产品化错误', (tester) async {
    transport.statusError = 401;
    await pumpPage(tester);
    await tester.enterText(find.byType(TextField).at(0), 'https://api.x.com/v1');
    await tester.enterText(find.byType(TextField).at(1), 'm');
    await tester.enterText(find.byType(TextField).at(2), 'bad-key');

    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(find.textContaining('密钥无效'), findsOneWidget);
  });

  testWidgets('读取已有配置失败也能进入表单', (tester) async {
    configStore = _ThrowingConfigStore();

    await pumpPage(tester);

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.textContaining('配置读取失败'), findsOneWidget);
  });
}

class _ThrowingConfigStore implements LlmConfigStore {
  @override
  Future<LlmConfig?> read() async => throw StateError('keychain unavailable');

  @override
  Future<void> write(LlmConfig config) async {}

  @override
  Future<void> clear() async {}
}
