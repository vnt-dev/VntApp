import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class LogPage extends StatefulWidget {
  @override
  _LogPageState createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final LogReader _logReader = LogReader(File('logs/vnt-core.log'));
  final ScrollController _scrollController = ScrollController();
  final List<String> _logLines = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMoreLogs();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final newLines = await _logReader.readNextBatch();
    setState(() {
      _logLines.addAll(newLines);
      _isLoading = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent &&
        !_isLoading) {
      _loadMoreLogs();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.download),
        //     onPressed: _exportLogs,
        //   ),
        // ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _buildLogView(),
      ),
    );
  }

  Widget _buildLogView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _logLines.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _logLines.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final line = _logLines[index];
        return SelectableText(
          line,
          style: TextStyle(
            color: line.contains('ERROR') ? Colors.red : Colors.black,
          ),
        );
      },
    );
  }

  void _exportLogs() {
    // 实现日志导出功能
  }
}

class LogReader {
  final File logFile;
  final int batchSize;
  int _currentOffset = 0;

  LogReader(this.logFile, {this.batchSize = 100});

  Future<List<String>> readNextBatch() async {
    final lines = <String>[];
    var fileLength = await logFile.length();
    if (_currentOffset >= fileLength) {
      // 如果偏移量超过文件长度，说明已经读取完毕
      return lines;
    }
    int bytesRead = 0;

    try {
      final fileStream = logFile.openRead(_currentOffset);
      await for (var line in fileStream
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())) {
        lines.add(line);

        bytesRead += utf8.encode(line).length + 1; // 是为了换行符
        if (lines.length >= batchSize) {
          break;
        }
      }
    } catch (e) {
      debugPrint('dart catch e:  $fileLength  $_currentOffset $e');
    }

    _currentOffset += bytesRead; // 更新偏移量
    return lines;
  }
}
