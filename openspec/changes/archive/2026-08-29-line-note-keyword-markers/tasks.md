## 1. L1 模型与生成

- [x] 1.1 为 KeywordNote 增加可选 pinyin 字段并兼容旧 JSON
- [x] 1.2 更新 L1 Prompt 要求返回带声调拼音
- [x] 1.3 增加 L1 拼音解析、缓存和旧数据回归测试

## 2. 阅读页联动

- [x] 2.1 让 LineNoteSheet 在结果加载后通知 ReaderPage
- [x] 2.2 从已有 line_note 缓存恢复关键词标记
- [x] 2.3 将 L1 关键词转换为可点击 WordNote，并与 L2/用户标记合并
- [x] 2.4 在关键词注抽屉中显示拼音，点击原文关键词显示对应解释

## 3. 验证

- [x] 3.1 增加 L1 关键词高亮、点击和缓存恢复 Widget 测试
- [x] 3.2 运行 flutter analyze、全量 Flutter 测试和 iOS 模拟器构建
