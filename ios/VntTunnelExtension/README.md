# VNT iOS Implementation

完整的iOS VPN实现，支持Network Extension和后台保活。

## 目录结构

```
ios/
├── Runner/                          # 主应用
│   ├── AppDelegate.swift           # 应用委托（含VPN方法通道）
│   ├── VPNManager.swift            # VPN管理器
│   └── Info.plist                  # 主应用配置
├── VntTunnelExtension/             # Network Extension
│   ├── PacketTunnelProvider.swift # VPN隧道提供者
│   ├── VNT-Bridging-Header.h      # Rust FFI桥接头文件
│   ├── Info.plist                  # Extension配置
│   ├── VntTunnelExtension.entitlements  # 权限配置
│   └── lib/                        # Rust静态库
│       ├── device/libvnt.a         # iOS设备库
│       ├── simulator/libvnt.a      # 模拟器库
│       └── VntCore.xcframework/    # XCFramework（推荐）
└── Runner.xcodeproj/               # Xcode项目
```

## 编译步骤

### 1. 编译Rust库

```bash
# 在项目根目录执行
./build-ios.sh
```

这将编译所有iOS目标并创建XCFramework。

### 2. 配置Xcode项目

#### 2.1 添加Network Extension Target

1. 打开Xcode项目
2. File → New → Target
3. 选择"Network Extension"
4. Product Name: `VntTunnelExtension`
5. Bundle Identifier: `com.vnt.app.tunnel`（需要与代码中一致）

#### 2.2 配置主应用Target

1. 选择Runner target
2. Signing & Capabilities:
   - 添加"Network Extensions"能力
   - 添加"App Groups"能力，Group ID: `group.com.vnt.app`
3. Build Settings:
   - 搜索"Bridging Header"
   - 设置为: `Runner/Runner-Bridging-Header.h`

#### 2.3 配置Extension Target

1. 选择VntTunnelExtension target
2. General:
   - 添加`VntCore.xcframework`到"Frameworks and Libraries"
   - 设置Embed为"Do Not Embed"
3. Signing & Capabilities:
   - 添加"Network Extensions"能力（Packet Tunnel Provider）
   - 添加"App Groups"能力，Group ID: `group.com.vnt.app`
4. Build Settings:
   - 搜索"Bridging Header"
   - 设置为: `VntTunnelExtension/VNT-Bridging-Header.h`
   - 搜索"Library Search Paths"
   - 添加: `$(PROJECT_DIR)/VntTunnelExtension/lib/$(PLATFORM_NAME)`
5. Build Phases:
   - 确保`PacketTunnelProvider.swift`在"Compile Sources"中
   - 确保`libvnt.a`在"Link Binary With Libraries"中

### 3. 配置证书和Provisioning Profile

#### 3.1 开发者账户要求

- 需要付费的Apple Developer账户
- 免费账户无法使用Network Extension

#### 3.2 创建App ID

1. 登录[Apple Developer](https://developer.apple.com/)
2. Certificates, Identifiers & Profiles → Identifiers
3. 创建两个App ID:
   - 主应用: `com.vnt.app`
   - Extension: `com.vnt.app.tunnel`
4. 为两个App ID启用:
   - Network Extensions
   - App Groups

#### 3.3 创建App Group

1. Identifiers → App Groups
2. 创建: `group.com.vnt.app`
3. 将此Group添加到两个App ID

#### 3.4 创建Provisioning Profile

1. Profiles → 创建Development Profile
2. 为主应用和Extension各创建一个Profile
3. 下载并安装到Xcode

#### 3.5 配置Xcode签名

1. 主应用Target:
   - Team: 选择你的开发团队
   - Provisioning Profile: 选择主应用的Profile
2. Extension Target:
   - Team: 选择你的开发团队
   - Provisioning Profile: 选择Extension的Profile

### 4. 构建和运行

```bash
# 使用Flutter构建
flutter build ios --no-codesign

# 或在Xcode中构建
# Product → Build
```

**注意**: 首次构建使用`--no-codesign`，然后在Xcode中配置签名后再构建。

## 使用方法

### Dart代码示例

```dart
import 'package:flutter/services.dart';

class IOSVPNService {
  static const platform = MethodChannel('com.vnt.app/vpn');
  
  // 启动VPN
  static Future<bool> startVPN({
    required String serverAddress,
    required String token,
    String? deviceName,
  }) async {
    try {
      final result = await platform.invokeMethod('startVPN', {
        'serverAddress': serverAddress,
        'token': token,
        'deviceName': deviceName ?? 'iOS Device',
      });
      return result == true;
    } catch (e) {
      print('Failed to start VPN: $e');
      return false;
    }
  }
  
  // 停止VPN
  static Future<bool> stopVPN() async {
    try {
      final result = await platform.invokeMethod('stopVPN');
      return result == true;
    } catch (e) {
      print('Failed to stop VPN: $e');
      return false;
    }
  }
  
  // 获取VPN状态
  static Future<Map<String, dynamic>?> getVPNStatus() async {
    try {
      final result = await platform.invokeMethod('getVPNStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Failed to get VPN status: $e');
      return null;
    }
  }
  
  // 保存配置
  static Future<bool> saveConfig({
    required String serverAddress,
    required String token,
  }) async {
    try {
      final result = await platform.invokeMethod('saveConfig', {
        'serverAddress': serverAddress,
        'token': token,
      });
      return result == true;
    } catch (e) {
      print('Failed to save config: $e');
      return false;
    }
  }
}
```

### 在UI中使用

```dart
// 启动VPN
await IOSVPNService.startVPN(
  serverAddress: 'vnt.example.com:29872',
  token: 'your-token-here',
);

// 停止VPN
await IOSVPNService.stopVPN();

// 获取状态
final status = await IOSVPNService.getVPNStatus();
print('VPN Status: $status');
```

## 功能特性

### 1. 后台保活

- Network Extension在后台持续运行
- 30秒心跳检测，确保VPN连接稳定
- 自动恢复异常断开的连接

### 2. 异常清理

- 应用退出时自动清理VPN连接
- Extension崩溃时系统自动重启
- 内存压力下的优雅降级

### 3. 网络切换

- 自动处理WiFi ↔ 蜂窝网络切换
- 网络中断后自动重连
- 保持连接状态同步

### 4. 日志记录

- 完整的日志记录系统
- 支持不同日志级别
- 可通过Console.app查看

## 调试

### 查看日志

```bash
# 实时查看日志
log stream --predicate 'subsystem == "com.vnt.app.tunnel"' --level debug

# 查看所有VNT相关日志
log show --predicate 'subsystem CONTAINS "vnt"' --last 1h
```

### 常见问题

#### 1. Extension无法启动

**症状**: VPN连接失败，Extension没有日志输出

**解决方案**:
- 检查Bundle Identifier是否正确
- 确认Provisioning Profile包含Network Extension权限
- 验证App Group配置正确

#### 2. 文件描述符为nil

**症状**: 日志显示"Tunnel fd not found"

**解决方案**:
- 确保在`setTunnelNetworkSettings`完成后获取fd
- 使用推荐的`getTunnelFileDescriptor()`方法
- 检查iOS版本（iOS 16+可能需要特殊处理）

#### 3. VPN频繁断开

**症状**: VPN连接不稳定，经常断开

**解决方案**:
- 检查服务器地址和端口是否正确
- 验证token是否有效
- 查看Extension日志中的错误信息
- 确认网络环境稳定

#### 4. 编译错误

**症状**: Xcode编译失败，找不到符号

**解决方案**:
- 确认已运行`./build-ios.sh`
- 检查Library Search Paths配置
- 验证XCFramework已正确添加
- 清理构建缓存: Product → Clean Build Folder

## 发布

### 1. 准备发布证书

1. 创建Distribution Certificate
2. 创建Distribution Provisioning Profile
3. 在Xcode中配置Release签名

### 2. 构建Release版本

```bash
flutter build ios --release
```

### 3. 上传到App Store

1. 在Xcode中: Product → Archive
2. 选择Archive → Distribute App
3. 选择App Store Connect
4. 上传到TestFlight或App Store

### 4. 注意事项

- Network Extension需要特殊审核
- 提交时需要说明VPN用途
- 准备隐私政策和使用说明
- 测试所有VPN功能

## 性能优化

### 1. 内存使用

- Extension内存限制约50MB
- 避免大量缓存
- 及时释放不用的资源

### 2. 电池消耗

- 优化心跳间隔
- 减少不必要的唤醒
- 使用高效的数据结构

### 3. 网络性能

- 调整MTU值（推荐1400）
- 启用数据压缩
- 优化路由配置

## 安全考虑

### 1. 数据保护

- 使用App Group安全共享数据
- 敏感信息存储在Keychain
- 传输数据加密

### 2. 权限最小化

- 只请求必要的权限
- 限制Extension访问范围
- 定期审查权限使用

### 3. 代码安全

- 输入验证
- 错误处理
- 防止注入攻击

## 更新日志

### v1.0.0 (2024-04-10)

- ✅ 完整的iOS Network Extension实现
- ✅ 后台保活机制
- ✅ 异常清理和恢复
- ✅ Flutter方法通道集成
- ✅ XCFramework支持
- ✅ 完整的文档和示例

## 许可证

Apache License 2.0

## 支持

如有问题，请提交Issue或查看文档。
