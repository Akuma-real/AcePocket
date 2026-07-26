import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_card.dart';
import '../models/cron.dart';
import '../providers/cron_providers.dart';
import '../providers/options_providers.dart';
import '../providers/storage_providers.dart';
import '../widgets/cron_expression_field.dart';
import '../widgets/feedback.dart';
import '../widgets/kv_editor.dart';
import '../widgets/multi_select_field.dart';
import '../widgets/no_server_view.dart';
import '../widgets/string_list_editor.dart';

/// 计划任务创建 / 编辑页（`/crons/edit`，带 `id` 查询参数时为编辑）。
class CronEditPage extends ConsumerStatefulWidget {
  const CronEditPage({super.key, this.id});

  /// 为 null 表示新建。
  final int? id;

  @override
  ConsumerState<CronEditPage> createState() => _CronEditPageState();
}

class _CronEditPageState extends ConsumerState<CronEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _timeController = TextEditingController(text: '*/30 * * * *');
  final _scriptController = TextEditingController(
    text: '#!/bin/bash\n'
        'export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:'
        '/usr/local/sbin:\$PATH\n\n'
        '# 在此填写脚本内容\n',
  );
  final _urlController = TextEditingController();
  final _bodyController = TextEditingController();
  final _keepController = TextEditingController(text: '1');
  final _timeoutController = TextEditingController(text: '10');
  final _retriesController = TextEditingController(text: '0');

  String _type = CronTypes.shell;
  String _subType = 'website';
  bool _flock = false;
  int _storage = 0;
  List<String> _targets = const [];
  String _method = 'GET';
  List<KvEntry> _headers = [];
  bool _insecure = false;

  bool _nameEdited = false;
  bool _loading = false;
  Object? _loadError;
  bool _saving = false;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (_nameController.text.isNotEmpty) _nameEdited = true;
    });
    if (_isEdit) {
      _load();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    _scriptController.dispose();
    _urlController.dispose();
    _bodyController.dispose();
    _keepController.dispose();
    _timeoutController.dispose();
    _retriesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(cronRepoProvider);
      final cron = await repo.get(widget.id!);
      String script = '';
      Object? scriptError;
      if (cron.type == CronTypes.shell && cron.shell.isNotEmpty) {
        try {
          script = await repo.readFile(cron.shell);
        } catch (e) {
          scriptError = e;
        }
      }
      if (!mounted) return;
      setState(() {
        _nameController.text = cron.name;
        _timeController.text = cron.time;
        _type = cron.type;
        _flock = cron.config.flock;
        _storage = cron.config.storage;
        _targets = List.of(cron.config.targets);
        _subType = cron.config.subType.isEmpty
            ? _defaultSubType(cron.type)
            : cron.config.subType;
        _keepController.text =
            '${cron.config.keep <= 0 ? 1 : cron.config.keep}';
        _urlController.text = cron.config.url;
        _method = cron.config.method.isEmpty ? 'GET' : cron.config.method;
        _headers = cron.config.headers.entries
            .map((e) => KvEntry(key: e.key, value: e.value))
            .toList();
        _bodyController.text = cron.config.body;
        _timeoutController.text = '${cron.config.timeout}';
        _retriesController.text = '${cron.config.retries}';
        _insecure = cron.config.insecure;
        if (script.isNotEmpty) _scriptController.text = script;
        _nameEdited = true;
        _loading = false;
      });
      if (scriptError != null && mounted) {
        showErrorSnack(context, scriptError);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  static String _defaultSubType(String type) {
    if (type == CronTypes.cutoff) return 'website';
    return 'website';
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(activeServerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑计划任务' : '新建计划任务'),
      ),
      body: server == null
          ? const NoServerView()
          : _loading
              ? const LoadingView(message: '正在加载任务详情…')
              : _loadError != null
                  ? ErrorView(error: _loadError!, onRetry: _load)
                  : _buildForm(context),
      bottomNavigationBar: server == null || _loading || _loadError != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? '保存' : '创建'),
              ),
            ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          SectionCard(
            title: '基本信息',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isEdit) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '任务类型'),
                    items: [
                      for (final type in CronTypes.all)
                        DropdownMenuItem(
                          value: type,
                          child: Text(CronTypes.label(type)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _type = value;
                        _subType = _defaultSubType(value);
                        _targets = const [];
                      });
                      _autoName();
                    },
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  InputDecorator(
                    decoration: const InputDecoration(labelText: '任务类型'),
                    child: Text(CronTypes.label(_type)),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '任务名称'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请填写任务名称' : null,
                ),
                const SizedBox(height: 16),
                CronExpressionField(controller: _timeController),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _flock,
                  onChanged: (v) => setState(() => _flock = v),
                  title: const Text('进程锁'),
                  subtitle: Text(
                    '上一次执行尚未结束时跳过本次执行',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_type == CronTypes.shell) _buildShellSection(theme),
          if (_type == CronTypes.url) _buildUrlSection(),
          if (_type == CronTypes.backup || _type == CronTypes.cutoff)
            _buildBackupSection(theme),
          if (_type == CronTypes.synctime)
            SectionCard(
              title: '说明',
              child: Text(
                '同步时间任务会按设定周期与 NTP 服务器校准系统时间，无需额外配置。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShellSection(ThemeData theme) {
    return SectionCard(
      title: '脚本内容',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _scriptController,
            maxLines: 16,
            minLines: 8,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              hintText: '#!/bin/bash',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? '请填写脚本内容'
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            '保存后脚本会写入服务器上的任务脚本文件并覆盖原内容。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlSection() {
    return SectionCard(
      title: '请求配置',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _method,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '请求方法'),
            items: [
              for (final m in CronTypes.httpMethods)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _method = v);
              _autoName();
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
            ),
            onChanged: (_) => _autoName(),
            validator: (v) {
              if (_type != CronTypes.url) return null;
              final text = (v ?? '').trim();
              if (text.isEmpty) return '请填写 URL';
              final uri = Uri.tryParse(text);
              if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
                return 'URL 格式不正确，需包含 http(s)://';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          KvEditor(
            label: '自定义请求头',
            entries: _headers,
            onChanged: (v) => setState(() => _headers = v),
          ),
          if (_method == 'POST' || _method == 'PUT' || _method == 'PATCH') ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _bodyController,
              maxLines: 6,
              minLines: 3,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '请求体',
                alignLabelWithHint: true,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _timeoutController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '超时（秒）'),
                  validator: (v) => _validateNonNegativeInt(v, '超时时间'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _retriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '失败重试次数'),
                  validator: (v) => _validateNonNegativeInt(v, '重试次数'),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _insecure,
            onChanged: (v) => setState(() => _insecure = v),
            title: const Text('忽略证书校验'),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupSection(ThemeData theme) {
    final isBackup = _type == CronTypes.backup;
    final subTypes =
        isBackup ? CronTypes.backupSubTypes : CronTypes.cutoffSubTypes;
    return SectionCard(
      title: isBackup ? '备份配置' : '日志切割配置',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: subTypes.containsKey(_subType) ? _subType : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: isBackup ? '备份类型' : '切割类型',
            ),
            items: [
              for (final entry in subTypes.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _subType = value;
                // Redis / Valkey 为整实例备份，目标固定为实例类型本身。
                _targets = (value == 'redis' || value == 'valkey')
                    ? [value]
                    : const [];
              });
              _autoName();
            },
            validator: (v) =>
                (v == null || v.isEmpty) ? '请选择${isBackup ? '备份' : '切割'}类型' : null,
          ),
          const SizedBox(height: 16),
          _buildTargetField(theme),
          const SizedBox(height: 16),
          TextFormField(
            controller: _keepController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '保留份数',
              helperText: '超出份数的旧备份会被自动清理',
            ),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n < 1) return '保留份数需为大于 0 的整数';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildStorageField(),
        ],
      ),
    );
  }

  Widget _buildTargetField(ThemeData theme) {
    final isBackup = _type == CronTypes.backup;

    if (isBackup && (_subType == 'redis' || _subType == 'valkey')) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: '备份目标'),
        child: Text(
          '${_subType == 'redis' ? 'Redis' : 'Valkey'} 整实例备份，无需选择具体库',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    if (isBackup && _subType == 'path') {
      return StringListEditor(
        label: '备份目录',
        values: _targets,
        hintText: '/www/wwwroot/example',
        addLabel: '添加目录',
        onChanged: (v) {
          setState(() => _targets = v);
          _autoName();
        },
      );
    }

    if (_subType == 'container') {
      return MultiSelectField(
        label: '选择容器',
        selected: _targets,
        options: ref.watch(containerOptionsProvider),
        onReload: () => ref.invalidate(containerOptionsProvider),
        onChanged: (v) {
          setState(() => _targets = v);
          _autoName();
        },
      );
    }

    if (isBackup && CronTypes.backupSubTypes.containsKey(_subType) &&
        _subType != 'website') {
      // mysql / postgresql / clickhouse
      final provider = databaseOptionsProvider(_subType);
      return MultiSelectField(
        label: '选择数据库',
        selected: _targets,
        options: ref.watch(provider),
        onReload: () => ref.invalidate(provider),
        onChanged: (v) {
          setState(() => _targets = v);
          _autoName();
        },
      );
    }

    return MultiSelectField(
      label: '选择网站',
      selected: _targets,
      options: ref.watch(websiteOptionsProvider),
      onReload: () => ref.invalidate(websiteOptionsProvider),
      onChanged: (v) {
        setState(() => _targets = v);
        _autoName();
      },
    );
  }

  Widget _buildStorageField() {
    final storages = ref.watch(storageOptionsProvider);
    return storages.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(labelText: '备份存储'),
        child: Text('加载中…'),
      ),
      error: (error, _) => InputDecorator(
        decoration: InputDecoration(
          labelText: '备份存储',
          errorText: describeError(error),
          suffixIcon: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(storageOptionsProvider),
          ),
        ),
        child: const Text('加载失败，默认使用本地存储'),
      ),
      data: (list) {
        final ids = list.map((e) => e.id).toList();
        final value = ids.contains(_storage) ? _storage : (ids.isEmpty ? null : ids.first);
        return DropdownButtonFormField<int>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '备份存储'),
          items: [
            for (final option in list)
              DropdownMenuItem(
                value: option.id,
                child: Text(option.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _storage = v ?? 0),
        );
      },
    );
  }

  String? _validateNonNegativeInt(String? value, String label) {
    final n = int.tryParse((value ?? '').trim());
    if (n == null || n < 0) return '$label需为不小于 0 的整数';
    return null;
  }

  /// 新建模式下根据类型与目标自动生成任务名（用户手动改过则不再覆盖）。
  void _autoName() {
    if (_isEdit || _nameEdited) return;
    String name;
    switch (_type) {
      case CronTypes.backup:
        final prefix = '备份${CronTypes.backupSubTypes[_subType] ?? ''}';
        name = _targets.isEmpty ? prefix : '$prefix - ${_targets.join('、')}';
        break;
      case CronTypes.cutoff:
        final prefix = '日志切割 - ${CronTypes.cutoffSubTypes[_subType] ?? ''}';
        name = _targets.isEmpty ? prefix : '$prefix - ${_targets.join('、')}';
        break;
      case CronTypes.url:
        final url = _urlController.text.trim();
        name = url.isEmpty ? '访问 URL' : '$_method - $url';
        break;
      case CronTypes.synctime:
        name = '同步时间';
        break;
      default:
        return;
    }
    // 直接改 text 会触发监听把 _nameEdited 置 true，这里手动还原。
    _nameController.text = name;
    _nameEdited = false;
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final needTargets =
        _type == CronTypes.backup || _type == CronTypes.cutoff;
    final targets =
        _targets.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (needTargets && targets.isEmpty) {
      showSnack(context, '请至少选择一个目标');
      return;
    }

    final headers = <String, String>{};
    for (final entry in _headers) {
      final key = entry.key.trim();
      if (key.isNotEmpty) headers[key] = entry.value;
    }

    final keep = int.tryParse(_keepController.text.trim()) ?? 1;
    final timeout = int.tryParse(_timeoutController.text.trim()) ?? 10;
    final retries = int.tryParse(_retriesController.text.trim()) ?? 0;

    setState(() => _saving = true);
    try {
      final repo = ref.read(cronRepoProvider);
      if (_isEdit) {
        await repo.update(
          id: widget.id!,
          name: _nameController.text.trim(),
          type: _type,
          time: _timeController.text.trim(),
          script: _type == CronTypes.shell ? _scriptController.text : '',
          subType: needTargets ? _subType : '',
          flock: _flock,
          storage: _storage,
          targets: targets,
          keep: keep < 1 ? 1 : keep,
          url: _urlController.text.trim(),
          method: _method,
          headers: headers,
          body: _bodyController.text,
          timeout: timeout,
          insecure: _insecure,
          retries: retries,
        );
      } else {
        await repo.create(
          name: _nameController.text.trim(),
          type: _type,
          time: _timeController.text.trim(),
          script: _type == CronTypes.shell ? _scriptController.text : '',
          subType: needTargets ? _subType : '',
          flock: _flock,
          storage: _storage,
          targets: targets,
          keep: keep < 1 ? 1 : keep,
          url: _urlController.text.trim(),
          method: _method,
          headers: headers,
          body: _bodyController.text,
          timeout: timeout,
          insecure: _insecure,
          retries: retries,
        );
      }
      if (!mounted) return;
      showSnack(context, _isEdit ? '已保存' : '创建成功');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
