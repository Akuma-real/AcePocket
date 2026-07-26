/// 终端连接状态。
enum TerminalStatus {
  /// 尚未开始连接。
  idle,

  /// 正在建立 WebSocket 会话（含面板登录）。
  connecting,

  /// 已连接，可正常收发。
  connected,

  /// 连接被关闭（命令退出 / 网络断开），可重连。
  disconnected,

  /// 连接失败（认证失败 / 网络错误等），可重试。
  failed,
}

/// 终端会话运行时状态。
class TerminalSessionState {
  const TerminalSessionState({
    this.status = TerminalStatus.idle,
    this.message,
    this.latencyMs,
    this.title,
    this.hasOutput = false,
    this.requiresCredentials = false,
    this.requiresPassCode = false,
    this.unstable = false,
    this.reconnectCount = 0,
  });

  final TerminalStatus status;

  /// 断开 / 失败时的提示信息（可直接展示）。
  final String? message;

  /// 最近一次心跳往返延迟（毫秒），未测得时为 null。
  final int? latencyMs;

  /// 服务端通过 OSC 下发的终端标题。
  final String? title;

  /// 是否已经收到过服务端输出（用于区分「首次连接」与「重连」的 UI）。
  final bool hasOutput;

  /// 需要用户补填面板账号密码。
  final bool requiresCredentials;

  /// 需要两步验证码（面板账号开启了 2FA）。
  final bool requiresPassCode;

  /// 心跳长时间无应答，连接可能已中断。
  final bool unstable;

  /// 已重连次数。
  final int reconnectCount;

  bool get isConnected => status == TerminalStatus.connected;

  bool get isConnecting => status == TerminalStatus.connecting;

  /// 是否处于「已断开 / 失败」需要用户介入的状态。
  bool get isBroken =>
      status == TerminalStatus.disconnected || status == TerminalStatus.failed;

  TerminalSessionState copyWith({
    TerminalStatus? status,
    String? message,
    bool clearMessage = false,
    int? latencyMs,
    bool clearLatency = false,
    String? title,
    bool? hasOutput,
    bool? requiresCredentials,
    bool? requiresPassCode,
    bool? unstable,
    int? reconnectCount,
  }) {
    return TerminalSessionState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      latencyMs: clearLatency ? null : (latencyMs ?? this.latencyMs),
      title: title ?? this.title,
      hasOutput: hasOutput ?? this.hasOutput,
      requiresCredentials: requiresCredentials ?? this.requiresCredentials,
      requiresPassCode: requiresPassCode ?? this.requiresPassCode,
      unstable: unstable ?? this.unstable,
      reconnectCount: reconnectCount ?? this.reconnectCount,
    );
  }
}
