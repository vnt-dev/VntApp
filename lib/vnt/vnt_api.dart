import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network_config.dart';
import '../src/rust/api/vnt_api.dart';
import '../utils/ip_utils.dart';
import 'package:synchronized/synchronized.dart';

class VntApiUtils {
  static VntApi? vntApi;
  static bool first = true;
  static VntConfig? vntConfig;
  static NetworkConfig? networkConfig;
  static Queue<ConnectLogEntry> logQueue = Queue();
  static final lock = Lock();
  static NetworkConfig? getNetConfig() {
    return networkConfig;
  }

  static Future<void> open(NetworkConfig config, SendPort uiCall) async {
    addLog(ConnectLogEntry(message: '连接vnts ${config.serverAddress}'));
    networkConfig = config;
    vntConfig = VntConfig(
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
      tcp: config.isTcp,
      ip: config.virtualIPv4.isEmpty ? null : config.virtualIPv4,
      noProxy: config.noInIpProxy,
      serverEncrypt: config.isServerEncrypted,
      parallel: 0,
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
    );

    var vntCall = VntApiCallback(successFn: () {
      if (first) {
        uiCall.send('success');
        //进入详情页
      }
      first = false;
    }, createTunFn: (info) {
      lock.synchronized(() {
        addLog(
            ConnectLogEntry(message: '创建虚拟网卡 ${info.name}  ${info.version}'));
      });
      // uiCall.send(info);
    }, connectFn: (info) {
      lock.synchronized(() {
        addLog(ConnectLogEntry(message: '第${info.count}次连接目标 ${info.address}'));
      });
      uiCall.send(info);
    }, handshakeFn: (info) {
      addLog(ConnectLogEntry(
          message: '握手成功 vnts版本 ${info.version} vnts指纹 ${info.finger}'));
      // uiCall.send(info);
      return true;
    }, registerFn: (info) {
      addLog(ConnectLogEntry(
          message:
              '注册成功 虚拟IP ${info.virtualIp}  ${info.virtualGateway}/${info.virtualNetmask}'));
      // uiCall.send(info);
      return true;
    }, generateTunFn: (info) async {
      //创建vpn
      try {
        const method_channel = MethodChannel('top.wherewego.vnt/vpn');
        int fd = await method_channel.invokeMethod(
            'startVpn', rustDeviceConfigToMap(info));
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
      addLog(ConnectLogEntry(
          message: '服务异常 类型 ${info.code.name} ${info.msg ?? ''}'));
      uiCall.send(info);
    }, stopFn: () {
      uiCall.send('stop');
    });
    vntApi = await vntInit(vntConfig: vntConfig!, call: vntCall);
  }

  static Map<String, dynamic> rustDeviceConfigToMap(
      RustDeviceConfig deviceConfig) {
    return {
      'virtualIp': deviceConfig.virtualIp,
      'virtualNetmask': deviceConfig.virtualNetmask,
      'virtualGateway': deviceConfig.virtualGateway,
      'mtu': vntConfig?.mtu ?? 1400,
      'externalRoute': deviceConfig.externalRoute.map((v) {
        return {
          'destination': v.$1,
          'netmask': v.$2,
        };
      }).toList(),
    };
  }

  static close() async {
    if (vntApi == null) {
      return;
    }
    await vntApi?.stop();
    first = true;
    vntApi = null;
    addLog(ConnectLogEntry(message: '关闭vnt连接'));
  }

  static Map<String, dynamic> currentDevice() {
    if (vntApi == null) {
      return {};
    }
    var currentDevice = vntApi!.currentDevice();

    var natInfo = vntApi!.natInfo();
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

  static List<RustPeerClientInfo> peerDeviceList() {
    if (vntApi == null) {
      return List.empty();
    }
    return vntApi!.deviceList();
  }

  static List<(String, List<RustRoute>)> routeList() {
    if (vntApi == null) {
      return List.empty();
    }
    return vntApi!.routeList();
  }

  static RustRoute? route(String ip) {
    if (vntApi == null) {
      return null;
    }
    return vntApi!.route(ip: ip);
  }

  static RustNatInfo? peerNatInfo(String ip) {
    if (vntApi == null) {
      return null;
    }
    return vntApi!.peerNatInfo(ip: ip);
  }

  static String downStream() {
    if (vntApi == null) {
      return '';
    }
    return vntApi!.downStream();
  }

  static String upStream() {
    if (vntApi == null) {
      return '';
    }
    return vntApi!.upStream();
  }

  static void addLog(ConnectLogEntry log) {
    logQueue.addFirst(log);
    if (logQueue.length > 100) {
      logQueue.removeLast();
    }
  }
}

class ConnectLogEntry {
  final DateTime date;
  final String message;

  ConnectLogEntry({DateTime? date, required this.message})
      : date = date ?? DateTime.now();
}
