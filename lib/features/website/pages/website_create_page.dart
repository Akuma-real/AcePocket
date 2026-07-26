import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/section_card.dart';
import '../models/lv_option.dart';
import '../providers/website_providers.dart';
import '../widgets/snack.dart';
import '../widgets/string_list_field.dart';

/// 创建网站页 `/websites/create`。
///
/// 表单字段与 `internal/request.WebsiteCreate` 一一对应：
/// type / name / listens / domains / path / db / db_type / db_name /
/// db_user / db_password / remark / php / proxy。
class WebsiteCreatePage extends ConsumerStatefulWidget {
  const WebsiteCreatePage({super.key});

  @override
  ConsumerState<WebsiteCreatePage> createState() => _WebsiteCreatePageState();
}

class _WebsiteCreatePageState extends ConsumerState<WebsiteCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  final _proxyController = TextEditingController();
  final _remarkController = TextEditingController();
  final _dbNameController = TextEditingController();
  final _dbUserController = TextEditingController();
  final _dbPasswordController = TextEditingController();

  String _type = 'proxy';
  List<String> _domains = <String>[];
  List<String> _listens = <String>['80'];
  int? _php;
  String _dbType = '0';
  bool _submitting = false;

  static final _nameRegExp = RegExp(r'^[a-zA-Z0-9_-]+$');
  static final _dbIdentifierRegExp = RegExp(r'^[a-zA-Z_-][a-zA-Z0-9_-]*$');

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    _proxyController.dispose();
    _remarkController.dispose();
    _dbNameController.dispose();
    _dbUserController.dispose();
    _dbPasswordController.dispose();
    super.dispose();
  }

  bool get _useDb => _dbType != '0' && _dbType.isNotEmpty;

  /// 与面板前端一致：把网站名转换为合法的库名/用户名。
  String _formatDbValue(String value) {
    var v = value.replaceAll('.', '_').replaceAll('-', '_');
    if (v.length > 16) v = v.substring(0, 16);
    return v;
  }

  String _randomPassword([int length = 16]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)])
        .join();
  }

  void _onDbTypeChanged(String value) {
    setState(() {
      _dbType = value;
      if (_useDb) {
        final base = _formatDbValue(_nameController.text.trim());
        if (_dbNameController.text.isEmpty) _dbNameController.text = base;
        if (_dbUserController.text.isEmpty) _dbUserController.text = base;
        if (_dbPasswordController.text.isEmpty) {
          _dbPasswordController.text = _randomPassword();
        }
      }
    });
  }

  Future<void> _submit() async {
    // 域名 / 监听由动态列表维护，需要单独校验。
    final domains =
        _domains.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final listens =
        _listens.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (domains.isEmpty) {
      showSnack(context, '请至少填写一个域名', error: true);
      return;
    }
    if (_type == 'php' && (_php == null || _php == 0)) {
      showSnack(context, '请选择 PHP 版本', error: true);
      return;
    }

    // 与面板前端一致：监听为空时补 80，且不允许在未配置证书时监听 443。
    if (listens.isEmpty) listens.add('80');
    listens.removeWhere((e) => e == '443');
    if (listens.isEmpty) {
      showSnack(context, '监听端口不能只有 443，请先创建网站再配置 HTTPS', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(websiteRepoProvider).create(
            type: _type,
            name: _nameController.text.trim(),
            listens: listens,
            domains: domains,
            path: _type == 'proxy' ? '' : _pathController.text.trim(),
            db: _useDb,
            dbType: _dbType,
            dbName: _useDb ? _dbNameController.text.trim() : '',
            dbUser: _useDb ? _dbUserController.text.trim() : '',
            dbPassword: _useDb ? _dbPasswordController.text : '',
            remark: _remarkController.text.trim(),
            php: _type == 'php' ? (_php ?? 0) : 0,
            proxy: _type == 'proxy' ? _proxyController.text.trim() : '',
          );
      if (!mounted) return;
      showSnack(context, '网站创建成功');
      ref.invalidate(websiteListProvider);
      context.pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final envAsync = ref.watch(installedEnvironmentProvider);
    final env = envAsync.valueOrNull ?? InstalledEnvironment.empty;

    return Scaffold(
      appBar: AppBar(title: const Text('新建网站')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          children: [
            SectionCard(
              title: '网站类型',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'proxy', label: Text('反向代理')),
                  ButtonSegment(value: 'php', label: Text('PHP')),
                  ButtonSegment(value: 'static', label: Text('纯静态')),
                ],
                selected: {_type},
                onSelectionChanged: (values) =>
                    setState(() => _type = values.first),
              ),
            ),
            SectionCard(
              title: '基本信息',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '网站名称',
                      helperText: '唯一，用于目录与数据库命名，仅支持字母、数字、- 和 _',
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return '请填写网站名称';
                      if (!_nameRegExp.hasMatch(v)) {
                        return '只能包含字母、数字、- 和 _';
                      }
                      if (v == 'phpmyadmin' || v == 'default') {
                        return '该名称为面板保留名称';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  StringListField(
                    label: '域名',
                    initialValues: const [''],
                    minItems: 1,
                    hintText: 'example.com',
                    addButtonText: '添加域名',
                    helperText: '可填写多个域名，支持泛域名（如 *.example.com）',
                    onChanged: (values) => _domains = values,
                  ),
                  const SizedBox(height: 12),
                  StringListField(
                    label: '监听端口',
                    initialValues: const ['80'],
                    minItems: 1,
                    hintText: '80',
                    addButtonText: '添加端口',
                    keyboardType: TextInputType.text,
                    helperText: '如 80、0.0.0.0:80；443 需在创建后于 HTTPS 中配置',
                    onChanged: (values) => _listens = values,
                  ),
                ],
              ),
            ),
            if (_type == 'proxy')
              SectionCard(
                title: '代理设置',
                child: TextFormField(
                  controller: _proxyController,
                  decoration: const InputDecoration(
                    labelText: '代理目标地址',
                    hintText: 'http://127.0.0.1:3000',
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (_type != 'proxy') return null;
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return '请填写代理目标地址';
                    if (!v.startsWith('http://') && !v.startsWith('https://')) {
                      return '需以 http:// 或 https:// 开头';
                    }
                    return null;
                  },
                ),
              )
            else
              SectionCard(
                title: '网站目录',
                child: TextFormField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    labelText: '目录（绝对路径）',
                    helperText: '留空时使用「网站目录/网站名/public」',
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return null;
                    if (!v.startsWith('/')) return '请填写绝对路径';
                    return null;
                  },
                ),
              ),
            if (_type == 'php')
              SectionCard(
                title: 'PHP 版本',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (envAsync.isLoading)
                      const LinearProgressIndicator()
                    else if (env.php.isEmpty)
                      Text(
                        envAsync.hasError
                            ? '获取已安装 PHP 版本失败：${errorMessage(envAsync.error!)}'
                            : '面板尚未安装任何 PHP 版本，请先在应用商店安装',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: _php,
                        decoration:
                            const InputDecoration(labelText: '选择 PHP 版本'),
                        items: [
                          for (final option in env.php)
                            DropdownMenuItem(
                              value: option.value,
                              child: Text(option.label),
                            ),
                        ],
                        onChanged: (v) => setState(() => _php = v),
                      ),
                  ],
                ),
              ),
            if (_type == 'php')
              SectionCard(
                title: '数据库',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: env.db.any((e) => e.value == _dbType)
                          ? _dbType
                          : '0',
                      decoration: const InputDecoration(labelText: '创建数据库'),
                      items: [
                        if (!env.db.any((e) => e.value == '0'))
                          const DropdownMenuItem(
                            value: '0',
                            child: Text('不使用'),
                          ),
                        for (final option in env.db)
                          DropdownMenuItem(
                            value: option.value,
                            child: Text(
                              option.value == '0' ? '不使用' : option.label,
                            ),
                          ),
                      ],
                      onChanged: (v) => _onDbTypeChanged(v ?? '0'),
                    ),
                    if (_useDb) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dbNameController,
                        decoration: const InputDecoration(labelText: '数据库名'),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (!_useDb) return null;
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return '请填写数据库名';
                          if (!_dbIdentifierRegExp.hasMatch(v)) {
                            return '仅支持字母、数字、- 和 _，且不能以数字开头';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dbUserController,
                        decoration: const InputDecoration(labelText: '数据库用户'),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (!_useDb) return null;
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return '请填写数据库用户';
                          if (!_dbIdentifierRegExp.hasMatch(v)) {
                            return '仅支持字母、数字、- 和 _，且不能以数字开头';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dbPasswordController,
                        decoration: InputDecoration(
                          labelText: '数据库密码',
                          suffixIcon: IconButton(
                            tooltip: '随机生成',
                            icon: const Icon(Icons.casino_outlined),
                            onPressed: () => setState(() =>
                                _dbPasswordController.text = _randomPassword()),
                          ),
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (!_useDb) return null;
                          if ((value ?? '').isEmpty) return '请填写数据库密码';
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            SectionCard(
              title: '备注',
              child: TextFormField(
                controller: _remarkController,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(
                  hintText: '选填，便于识别该网站',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_submitting ? '正在创建…' : '创建网站'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
