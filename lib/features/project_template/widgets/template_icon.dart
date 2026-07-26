import 'package:flutter/material.dart';

/// 模板图标：优先加载远端图标，失败或未提供时回退为首字母方块。
///
/// 面板返回的 `icon` 是应用商店 CDN 上的图片地址，手机端可能无外网，
/// 因此加载失败必须静默降级，不影响列表展示。
class TemplateIcon extends StatelessWidget {
  const TemplateIcon({
    super.key,
    required this.name,
    required this.iconUrl,
    this.size = 40,
  });

  final String name;
  final String iconUrl;
  final double size;

  bool get _isNetworkIcon =>
      iconUrl.startsWith('http://') || iconUrl.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (!_isNetworkIcon) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        iconUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}
