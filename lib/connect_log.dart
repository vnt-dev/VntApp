import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/utils/responsive_utils.dart';
import 'package:vnt_app/utils/log_utils.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:vnt_app/utils/toast_utils.dart';
import 'package:vnt_app/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class LogPage extends StatefulWidget {
  @override
  _LogPageState createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  LogReader? _logReader;
  final ScrollController _scrollController = ScrollController();
  final List<String> _logLines = [];
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _availableLogFiles = [];
  String? _currentLogFile;
  
  // 性能优化：限制显示的日志行数
  static const int _maxDisplayLines = 1000; // 最多显示1000行
  static const int _maxLoadLines = 2000;    // 最多加载2000行（从文件末尾开始）

  @override
  void initState() {
    super.initState();
    _initializeLogReader();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initializeLogReader() async {
    // 先清理旧的资源
    _fileWatchTimer?.cancel();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 使用统一的日志路径工具类获取日志目录
      final logsDir = await LogUtils.getLogDirectory();
      debugPrint('日志目录: $logsDir');

      // 检查 logs 目录是否存在
      final logsDirEntity = Directory(logsDir);
      if (!await logsDirEntity.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage = '日志目录不存在: $logsDir\n\n请确保应用已经运行过尝试连接一个网络后再查看日志。';
        });
        return;
      }

      // 查找所有日志文件（包括滚动的日志文件）
      final logFiles = <String>[];
      await for (var entity in logsDirEntity.list()) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          // 匹配 vnt-core.log 和 vnt-core.1.log, vnt-core.2.log 等
          if (fileName.startsWith('vnt-core') && fileName.endsWith('.log')) {
            logFiles.add(entity.path);
            debugPrint('找到日志文件: ${entity.path}');
          }
        }
      }

      if (logFiles.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '未找到日志文件\n\n日志目录: $logsDir\n\n请确保应用已经运行过并尝试连接一个网络后再查看日志。';
        });
        return;
      }

      debugPrint('共找到 ${logFiles.length} 个日志文件');

      // 按文件名排序（vnt-core.log 应该是最新的）
      logFiles.sort((a, b) {
        final aName = path.basename(a);
        final bName = path.basename(b);
        // vnt-core.log 排在最前面
        if (aName == 'vnt-core.log') return -1;
        if (bName == 'vnt-core.log') return 1;
        return aName.compareTo(bName);
      });

      setState(() {
        _availableLogFiles = logFiles;
        _currentLogFile = logFiles.first;
        // 在调用 _loadMoreLogs 之前将 _isLoading 设为 false
        _isLoading = false;
      });

      debugPrint('开始读取日志文件: $_currentLogFile');

      // 创建日志读取器
      _logReader = LogReader(File(_currentLogFile!));
      await _loadMoreLogs();

      debugPrint('日志加载完成，共 ${_logLines.length} 行');

      // 加载完成后自动滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      // 启动文件监听
      _startFileWatcher();
    } catch (e) {
      debugPrint('初始化日志读取器失败: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化日志读取器失败: $e';
      });
    }
  }

  // 滚动到底部的辅助方法
  Timer? _fileWatchTimer;
  int _lastFileSize = 0;

  void _startFileWatcher() {
    if (_currentLogFile == null) return;

    final file = File(_currentLogFile!);

    // 记录当前文件大小
    file.length().then((size) {
      _lastFileSize = size;
    });

    // 每秒检查一次文件变化
    _fileWatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        if (!await file.exists()) return;

        final currentSize = await file.length();
        if (currentSize > _lastFileSize) {
          // 文件有新内容，读取新增的部分
          final raf = await file.open(mode: FileMode.read);
          await raf.setPosition(_lastFileSize);
          final newBytes = await raf.read(currentSize - _lastFileSize);
          await raf.close();

          final newContent = utf8.decode(newBytes);
          final newLines = newContent.split('\n').where((line) => line.trim().isNotEmpty).toList();

          if (newLines.isNotEmpty && mounted) {
            setState(() {
              _logLines.addAll(newLines);
              // 限制加载的日志行数（保留最新的）
              if (_logLines.length > _maxLoadLines) {
                _logLines.removeRange(0, _logLines.length - _maxLoadLines);
              }
            });

            // 如果用户在底部，自动滚动到新日志
            if (_scrollController.hasClients) {
              final position = _scrollController.position;
              if (position.pixels >= position.maxScrollExtent - 50) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });
              }
            }
          }

          _lastFileSize = currentSize;
        }
      } catch (e) {
        debugPrint('监听文件变化失败: $e');
      }
    });
  }

  // 滚动到底部的辅助方法
  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients || _logLines.isEmpty) return;

    // 等待 ListView 完全构建
    await Future.delayed(const Duration(milliseconds: 100));

    if (!_scrollController.hasClients) return;

    try {
      // 直接跳转到底部，不使用动画
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    } catch (e) {
      debugPrint('滚动到底部失败: $e');
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoading || _logReader == null) return;

    setState(() => _isLoading = true);

    try {
      final newLines = await _logReader!.readNextBatch();
      setState(() {
        _logLines.addAll(newLines);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('读取日志失败: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '读取日志失败: $e';
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent &&
        !_isLoading) {
      _loadMoreLogs();
    }
  }

  Future<void> _switchLogFile(String logFilePath) async {
    setState(() {
      _currentLogFile = logFilePath;
      _logLines.clear();
      _isLoading = true;
      _errorMessage = null;
    });

    _logReader = LogReader(File(logFilePath));
    await _loadMoreLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // 清理文件监听
    _fileWatchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // 设置状态栏颜色以适配当前主题
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(
          '日志',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.15),
                primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
        ),
        actions: [
          // 滚动到底部按钮
          if (_logLines.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.keyboard_double_arrow_down),
              tooltip: '滚动到底部',
              onPressed: _scrollToBottom,
            ),
          // 复制按钮
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '复制日志',
            onPressed: _copyLogs,
          ),
          // 下载按钮
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: '下载日志',
            onPressed: _downloadLogs,
          ),
          // 清空按钮
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // 实时状态指示器（文件监听）
          if (_logLines.isNotEmpty && _fileWatchTimer != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: (isDark ? Colors.green.shade900 : Colors.green.shade50).withOpacity(0.5),
              child: Row(
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    color: Colors.green,
                    size: 12,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '实时监听中 - 新日志将自动显示',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.green.shade200 : Colors.green.shade800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_logLines.length} 行',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          // 日志视图
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildLogView(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogView(bool isDark) {
    // 如果有错误信息，显示错误提示
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            SizedBox(height: context.spacingMedium),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingLarge),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: context.fontBody,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ),
            SizedBox(height: context.spacingLarge),
            ElevatedButton.icon(
              onPressed: _initializeLogReader,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // 如果正在加载且没有日志行，显示加载指示器
    if (_isLoading && _logLines.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 如果没有日志行且不在加载中，显示无日志提示
    if (_logLines.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            SizedBox(height: context.spacingMedium),
            Text(
              '暂无日志',
              style: TextStyle(
                fontSize: context.fontLarge,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            SizedBox(height: context.spacingSmall),
            Text(
              '日志文件为空或尚未产生日志。',
              style: TextStyle(
                fontSize: context.fontBody,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // 显示日志列表
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        borderRadius: BorderRadius.circular(context.cardRadius),
      ),
      child: SelectionArea(
        selectionControls: Platform.isWindows || Platform.isLinux
            ? DesktopTextSelectionControls()
            : (Platform.isMacOS
                ? CupertinoDesktopTextSelectionControls()
                : materialTextSelectionControls),
        contextMenuBuilder: (context, selectableRegionState) {
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: selectableRegionState.contextMenuAnchors,
            buttonItems: [
              ContextMenuButtonItem(
                label: '复制选中',
                onPressed: () {
                  selectableRegionState.copySelection(SelectionChangedCause.toolbar);
                  ContextMenuController.removeAny();
                  if (mounted) {
                    showTopToast(context, '已复制选中内容', isSuccess: true);
                  }
                },
              ),
              if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
                ContextMenuButtonItem(
                  label: '复制全部',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _copyLogs();
                  },
                ),
            ],
          );
        },
        child: _buildLogListView(isDark),
      ),
    );
  }
  
  // 构建日志列表视图（性能优化版本）
  Widget _buildLogListView(bool isDark) {
    // 计算要显示的日志范围
    final displayLines = _logLines.length > _maxDisplayLines
        ? _logLines.sublist(_logLines.length - _maxDisplayLines)
        : _logLines;
    
    final skippedLines = _logLines.length - displayLines.length;
    
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(context.spacingSmall),
      itemCount: displayLines.length + (_isLoading ? 1 : 0) + (skippedLines > 0 ? 1 : 0),
      itemBuilder: (context, index) {
        // 显示跳过的行数提示
        if (skippedLines > 0 && index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.orange.shade900 : Colors.orange.shade100).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '已隐藏前 $skippedLines 行日志（性能优化）',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
                  ),
                ),
              ),
            ),
          );
        }
        
        // 调整索引
        final adjustedIndex = skippedLines > 0 ? index - 1 : index;
        
        if (adjustedIndex >= displayLines.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final line = displayLines[adjustedIndex];
        Color textColor;

        // 判断日志级别并设置颜色
        if (line.contains('ERROR') || line.contains(' E/') || line.contains(' E ')) {
          textColor = Colors.red;
        } else if (line.contains('WARN') || line.contains(' W/') || line.contains(' W ')) {
          textColor = Colors.orange;
        } else if (line.contains('INFO') || line.contains(' I/') || line.contains(' I ')) {
          textColor = isDark ? Colors.lightBlue : Colors.blue;
        } else if (line.contains('DEBUG') || line.contains(' D/') || line.contains(' D ')) {
          textColor = isDark ? Colors.grey : Colors.grey.shade600;
        } else {
          textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
        }

        // 移动端：使用SelectableText支持选择
        // 桌面端：使用Text + 右键菜单
        if (Platform.isAndroid || Platform.isIOS) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              line,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          );
        } else {
          // 桌面端：Text即可，SelectionArea在外层处理
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: Text(
                line,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          );
        }
      },
    );
  }

  void _exportLogs() {
    // 实现日志导出功能
  }

  // 复制所有日志到剪贴板
  Future<void> _copyLogs() async {
    try {
      if (_logLines.isEmpty) {
        if (mounted) {
          showTopToast(context, '没有日志可复制', isSuccess: false);
        }
        return;
      }

      String allLogs = '';

      // 所有平台统一使用文件日志模式：复制所有日志文件
      for (var logFile in _availableLogFiles) {
        final file = File(logFile);
        if (await file.exists()) {
          final content = await file.readAsString();
          allLogs += '=== ${path.basename(logFile)} ===\n';
          allLogs += content;
          allLogs += '\n\n';
        }
      }

      if (allLogs.trim().isEmpty) {
        if (mounted) {
          showTopToast(context, '没有日志可复制', isSuccess: false);
        }
        return;
      }

      debugPrint('准备复制到剪贴板，总长度: ${allLogs.length} 字符');

      // macOS 平台特殊处理：使用 pbcopy 命令
      if (Platform.isMacOS) {
        try {
          // 先尝试使用 Flutter 的剪贴板 API
          await Clipboard.setData(ClipboardData(text: allLogs));
          await Future.delayed(const Duration(milliseconds: 100));

          // 尝试验证复制是否成功
          bool copySuccess = false;
          try {
            final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
            if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
              copySuccess = true;
              debugPrint('Flutter 剪贴板 API 复制成功');
            }
          } catch (e) {
            debugPrint('Flutter 剪贴板验证失败: $e');
          }

          // 如果 Flutter API 失败，尝试使用 pbcopy 命令
          if (!copySuccess) {
            debugPrint('尝试使用 pbcopy 命令复制到剪贴板');
            final process = await Process.start('pbcopy', []);
            process.stdin.write(allLogs);
            await process.stdin.close();
            final exitCode = await process.exitCode;

            if (exitCode == 0) {
              copySuccess = true;
              debugPrint('pbcopy 命令复制成功');
            } else {
              debugPrint('pbcopy 命令失败，退出码: $exitCode');
            }
          }

          if (mounted) {
            if (copySuccess) {
              final lineCount = allLogs.split('\n').where((line) => line.trim().isNotEmpty).length;
              showTopToast(context, '已复制 $lineCount 行日志到剪贴板', isSuccess: true);
            } else {
              showTopToast(context, '复制失败，建议使用下载功能', isSuccess: false);
            }
          }
          return;
        } catch (e) {
          debugPrint('macOS 复制失败: $e');
          if (mounted) {
            showTopToast(context, '复制失败，建议使用下载功能', isSuccess: false);
          }
          return;
        }
      }

      // 其他平台使用标准的剪贴板 API
      try {
        // 使用 Clipboard.setData 复制，添加短暂延迟确保操作完成
        await Clipboard.setData(ClipboardData(text: allLogs));

        // 添加短暂延迟，确保剪贴板操作完成
        await Future.delayed(const Duration(milliseconds: 100));

        // 验证复制是否成功
        try {
            final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
            if (clipboardData != null && clipboardData.text != null) {
              final copiedLength = clipboardData.text!.length;
              debugPrint('剪贴板验证成功，长度: $copiedLength 字符');

              // 检查复制的内容是否完整
              if (copiedLength < allLogs.length * 0.9) {
                // 如果复制的内容少于原始内容的90%，认为复制不完整
                debugPrint('警告：复制内容不完整，原始长度: ${allLogs.length}, 复制长度: $copiedLength');
                throw Exception('复制内容不完整');
              }

              debugPrint('剪贴板前100个字符: ${clipboardData.text!.substring(0, clipboardData.text!.length > 100 ? 100 : clipboardData.text!.length)}');
            } else {
              debugPrint('剪贴板验证失败：无法读取剪贴板内容');
              throw Exception('无法验证剪贴板内容');
            }
          } catch (verifyError) {
            debugPrint('剪贴板验证失败: $verifyError');
            // 验证失败不影响复制操作，继续显示成功提示
          }

        if (mounted) {
          final lineCount = allLogs.split('\n').where((line) => line.trim().isNotEmpty).length;
          debugPrint('复制成功，共 $lineCount 行');
          showTopToast(context, '已复制 $lineCount 行日志到剪贴板', isSuccess: true);
        }
      } catch (clipboardError) {
        debugPrint('剪贴板操作失败: $clipboardError');

        if (Platform.isAndroid && allLogs.length > 100000) {
          // 如果是 Android 且文本较大，提示用户使用下载功能
          if (mounted) {
            showTopToast(context, '日志内容过大，建议下载日志', isSuccess: false);
          }
        } else {
          // 重新抛出异常，让外层 catch 处理
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('复制日志失败: $e');
      if (mounted) {
        showTopToast(context, '复制失败: $e', isSuccess: false);
      }
    }
  }

  // 下载所有日志文件
  Future<void> _downloadLogs() async {
    try {
      if (Platform.isAndroid) {
        // Android 平台下载日志
        final directory = await getTemporaryDirectory();
        final fileName = 'vnt_logs_${DateTime.now().millisecondsSinceEpoch}.txt';
        final filePath = '${directory.path}/$fileName';

        final file = File(filePath);

        // 合并所有日志文件
        String allLogs = '';
        for (var logFile in _availableLogFiles) {
          final logFileEntity = File(logFile);
          if (await logFileEntity.exists()) {
            final content = await logFileEntity.readAsString();
            allLogs += '=== ${path.basename(logFile)} ===\n';
            allLogs += content;
            allLogs += '\n\n';
          }
        }
        await file.writeAsString(allLogs);

        final success = await FileSaver.copyFile(
          sourceFilePath: filePath,
          fileName: fileName,
          mimeType: 'text/plain',
        );

        if (await file.exists()) {
          await file.delete();
        }

        if (mounted) {
          if (success) {
            showTopToast(context, '日志已保存: $fileName', isSuccess: true);
          } else {
            showTopToast(context, '保存已取消', isSuccess: false);
          }
        }
      } else if (Platform.isIOS) {
        // iOS使用Share Sheet分享日志
        final tempDir = await getTemporaryDirectory();
        final fileName = 'vnt_log_${DateTime.now().millisecondsSinceEpoch}.txt';
        final filePath = '${tempDir.path}/$fileName';

        final file = File(filePath);

        // 合并所有日志文件
        String allLogs = '';
        for (var logFile in _availableLogFiles) {
          final logFileEntity = File(logFile);
          if (await logFileEntity.exists()) {
            final content = await logFileEntity.readAsString();
            allLogs += '=== ${path.basename(logFile)} ===\n';
            allLogs += content;
            allLogs += '\n\n';
          }
        }
        await file.writeAsString(allLogs);

        // 使用Share Sheet分享
        try {
          final box = context.findRenderObject() as RenderBox?;
          final result = await Share.shareXFiles(
            [XFile(filePath)],
            sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
          );
          
          if (mounted) {
            if (result.status == ShareResultStatus.success) {
              showTopToast(context, '日志已导出', isSuccess: true);
            } else if (result.status == ShareResultStatus.dismissed) {
              showTopToast(context, '操作已取消', isSuccess: false);
            }
          }
        } catch (e) {
          debugPrint('分享日志失败: $e');
          if (mounted) {
            showTopToast(context, '分享失败: $e', isSuccess: false);
          }
        }

        // 延迟清理临时文件
        Future.delayed(const Duration(seconds: 5), () async {
          if (await file.exists()) {
            await file.delete();
          }
        });
      } else {
        // Windows/macOS/Linux 平台使用文件选择器
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'vnt_logs_$timestamp.txt';

        // 让用户选择保存位置
        String? savePath = await FilePicker.platform.saveFile(
          dialogTitle: '保存日志文件',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['txt'],
        );

        if (savePath == null) {
          if (mounted) {
            showTopToast(context, '保存已取消', isSuccess: false);
          }
          return;
        }

        // 合并所有日志文件
        String allLogs = '';
        for (var logFile in _availableLogFiles) {
          final file = File(logFile);
          if (await file.exists()) {
            final content = await file.readAsString();
            allLogs += '=== ${path.basename(logFile)} ===\n';
            allLogs += content;
            allLogs += '\n\n';
          }
        }

        // 保存到用户选择的位置
        final saveFile = File(savePath);
        await saveFile.writeAsString(allLogs);

        if (mounted) {
          showTopToast(context, '日志已保存: $savePath', isSuccess: true);
        }
      }
    } catch (e) {
      debugPrint('下载日志失败: $e');
      if (mounted) {
        showTopToast(context, '下载失败: $e', isSuccess: false);
      }
    }
  }

  // 显示右键菜单（桌面端）
  void _showDesktopContextMenu(BuildContext context, Offset position, String line) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
              const SizedBox(width: 8),
              Text('复制选中', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              if (mounted) {
                showTopToast(context, '请使用 Ctrl+C 复制选中内容', isSuccess: true);
              }
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.select_all, size: 18, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
              const SizedBox(width: 8),
              Text('复制全部', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              _copyLogs();
            });
          },
        ),
      ],
    );
  }

  void _showContextMenu(BuildContext context, Offset position, String line) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 如果 position 是 Offset.zero，说明是从长按触发的，使用屏幕中心
    if (position == Offset.zero) {
      _showMobileContextMenu(context, line);
      return;
    }
    
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
              const SizedBox(width: 8),
              Text('复制此行', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ],
          ),
          onTap: () {
            Clipboard.setData(ClipboardData(text: line));
            Future.delayed(Duration.zero, () {
              if (mounted) {
                showTopToast(context, '已复制 1 行', isSuccess: true);
              }
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.select_all, size: 18, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
              const SizedBox(width: 8),
              Text('复制所有日志', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              _copyLogs();
            });
          },
        ),
      ],
    );
  }

  // 显示移动端菜单
  void _showMobileContextMenu(BuildContext context, String line) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.copy, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
              title: Text('复制此行', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: line));
                if (mounted) {
                  showTopToast(context, '已复制 1 行', isSuccess: true);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.select_all, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
              title: Text('复制所有日志', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
              onTap: () {
                Navigator.pop(context);
                _copyLogs();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // 清空日志
  Future<void> _clearLogs() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.cardRadius)),
        title: Text(
          '清空日志',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        content: Text(
          '确定要清空所有日志文件吗？\n\n注意：日志文件内容将被清空，但文件会保留在logs目录。',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 所有平台统一清空日志文件内容
      int clearedCount = 0;
      List<String> failedFiles = [];

      for (var logFile in _availableLogFiles) {
        final file = File(logFile);
        if (await file.exists()) {
          try {
            // 清空文件内容而不是删除文件
            // 这样后台程序可以继续写入，避免文件锁定问题
            await file.writeAsString('');
            clearedCount++;
            debugPrint('已清空日志文件: $logFile');
          } catch (e) {
            debugPrint('清空日志文件失败: $logFile, 错误: $e');
            failedFiles.add(path.basename(logFile));
          }
        }
      }

      setState(() {
        _logLines.clear();
        // 不清空 _availableLogFiles，因为文件还存在
        // 重置 LogReader 以便重新读取
        _logReader = null;
      });

      if (mounted) {
        if (failedFiles.isEmpty) {
          showTopToast(context, '已清空 $clearedCount 个日志文件', isSuccess: true);
        } else {
          showTopToast(
            context,
            '已清空 $clearedCount 个文件，${failedFiles.length} 个失败: ${failedFiles.join(", ")}',
            isSuccess: false,
          );
        }
      }

      // 清空后重新初始化，以便显示空日志或新生成的日志
      await _initializeLogReader();
    } catch (e) {
      debugPrint('清空日志失败: $e');
      if (mounted) {
        showTopToast(context, '清空失败: $e', isSuccess: false);
      }
    }
  }
}

class LogReader {
  final File logFile;
  final int batchSize;
  bool _hasReadAll = false;
  static const int _maxLinesToRead = 2000; // 只读取最后2000行

  LogReader(this.logFile, {this.batchSize = 100});

  Future<List<String>> readNextBatch() async {
    final lines = <String>[];

    // 检查文件是否存在
    if (!await logFile.exists()) {
      debugPrint('日志文件不存在: ${logFile.path}');
      return lines;
    }

    // 如果已经读取完毕，直接返回空列表
    if (_hasReadAll) {
      return lines;
    }

    try {
      // 读取整个文件
      final content = await logFile.readAsString();
      final allLines = content.split('\n');

      // 只保留最后N行（性能优化）
      final startIndex = allLines.length > _maxLinesToRead 
          ? allLines.length - _maxLinesToRead 
          : 0;

      // 返回最后的非空行
      for (var i = startIndex; i < allLines.length; i++) {
        final line = allLines[i].trim();
        if (line.isNotEmpty) {
          lines.add(allLines[i]);
        }
      }

      _hasReadAll = true;
      
      if (startIndex > 0) {
        debugPrint('读取日志文件: ${logFile.path}, 跳过前 $startIndex 行，加载最后 ${lines.length} 行');
      } else {
        debugPrint('读取日志文件: ${logFile.path}, 共 ${lines.length} 行');
      }
    } catch (e) {
      debugPrint('读取日志文件失败: ${logFile.path} $e');
    }

    return lines;
  }
}
