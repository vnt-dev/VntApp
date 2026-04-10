import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// Windows 平台使用程序目录下的 config.json
/// 其他平台使用 shared_preferences
class ConfigManager {
  static final ConfigManager _instance = ConfigManager._internal();
  factory ConfigManager() => _instance;
  ConfigManager._internal();

  File? _configFile;
  Map<String, dynamic> _cache = {};

  /// 初始化配置文件路径
  Future<void> init() async {
    if (Platform.isWindows) {
      // Windows: 使用程序当前目录/config/config.json
      final exePath = Platform.resolvedExecutable;
      final exeDir = path.dirname(exePath);
      final configDir = Directory(path.join(exeDir, 'config'));
      
      // 确保 config 目录存在
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }
      
      _configFile = File(path.join(configDir.path, 'config.json'));
      
      // 加载现有配置
      if (await _configFile!.exists()) {
        try {
          final content = await _configFile!.readAsString();
          _cache = json.decode(content) as Map<String, dynamic>;
        } catch (e) {
          print('加载配置文件失败: $e');
          _cache = {};
        }
      }
    }
  }

  /// 保存配置
  Future<void> _save() async {
    if (_configFile != null) {
      try {
        await _configFile!.writeAsString(
          const JsonEncoder.withIndent('  ').convert(_cache),
        );
      } catch (e) {
        print('保存配置文件失败: $e');
      }
    }
  }

  /// 设置字符串值
  Future<void> setString(String key, String value) async {
    _cache[key] = value;
    await _save();
  }

  /// 获取字符串值
  String? getString(String key) {
    return _cache[key] as String?;
  }

  /// 设置布尔值
  Future<void> setBool(String key, bool value) async {
    _cache[key] = value;
    await _save();
  }

  /// 获取布尔值
  bool? getBool(String key) {
    return _cache[key] as bool?;
  }

  /// 设置整数值
  Future<void> setInt(String key, int value) async {
    _cache[key] = value;
    await _save();
  }

  /// 获取整数值
  int? getInt(String key) {
    return _cache[key] as int?;
  }

  /// 获取双精度浮点数值
  double? getDouble(String key) {
    final value = _cache[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }

  /// 设置双精度浮点数值
  Future<void> setDouble(String key, double value) async {
    _cache[key] = value;
    await _save();
  }

  /// 设置字符串列表
  Future<void> setStringList(String key, List<String> value) async {
    _cache[key] = value;
    await _save();
  }

  /// 获取字符串列表
  List<String>? getStringList(String key) {
    final value = _cache[key];
    if (value is List) {
      return value.cast<String>();
    }
    return null;
  }

  /// 删除键
  Future<void> remove(String key) async {
    _cache.remove(key);
    await _save();
  }

  /// 获取所有键
  Set<String> getKeys() {
    return _cache.keys.toSet();
  }

  /// 清空所有配置
  Future<void> clear() async {
    _cache.clear();
    await _save();
  }
}
