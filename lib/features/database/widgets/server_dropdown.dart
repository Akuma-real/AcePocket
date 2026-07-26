import 'package:flutter/material.dart';

import '../models/database_server.dart';
import '../models/db_types.dart';

/// 数据库服务器下拉选择框（纯展示，数据由调用方提供）。
class ServerDropdown extends StatelessWidget {
  const ServerDropdown({
    super.key,
    required this.servers,
    required this.value,
    required this.onChanged,
    this.label = '数据库服务器',
    this.showType = true,
    this.enabled = true,
  });

  final List<DatabaseServer> servers;

  /// 当前选中的服务器 id。
  final int? value;

  final ValueChanged<DatabaseServer> onChanged;
  final String label;

  /// 是否在条目里展示类型（同类型列表可关掉）。
  final bool showType;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ids = servers.map((s) => s.id).toSet();
    final current = ids.contains(value) ? value : null;
    return DropdownButtonFormField<int>(
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: Text(servers.isEmpty ? '暂无可用服务器' : '请选择服务器'),
      items: [
        for (final server in servers)
          DropdownMenuItem<int>(
            value: server.id,
            child: Text(
              showType
                  ? '${server.name}（${dbTypeLabel(server.type)} · ${server.displayAddress}）'
                  : '${server.name}（${server.displayAddress}）',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: !enabled || servers.isEmpty
          ? null
          : (id) {
              if (id == null) return;
              onChanged(servers.firstWhere((s) => s.id == id));
            },
    );
  }
}
