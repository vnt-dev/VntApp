import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 日志路径工具类
/// 统一管理日志目录路径，确保核心写入和页面读取使用相同的路径
class LogUtils {
  /// 获取日���目录路径
  ///
  /// 不同平台的日志目录：
  /// - Android/iOS: 应用文档目录/logs
  /// - macOS: /tmp/vnt_app/logs (避免提权后路径变化)
  /// - Windows/Linux: 当前目录/logs
  static Future<String> getLogDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      // 移动平台：使用应用文档目录
      final appDocDir = await getApplicationDocumentsDirectory();
      return '${appDocDir.path}/logs';
    } else if (Platform.isMacOS) {
      // macOS：使用 /tmp 目录，避免提权后路径变化
      // /tmp 目录所有用户都能访问，不受提权影响
      return '/tmp/vnt_app/logs';
    } else {
      // Windows/Linux 桌面平台：使用当前目录
      return 'logs';
    }
  }
}
