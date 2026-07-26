import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_card.dart';
import '../models/kv_pair.dart';
import '../models/template.dart';
import '../providers/template_providers.dart';
import '../widgets/kv_list_field.dart';
import '../widgets/snack.dart';

/// 编排名称合法字符，与 `request.TemplateCreate` 的
/// `regex:"^[a-zA-Z0-9_-]+$"` 一致。
final RegExp _kComposeNamePattern = RegExp(r'^[a-zA-Z0-9_-]+$');

/// 模板部署页 `/templates/:slug/deploy`。
///
/// 对应面板 `POST /api/template`：用模板生成一个 docker compose 编排目录，
/// 可选自动放行 compose 中声明的端口；创建完成后可立即启动编排
/// （`POST /api/container/compose/{name}/up`）。
class TemplateDeployPage extends ConsumerWidget {
  const TemplateDeployPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(templateDetailProvider(slug));
    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('部署模板')),
        body: const LoadingView(message: '正在加载模板…'),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('部署模板')),
        body: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(templateDetailProvider(slug)),
        ),
      ),
      data: (template) => _DeployForm(template: template),
    );
  }
}

class _DeployForm extends ConsumerStatefulWidget {
  const _DeployForm({required this.template});

  final AppTemplate template;

  @override
  ConsumerState<_DeployForm> createState() => _DeployFormState();
}

class _DeployFormState extends ConsumerState<_DeployForm> {
  late final TextEditingController _nameController =
      TextEditingController(text: _sanitizeName(widget.template.slug));
  late final TextEditingController _composeController =
      TextEditingController(text: widget.template.compose);

  /// 模板定义的环境变量当前值（key 为变量名）。
  final Map<String, String> _envValues = {};

  /// 文本类环境变量的输入控制器。
  final Map<String, TextEditingController> _envControllers = {};

  /// 用户额外添加的变量（同名时覆盖模板变量）。
  List<KvPair> _extraEnvs = const <KvPair>[];

  bool _autoFirewall = false;
  bool _autoStart = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final env in widget.template.environments) {
      var initial = env.defaultValue ?? '';
      if (env.type == 'select') {
        // 默认值必须落在候选项内，否则取第一个候选项。
        final options = _selectOptions(env);
        if (!options.any((e) => e.$1 == initial)) {
          initial = options.isEmpty ? '' : options.first.$1;
        }
      } else {
        _envControllers[env.name] = TextEditingController(text: initial);
      }
      _envValues[env.name] = initial;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _composeController.dispose();
    for (final controller in _envControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 编排名称只允许字母、数字、下划线与短横线，模板 slug 里的点号等一律转下划线。
  static String _sanitizeName(String slug) {
    final cleaned = slug.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return cleaned.isEmpty ? 'app' : cleaned;
  }

  /// select 类型的候选项（面板返回 `label -> value`）。
  List<(String, String)> _selectOptions(TemplateEnvironment env) {
    final options = <(String, String)>[];
    env.options.forEach((label, value) => options.add((value, label)));
    return options;
  }

  /// 合并模板变量与用户自定义变量，后者同名覆盖。
  List<KvPair> _finalEnvs() {
    final merged = <String, String>{};
    for (final env in widget.template.environments) {
      merged[env.name] = _envValues[env.name] ?? '';
    }
    for (final extra in _extraEnvs) {
      merged[extra.key] = extra.value;
    }
    return [
      for (final entry in merged.entries)
        KvPair(key: entry.key, value: entry.value),
    ];
  }

  String? _validate() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return '请填写编排名称';
    if (!_kComposeNamePattern.hasMatch(name)) {
      return '编排名称只能包含字母、数字、下划线与短横线';
    }
    if (_composeController.text.trim().isEmpty) {
      return '编排内容不能为空';
    }
    for (final env in widget.template.environments) {
      final value = (_envValues[env.name] ?? '').trim();
      if (env.required && value.isEmpty) {
        return '请填写「${env.label}」';
      }
      if (value.isEmpty) continue;
      if (env.type == 'port') {
        final port = int.tryParse(value);
        if (port == null || port < 1 || port > 65535) {
          return '「${env.label}」应为 1-65535 之间的端口号';
        }
      } else if (env.type == 'number') {
        if (double.tryParse(value) == null) {
          return '「${env.label}」应为数字';
        }
      } else if (env.type == 'url') {
        final uri = Uri.tryParse(value);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          return '「${env.label}」应为合法的链接';
        }
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }

    final name = _nameController.text.trim();
    final ok = await showConfirmDialog(
      context,
      title: '部署模板',
      content: '将使用模板「${widget.template.name}」创建编排「$name」。'
          '${_autoFirewall ? '\n面板会自动放行编排中声明的端口。' : ''}'
          '${_autoStart ? '\n创建完成后立即启动编排（docker compose up -d）。' : ''}',
      confirmText: '开始部署',
    );
    if (!ok) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(templateRepoProvider);
      final dir = await repo.createCompose(
        slug: widget.template.slug,
        name: name,
        compose: _composeController.text,
        envs: _finalEnvs(),
        autoFirewall: _autoFirewall,
      );
      var startError = '';
      if (_autoStart) {
        try {
          await repo.composeUp(name);
        } catch (e) {
          startError = errorMessage(e);
        }
      }
      if (!mounted) return;
      await _showResultDialog(name: name, dir: dir, startError: startError);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showResultDialog({
    required String name,
    required String dir,
    required String startError,
  }) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(startError.isEmpty ? '部署完成' : '编排已创建，但启动失败'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('编排名称：$name'),
            if (dir.isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText('编排目录：$dir'),
            ],
            if (startError.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                startError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('stay'),
            child: const Text('留在本页'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('compose'),
            child: const Text('查看编排'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'compose') {
      context.pushReplacement('/containers/compose/${Uri.encodeComponent(name)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final template = widget.template;

    return Scaffold(
      appBar: AppBar(
        title: Text('部署 · ${template.name.isEmpty ? template.slug : template.name}'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.rocket_launch_outlined),
            label: Text(_submitting ? '正在部署…' : '开始部署'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          SectionCard(
            title: '编排设置',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: '编排名称',
                    helperText: '仅字母、数字、下划线与短横线；同名编排已存在时会创建失败',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('自动放行端口'),
                  subtitle: const Text('由面板放行编排中声明的端口'),
                  value: _autoFirewall,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _autoFirewall = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('创建后立即启动'),
                  subtitle: const Text('等价于 docker compose up -d'),
                  value: _autoStart,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _autoStart = value),
                ),
              ],
            ),
          ),
          if (template.environments.isNotEmpty)
            SectionCard(
              title: '环境变量',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final env in template.environments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildEnvField(env),
                    ),
                ],
              ),
            ),
          SectionCard(
            child: KvListField(
              label: '自定义变量',
              helper: '追加写入编排的 .env；与模板变量同名时覆盖模板值',
              initialValues: _extraEnvs,
              onChanged: (value) => _extraEnvs = value,
            ),
          ),
          SectionCard(
            title: 'docker-compose.yml',
            trailing: TextButton.icon(
              onPressed: _submitting
                  ? null
                  : () => setState(
                        () => _composeController.text = template.compose,
                      ),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('恢复默认'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '可直接编辑，留空则无法提交。变量以 ${r'${VAR}'} 形式引用上方环境变量。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _composeController,
                  autocorrect: false,
                  enableSuggestions: false,
                  minLines: 10,
                  maxLines: 30,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvField(TemplateEnvironment env) {
    final label = env.required ? '${env.label} *' : env.label;
    final helper = env.name;

    if (env.type == 'select') {
      final options = _selectOptions(env);
      final current = _envValues[env.name] ?? '';
      return DropdownButtonFormField<String>(
        initialValue: options.any((e) => e.$1 == current) ? current : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option.$1, child: Text(option.$2)),
        ],
        onChanged: _submitting
            ? null
            : (newValue) {
                if (newValue == null) return;
                setState(() => _envValues[env.name] = newValue);
              },
      );
    }

    final controller = _envControllers[env.name]!;
    final isNumber = env.type == 'number' || env.type == 'port';
    return TextField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      obscureText: env.type == 'password',
      keyboardType: isNumber
          ? TextInputType.number
          : (env.type == 'url' ? TextInputType.url : TextInputType.text),
      inputFormatters: switch (env.type) {
        'port' => [FilteringTextInputFormatter.digitsOnly],
        'number' => [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        _ => null,
      },
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        hintText: env.defaultValue,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (value) => _envValues[env.name] = value,
    );
  }
}
