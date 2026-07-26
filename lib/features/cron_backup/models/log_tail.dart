import 'json_utils.dart';

/// 文件反向分页读取结果（对应面板 `FileService.Tail` 的响应）。
///
/// - [lines]：当前块的日志行（按文件正序）；
/// - [hasMore]：是否还有更早的内容；
/// - [size]：文件总字节数。
class LogTail {
  const LogTail({
    required this.lines,
    required this.hasMore,
    required this.size,
  });

  final List<String> lines;
  final bool hasMore;
  final int size;

  factory LogTail.fromJson(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return const LogTail(lines: [], hasMore: false, size: 0);
    }
    return LogTail(
      lines: jsonStringList(data['lines']),
      hasMore: jsonBool(data['has_more']),
      size: jsonInt(data['size']),
    );
  }
}
