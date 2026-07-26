import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/api/ws_client.dart';
import '../../../core/storage/server_store.dart';
import '../models/json_utils.dart';
import '../providers/container_providers.dart';
import 'action_runner.dart';

/// 弹出「拉取镜像」面板。返回 true 表示拉取成功（调用方应刷新列表）。
Future<bool> showImagePullSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _ImagePullSheet(),
  );
  return result ?? false;
}

/// 镜像拉取面板。
///
/// 优先使用 `GET /api/ws/container/image/pull`（连接后发送
/// `{name, auth, username, password}`）以获得逐层进度；
/// 未配置面板账号密码（WS 无法认证）时自动回退到
/// `POST /api/container/image` 的阻塞式拉取。
class _ImagePullSheet extends ConsumerStatefulWidget {
  const _ImagePullSheet();

  @override
  ConsumerState<_ImagePullSheet> createState() => _ImagePullSheetState();
}

class _ImagePullSheetState extends ConsumerState<_ImagePullSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _useAuth = false;
  bool _pulling = false;
  bool _done = false;

  /// 回退到 HTTP 阻塞拉取（无逐层进度）。
  bool _fallbackMode = false;

  String _statusText = '';
  String? _error;

  /// 逐层进度：layerId -> 状态文本。
  final Map<String, _LayerProgress> _layers = {};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  double get _progressValue {
    final layers =
        _layers.values.where((l) => l.id.isNotEmpty && l.id.length >= 8);
    if (layers.isEmpty) return 0;
    final completed = layers
        .where((l) => l.status == 'Pull complete' || l.status == 'Already exists')
        .length;
    return completed / layers.length;
  }

  Future<void> _start() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final server = ref.read(activeServerProvider);

    setState(() {
      _pulling = true;
      _done = false;
      _error = null;
      _layers.clear();
      _fallbackMode = false;
      _statusText = '正在连接…';
    });

    if (server == null) {
      setState(() {
        _pulling = false;
        _error = '尚未选择服务器';
      });
      return;
    }

    try {
      final channel = await wsConnect(server, '/ws/container/image/pull');
      if (!mounted) {
        channel.sink.close();
        return;
      }
      _channel = channel;
      channel.sink.add(jsonEncode({
        'name': name,
        'auth': _useAuth,
        'username': _useAuth ? _usernameController.text : '',
        'password': _useAuth ? _passwordController.text : '',
      }));
      setState(() => _statusText = '正在拉取 $name …');
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _pulling = false;
            _error = describeError(error);
          });
        },
        onDone: () {
          if (!mounted || _done) return;
          setState(() {
            _pulling = false;
            if (_error == null) {
              _done = true;
              _statusText = '拉取结束';
            }
          });
        },
      );
    } on WsAuthException catch (error) {
      // 未配置面板账号密码：回退到 HTTP 拉取（无进度）。
      if (!mounted) return;
      setState(() {
        _fallbackMode = true;
        _statusText = '${describeError(error)}\n已改用普通模式拉取（无实时进度）…';
      });
      await _pullOverHttp(name);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pulling = false;
        _error = describeError(error);
      });
    }
  }

  Future<void> _pullOverHttp(String name) async {
    try {
      await ref.read(containerRepoProvider).pullImage(
            name: name,
            auth: _useAuth,
            username: _usernameController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      setState(() {
        _pulling = false;
        _done = true;
        _statusText = '镜像 $name 拉取完成';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pulling = false;
        _error = '${describeError(error)}\n'
            '（若为超时，镜像可能仍在服务器后台拉取，可稍后刷新列表确认）';
      });
    }
  }

  void _onMessage(dynamic message) {
    final text = message is String
        ? message
        : message is List<int>
            ? const Utf8Decoder(allowMalformed: true).convert(message)
            : '$message';
    if (text.trim().isEmpty) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return;
    }
    final map = asMap(decoded);
    if (map.isEmpty) return;

    final error = asString(map['error']);
    if (error.isNotEmpty || asString(map['status']) == 'error') {
      setState(() {
        _pulling = false;
        _error = error.isEmpty ? '拉取失败' : error;
      });
      return;
    }

    if (asBool(map['complete'])) {
      setState(() {
        _pulling = false;
        _done = true;
        _statusText = '拉取完成';
      });
      return;
    }

    final status = asString(map['status']);
    final id = asString(map['id']);
    final detail = asMap(map['progressDetail']);
    final current = asInt(detail['current']);
    final total = asInt(detail['total']);

    setState(() {
      if (id.isEmpty) {
        if (status.isNotEmpty) _statusText = status;
      } else {
        _layers[id] = _LayerProgress(
          id: id,
          status: status,
          current: current,
          total: total,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final server = ref.watch(activeServerProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('拉取镜像', style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(_done),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          enabled: !_pulling,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: '镜像名称',
                            hintText: '如 nginx:alpine',
                          ),
                          validator: (value) =>
                              (value ?? '').trim().isEmpty ? '请输入镜像名称' : null,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('使用仓库账号'),
                          subtitle: const Text('拉取私有仓库镜像时开启'),
                          value: _useAuth,
                          onChanged: _pulling
                              ? null
                              : (value) => setState(() => _useAuth = value),
                        ),
                        if (_useAuth) ...[
                          TextFormField(
                            controller: _usernameController,
                            enabled: !_pulling,
                            decoration:
                                const InputDecoration(labelText: '仓库用户名'),
                            validator: (value) => _useAuth &&
                                    (value ?? '').trim().isEmpty
                                ? '请输入仓库用户名'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !_pulling,
                            obscureText: true,
                            decoration:
                                const InputDecoration(labelText: '仓库密码'),
                            validator: (value) =>
                                _useAuth && (value ?? '').isEmpty
                                    ? '请输入仓库密码'
                                    : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_statusText.isNotEmpty)
                    Text(
                      _statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (_pulling) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _fallbackMode || _layers.isEmpty
                          ? null
                          : _progressValue,
                    ),
                  ],
                  if (_layers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final layer in _layers.values)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  layer.display,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    fontFamilyFallback: const ['Courier'],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                  if (_fallbackMode && server != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(_done);
                          context.push(
                            '/servers/edit?id=${server.id}&advanced=1',
                          );
                        },
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('补填面板账号以查看实时进度'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_done)
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.check),
                      label: const Text('完成'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _pulling ? null : _start,
                      icon: _pulling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(_pulling ? '拉取中…' : '开始拉取'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerProgress {
  const _LayerProgress({
    required this.id,
    required this.status,
    required this.current,
    required this.total,
  });

  final String id;
  final String status;
  final int current;
  final int total;

  String get display {
    if (total > 0 && current > 0) {
      final percent = (current / total * 100).clamp(0, 100).toStringAsFixed(0);
      return '$id  $status  $percent%';
    }
    return '$id  $status';
  }
}
