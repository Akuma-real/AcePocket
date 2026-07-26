/// 通用「值-标签」选项（用于网站 / 数据库 / 容器 / 备份存储等下拉选择）。
class OptionItem {
  const OptionItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OptionItem && other.value == value && other.label == label;

  @override
  int get hashCode => Object.hash(value, label);
}

/// 备份存储选项（存储 ID 为整数，0 表示面板本地存储）。
class StorageOption {
  const StorageOption({required this.id, required this.name});

  final int id;
  final String name;
}
