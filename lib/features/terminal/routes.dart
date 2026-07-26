import 'package:go_router/go_router.dart';

import 'models/terminal_session_spec.dart';
import 'pages/terminal_page.dart';

/// 「终端」模块路由。
///
/// - `/terminal` —— 全屏终端（默认连接面板本机 PTY 并执行 `bash`）。
///
/// 支持的查询参数（其他模块可直接复用本页面打开终端）：
/// - `command`   —— PTY 要执行的命令，默认 `bash`，例如
///   `/terminal?command=journalctl%20-f&title=系统日志`；
/// - `ssh`       —— 面板中已保存的 SSH 主机 id，例如 `/terminal?ssh=3`；
/// - `container` —— 容器 id，例如 `/terminal?container=abc123`；
/// - `title`     —— 页面标题。
final List<RouteBase> terminalRoutes = [
  GoRoute(
    path: '/terminal',
    builder: (context, state) => TerminalPage(
      spec: TerminalSessionSpec.fromQuery(state.uri.queryParameters),
    ),
  ),
];
