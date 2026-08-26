/// 分类页过滤选项 —— v1 固定三集子维度(与数据注册表对齐)。
///
/// 更细的题材标签(tags 字段)留待后续版本。

library;

class BrowseFilters {
  const BrowseFilters(this.key, this.label, this.dynasty, this.type);

  final String key;
  final String label;
  final String? dynasty;
  final String? type;

  (String?, String?) toQuery() => (dynasty, type);

  static const allKey = 'all';
  static const all = <BrowseFilters>[
    BrowseFilters(allKey, '全部', null, null),
    BrowseFilters('tangshi', '唐诗', '唐', 'shi'),
    BrowseFilters('songshi', '宋诗', '宋', 'shi'),
    BrowseFilters('songci', '宋词', '宋', 'ci'),
  ];
}
