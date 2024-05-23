import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network_config.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

class DataPersistence {
  static const String dataKey = 'data-key';
  static const String vntUniqueIdKey = 'vnt-unique-id-key';

  Future<void> saveData(List<NetworkConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonDataList =
        configs.map((config) => jsonEncode(config.toJson())).toList();
    await prefs.setStringList(dataKey, jsonDataList);
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

  Future<bool?> loadAutoStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is-auto-start');
  }

  Future<void> saveAutoStart(bool autoStart) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is-auto-start', autoStart);
  }

  Future<String?> loadAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auto-connect-key');
  }

  Future<void> saveAutoConnect(String autoConnect) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('auto-connect-key', autoConnect);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
  }
}
