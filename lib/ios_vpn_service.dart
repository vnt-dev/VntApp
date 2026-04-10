import 'package:flutter/services.dart';
import 'dart:io';

/// iOS VPN服务
/// 通过Method Channel与iOS Network Extension通信
class IOSVPNService {
  static const platform = MethodChannel('com.vnt.app/vpn');
  
  /// 检查是否为iOS平台
  static bool get isIOS => Platform.isIOS;
  
  /// 启动VPN连接
  /// 
  /// [serverAddress] 服务器地址，格式: host:port
  /// [token] 认证令牌
  /// [deviceName] 设备名称（可选，默认使用设备名）
  /// 
  /// 返回: true表示启动成功，false表示失败
  static Future<bool> startVPN({
    required String serverAddress,
    required String token,
    String? deviceName,
  }) async {
    if (!isIOS) {
      print('[iOS VPN] Not running on iOS platform');
      return false;
    }
    
    try {
      print('[iOS VPN] Starting VPN...');
      print('[iOS VPN] Server: $serverAddress');
      
      final result = await platform.invokeMethod('startVPN', {
        'serverAddress': serverAddress,
        'token': token,
        'deviceName': deviceName ?? 'iOS Device',
      });
      
      print('[iOS VPN] Start result: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('[iOS VPN] Failed to start VPN: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('[iOS VPN] Unexpected error: $e');
      return false;
    }
  }
  
  /// 停止VPN连接
  /// 
  /// 返回: true表示停止成功，false表示失败
  static Future<bool> stopVPN() async {
    if (!isIOS) {
      print('[iOS VPN] Not running on iOS platform');
      return false;
    }
    
    try {
      print('[iOS VPN] Stopping VPN...');
      
      final result = await platform.invokeMethod('stopVPN');
      
      print('[iOS VPN] Stop result: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('[iOS VPN] Failed to stop VPN: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('[iOS VPN] Unexpected error: $e');
      return false;
    }
  }
  
  /// 获取VPN状态
  /// 
  /// 返回: 包含状态信息的Map，如果失败返回null
  /// 
  /// 返回的Map包含:
  /// - status: VPN状态码 (0=离线, 1=在线, -1=无实例)
  /// - running: 是否正在运行 (bool)
  static Future<Map<String, dynamic>?> getVPNStatus() async {
    if (!isIOS) {
      print('[iOS VPN] Not running on iOS platform');
      return null;
    }
    
    try {
      final result = await platform.invokeMethod('getVPNStatus');
      
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      print('[iOS VPN] Failed to get VPN status: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('[iOS VPN] Unexpected error: $e');
      return null;
    }
  }
  
  /// 保存VPN配置到App Group
  /// 
  /// [serverAddress] 服务器地址
  /// [token] 认证令牌
  /// 
  /// 返回: true表示保存成功，false表示失败
  static Future<bool> saveConfig({
    required String serverAddress,
    required String token,
  }) async {
    if (!isIOS) {
      print('[iOS VPN] Not running on iOS platform');
      return false;
    }
    
    try {
      print('[iOS VPN] Saving configuration...');
      
      final result = await platform.invokeMethod('saveConfig', {
        'serverAddress': serverAddress,
        'token': token,
      });
      
      print('[iOS VPN] Save result: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('[iOS VPN] Failed to save config: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('[iOS VPN] Unexpected error: $e');
      return false;
    }
  }
  
  /// 检查VPN是否在线
  /// 
  /// 返回: true表示在线，false表示离线或无法获取状态
  static Future<bool> isConnected() async {
    final status = await getVPNStatus();
    if (status == null) return false;
    
    final statusCode = status['status'] as int?;
    final running = status['running'] as bool?;
    
    return statusCode == 1 && running == true;
  }
  
  /// 获取VPN状态描述
  /// 
  /// 返回: 状态描述字符串
  static Future<String> getStatusDescription() async {
    final status = await getVPNStatus();
    if (status == null) return 'Unknown';
    
    final statusCode = status['status'] as int?;
    final running = status['running'] as bool?;
    
    if (running != true) {
      return 'Stopped';
    }
    
    switch (statusCode) {
      case 1:
        return 'Connected';
      case 0:
        return 'Disconnected';
      case -1:
        return 'No Instance';
      default:
        return 'Unknown';
    }
  }
}
