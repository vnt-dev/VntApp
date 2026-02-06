import 'dart:io';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vnt_app/data_persistence.dart';
import 'package:vnt_app/vnt/vnt_manager.dart';
import 'package:vnt_app/network_config.dart';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:vnt_app/src/rust/api/vnt_api.dart';

/// 系统托盘管理器 - 提供全局访问的托盘更新功能
class SystemTrayManager {
  static final SystemTrayManager _instance = SystemTrayManager._internal();
  factory SystemTrayManager() => _instance;
  SystemTrayManager._internal();

  // 使用外部传入的 SystemTray 实例
  SystemTray? _systemTray;

  /// 初始化系统托盘实例
  void initialize(SystemTray systemTray) {
    _systemTray = systemTray;
  }

  SystemTray get systemTray {
    if (_systemTray == null) {
      throw Exception('SystemTrayManager 未初始化，请先调用 initialize()');
    }
    return _systemTray!;
  }

  /// 更新系统托盘菜单
  /// [optimisticState] 乐观更新的连接状态，如果为null则使用实际状态
  Future<void> updateMenu({bool? optimisticState}) async {
    // 只在桌面平台执行
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return;
    }

    final dataPersistence = DataPersistence();
    final configs = await dataPersistence.loadData();
    // 使用乐观状态或实际状态
    final hasConnection = optimisticState ?? vntManager.hasConnection();

    final Menu menu = Menu();
    final List<MenuItemBase> menuItems = [];

    // 连接/断开连���
    if (hasConnection) {
      menuItems.add(MenuItemLabel(
        label: '断开连接',
        onClicked: (menuItem) async {
          // 乐观更新：先更新UI为未连接状态
          await updateMenu(optimisticState: false);
          await updateTooltip(optimisticState: false);

          // 执行断开操作
          await vntManager.removeAll();

          // 根据实际状态更新UI
          await updateMenu();
          await updateTooltip();
        },
      ));
    } else {
      menuItems.add(MenuItemLabel(
        label: '连接默认配置',
        onClicked: (menuItem) async {
          final defaultKey = await dataPersistence.loadDefaultKey();
          if (defaultKey != null && defaultKey.isNotEmpty) {
            final config = configs.where((c) => c.itemKey == defaultKey).firstOrNull;
            if (config != null) {
              await _connectConfig(config);
            }
          }
        },
      ));
    }

    menuItems.add(MenuSeparator());

    // 配置列表子菜单
    if (configs.isNotEmpty) {
      final List<MenuItemBase> configMenuItems = [];
      for (final config in configs) {
        configMenuItems.add(MenuItemLabel(
          label: config.configName,
          onClicked: (menuItem) async {
            // 如果已有连接，先断开
            if (vntManager.hasConnection()) {
              // 乐观更新：先更新UI为未连接状态
              await updateMenu(optimisticState: false);
              await updateTooltip(optimisticState: false);

              await vntManager.removeAll();
              await Future.delayed(const Duration(milliseconds: 500));
            }
            await _connectConfig(config);
          },
        ));
      }

      menuItems.add(SubMenu(
        label: '配置列表',
        children: configMenuItems,
      ));
      menuItems.add(MenuSeparator());
    }

    // 显示主界面
    menuItems.add(MenuItemLabel(
      label: '显示主界面',
      onClicked: (menuItem) {
        windowManager.show();
      },
    ));

    // 隐藏窗口
    menuItems.add(MenuItemLabel(
      label: '隐藏窗口',
      onClicked: (menuItem) {
        windowManager.hide();
      },
    ));

    menuItems.add(MenuSeparator());

    // 退出
    menuItems.add(MenuItemLabel(
      label: '退出',
      onClicked: (menuItem) async {
        if (vntManager.hasConnection()) {
          await vntManager.removeAll();
        }
        windowManager.setPreventClose(false);
        // 使用exit退出应用
        exit(0);
      },
    ));

    menu.buildFrom(menuItems);
    await systemTray.setContextMenu(menu);
  }

  /// 更新系统托盘tooltip
  /// [optimisticState] 乐观更新的连接状态，如果为null则使用实际状态
  Future<void> updateTooltip({bool? optimisticState}) async {
    // 只在桌面平台执行
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return;
    }

    String tooltip = "VNT - Virtual Network Tool";

    // 使用乐观状态或实际状态
    final hasConnection = optimisticState ?? vntManager.hasConnection();

    if (hasConnection) {
      // 获取第一个连接的配置
      final vntBox = vntManager.getOne();
      if (vntBox != null) {
        final config = vntBox.getNetConfig();
        if (config != null) {
          tooltip = "VNT - ${config.configName} 已连接";
        }
      }
    }

    await systemTray.setToolTip(tooltip);
  }

  /// 连接到指定配置
  Future<void> _connectConfig(NetworkConfig config) async {
    try {
      // 乐观更新：先更新UI为已连接状态
      await updateMenu(optimisticState: true);
      await updateTooltip(optimisticState: true);

      final receivePort = ReceivePort();
      bool connectionSuccessful = false;

      receivePort.listen((message) {
        if (message == 'success') {
          connectionSuccessful = true;
          // 连接成功，更新托盘
          updateMenu();
          updateTooltip();
        } else if (message == 'stop' || message is Map) {
          // 连接失败或停止，恢复UI状态
          if (!connectionSuccessful) {
            updateMenu();
            updateTooltip();
          }
        }
      });

      await vntManager.create(config, receivePort.sendPort);

      // 等待一小段时间检查连接是否成功
      await Future.delayed(const Duration(milliseconds: 100));

      // 如果连接失败，恢复UI状态
      if (!vntManager.hasConnection()) {
        await updateMenu();
        await updateTooltip();
      }
    } catch (e) {
      debugPrint('连接配置失败: $e');
      // 连接失败，恢复UI状态
      await updateMenu();
      await updateTooltip();
    }
  }
}
