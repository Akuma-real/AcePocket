import 'json_utils.dart';
import 'kv.dart';

/// 容器存储卷（对应源码 `pkg/types/container_volume.go` 的 `ContainerVolume`）。
///
/// 删除接口的 `{id}` 实际传卷名（前端 `volumeRemove(row.name)`）。
class ContainerVolume {
  const ContainerVolume({
    this.name = '',
    this.driver = '',
    this.scope = '',
    this.mountPoint = '',
    this.createdAt,
    this.labels = const [],
    this.options = const [],
    this.refCount = 0,
    this.size = '',
  });

  final String name;
  final String driver;
  final String scope;
  final String mountPoint;
  final DateTime? createdAt;
  final List<KV> labels;
  final List<KV> options;

  /// 引用该卷的容器数（-1 表示未知）。
  final int refCount;

  /// 服务端格式化后的占用大小字符串。
  final String size;

  factory ContainerVolume.fromJson(Map<String, dynamic> json) =>
      ContainerVolume(
        name: asString(json['name']),
        driver: asString(json['driver']),
        scope: asString(json['scope']),
        mountPoint: asString(json['mount_point']),
        createdAt: asDateTime(json['created_at']),
        labels: KV.listFromJson(json['labels']),
        options: KV.listFromJson(json['options']),
        refCount: asInt(json['ref_count']),
        size: asString(json['size']),
      );

  bool get inUse => refCount > 0;
}
