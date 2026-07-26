import 'dart:convert';

/// `/api/ws/pty` 消息协议（与面板源码 `pkg/shell/pty.go` 逐字段对齐）：
///
/// - 建连后客户端发送的**第一条消息**为要执行的命令（官方前端本机终端发 `bash`，
///   见 `web/src/views/ssh/IndexView.vue` 与 `internal/service/ws.go` 的 `PTY`）；
/// - 之后客户端发送的普通文本 / 二进制帧原样写入 PTY stdin；
/// - JSON `{"resize":true,"columns":N,"rows":N}` 调整 PTY 窗口大小
///   （`shell.MessageResize`）；
/// - JSON `{"ping":true}` 为应用层心跳（`shell.MessagePing`），
///   服务端回复文本帧 `{"pong":true}`；
/// - 服务端的 PTY 输出以**二进制帧**下发（UTF-8 字节流，可能在多字节字符
///   中间被切分，需要流式解码）。
class TerminalWsProtocol {
  const TerminalWsProtocol._();

  /// 默认执行的命令（与官方前端「本机」终端一致）。
  static const String defaultCommand = 'bash';

  /// 心跳消息。
  static String ping() => jsonEncode({'ping': true});

  /// 终端大小调整消息。
  static String resize(int columns, int rows) =>
      jsonEncode({'resize': true, 'columns': columns, 'rows': rows});

  /// 判断服务端文本帧是否为心跳应答 `{"pong":true}`。
  static bool isPong(String data) {
    final trimmed = data.trimLeft();
    if (!trimmed.startsWith('{')) return false;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, dynamic> && decoded['pong'] == true;
    } catch (_) {
      return false;
    }
  }
}

/// UTF-8 流式解码器。
///
/// PTY 输出按 8192 字节分块下发（`pkg/shell/pty.go` 的 `Pipe`），
/// 多字节字符可能被切分在两个 WebSocket 帧之间；本解码器把不完整的
/// 尾部字节缓存到下一帧再解码，避免中文等字符显示为乱码。
class Utf8StreamDecoder {
  final List<int> _pending = <int>[];

  /// 解码一块字节，返回当前可安全解码的文本（可能为空字符串）。
  String decode(List<int> chunk) {
    _pending.addAll(chunk);
    var cut = _pending.length;
    // 从尾部最多回看 3 个字节，寻找可能不完整的多字节序列起始字节。
    final lowerBound = _pending.length - 3 < 0 ? 0 : _pending.length - 3;
    for (var i = _pending.length - 1; i >= lowerBound; i--) {
      final b = _pending[i];
      if (b & 0x80 == 0) break; // ASCII，序列完整
      if (b & 0xC0 == 0xC0) {
        // 前导字节：判断该序列需要的总字节数是否已经到齐。
        final int need;
        if (b & 0xE0 == 0xC0) {
          need = 2;
        } else if (b & 0xF0 == 0xE0) {
          need = 3;
        } else if (b & 0xF8 == 0xF0) {
          need = 4;
        } else {
          need = 1; // 非法前导字节，交给 allowMalformed 处理
        }
        if (_pending.length - i < need) cut = i;
        break;
      }
      // 延续字节（10xxxxxx），继续向前找前导字节。
    }
    final out = utf8.decode(_pending.sublist(0, cut), allowMalformed: true);
    final rest = _pending.sublist(cut);
    _pending
      ..clear()
      ..addAll(rest);
    return out;
  }

  /// 清空缓存（重新建连时调用）。
  void reset() => _pending.clear();
}
