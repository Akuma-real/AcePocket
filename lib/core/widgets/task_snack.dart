import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 「面板后台任务已提交」提示，附带跳转任务中心（`/tasks`）的动作。
///
/// 压缩 / 解压 / 远程下载 / 备份 / 恢复 / 应用安装等接口在面板侧都是**异步任务**：
/// 接口立即返回，实际执行进度需要到任务中心查看。
void showTaskSubmittedSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: '查看任务',
          onPressed: () {
            // SnackBar 存活时间可能长于页面，跳转前再确认一次。
            if (context.mounted) context.push('/tasks');
          },
        ),
      ),
    );
}
