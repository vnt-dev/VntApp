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
    );
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
  Future<VntBox> create(NetworkConfig config, SendPort uiCall) async {
    var key = config.itemKey;
    if (map.containsKey(key)) {
      return map[key]!;
    }
    var vntBox = await VntBox.create(config, uiCall);
    map[key] = vntBox;
    return vntBox;
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
  }

  Future<void> removeAll() async {
    for (var element in map.entries) {
      await element.value.close();
    }
    map.clear();
  }

  bool hasConnectionItem(String key) {
    var vntBox = map[key];
    return vntBox != null && !vntBox.isClosed();
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

class VntAppCall {
  static MethodChannel channel = const MethodChannel('top.wherewego.vnt/vpn');
  static void init() {
    channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'stopVnt':
          await vntManager.removeAll();
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: 'methodName is not implemented',
          );
      }
    });
  }

  static Future<int> startVpn(RustDeviceConfig info, int mtu) async {
    return await VntAppCall.channel
        .invokeMethod('startVpn', rustDeviceConfigToMap(info, mtu));
  }

  static Future<void> stopVpn() async {
    return await VntAppCall.channel.invokeMethod('stopVpn');
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
