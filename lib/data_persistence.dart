import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network_config.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'dart:io';

class DataPersistence {
  static const String dataKey = 'data-key';
  static const String dataKeyForNative = 'data-key-native'; // 供 Android 原生代码读取的 JSON 格式
  static const String vntUniqueIdKey = 'vnt-unique-id-key';

  Future<void> saveData(List<NetworkConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonDataList =
        configs.map((config) => jsonEncode(config.toJson())).toList();
    await prefs.setStringList(dataKey, jsonDataList);

    // 额外存储一个 JSON 数组字符串，供 Android 原生代码（如磁贴）读取
    await prefs.setString(dataKeyForNative, jsonEncode(jsonDataList));
  }

  Future<List<NetworkConfig>> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? jsonDataList = prefs.getStringList(dataKey);

    if (jsonDataList != null) {
      return jsonDataList
          .map((jsonData) => NetworkConfig.fromJson(jsonDecode(jsonData)))
          .toList();
    } else {
      return [];
    }
  }

  Future<String> loadUniqueId() async {
    final prefs = await SharedPreferences.getInstance();
    String? uniqueId = prefs.getString(vntUniqueIdKey);
    if (uniqueId == null || uniqueId.isEmpty) {
      uniqueId = const Uuid().v4().toString();
      prefs.setString(vntUniqueIdKey, uniqueId);
    }
    return uniqueId;
  }

  Future<Size?> loadWindowSize() async {
    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getDouble('window-width');
    final height = prefs.getDouble('window-height');
    if (width != null && height != null) {
      return Size(width, height);
    }
    return const Size(600, 700);
  }

  Future<void> saveWindowSize(Size size) async {
    if (size.width == 600 && size.height == 700) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('window-width', size.width);
    await prefs.setDouble('window-height', size.height);
  }

  Future<bool?> loadCloseApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is-close-app');
  }

  Future<void> saveCloseApp(bool isClose) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is-close-app', isClose);
  }

  Future<bool> loadAlwaysOnTop() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is-always-on-top') ?? false;
  }

  Future<void> saveAlwaysOnTop(bool alwaysOnTop) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is-always-on-top', alwaysOnTop);
  }

  Future<bool?> loadAutoStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is-auto-start');
  }

  Future<void> saveAutoStart(bool autoStart) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is-auto-start', autoStart);
  }

  Future<bool?> loadAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is-auto-connect');
  }

  Future<void> saveAutoConnect(bool autoConnect) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is-auto-connect', autoConnect);
  }

  Future<String?> loadDefaultKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('default-key');
  }

  Future<void> saveDefaultKey(String defaultKey) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('default-key', defaultKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
  }

  // 主题模式持久化
  Future<ThemeMode?> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('theme-mode');
    if (index != null && index >= 0 && index < ThemeMode.values.length) {
      return ThemeMode.values[index];
    }
    return null;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme-mode', mode.index);
  }

  // 自定义主题颜色持久化
  /// 保存自定义主题颜色（保存为 ARGB 整数值）
  Future<void> saveCustomThemeColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('custom-theme-color', color.value);
  }

  /// 加载自定义主题颜色（返回 null 表示使用默认颜色）
  Future<Color?> loadCustomThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('custom-theme-color');
    if (colorValue != null) {
      return Color(colorValue);
    }
    return null;
  }

  // 导出所有配置到文件
  Future<void> exportAllConfigs(String filePath) async {
    try {
      final configs = await loadData();
      final jsonData = {
        'version': '1.0',
        'export_time': DateTime.now().toIso8601String(),
        'configs': configs.map((c) => c.toJson()).toList(),
      };
      final file = File(filePath);
      // 确保父目录存在
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await file.writeAsString(JsonEncoder.withIndent('  ').convert(jsonData));
      debugPrint('配置导出成功: $filePath');
    } catch (e) {
      debugPrint('配置导出失败: $e');
      rethrow;
    }
  }

  // 从文件导入所有配置
  Future<void> importAllConfigs(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }
      final content = await file.readAsString();
      final jsonData = jsonDecode(content);
      final configs = (jsonData['configs'] as List)
          .map((c) => NetworkConfig.fromJson(c))
          .toList();
      await saveData(configs);
      debugPrint('配置导入成功: ${configs.length}个配置');
    } catch (e) {
      debugPrint('配置导入失败: $e');
      rethrow;
    }
  }

  // 导出单个配置到文件
  Future<void> exportSingleConfig(String filePath, NetworkConfig config) async {
    try {
      final jsonData = {
        'version': '1.0',
        'export_time': DateTime.now().toIso8601String(),
        'config': config.toJson(),
      };
      final file = File(filePath);
      // 确保父目录存在
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await file.writeAsString(JsonEncoder.withIndent('  ').convert(jsonData));
      debugPrint('单个配置导出成功: $filePath');
    } catch (e) {
      debugPrint('单个配置导出失败: $e');
      rethrow;
    }
  }

  // 从文件导入单个配置
  Future<void> importSingleConfig(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }
      final content = await file.readAsString();
      final jsonData = jsonDecode(content);
      final config = NetworkConfig.fromJson(jsonData['config']);
      final configs = await loadData();
      configs.add(config);
      await saveData(configs);
      debugPrint('单个配置导入成功: ${config.configName}');
    } catch (e) {
      debugPrint('单个配置导入失败: $e');
      rethrow;
    }
  }
}
