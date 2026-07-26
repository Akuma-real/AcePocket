import '../../../core/providers/paged_notifier_base.dart';

/// 解析面板列表接口的分页载荷 `data: { total, items }`
/// （见源码 `internal/service/respond.go` 的 `Page[T]`），
/// 直接产出 core 分页设施使用的 [PagedResult]。
///
/// [itemParser] 负责解析单个条目；对 null / 非法结构容错，返回空列表。
PagedResult<T> parsePagedResult<T>(
  dynamic json,
  T Function(Map<String, dynamic>) itemParser,
) {
  if (json is! Map) {
    return PagedResult<T>(total: 0, items: <T>[]);
  }
  final items = <T>[];
  final rawItems = json['items'];
  if (rawItems is List) {
    for (final item in rawItems) {
      if (item is Map) {
        items.add(itemParser(Map<String, dynamic>.from(item)));
      }
    }
  }
  return PagedResult<T>(
    total: (json['total'] as num?)?.toInt() ?? items.length,
    items: items,
  );
}
