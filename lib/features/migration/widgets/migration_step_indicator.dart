import 'package:flutter/material.dart';

import '../providers/migration_providers.dart';

/// 迁移向导的步骤指示条（连接 → 预检 → 选择 → 迁移 → 完成）。
class MigrationStepIndicator extends StatelessWidget {
  const MigrationStepIndicator({super.key, required this.stage});

  final MigrationStage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = stage.index0;
    final stages = MigrationStage.values;

    return SizedBox(
      height: 62,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stages.length,
        itemBuilder: (context, index) {
          final done = index < current;
          final active = index == current;
          final circleColor = done || active
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest;
          final labelColor = active
              ? colorScheme.primary
              : done
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant;

          return Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                    ),
                    child: done
                        ? Icon(Icons.check,
                            size: 16, color: colorScheme.onPrimary)
                        : Text(
                            '${index + 1}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: active
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stages[index].label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      fontWeight: active ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
              if (index != stages.length - 1)
                Container(
                  width: 28,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: done
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                ),
            ],
          );
        },
      ),
    );
  }
}
