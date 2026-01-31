import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class FileSaver {
  static const MethodChannel _channel = MethodChannel('top.wherewego.vnt/file');

  /// 保存文件到用户选择的位置
  ///
  /// [sourceFilePath] 源文件路径
  /// [fileName] 建议的文件名
  /// [mimeType] MIME类型，例如 'application/json' 或 'text/plain'
  ///
  /// 返回保存的URI，如果用户取消则返回null
  static Future<String?> saveFile({
    required String sourceFilePath,
    required String fileName,
    String? mimeType,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('This method is only supported on Android');
    }

    try {
      final result = await _channel.invokeMethod('saveFile', {
        'filePath': sourceFilePath,
        'fileName': fileName,
        'mimeType': mimeType,
      });
      return result as String?;
    } on PlatformException catch (e) {
      throw Exception('Failed to save file: ${e.message}');
    }
  }

  /// 导出文件的便捷方法
  ///
  /// 先将内容写入临时文件，然后调用系统文件选择器保存
  static Future<bool> exportFile({
    required String content,
    required String fileName,
    String? mimeType,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('This method is only supported on Android');
    }

    try {
      // 写入临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(content);

      // 调用系统文件选择器
      final result = await saveFile(
        sourceFilePath: tempFile.path,
        fileName: fileName,
        mimeType: mimeType,
      );

      // 清理临时文件
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return result != null;
    } catch (e) {
      rethrow;
    }
  }

  /// 复制文件到用户选择的位置
  static Future<bool> copyFile({
    required String sourceFilePath,
    required String fileName,
    String? mimeType,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('This method is only supported on Android');
    }

    try {
      final result = await saveFile(
        sourceFilePath: sourceFilePath,
        fileName: fileName,
        mimeType: mimeType,
      );
      return result != null;
    } catch (e) {
      rethrow;
    }
  }
}
