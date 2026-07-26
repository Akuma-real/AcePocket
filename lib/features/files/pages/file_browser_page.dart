import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/task_snack.dart';
import '../models/file_item.dart';
import '../models/upload_source.dart';
import '../providers/files_providers.dart';
import '../repo/file_repo.dart';
import '../widgets/compress_dialog.dart';
import '../widgets/download_dialogs.dart';
import '../widgets/file_action_sheet.dart';
import '../widgets/file_list_tile.dart';
import '../widgets/file_property_sheet.dart';
import '../widgets/name_input_dialog.dart';
import '../widgets/path_breadcrumb.dart';
import '../widgets/permission_dialog.dart';
import '../widgets/share_dialogs.dart';
import '../widgets/upload_conflict_dialog.dart';
import '../widgets/upload_dialogs.dart';
import '../widgets/upload_progress_dialog.dart';

/// 文件浏览器：目录导航、增删改、复制移动、权限、压缩解压、上传与分享。
class FileBrowserPage extends ConsumerStatefulWidget {
  const FileBrowserPage({super.key, this.initialPath});

  /// 进入时的目录，缺省为 [kDefaultBrowsePath]。
  final String? initialPath;

  @override
  ConsumerState<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends ConsumerState<FileBrowserPage> {
  late List<String> _history;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// 已应用的搜索关键字（空串表示浏览模式）。
  String _keyword = '';

  /// 是否处于搜索输入状态。
  bool _searching = false;

  /// 多选中的完整路径。
  final Set<String> _selected = <String>{};

  /// 是否有操作正在执行（展示顶部进度条并屏蔽重复点击）。
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _history = [posixNormalize(widget.initialPath ?? kDefaultBrowsePath)];
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _path => _history.last;

  FileListQuery get _query =>
      (path: _path, keyword: _keyword, sort: ref.read(fileSortProvider));

  // ---------------------------------------------------------------------------
  // 通用工具
  // ---------------------------------------------------------------------------

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? theme.colorScheme.errorContainer : null,
        showCloseIcon: error,
      ));
  }

  /// 面板后台任务已提交的提示（带「查看任务」跳转 `/tasks`）。
  void _taskSnack(String message) {
    if (!mounted) return;
    showTaskSubmittedSnack(context, message);
  }

  Future<void> _refresh() async {
    final query = _query;
    ref.invalidate(fileListProvider(query));
    try {
      await ref.read(fileListProvider(query).future);
    } catch (_) {
      // 错误由 ErrorView 呈现，这里吞掉避免 RefreshIndicator 抛出。
    }
  }

  /// 执行一次会改变服务端状态的操作：统一 loading、错误提示与刷新。
  ///
  /// [action] 返回 false 表示用户中途取消（如放弃覆盖），此时不提示成功。
  Future<void> _run(
    Future<bool> Function() action, {
    String? success,
    bool task = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final done = await action();
      if (done && success != null) {
        if (task) {
          _taskSnack(success);
        } else {
          _snack(success);
        }
      }
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      // 无论成功还是部分失败都刷新列表，保证展示与服务端一致。
      if (mounted) {
        setState(() => _busy = false);
        await _refresh();
      }
    }
  }

  void _navigateTo(String path) {
    final normalized = posixNormalize(path);
    if (normalized == _path && _keyword.isEmpty) return;
    setState(() {
      _history.add(normalized);
      _selected.clear();
      _keyword = '';
      _searching = false;
      _searchController.clear();
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  bool _goBack() {
    if (_selected.isNotEmpty) {
      setState(_selected.clear);
      return true;
    }
    if (_searching || _keyword.isNotEmpty) {
      setState(() {
        _searching = false;
        _keyword = '';
        _searchController.clear();
      });
      return true;
    }
    if (_history.length > 1) {
      setState(() {
        _history.removeLast();
        _selected.clear();
      });
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // 文件操作
  // ---------------------------------------------------------------------------

  Future<void> _createEntry({required bool dir}) async {
    final name = await showNameInputDialog(
      context,
      title: dir ? '新建文件夹' : '新建文件',
      label: '名称',
      helperText: '将创建在 $_path',
      validator: (value) => value.contains('/') ? '名称不能包含 /' : null,
    );
    if (name == null || !mounted) return;
    final target = posixJoin(_path, name);
    await _run(() async {
      final exists = await ref.read(fileRepoProvider).exist([target]);
      if (exists.isNotEmpty && exists.first) {
        throw ApiException('「$name」已存在');
      }
      await ref.read(fileRepoProvider).create(target, dir: dir);
      return true;
    }, success: dir ? '文件夹已创建' : '文件已创建');
  }

  Future<void> _rename(FileItem item) async {
    final name = await showNameInputDialog(
      context,
      title: '重命名',
      initialValue: item.name,
      selectBaseName: !item.dir,
      validator: (value) => value.contains('/') ? '名称不能包含 /' : null,
    );
    if (name == null || name == item.name || !mounted) return;
    final target = posixJoin(posixParent(item.full), name);
    await _run(() async {
      final exists = await ref.read(fileRepoProvider).exist([target]);
      var force = false;
      if (exists.isNotEmpty && exists.first) {
        if (!mounted) return false;
        final ok = await showConfirmDialog(
          context,
          title: '目标已存在',
          content: '「$name」已存在，是否覆盖？',
          confirmText: '覆盖',
          danger: true,
        );
        if (!ok) return false;
        force = true;
      }
      await ref.read(fileRepoProvider).move([
        FileTransferItem(source: item.full, target: target, force: force),
      ]);
      return true;
    }, success: '已重命名');
  }

  Future<void> _delete(List<String> paths) async {
    if (paths.isEmpty) return;
    final ok = await showConfirmDialog(
      context,
      title: '删除',
      content: paths.length == 1
          ? '确定要删除「${posixBaseName(paths.first)}」吗？\n目录将连同其中所有内容一并删除，且不可恢复。'
          : '确定要删除选中的 ${paths.length} 项吗？\n目录将连同其中所有内容一并删除，且不可恢复。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      final repo = ref.read(fileRepoProvider);
      final failures = <String>[];
      for (final path in paths) {
        try {
          await repo.deletePath(path);
        } on ApiException catch (e) {
          failures.add('${posixBaseName(path)}：${e.message}');
        }
      }
      setState(_selected.clear);
      if (failures.isNotEmpty) {
        throw ApiException('部分项目删除失败：\n${failures.join('\n')}');
      }
      return true;
    }, success: '已删除');
  }

  Future<void> _truncate(FileItem item) async {
    final ok = await showConfirmDialog(
      context,
      title: '清空文件内容',
      content: '确定要把「${item.name}」截断为 0 字节吗？内容不可恢复。',
      confirmText: '清空',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      await ref.read(fileRepoProvider).truncate(item.full);
      return true;
    }, success: '文件已清空');
  }

  void _copyToClipboard(List<String> paths, {required bool isMove}) {
    if (paths.isEmpty) return;
    ref.read(fileClipboardProvider.notifier).set(paths, isMove: isMove);
    setState(_selected.clear);
    _snack(isMove ? '已剪切 ${paths.length} 项，请到目标目录粘贴' : '已复制 ${paths.length} 项，请到目标目录粘贴');
  }

  Future<void> _paste() async {
    final clip = ref.read(fileClipboardProvider);
    if (clip == null || clip.paths.isEmpty) return;
    final targets = <FileTransferItem>[];
    for (final source in clip.paths) {
      final target = posixJoin(_path, posixBaseName(source));
      targets.add(FileTransferItem(source: source, target: target));
    }
    await _run(() async {
      final repo = ref.read(fileRepoProvider);
      final exists = await repo.exist(targets.map((e) => e.target).toList());
      var force = false;
      final conflicts = <String>[];
      for (var i = 0; i < targets.length; i++) {
        if (i < exists.length && exists[i] && targets[i].source != targets[i].target) {
          conflicts.add(posixBaseName(targets[i].target));
        }
      }
      if (conflicts.isNotEmpty) {
        if (!mounted) return false;
        final ok = await showConfirmDialog(
          context,
          title: '目标已存在',
          content: '以下项目已存在，是否覆盖？\n${conflicts.join('、')}',
          confirmText: '覆盖',
          danger: true,
        );
        if (!ok) return false;
        force = true;
      }
      final items = targets
          .map((e) => FileTransferItem(
                source: e.source,
                target: e.target,
                force: force,
              ))
          .toList();
      if (clip.isMove) {
        await repo.move(items);
      } else {
        await repo.copy(items);
      }
      ref.read(fileClipboardProvider.notifier).clear();
      return true;
    }, success: clip.isMove ? '已移动' : '已复制');
  }

  Future<void> _changePermission(List<String> paths) async {
    if (paths.isEmpty) return;
    var mode = '0755';
    var owner = 'www';
    var group = 'www';
    try {
      final info = await ref.read(fileRepoProvider).info(paths.first);
      mode = info.mode.isEmpty ? mode : info.mode;
      owner = info.owner.isEmpty ? owner : info.owner;
      group = info.group.isEmpty ? group : info.group;
    } on ApiException {
      // 读取失败时用默认值继续，用户仍可手动设置。
    }
    if (!mounted) return;
    final result = await showPermissionDialog(
      context,
      targetLabel: paths.length == 1
          ? paths.first
          : '共 ${paths.length} 项（$_path）',
      initialMode: mode,
      initialOwner: owner,
      initialGroup: group,
    );
    if (result == null || !mounted) return;
    await _run(() async {
      final repo = ref.read(fileRepoProvider);
      final failures = <String>[];
      for (final path in paths) {
        try {
          await repo.permission(
            path: path,
            mode: result.mode,
            owner: result.owner,
            group: result.group,
          );
        } on ApiException catch (e) {
          failures.add('${posixBaseName(path)}：${e.message}');
        }
      }
      setState(_selected.clear);
      if (failures.isNotEmpty) {
        throw ApiException('部分项目设置失败：\n${failures.join('\n')}');
      }
      return true;
    }, success: '权限已更新');
  }

  Future<void> _compress(List<String> paths) async {
    if (paths.isEmpty) return;
    final dir = posixParent(paths.first);
    if (paths.any((p) => posixParent(p) != dir)) {
      _snack('所选项目不在同一目录，无法一起压缩', error: true);
      return;
    }
    final names = paths.map(posixBaseName).toList();
    final dest = await showCompressDialog(context, dir: dir, names: names);
    if (dest == null || !mounted) return;
    await _run(() async {
      await ref
          .read(fileRepoProvider)
          .compress(dir: dir, paths: names, file: dest);
      setState(_selected.clear);
      return true;
    }, success: '压缩任务已创建', task: true);
  }

  Future<void> _unCompress(FileItem item) async {
    final target = await showUnCompressDialog(
      context,
      archivePath: item.full,
      currentDir: _path,
    );
    if (target == null || !mounted) return;
    await _run(() async {
      await ref
          .read(fileRepoProvider)
          .unCompress(file: item.full, path: target);
      return true;
    }, success: '解压任务已创建', task: true);
  }

  Future<void> _share(FileItem item) async {
    final form = await showShareCreateDialog(
      context,
      initialPath: item.full,
      pathEditable: false,
    );
    if (form == null || !mounted) return;
    await _run(() async {
      final share = await ref.read(fileSharesProvider.notifier).create(
            path: form.path,
            expireHours: form.expireHours,
            maxDownloads: form.maxDownloads,
          );
      if (!mounted) return false;
      final url = ref.read(fileRepoProvider).shareDownloadUrl(share);
      await showShareLinkDialog(context, url: url);
      return true;
    });
  }

  Future<void> _uploadText() async {
    final result = await showTextUploadDialog(context, dir: _path);
    if (result == null || !mounted) return;
    final target = posixJoin(_path, result.name);
    await _run(() async {
      final repo = ref.read(fileRepoProvider);
      final exists = await repo.exist([target]);
      var force = false;
      if (exists.isNotEmpty && exists.first) {
        if (!mounted) return false;
        final ok = await showConfirmDialog(
          context,
          title: '目标已存在',
          content: '「${result.name}」已存在，是否覆盖？',
          confirmText: '覆盖',
          danger: true,
        );
        if (!ok) return false;
        force = true;
      }
      await repo.upload(
        path: target,
        bytes: utf8.encode(result.content),
        force: force,
      );
      return true;
    }, success: '文件已上传');
  }

  // ---------------------------------------------------------------------------
  // 本地文件上传 / 下载到手机
  // ---------------------------------------------------------------------------

  /// 用系统文件选择器挑选手机中的文件并上传到当前目录。
  ///
  /// 小文件走 `POST /file/upload`，大文件自动走 `/file/chunk/start` →
  /// `/file/chunk/upload` → `/file/chunk/finish` 分片流程（可续传）。
  Future<void> _uploadLocalFiles() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        allowMultiple: true,
        // 大文件不预读进内存，统一由 UploadSource 按需分片读取。
        withData: false,
        withReadStream: false,
      );
    } catch (e) {
      _snack('打开文件选择器失败：$e', error: true);
      return;
    }
    if (picked == null || picked.files.isEmpty || !mounted) return;

    final sources = <UploadSource>[];
    final unreadable = <String>[];
    for (final file in picked.files) {
      try {
        final path = file.path;
        if (path != null && path.isNotEmpty) {
          sources.add(
              await LocalFileUploadSource.open(File(path), name: file.name));
        } else if (file.bytes != null) {
          sources
              .add(BytesUploadSource(name: file.name, bytes: file.bytes!));
        } else {
          unreadable.add(file.name);
        }
      } catch (_) {
        unreadable.add(file.name);
      }
    }
    if (sources.isEmpty) {
      _snack('没有可读取的文件，请重新选择', error: true);
      return;
    }

    Future<void> closeAll() async {
      for (final source in sources) {
        await source.close();
      }
    }

    final repo = ref.read(fileRepoProvider);
    final jobs = <UploadJob>[];
    try {
      final exists =
          await repo.exist([for (final s in sources) posixJoin(_path, s.name)]);
      final conflicts = <int>[
        for (var i = 0; i < sources.length; i++)
          if (i < exists.length && exists[i]) i,
      ];

      var action = UploadConflictAction.overwrite;
      if (conflicts.isNotEmpty) {
        if (!mounted) {
          await closeAll();
          return;
        }
        final chosen = await showUploadConflictDialog(
          context,
          names: [for (final i in conflicts) sources[i].name],
        );
        if (chosen == null || !mounted) {
          await closeAll();
          return;
        }
        action = chosen;
      }

      // 本批次已占用的目标文件名，避免多选到同名文件时互相覆盖。
      final reserved = <String>{};

      Future<void> addRenamed(UploadSource source) async {
        final name = await _uniqueRemoteName(repo, source.name, reserved);
        reserved.add(name);
        jobs.add(UploadJob(source: source, targetName: name));
      }

      Future<void> addJob(UploadSource source, {required bool force}) async {
        if (reserved.contains(source.name)) {
          // 同批次内重名：改名后必然不冲突，无需覆盖。
          await addRenamed(source);
          return;
        }
        reserved.add(source.name);
        jobs.add(
            UploadJob(source: source, targetName: source.name, force: force));
      }

      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        if (!conflicts.contains(i)) {
          await addJob(source, force: false);
          continue;
        }
        switch (action) {
          case UploadConflictAction.overwrite:
            await addJob(source, force: true);
          case UploadConflictAction.rename:
            await addRenamed(source);
          case UploadConflictAction.skip:
            await source.close();
        }
      }
    } on ApiException catch (e) {
      await closeAll();
      _snack(e.message, error: true);
      return;
    } catch (e) {
      await closeAll();
      _snack('$e', error: true);
      return;
    }

    if (jobs.isEmpty) {
      _snack('已跳过全部文件，未执行上传');
      return;
    }
    if (!mounted) {
      await closeAll();
      return;
    }

    final outcome = await showUploadProgressDialog(
      context,
      repo: repo,
      dir: _path,
      jobs: jobs,
    );
    if (!mounted) return;
    await _refresh();
    if (!mounted || outcome == null) return;

    final messages = <String>[];
    if (outcome.succeeded > 0) messages.add('成功 ${outcome.succeeded} 个');
    if (outcome.cancelled) messages.add('已取消剩余文件');
    if (unreadable.isNotEmpty) {
      messages.add('${unreadable.length} 个文件无法读取');
    }
    if (outcome.failures.isNotEmpty) {
      _snack('上传结束：${messages.join('，')}\n${outcome.failures.join('\n')}',
          error: true);
    } else {
      _snack(messages.isEmpty ? '未上传任何文件' : '上传完成：${messages.join('，')}');
    }
  }

  /// 在当前目录里找一个不冲突的文件名（追加 `-1`、`-2`…）。
  Future<String> _uniqueRemoteName(
    FileRepo repo,
    String fileName,
    Set<String> reserved,
  ) async {
    final dot = fileName.lastIndexOf('.');
    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '';
    const batch = 10;
    for (var offset = 1; offset <= 200; offset += batch) {
      final candidates = [
        for (var i = 0; i < batch; i++) '$stem-${offset + i}$ext',
      ];
      final exists =
          await repo.exist([for (final n in candidates) posixJoin(_path, n)]);
      for (var i = 0; i < candidates.length; i++) {
        final name = candidates[i];
        if (!(i < exists.length && exists[i]) && !reserved.contains(name)) {
          return name;
        }
      }
    }
    return '$stem-${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  /// 下载服务器文件到手机本地，并提供「用其他应用打开」。
  Future<void> _downloadToPhone(FileItem item) async {
    if (item.dir) {
      _snack('目录无法直接下载，请先压缩为压缩包', error: true);
      return;
    }
    final repo = ref.read(fileRepoProvider);
    final outcome = await showDownloadProgressDialog(
      context,
      fileName: item.name,
      runner: ({
        required savePath,
        required onProgress,
        required cancelToken,
      }) =>
          repo.downloadToLocal(
        path: item.full,
        savePath: savePath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      ),
    );
    if (!mounted || outcome == null) return;
    if (outcome.cancelled) {
      _snack('下载已取消');
      return;
    }
    final error = outcome.error;
    if (error != null) {
      _snack(error, error: true);
      return;
    }
    final file = outcome.file;
    if (file == null) return;
    await showDownloadResultDialog(context, file: file);
  }

  Future<void> _remoteDownload() async {
    final result = await showRemoteDownloadDialog(context, dir: _path);
    if (result == null || !mounted) return;
    await _run(() async {
      await ref.read(fileRepoProvider).remoteDownload(
            path: posixJoin(_path, result.name),
            url: result.url,
          );
      return true;
    }, success: '下载任务已创建', task: true);
  }

  Future<void> _promptPath() async {
    final path = await showNameInputDialog(
      context,
      title: '跳转到路径',
      label: '绝对路径',
      initialValue: _path,
      confirmText: '跳转',
      validator: (value) => value.startsWith('/') ? null : '请输入以 / 开头的绝对路径',
    );
    if (path == null || !mounted) return;
    _navigateTo(path);
  }

  Future<void> _openItem(FileItem item) async {
    if (item.dir) {
      _navigateTo(item.full);
      return;
    }
    await context.push(
      '/files/edit?path=${Uri.encodeQueryComponent(item.full)}',
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    _snack('路径已复制到剪贴板');
  }

  Future<void> _handleAction(FileItem item) async {
    final action = await showFileActionSheet(context, item: item);
    if (action == null || !mounted) return;
    switch (action) {
      case FileAction.open:
      case FileAction.edit:
        await _openItem(item);
      case FileAction.rename:
        await _rename(item);
      case FileAction.download:
        await _downloadToPhone(item);
      case FileAction.copy:
        _copyToClipboard([item.full], isMove: false);
      case FileAction.cut:
        _copyToClipboard([item.full], isMove: true);
      case FileAction.permission:
        await _changePermission([item.full]);
      case FileAction.compress:
        await _compress([item.full]);
      case FileAction.unCompress:
        await _unCompress(item);
      case FileAction.share:
        await _share(item);
      case FileAction.truncate:
        await _truncate(item);
      case FileAction.copyPath:
        await _copyPath(item.full);
      case FileAction.property:
        await showFilePropertySheet(context, item.full);
      case FileAction.delete:
        await _delete([item.full]);
    }
  }

  Future<void> _showCreateSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('新建文件'),
              onTap: () => Navigator.of(context).pop('file'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('新建文件夹'),
              onTap: () => Navigator.of(context).pop('dir'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('上传文件'),
              subtitle: const Text('从手机选择文件、粘贴文本或让面板远程下载'),
              onTap: () => Navigator.of(context).pop('upload'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'file':
        await _createEntry(dir: false);
      case 'dir':
        await _createEntry(dir: true);
      case 'upload':
        final method = await showUploadMethodSheet(context);
        if (method == null || !mounted) return;
        switch (method) {
          case UploadMethod.local:
            await _uploadLocalFiles();
          case UploadMethod.text:
            await _uploadText();
          case UploadMethod.remote:
            await _remoteDownload();
        }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar(int visibleCount) {
    final sort = ref.watch(fileSortProvider);
    final showHidden = ref.watch(showHiddenFilesProvider);

    if (_selected.isNotEmpty) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '取消选择',
          onPressed: () => setState(_selected.clear),
        ),
        title: Text('已选择 ${_selected.length} 项'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: '复制',
            onPressed: () =>
                _copyToClipboard(_selected.toList(), isMove: false),
          ),
          IconButton(
            icon: const Icon(Icons.content_cut),
            tooltip: '剪切',
            onPressed: () => _copyToClipboard(_selected.toList(), isMove: true),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: () => _delete(_selected.toList()),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) async {
              switch (value) {
                case 'all':
                  _selectAll();
                case 'compress':
                  await _compress(_selected.toList());
                case 'permission':
                  await _changePermission(_selected.toList());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Text(
                  _selected.length >= visibleCount ? '取消全选' : '全选',
                ),
              ),
              const PopupMenuItem(value: 'compress', child: Text('压缩')),
              const PopupMenuItem(value: 'permission', child: Text('权限设置')),
            ],
          ),
        ],
      );
    }

    if (_searching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _searching = false;
            _keyword = '';
            _searchController.clear();
          }),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索当前目录及子目录',
            border: InputBorder.none,
          ),
          onSubmitted: (value) => setState(() => _keyword = value.trim()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () =>
                setState(() => _keyword = _searchController.text.trim()),
          ),
        ],
      );
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回',
        onPressed: () {
          if (_goBack()) return;
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            posixBaseName(_path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$visibleCount 项',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: '搜索',
          onPressed: () => setState(() => _searching = true),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          tooltip: '排序',
          onSelected: (value) =>
              ref.read(fileSortProvider.notifier).set(value),
          itemBuilder: (context) => [
            for (final option in const <(String, String)>[
              ('', '默认（目录优先）'),
              ('name', '名称升序'),
              ('-name', '名称降序'),
              ('size', '大小升序'),
              ('-size', '大小降序'),
              ('modify', '修改时间升序'),
              ('-modify', '修改时间降序'),
            ])
              CheckedPopupMenuItem<String>(
                value: option.$1,
                checked: sort == option.$1,
                child: Text(option.$2),
              ),
          ],
        ),
        PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (value) async {
            switch (value) {
              case 'hidden':
                ref.read(showHiddenFilesProvider.notifier).toggle();
              case 'shares':
                await context.push('/files/shares');
              case 'refresh':
                await _refresh();
              case 'path':
                await _promptPath();
            }
          },
          itemBuilder: (context) => [
            CheckedPopupMenuItem<String>(
              value: 'hidden',
              checked: showHidden,
              child: const Text('显示隐藏文件'),
            ),
            const PopupMenuItem(value: 'path', child: Text('跳转到路径')),
            const PopupMenuItem(value: 'shares', child: Text('文件分享管理')),
            const PopupMenuItem(value: 'refresh', child: Text('刷新')),
          ],
        ),
      ],
    );
  }

  void _selectAll() {
    final state = ref.read(fileListProvider(_query)).valueOrNull;
    if (state == null) return;
    final visible = _visibleItems(state.items);
    setState(() {
      if (_selected.length >= visible.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(visible.map((e) => e.full));
      }
    });
  }

  List<FileItem> _visibleItems(List<FileItem> items) {
    final showHidden = ref.read(showHiddenFilesProvider);
    if (showHidden) return items;
    return items.where((e) => !e.hidden).toList();
  }

  Widget _buildClipboardBar() {
    final clip = ref.watch(fileClipboardProvider);
    if (clip == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            Icon(
              clip.isMove ? Icons.content_cut : Icons.copy_outlined,
              size: 18,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${clip.isMove ? '待移动' : '待复制'} ${clip.paths.length} 项',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _paste,
              child: const Text('粘贴到此'),
            ),
            IconButton(
              iconSize: 18,
              tooltip: '取消',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  ref.read(fileClipboardProvider.notifier).clear(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(FileListState state) {
    final visible = _visibleItems(state.items);
    final hasParentTile = _keyword.isEmpty && _path != '/';

    if (visible.isEmpty && !state.hasMore) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (hasParentTile) _parentTile(),
            SizedBox(
              height: 320,
              child: EmptyView(
                message: _keyword.isEmpty
                    ? '该目录为空'
                    : '没有匹配「$_keyword」的文件',
                icon: Icons.folder_off_outlined,
                action: _keyword.isEmpty
                    ? FilledButton.tonalIcon(
                        onPressed: _showCreateSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('新建'),
                      )
                    : null,
              ),
            ),
          ],
        ),
      );
    }

    final leadingCount = hasParentTile ? 1 : 0;
    final trailingCount = state.hasMore ? 1 : 0;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: leadingCount + visible.length + trailingCount,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (hasParentTile && index == 0) return _parentTile();
          final dataIndex = index - leadingCount;
          if (dataIndex >= visible.length) {
            // 触底自动加载下一页。
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(fileListProvider(_query).notifier).loadMore();
            });
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }
          final item = visible[dataIndex];
          final selected = _selected.contains(item.full);
          return FileListTile(
            item: item,
            selectionMode: _selected.isNotEmpty,
            selected: selected,
            onTap: () {
              if (_selected.isNotEmpty) {
                setState(() {
                  if (selected) {
                    _selected.remove(item.full);
                  } else {
                    _selected.add(item.full);
                  }
                });
                return;
              }
              _openItem(item);
            },
            onLongPress: () => setState(() {
              if (selected) {
                _selected.remove(item.full);
              } else {
                _selected.add(item.full);
              }
            }),
            onMore: () => _handleAction(item),
          );
        },
      ),
    );
  }

  Widget _parentTile() {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.drive_folder_upload_outlined,
          color: theme.colorScheme.onSurfaceVariant),
      title: const Text('上一级目录'),
      subtitle: Text(
        posixParent(_path),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => _navigateTo(posixParent(_path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      path: _path,
      keyword: _keyword,
      sort: ref.watch(fileSortProvider),
    );
    final listAsync = ref.watch(fileListProvider(query));
    final visibleCount = listAsync.valueOrNull == null
        ? 0
        : _visibleItems(listAsync.valueOrNull!.items).length;

    return PopScope(
      canPop: _selected.isEmpty &&
          !_searching &&
          _keyword.isEmpty &&
          _history.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        appBar: _buildAppBar(visibleCount),
        floatingActionButton: _selected.isEmpty && !_searching
            ? FloatingActionButton(
                onPressed: _busy ? null : _showCreateSheet,
                tooltip: '新建',
                child: const Icon(Icons.add),
              )
            : null,
        body: Column(
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            PathBreadcrumb(
              path: _path,
              onNavigate: _navigateTo,
              onEditPath: _promptPath,
            ),
            _buildClipboardBar(),
            Expanded(
              child: listAsync.when(
                loading: () => const LoadingView(message: '正在读取目录…'),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(fileListProvider(query)),
                ),
                data: _buildList,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
