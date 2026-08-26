/// 人格系统(任务 1.4) —— 模板随安装包分发,运行期只拼接不改写。
///
/// 契约(specs/poem-annotation「人格系统」):
/// - 三套: 先生/知音/词客, 默认知音;
/// - 人格作用于全部 AI 内容(system prompt 注入), 不影响 UI 文案;
/// - 每条生成物记录生成时的人格。
library;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Persona {
  const Persona(this.id, this.name, this.description, this.assetPath);

  final String id;
  final String name;
  final String description;
  final String assetPath;
}

const personas = <Persona>[
  Persona('xiansheng', '先生', '权威 · 条理 · 鉴赏家', 'assets/personas/xiansheng.md'),
  Persona('zhiyin', '知音', '亲切 · 轻盈 · 老友', 'assets/personas/zhiyin.md'),
  Persona('cike', '词客', '态度 · 文气 · 同好', 'assets/personas/cike.md'),
];

const defaultPersonaId = 'zhiyin';

Persona personaById(String id) =>
    personas.firstWhere((p) => p.id == id, orElse: () => personas[1]);

/// 人格选择持久化 + system prompt 组装。
class PersonaService {
  PersonaService({
    required AssetBundle assets,
    required SharedPreferencesAsync prefs,
  })  : _assets = assets,
        _prefs = prefs;

  static const _key = 'persona_id';

  final AssetBundle _assets;
  final SharedPreferencesAsync _prefs;

  Future<String> selectedId() async =>
      await _prefs.getString(_key) ?? defaultPersonaId;

  Future<void> select(String id) => _prefs.setString(_key, id);

  /// 加载人格模板原文(含护栏条款)
  Future<String> loadPrompt(String personaId) async {
    final persona = personaById(personaId);
    try {
      return await _assets.loadString(persona.assetPath);
    } on Exception {
      // 资产缺失兜底: 回退默认人格
      return await _assets.loadString(defaultPersonaAssetPath);
    }
  }

  /// 组装完整 system prompt: 人格模板 + 本诗事实。
  ///
  /// [poemBody] 为简体全文;[metaLine] 形如 "苏轼 · 宋"。
  Future<String> buildSystemPrompt(
    String personaId, {
    required String poemBody,
    required String metaLine,
  }) async {
    final template = await loadPrompt(personaId);
    return '$template\n\n【本诗】\n$metaLine\n\n$poemBody';
  }
}

const defaultPersonaAssetPath = 'assets/personas/zhiyin.md';
