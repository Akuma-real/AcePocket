import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_card.dart';
import '../models/php_models.dart';
import '../providers/environment_providers.dart';
import '../widgets/environment_ui.dart';

/// PHP 参数调优页（`/environments/php/:version/tune`）。
///
/// 对应 `GET/POST /environment/php/{version}/config_tune`：面板逐项读写
/// `php.ini` 与 `php-fpm.conf`，留空表示注释掉该配置项。
/// 另含 `POST /environment/php/{version}/clean_session`（清理 Session 文件）。
class PhpConfigTunePage extends ConsumerWidget {
  const PhpConfigTunePage({super.key, required this.version});

  final int version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tune = ref.watch(phpConfigTuneProvider(version));
    return Scaffold(
      appBar: AppBar(
        title: Text('参数调优 · PHP $version'),
        actions: [
          IconButton(
            tooltip: '重新载入',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(phpConfigTuneProvider(version)),
          ),
        ],
      ),
      body: tune.when(
        loading: () => const LoadingView(message: '读取 PHP 配置…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(phpConfigTuneProvider(version)),
        ),
        data: (data) => _TuneForm(
          key: ValueKey(data.toJson().toString()),
          version: version,
          initial: data,
        ),
      ),
    );
  }
}

/// Session 保存方式支持的取值。
const List<String> _sessionHandlers = ['files', 'redis', 'memcached'];

/// php-fpm 进程管理方式（服务端 `validate:"in:static,dynamic,ondemand"`）。
const List<String> _pmModes = ['dynamic', 'static', 'ondemand'];

/// 容量单位。
const List<String> _sizeUnits = ['K', 'M', 'G'];

class _TuneForm extends ConsumerStatefulWidget {
  const _TuneForm({
    super.key,
    required this.version,
    required this.initial,
  });

  final int version;
  final PhpConfigTune initial;

  @override
  ConsumerState<_TuneForm> createState() => _TuneFormState();
}

class _TuneFormState extends ConsumerState<_TuneForm> {
  // 常规
  late String _shortOpenTag = _normalizeOnOff(widget.initial.shortOpenTag);
  late String _displayErrors = _normalizeOnOff(widget.initial.displayErrors);
  late final TextEditingController _dateTimezone =
      TextEditingController(text: widget.initial.dateTimezone);
  late final TextEditingController _errorReporting =
      TextEditingController(text: widget.initial.errorReporting);

  // 禁用函数
  late final TextEditingController _disableFunctions =
      TextEditingController(text: widget.initial.disableFunctions);

  // 上传限制
  late final PhpSizeValue _uploadInit =
      PhpSizeValue.parse(widget.initial.uploadMaxFilesize);
  late final PhpSizeValue _postInit =
      PhpSizeValue.parse(widget.initial.postMaxSize);
  late final PhpSizeValue _memoryInit =
      PhpSizeValue.parse(widget.initial.memoryLimit);
  late final TextEditingController _uploadMaxFilesize =
      TextEditingController(text: _uploadInit.number);
  late String _uploadUnit = _uploadInit.unit;
  late final TextEditingController _postMaxSize =
      TextEditingController(text: _postInit.number);
  late String _postUnit = _postInit.unit;
  late final TextEditingController _memoryLimit =
      TextEditingController(text: _memoryInit.number);
  late String _memoryUnit = _memoryInit.unit;
  late final TextEditingController _maxFileUploads =
      TextEditingController(text: widget.initial.maxFileUploads);

  // 超时限制
  late final TextEditingController _maxExecutionTime =
      TextEditingController(text: widget.initial.maxExecutionTime);
  late final TextEditingController _maxInputTime =
      TextEditingController(text: widget.initial.maxInputTime);
  late final TextEditingController _maxInputVars =
      TextEditingController(text: widget.initial.maxInputVars);

  // Session
  late String _sessionHandler = _sessionHandlers.contains(
    widget.initial.sessionSaveHandler.trim(),
  )
      ? widget.initial.sessionSaveHandler.trim()
      : 'files';
  late final TextEditingController _sessionSavePath = TextEditingController(
    text: _sessionHandler == 'files' ? widget.initial.sessionSavePath : '',
  );
  late final _RedisSavePath _redisInit =
      _RedisSavePath.parse(widget.initial.sessionSavePath);
  late final _MemcachedSavePath _memcachedInit =
      _MemcachedSavePath.parse(widget.initial.sessionSavePath);
  late final TextEditingController _redisHost =
      TextEditingController(text: _redisInit.host);
  late final TextEditingController _redisPort =
      TextEditingController(text: _redisInit.port);
  late final TextEditingController _redisPassword =
      TextEditingController(text: _redisInit.password);
  late final TextEditingController _memcachedHost =
      TextEditingController(text: _memcachedInit.host);
  late final TextEditingController _memcachedPort =
      TextEditingController(text: _memcachedInit.port);
  late final TextEditingController _sessionGcMaxlifetime =
      TextEditingController(text: widget.initial.sessionGcMaxlifetime);
  late final TextEditingController _sessionCookieLifetime =
      TextEditingController(text: widget.initial.sessionCookieLifetime);

  // FPM 进程管理
  late String _pm = _pmModes.contains(widget.initial.pm.trim())
      ? widget.initial.pm.trim()
      : 'dynamic';
  late final TextEditingController _pmMaxChildren =
      TextEditingController(text: widget.initial.pmMaxChildren);
  late final TextEditingController _pmStartServers =
      TextEditingController(text: widget.initial.pmStartServers);
  late final TextEditingController _pmMinSpareServers =
      TextEditingController(text: widget.initial.pmMinSpareServers);
  late final TextEditingController _pmMaxSpareServers =
      TextEditingController(text: widget.initial.pmMaxSpareServers);

  bool _saving = false;
  bool _cleaning = false;

  @override
  void dispose() {
    for (final controller in [
      _dateTimezone,
      _errorReporting,
      _disableFunctions,
      _uploadMaxFilesize,
      _postMaxSize,
      _memoryLimit,
      _maxFileUploads,
      _maxExecutionTime,
      _maxInputTime,
      _maxInputVars,
      _sessionSavePath,
      _redisHost,
      _redisPort,
      _redisPassword,
      _memcachedHost,
      _memcachedPort,
      _sessionGcMaxlifetime,
      _sessionCookieLifetime,
      _pmMaxChildren,
      _pmStartServers,
      _pmMinSpareServers,
      _pmMaxSpareServers,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _normalizeOnOff(String raw) {
    final value = raw.trim();
    if (value.toLowerCase() == 'on' || value == '1') return 'On';
    if (value.toLowerCase() == 'off' || value == '0') return 'Off';
    return '';
  }

  String get _composedSavePath {
    switch (_sessionHandler) {
      case 'redis':
        return _RedisSavePath(
          host: _redisHost.text.trim().isEmpty
              ? '127.0.0.1'
              : _redisHost.text.trim(),
          port: _redisPort.text.trim().isEmpty ? '6379' : _redisPort.text.trim(),
          password: _redisPassword.text,
        ).compose();
      case 'memcached':
        return _MemcachedSavePath(
          host: _memcachedHost.text.trim().isEmpty
              ? '127.0.0.1'
              : _memcachedHost.text.trim(),
          port: _memcachedPort.text.trim().isEmpty
              ? '11211'
              : _memcachedPort.text.trim(),
        ).compose();
      default:
        return _sessionSavePath.text.trim();
    }
  }

  PhpConfigTune _collect() => widget.initial.copyWith(
        shortOpenTag: _shortOpenTag,
        dateTimezone: _dateTimezone.text.trim(),
        displayErrors: _displayErrors,
        errorReporting: _errorReporting.text.trim(),
        disableFunctions: _disableFunctions.text.trim(),
        uploadMaxFilesize:
            PhpSizeValue(_uploadMaxFilesize.text.trim(), _uploadUnit).raw,
        postMaxSize: PhpSizeValue(_postMaxSize.text.trim(), _postUnit).raw,
        maxFileUploads: _maxFileUploads.text.trim(),
        memoryLimit: PhpSizeValue(_memoryLimit.text.trim(), _memoryUnit).raw,
        maxExecutionTime: _maxExecutionTime.text.trim(),
        maxInputTime: _maxInputTime.text.trim(),
        maxInputVars: _maxInputVars.text.trim(),
        sessionSaveHandler: _sessionHandler,
        sessionSavePath: _composedSavePath,
        sessionGcMaxlifetime: _sessionGcMaxlifetime.text.trim(),
        sessionCookieLifetime: _sessionCookieLifetime.text.trim(),
        pm: _pm,
        pmMaxChildren: _pmMaxChildren.text.trim(),
        pmStartServers: _pmStartServers.text.trim(),
        pmMinSpareServers: _pmMinSpareServers.text.trim(),
        pmMaxSpareServers: _pmMaxSpareServers.text.trim(),
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(environmentRepoProvider)
          .updatePhpConfigTune(widget.version, _collect());
      ref.invalidate(phpConfigTuneProvider(widget.version));
      ref.invalidate(phpIniProvider(widget.version));
      ref.invalidate(phpFpmConfigProvider(widget.version));
      if (!mounted) return;
      showEnvSnack(context, '配置已保存，需重启 PHP-FPM 后生效');
    } catch (e) {
      if (!mounted) return;
      showEnvSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cleanSession() async {
    final ok = await showConfirmDialog(
      context,
      title: '清理 Session 文件？',
      content: '将删除 session.save_path 下所有 sess_* 文件，'
          '所有已登录用户的会话都会失效（仅 save_handler 为 files 时可用）。',
      confirmText: '清理',
      danger: true,
    );
    if (!ok) return;
    setState(() => _cleaning = true);
    try {
      await ref.read(environmentRepoProvider).cleanPhpSession(widget.version);
      if (!mounted) return;
      showEnvSnack(context, 'Session 文件已清理');
    } catch (e) {
      if (!mounted) return;
      showEnvSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              const HintBanner(
                '留空的配置项会被面板注释掉（恢复 PHP 默认值）；'
                '保存后需重启对应的 php-fpm 服务才会生效。',
              ),
              _generalCard(),
              _disableFunctionsCard(),
              _uploadCard(),
              _timeoutCard(),
              _sessionCard(),
              _performanceCard(),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('保存全部配置'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ 分区

  Widget _generalCard() => SectionCard(
        title: '常规设置（php.ini）',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormFieldRow(
              label: '短标签 short_open_tag',
              child: _onOffDropdown(
                value: _shortOpenTag,
                onChanged: (v) => setState(() => _shortOpenTag = v),
              ),
            ),
            FormFieldRow(
              label: '时区 date.timezone',
              helper: '如 Asia/Shanghai',
              child: _textField(_dateTimezone, hint: 'Asia/Shanghai'),
            ),
            FormFieldRow(
              label: '显示错误 display_errors',
              helper: '生产环境建议 Off',
              child: _onOffDropdown(
                value: _displayErrors,
                onChanged: (v) => setState(() => _displayErrors = v),
              ),
            ),
            FormFieldRow(
              label: '错误级别 error_reporting',
              helper: '如 E_ALL & ~E_DEPRECATED & ~E_STRICT',
              child: _textField(_errorReporting, hint: 'E_ALL'),
            ),
          ],
        ),
      );

  Widget _disableFunctionsCard() => SectionCard(
        title: '禁用函数（php.ini）',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '以英文逗号分隔。常见危险函数：exec、shell_exec、system、'
              'passthru、proc_open、popen 等。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _disableFunctions,
              maxLines: 6,
              minLines: 3,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'exec,shell_exec,system,passthru',
              ),
            ),
          ],
        ),
      );

  Widget _uploadCard() => SectionCard(
        title: '上传与内存限制（php.ini）',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormFieldRow(
              label: '最大上传文件 upload_max_filesize',
              child: _sizeField(
                controller: _uploadMaxFilesize,
                unit: _uploadUnit,
                onUnitChanged: (v) => setState(() => _uploadUnit = v),
                hint: '50',
              ),
            ),
            FormFieldRow(
              label: '最大 POST 大小 post_max_size',
              helper: '应不小于 upload_max_filesize',
              child: _sizeField(
                controller: _postMaxSize,
                unit: _postUnit,
                onUnitChanged: (v) => setState(() => _postUnit = v),
                hint: '50',
              ),
            ),
            FormFieldRow(
              label: '最大上传文件数 max_file_uploads',
              child: _numberField(_maxFileUploads, hint: '20'),
            ),
            FormFieldRow(
              label: '内存限制 memory_limit',
              child: _sizeField(
                controller: _memoryLimit,
                unit: _memoryUnit,
                onUnitChanged: (v) => setState(() => _memoryUnit = v),
                hint: '256',
              ),
            ),
          ],
        ),
      );

  Widget _timeoutCard() => SectionCard(
        title: '超时限制（php.ini）',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormFieldRow(
              label: '脚本最大执行时间 max_execution_time',
              helper: '单位秒，-1 表示不限制',
              child: _numberField(_maxExecutionTime, hint: '30', allowNegative: true),
            ),
            FormFieldRow(
              label: '输入解析最大时间 max_input_time',
              helper: '单位秒，-1 表示不限制',
              child: _numberField(_maxInputTime, hint: '60', allowNegative: true),
            ),
            FormFieldRow(
              label: '最大输入变量数 max_input_vars',
              child: _numberField(_maxInputVars, hint: '1000'),
            ),
          ],
        ),
      );

  Widget _sessionCard() => SectionCard(
        title: 'Session（php.ini）',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormFieldRow(
              label: '保存方式 session.save_handler',
              helper: '使用 redis / memcached 需先安装对应扩展并确保服务可用',
              child: DropdownButtonFormField<String>(
                initialValue: _sessionHandler,
                isDense: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final handler in _sessionHandlers)
                    DropdownMenuItem(value: handler, child: Text(handler)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _sessionHandler = value);
                },
              ),
            ),
            if (_sessionHandler == 'files')
              FormFieldRow(
                label: '保存路径 session.save_path',
                child: _textField(_sessionSavePath, hint: '/tmp'),
              ),
            if (_sessionHandler == 'redis') ...[
              FormFieldRow(
                label: 'Redis 主机',
                child: _textField(_redisHost, hint: '127.0.0.1'),
              ),
              FormFieldRow(
                label: 'Redis 端口',
                child: _numberField(_redisPort, hint: '6379'),
              ),
              FormFieldRow(
                label: 'Redis 密码',
                helper: '无密码留空',
                child: _textField(_redisPassword, obscure: true),
              ),
            ],
            if (_sessionHandler == 'memcached') ...[
              FormFieldRow(
                label: 'Memcached 主机',
                child: _textField(_memcachedHost, hint: '127.0.0.1'),
              ),
              FormFieldRow(
                label: 'Memcached 端口',
                child: _numberField(_memcachedPort, hint: '11211'),
              ),
            ],
            FormFieldRow(
              label: '回收时间 session.gc_maxlifetime',
              helper: '单位秒',
              child: _numberField(_sessionGcMaxlifetime, hint: '1440'),
            ),
            FormFieldRow(
              label: 'Cookie 有效期 session.cookie_lifetime',
              helper: '单位秒，0 表示浏览器关闭即失效',
              child: _numberField(_sessionCookieLifetime, hint: '0'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _cleaning ? null : _cleanSession,
                icon: _cleaning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cleaning_services_outlined, size: 18),
                label: const Text('清理 Session 文件'),
              ),
            ),
          ],
        ),
      );

  Widget _performanceCard() => SectionCard(
        title: '进程管理（php-fpm.conf）',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormFieldRow(
              label: '进程管理方式 pm',
              helper: 'dynamic 动态、static 固定、ondemand 按需',
              child: DropdownButtonFormField<String>(
                initialValue: _pm,
                isDense: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final mode in _pmModes)
                    DropdownMenuItem(value: mode, child: Text(mode)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _pm = value);
                },
              ),
            ),
            FormFieldRow(
              label: '最大子进程数 pm.max_children',
              child: _numberField(_pmMaxChildren, hint: '30'),
            ),
            if (_pm == 'dynamic') ...[
              FormFieldRow(
                label: '启动进程数 pm.start_servers',
                child: _numberField(_pmStartServers, hint: '5'),
              ),
              FormFieldRow(
                label: '最少空闲进程 pm.min_spare_servers',
                child: _numberField(_pmMinSpareServers, hint: '3'),
              ),
              FormFieldRow(
                label: '最多空闲进程 pm.max_spare_servers',
                child: _numberField(_pmMaxSpareServers, hint: '10'),
              ),
            ],
          ],
        ),
      );

  // ------------------------------------------------------------------ 控件

  Widget _onOffDropdown({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: '', child: Text('不设置')),
        DropdownMenuItem(value: 'On', child: Text('On')),
        DropdownMenuItem(value: 'Off', child: Text('Off')),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }

  Widget _textField(
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller, {
    String? hint,
    bool allowNegative = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(signed: allowNegative),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          allowNegative ? RegExp(r'^-?\d*') : RegExp(r'\d*'),
        ),
      ],
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _sizeField({
    required TextEditingController controller,
    required String unit,
    required ValueChanged<String> onUnitChanged,
    String? hint,
  }) {
    return Row(
      children: [
        Expanded(child: _numberField(controller, hint: hint)),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: DropdownButtonFormField<String>(
            initialValue: unit,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final item in _sizeUnits)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (value) {
              if (value == null) return;
              onUnitChanged(value);
            },
          ),
        ),
      ],
    );
  }
}

/// Redis 形式的 `session.save_path`：`tcp://host:port?auth=password`。
class _RedisSavePath {
  const _RedisSavePath({
    required this.host,
    required this.port,
    required this.password,
  });

  factory _RedisSavePath.parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return const _RedisSavePath(
        host: '127.0.0.1',
        port: '6379',
        password: '',
      );
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return const _RedisSavePath(
        host: '127.0.0.1',
        port: '6379',
        password: '',
      );
    }
    return _RedisSavePath(
      host: uri.host,
      port: uri.hasPort ? '${uri.port}' : '6379',
      password: uri.queryParameters['auth'] ?? '',
    );
  }

  final String host;
  final String port;
  final String password;

  String compose() => password.isEmpty
      ? 'tcp://$host:$port'
      : 'tcp://$host:$port?auth=$password';
}

/// Memcached 形式的 `session.save_path`：`host:port`。
class _MemcachedSavePath {
  const _MemcachedSavePath({required this.host, required this.port});

  factory _MemcachedSavePath.parse(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 2 || parts.first.isEmpty) {
      return const _MemcachedSavePath(host: '127.0.0.1', port: '11211');
    }
    return _MemcachedSavePath(host: parts[0], port: parts[1]);
  }

  final String host;
  final String port;

  String compose() => '$host:$port';
}
