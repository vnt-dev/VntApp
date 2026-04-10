import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vnt_app/network_config.dart';
import 'package:vnt_app/src/rust/api/vnt_api.dart';
import 'package:vnt_app/utils/ip_utils.dart';

/// macOS 权限管理器
class MacOSPrivilegeManager {
  /// 检查当前进程是否有 root 权限
  static Future<bool> hasRootPrivilege() async {
    if (!Platform.isMacOS) return true;

    try {
      // 尝试执行一个需要 root 权限���命令来检测
      final result = await Process.run('id', ['-u']);
      final uid = int.tryParse(result.stdout.toString().trim()) ?? -1;
      return uid == 0; // uid 0 表示 root
    } catch (e) {
      return false;
    }
  }

  /// 使用 osascript 以管理员权限重新启动 app
  /// [showPrompt] 是否显示友好的提示信息
  static Future<bool> restartWithPrivilege({bool showPrompt = false}) async {
    if (!Platform.isMacOS) return false;

    try {
      // 获取当前 app 的路径
      final executablePath = Platform.resolvedExecutable;
      // 获取 .app bundle 的路径
      // 例如：/Applications/vnt_app.app/Contents/MacOS/vnt_app
      // 需要提取到：/Applications/vnt_app.app
      final appBundlePath = _getAppBundlePath(executablePath);

      if (appBundlePath == null) {
        return false;
      }


      // 构建 AppleScript 脚本
      // 如果需要显示提示，添加友好的提示信息
      String script;
      if (showPrompt) {
        script = '''
tell application "System Events"
    display dialog "VNT 需要管理员权限来创建虚拟网络设备。\\n\\n授权后将自动重启应用。" buttons {"取消", "授权"} default button "授权" with icon caution
    if button returned of result is "授权" then
        do shell script "\\"$executablePath\\" > /dev/null 2>&1 &" with administrator privileges
    end if
end tell
''';
      } else {
        // 直接请求权限，不显示额外提示
        script = 'do shell script "\\"$executablePath\\" > /dev/null 2>&1 &" with administrator privileges';
      }

      final result = await Process.run('osascript', ['-e', script]);

      if (result.exitCode == 0) {
        // 延迟退出当前 app，给新 app 启动的时间
        Future.delayed(const Duration(milliseconds: 500), () {
          exit(0);
        });
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// 从可执行文件路径提取 .app bundle 路径
  static String? _getAppBundlePath(String executablePath) {
    // 例如：/Applications/vnt_app.app/Contents/MacOS/vnt_app
    // 需要提取：/Applications/vnt_app.app

    final contentsIndex = executablePath.indexOf('/Contents/MacOS/');
    if (contentsIndex == -1) {
      return null;
    }

    return executablePath.substring(0, contentsIndex) + '.app';
  }

  /// 启动时检查并请求权限（用于 app 启动时调用）
  /// 返回 true 表示需要重启（已经开始重启流程）
  /// 返回 false 表示不需要重启（已有权限或不是 macOS）
  static Future<bool> checkAndRequestPrivilegeOnStartup() async {
    if (!Platform.isMacOS) return false;

    final hasPrivilege = await hasRootPrivilege();
    if (hasPrivilege) {
      return false;
    }

    // 启动时直接请求权限，不显示额外提示（系统会显示标准的密码框）
    return await restartWithPrivilege(showPrompt: false);
  }

  /// 连接时检查权限（用于连接 VPN 时调用，作为兜底检查）
  /// 返回 true 表示需要重启（已经开始重启流程）
  /// 返回 false 表示不需要重启（已有权限或不是 macOS）
  static Future<bool> checkAndRequestPrivilege() async {
    if (!Platform.isMacOS) return false;

    final hasPrivilege = await hasRootPrivilege();
    if (hasPrivilege) {
      print('✓ 已有管理员权限');
      return false;
    }

    return await restartWithPrivilege(showPrompt: false);
  }
}

final VntManager vntManager = VntManager();

class VntBox {
  final VntApi vntApi;
  final VntConfig vntConfig;
  final NetworkConfig networkConfig;
  VntBox({
    required this.vntApi,
    required this.vntConfig,
    required this.networkConfig,
  });
  static Future<VntBox> create(NetworkConfig config, SendPort uiCall) async {
    var vntConfig = VntConfig(
        tap: false,
        token: config.token,
        deviceId: config.deviceID,
        name: config.deviceName,
        serverAddressStr: config.serverAddress,
        nameServers: config.dns,
        stunServer: config.stunServers,
        inIps: config.inIps.map((v) => IpUtils.parseInIpString(v)).toList(),
        outIps: config.outIps.map((v) => IpUtils.parseOutIpString(v)).toList(),
        password: config.groupPassword.isEmpty ? null : config.groupPassword,
        mtu: config.mtu == 0 ? null : config.mtu,
        ip: config.virtualIPv4.isEmpty ? null : config.virtualIPv4,
        noProxy: config.noInIpProxy,
        serverEncrypt: config.isServerEncrypted,
        cipherModel: config.encryptionAlgorithm,
        finger: config.dataFingerprintVerification,
        punchModel: config.punchModel,
        ports: config.ports.isEmpty ? null : Uint16List.fromList(config.ports),
        firstLatency: config.firstLatency,
        deviceName: config.virtualNetworkCardName.isEmpty
            ? null
            : config.virtualNetworkCardName,
        useChannelType: config.useChannelType,
        packetLossRate: config.simulatedPacketLossRate == 0
            ? null
            : config.simulatedPacketLossRate,
        packetDelay: config.simulatedLatency,
        portMappingList: config.portMappings,
        compressor: config.compressor.isEmpty ? 'none' : config.compressor,
        allowWireGuard: config.allowWg,
        localDev: config.localDev.isEmpty ? null : config.localDev,
        disableRelay: config.disableRelay);
    var vntCall = VntApiCallback(successFn: () {
      uiCall.send('success');
    }, createTunFn: (info) {
      // uiCall.send(info);
    }, connectFn: (info) {
      uiCall.send(info);
    }, handshakeFn: (info) {
      // uiCall.send(info);
      return true;
    }, registerFn: (info) {
      // uiCall.send(info);
      return true;
    }, generateTunFn: (info) async {
      //创建vpn
      try {
        int fd = await VntAppCall.startVpn(info, vntConfig.mtu ?? 1400);
        return fd;
      } catch (e) {
        debugPrint('创建vpn异常 $e');
        uiCall.send('stop');
        return 0;
      }
    }, peerClientListFn: (info) {
      // uiCall.send(info);
    }, errorFn: (info) {
      debugPrint('服务异常 类型 ${info.code.name} ${info.msg ?? ''}');
      uiCall.send(info);
    }, stopFn: () {
      uiCall.send('stop');
    });
    var vntApi = await vntInit(vntConfig: vntConfig, call: vntCall);

    return VntBox(vntApi: vntApi, vntConfig: vntConfig, networkConfig: config);
  }

  Future<void> close() async {
    vntApi.stop();
    if (Platform.isAndroid) {
      await VntAppCall.stopVpn();
    }
  }

  bool isClosed() {
    return vntApi.isStopped();
  }

  NetworkConfig? getNetConfig() {
    return networkConfig;
  }

  Map<String, dynamic> currentDevice() {
    var currentDevice = vntApi.currentDevice();

    var natInfo = vntApi.natInfo();
    return {
      'virtualIp': currentDevice.virtualIp,
      'virtualNetmask': currentDevice.virtualNetmask,
      'virtualGateway': currentDevice.virtualGateway,
      'virtualNetwork': currentDevice.virtualNetwork,
      'broadcastIp': currentDevice.broadcastIp,
      'connectServer': currentDevice.connectServer,
      'status': currentDevice.status,
      'publicIps': natInfo.publicIps,
      'natType': natInfo.natType,
      'localIpv4': natInfo.localIpv4,
      'ipv6': natInfo.ipv6,
    };
  }

  List<RustPeerClientInfo> peerDeviceList() {
    return vntApi.deviceList();
  }

  List<(String, List<RustRoute>)> routeList() {
    return vntApi.routeList();
  }

  RustRoute? route(String ip) {
    return vntApi.route(ip: ip);
  }

  RustNatInfo? peerNatInfo(String ip) {
    return vntApi.peerNatInfo(ip: ip);
  }

  String downStream() {
    return vntApi.downStream();
  }

  String upStream() {
    return vntApi.upStream();
  }
}

class VntManager {
  HashMap<String, VntBox> map = HashMap();
  bool connecting = false;
  // 记录主动断开连接的配置key，避免显示"服务已停止"提示
  final Set<String> _manualDisconnecting = {};

  // 判断设备是否在线 - 不区分大小写，去掉空格和换行
  bool _isDeviceOnline(String status) {
    return status.trim().toLowerCase() == 'online';
  }

  /// 标记为主动断开连接
  void markManualDisconnect(String key) {
    _manualDisconnecting.add(key);
  }

  /// 检查是否为主动断开连接
  bool isManualDisconnect(String key) {
    return _manualDisconnecting.contains(key);
  }

  /// 清除主动断开标记
  void clearManualDisconnect(String key) {
    _manualDisconnecting.remove(key);
  }

  Future<VntBox> create(NetworkConfig config, SendPort uiCall) async {
    var key = config.itemKey;
    if (map.containsKey(key)) {
      return map[key]!;
    }
    try {
      connecting = true;

      // macOS 权限检查：如果没有权限，请求重新启动
      if (Platform.isMacOS) {
        final needsRestart = await MacOSPrivilegeManager.checkAndRequestPrivilege();
        if (needsRestart) {
          // 已经开始重启流程，抛出异常通知 UI
          throw Exception('需要管理员权限，app 正在重新启动...');
        }
      }

      var vntBox = await VntBox.create(config, uiCall);
      map[key] = vntBox;
      return vntBox;
    } finally {
      connecting = false;
    }
  }

  VntBox? get(String key) {
    var vntBox = map[key];
    if (vntBox != null && !vntBox.isClosed()) {
      return vntBox;
    }
    return null;
  }

  Future<void> remove(String key) async {
    var vnt = map.remove(key);
    if (vnt != null) {
      await vnt.close();
    }
    // 更新磁贴和小组件状态
    if (Platform.isAndroid) {
      VntAppCall.updateWidgetAndTile(hasConnection());
    }
  }

  Future<void> removeAll() async {
    for (var element in map.entries) {
      await element.value.close();
    }
    map.clear();
    // 更新磁贴和小组件状态
    if (Platform.isAndroid) {
      VntAppCall.updateWidgetAndTile(false);
    }
  }

  bool hasConnectionItem(String key) {
    var vntBox = map[key];
    return vntBox != null && !vntBox.isClosed();
  }

  bool isConnecting() {
    return connecting;
  }

  bool hasConnection() {
    if (map.isEmpty) {
      return false;
    }
    map.removeWhere((key, val) => val.isClosed());
    return map.isNotEmpty;
  }

  int size() {
    map.removeWhere((key, val) => val.isClosed());
    return map.length;
  }

  bool supportMultiple() {
    return !Platform.isAndroid;
  }

  VntBox? getOne() {
    if (map.isEmpty) {
      return null;
    }
    return map.entries.first.value;
  }
}

typedef StartCallback = Future<void> Function(String? configKey);

class VntAppCall {
  static MethodChannel channel = const MethodChannel('top.wherewego.vnt/vpn');
  static StartCallback startCall = (String? configKey) async {};
  static void setStartCall(StartCallback startCall) {
    VntAppCall.startCall = startCall;
  }

  static void init() {
    channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'stopVnt':
          await vntManager.removeAll();
          break;
        case 'startVnt':
          // 获取可选的配置key参数
          String? configKey = call.arguments as String?;
          await startCall(configKey);
          return vntManager.hasConnection();
        case 'isRunning':
          debugPrint("isRunning ${vntManager.hasConnection()}");
          return vntManager.hasConnection();
        case 'getDeviceInfo':
          // 获取设备信息：在线数量、离线数量、配置名称
          return _getDeviceInfo();
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: 'methodName is not implemented',
          );
      }
    });
  }

  /// 获取设备信息
  static Map<String, dynamic> _getDeviceInfo() {
    var vntBox = vntManager.getOne();
    if (vntBox == null) {
      return {
        'isConnected': false,
        'configName': '',
        'onlineCount': 0,
        'offlineCount': 0,
      };
    }

    var deviceList = vntBox.peerDeviceList();
    int onlineCount = 0;
    int offlineCount = 0;

    for (var device in deviceList) {
      if (vntManager._isDeviceOnline(device.status)) {
        onlineCount++;
      } else {
        offlineCount++;
      }
    }

    var networkConfig = vntBox.getNetConfig();
    String configName = networkConfig?.configName ?? '未知配置';

    return {
      'isConnected': true,
      'configName': configName,
      'onlineCount': onlineCount,
      'offlineCount': offlineCount,
    };
  }

  static Future<int> startVpn(RustDeviceConfig info, int mtu) async {
    return await VntAppCall.channel
        .invokeMethod('startVpn', rustDeviceConfigToMap(info, mtu));
  }

  static Future<void> moveTaskToBack() async {
    return await VntAppCall.channel.invokeMethod('moveTaskToBack');
  }

  static Future<bool> isTileStart() async {
    return await VntAppCall.channel.invokeMethod('isTileStart');
  }

  static Future<String?> getTileConfigKey() async {
    return await VntAppCall.channel.invokeMethod('getTileConfigKey');
  }

  static Future<void> stopVpn() async {
    return await VntAppCall.channel.invokeMethod('stopVpn');
  }

  /// 更新磁贴和小组件状态
  /// @param isConnected 是否已连接
  static Future<void> updateWidgetAndTile(bool isConnected) async {
    try {
      await VntAppCall.channel.invokeMethod('updateWidgetAndTile', {
        'isConnected': isConnected,
      });
      debugPrint('已通知更新磁贴和小组件状态: isConnected=$isConnected');
    } catch (e) {
      debugPrint('更新磁贴和小组件状态失败: $e');
    }
  }

  static Map<String, dynamic> rustDeviceConfigToMap(
      RustDeviceConfig deviceConfig, int mtu) {
    return {
      'virtualIp': deviceConfig.virtualIp,
      'virtualNetmask': deviceConfig.virtualNetmask,
      'virtualGateway': deviceConfig.virtualGateway,
      'mtu': mtu,
      'externalRoute': deviceConfig.externalRoute.map((v) {
        return {
          'destination': v.$1,
          'netmask': v.$2,
        };
      }).toList(),
    };
  }
}
