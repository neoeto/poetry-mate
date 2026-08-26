/// LLM 相关依赖装配。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'llm_client.dart';
import 'llm_config.dart';
import 'llm_transport.dart';
import 'secure_key_store.dart';

final secureKeyStoreProvider =
    Provider<SecureKeyStore>((ref) => const FlutterSecureKeyStore());

final sharedPreferencesAsyncProvider = Provider<SharedPreferencesAsync>(
    (ref) => SharedPreferencesAsync());

final prefsStoreProvider = Provider<PrefsStore>(
    (ref) => SharedPrefsStore(ref.watch(sharedPreferencesAsyncProvider)));

final llmConfigStoreProvider = Provider<LlmConfigStore>((ref) {
  return LlmConfigStoreImpl(
    secureKeyStore: ref.watch(secureKeyStoreProvider),
    prefs: ref.watch(prefsStoreProvider),
  );
});

final llmTransportProvider =
    Provider<LlmTransport>((ref) => HttpLlmTransport());

final llmClientProvider = Provider<LlmClient>((ref) {
  return LlmClient(
    configStore: ref.watch(llmConfigStoreProvider),
    transport: ref.watch(llmTransportProvider),
  );
});
