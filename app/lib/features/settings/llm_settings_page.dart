/// LLM 配置页(任务 1.2) —— 三元组表单 + 连接测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/llm_client.dart';
import '../../core/llm/llm_config.dart';
import '../../core/llm/llm_exception.dart';
import '../../core/llm/llm_providers.dart';

class LlmSettingsPage extends ConsumerStatefulWidget {
  const LlmSettingsPage({super.key});

  @override
  ConsumerState<LlmSettingsPage> createState() => _LlmSettingsPageState();
}

class _LlmSettingsPageState extends ConsumerState<LlmSettingsPage> {
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _loaded = false;
  String? _loadError;

  String? _testStatus; // null=未测试
  bool? _testOk;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final config = await ref
          .read(llmConfigStoreProvider)
          .read()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        if (config != null) {
          _baseUrlController.text = config.baseUrl;
          _modelController.text = config.model;
          _apiKeyController.text = config.apiKey;
        }
        _loaded = true;
      });
    } catch (_) {
      // Keychain/偏好读取失败不能把配置页永久卡在 loading；
      // 允许用户重新填写并覆盖保存，不展示平台异常细节。
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _loadError = '已有配置读取失败，请重新填写并保存。';
      });
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  LlmConfig _configFromFields() => LlmConfig(
        baseUrl: _baseUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(),
      );

  bool get _fieldsValid => _configFromFields().isComplete;

  Future<void> _save() async {
    if (!_fieldsValid) {
      _showSnack('三项都需要填写');
      return;
    }
    try {
      await ref.read(llmConfigStoreProvider).write(_configFromFields());
    } catch (_) {
      if (mounted) _showSnack('安全存储暂不可用，请稍后再试');
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存')));
  }

  Future<void> _testConnection() async {
    if (!_fieldsValid) {
      _showSnack('先填写完整三项再测试');
      return;
    }
    setState(() {
      _testing = true;
      _testStatus = null;
    });

    // 用表单当前值构造一次性客户端(不落盘,先测后存)
    final config = _configFromFields();
    final client = LlmClient(
      configStore: _StaticConfigStore(config),
      transport: ref.read(llmTransportProvider),
    );

    try {
      final reply = await client.complete(
        [const LlmMessage('user', '请只回复两个字：连通')],
        maxTokens: 20,
        temperature: 0,
      );
      setState(() {
        _testOk = true;
        _testStatus = '连接成功，模型回复：${reply.trim()}';
      });
    } on LlmException catch (e) {
      setState(() {
        _testOk = false;
        _testStatus = e.message;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LLM 配置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_loaded) const LinearProgressIndicator(),
          if (!_loaded) const SizedBox(height: 12),
          Text('接入你自己的 OpenAI 兼容模型服务（BYOK）。\n'
              'API Key 只保存在本机安全存储中。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (_loadError != null) ...[
            const SizedBox(height: 10),
            Text(
              _loadError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.deepseek.com/v1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: '模型名称',
              hintText: 'deepseek-chat',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              FilledButton(onPressed: _save, child: const Text('保存')),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.network_check),
                label: const Text('测试连接'),
              ),
            ],
          ),
          if (_testStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _testStatus!,
                style: TextStyle(
                  color: _testOk == true
                      ? Colors.green.shade700
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 仅用于"先测后存"的一次性配置容器
class _StaticConfigStore implements LlmConfigStore {
  _StaticConfigStore(this.config);

  final LlmConfig config;

  @override
  Future<LlmConfig?> read() async => config;

  @override
  Future<void> write(LlmConfig config) async {}

  @override
  Future<void> clear() async {}
}
