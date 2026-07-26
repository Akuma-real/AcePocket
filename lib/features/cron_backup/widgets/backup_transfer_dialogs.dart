import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../files/repo/transfer_client.dart';
import '../../files/widgets/transfer_indicator.dart';
import '../repo/backup_transfer.dart';

/// 上传结果。
class BackupUploadOutcome {
  const BackupUploadOutcome({this.error, this.cancelled = false});

  /// 失败原因（可直接展示）；为 null 且未取消表示成功。
  final String? error;

  /// 是否被用户取消。
  final bool cancelled;

  bool get succeeded => error == null && !cancelled;
}

/// 展示上传进度对话框并实际执行备份上传，结束后返回结果。
///
/// 上传全程流式（见 [BackupUploader]），可随时取消；取消后服务端不会留下半个文件
/// （面板侧 multipart 解析失败即中止）。
Future<BackupUploadOutcome?> showBackupUploadDialog(
  BuildContext context, {
  required BackupUploader uploader,
  required String type,
  required File source,
  required String fileName,
}) {
  return showDialog<BackupUploadOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _BackupUploadDialog(
      uploader: uploader,
      type: type,
      source: source,
      fileName: fileName,
    ),
  );
}

class _BackupUploadDialog extends StatefulWidget {
  const _BackupUploadDialog({
    required this.uploader,
    required this.type,
    required this.source,
    required this.fileName,
  });

  final BackupUploader uploader;
  final String type;
  final File source;
  final String fileName;

  @override
  State<_BackupUploadDialog> createState() => _BackupUploadDialogState();
}

class _BackupUploadDialogState extends State<_BackupUploadDialog> {
  final TransferCancelToken _cancelToken = TransferCancelToken();

  Timer? _ticker;
  int _sent = 0;
  int _total = -1;
  double _speed = 0;
  bool _cancelled = false;
  bool _finished = false;

  int _lastSampleBytes = 0;
  int _lastSampleAt = 0;

  @override
  void initState() {
    super.initState();
    _lastSampleAt = DateTime.now().millisecondsSinceEpoch;
    // 进度回调非常密集，统一按固定频率刷新 UI 并采样速度。
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _finished) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = (now - _lastSampleAt) / 1000;
      if (elapsed > 0) {
        _speed = (_sent - _lastSampleBytes) / elapsed;
      }
      _lastSampleBytes = _sent;
      _lastSampleAt = now;
      setState(() {});
    });
    unawaited(_run());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (!_finished) _cancelToken.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    BackupUploadOutcome outcome;
    try {
      await widget.uploader.uploadBackup(
        type: widget.type,
        source: widget.source,
        fileName: widget.fileName,
        onProgress: (sent, total) {
          _sent = sent;
          _total = total;
        },
        cancelToken: _cancelToken,
      );
      outcome = const BackupUploadOutcome();
    } on TransferCancelledException {
      outcome = const BackupUploadOutcome(cancelled: true);
    } on ApiException catch (e) {
      outcome = BackupUploadOutcome(error: e.message);
    } catch (e) {
      outcome = BackupUploadOutcome(
        error: e.toString().replaceFirst(RegExp(r'^\w+Exception:\s*'), ''),
      );
    }
    _finished = true;
    _ticker?.cancel();
    if (!mounted) return;
    Navigator.of(context).pop(outcome);
  }

  void _cancel() {
    if (_cancelled || _finished) return;
    setState(() => _cancelled = true);
    _cancelToken.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('上传备份'),
        content: SizedBox(
          width: 420,
          child: TransferIndicator(
            title: widget.fileName,
            transferred: _sent,
            total: _total,
            speed: formatTransferSpeed(_speed),
            subtitle: _cancelled ? '正在取消…' : '正在上传到面板备份目录',
          ),
        ),
        actions: [
          TextButton(
            onPressed: _cancelled ? null : _cancel,
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}
