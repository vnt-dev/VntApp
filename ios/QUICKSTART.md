# iOS 快速开始指南

本指南将帮助你快速在iOS上运行VNT应用。

## 前提条件

- ✅ macOS系统（用于Xcode开发）
- ✅ Xcode 14.0或更高版本
- ✅ Flutter 3.0或更高版本
- ✅ Rust工具链
- ✅ Apple Developer账户（付费账户，用于Network Extension）

## 快速开始（4步）

### 步骤1: 打开Xcode项目

```bash
# 在项目根目录执行
open ios/Runner.xcworkspace
```

**注意**: 必须打开`.xcworkspace`文件，不是`.xcodeproj`！

### 步骤2: 添加Network Extension Target

1. 在Xcode中，点击 **File → New → Target**
2. 选择 **iOS → Network Extension**
3. 填写信息:
   - Product Name: `VntTunnelExtension`
   - Team: 选择你的开发团队
   - Language: Swift
   - Bundle Identifier: `com.vnt.app.tunnel`（或你的Bundle ID + `.tunnel`）
4. 点击 **Finish**
5. 弹出对话框询问是否激活scheme，点击 **Activate**

### 步骤3: 配置Extension

#### 4.1 添加文件到Extension

1. 在Project Navigator中，找到`VntTunnelExtension`文件夹
2. 删除自动生成的`PacketTunnelProvider.swift`
3. 右键点击`VntTunnelExtension`文件夹 → **Add Files to "Runner"...**
4. 选择以下文件:
   - `ios/VntTunnelExtension/PacketTunnelProvider.swift`
   - `ios/VntTunnelExtension/VNT-Bridging-Header.h`
   - `ios/VntTunnelExtension/Info.plist`（替换现有的）
   - `ios/VntTunnelExtension/VntTunnelExtension.entitlements`

#### 3.2 配置Build Settings

1. 选择`VntTunnelExtension` target
2. 点击 **Build Settings** 标签
3. 搜索 **Bridging Header**:
   - 设置为: `VntTunnelExtension/VNT-Bridging-Header.h`

#### 3.3 配置Capabilities

1. 选择`VntTunnelExtension` target
2. 点击 **Signing & Capabilities** 标签
3. 点击 **+ Capability**，添加:
   - **Network Extensions** (选择Packet Tunnel Provider)
   - **App Groups** (添加: `group.com.vnt.app`)

### 步骤4: 配置主应用

#### 4.1 添加文件

1. 右键点击`Runner`文件夹 → **Add Files to "Runner"...**
2. 选择 `ios/Runner/VPNManager.swift`

#### 4.2 配置Capabilities

1. 选择`Runner` target
2. 点击 **Signing & Capabilities** 标签
3. 点击 **+ Capability**，添加:
   - **Network Extensions**
   - **App Groups** (添加: `group.com.vnt.app`)

#### 4.3 配置Entitlements

1. 确保`Runner.entitlements`文件存在
2. 如果不存在，创建它并添加以下内容:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.networking.networkextension</key>
	<array>
		<string>packet-tunnel-provider</string>
	</array>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.vnt.app</string>
	</array>
</dict>
</plist>
```

## 运行应用

### 在真机上运行

1. 连接iPhone到Mac
2. 在Xcode中选择你的设备
3. 点击 **Run** 按钮（或按 Cmd+R）
4. 首次运行需要在设备上信任开发者证书:
   - 设置 → 通用 → VPN与设备管理 → 开发者App → 信任

### 在模拟器上运行

**注意**: Network Extension在模拟器上有限制，建议在真机上测试。

```bash
flutter run -d "iPhone 15 Pro"
```

## 测试VPN功能

### 在Dart代码中使用

```dart
import 'package:vnt_app/ios_vpn_service.dart';

// 启动VPN
final success = await IOSVPNService.startVPN(
  serverAddress: 'your-server.com:29872',
  token: 'your-token',
);

if (success) {
  print('VPN started successfully');
} else {
  print('Failed to start VPN');
}

// 检查状态
final connected = await IOSVPNService.isConnected();
print('VPN connected: $connected');

// 停止VPN
await IOSVPNService.stopVPN();
```

## 常见问题

### Q1: 编译失败

**A**: Flutter会通过cargokit自动构建Rust库。确保：
- Rust工具链已安装
- iOS目标已添加：`rustup target add aarch64-apple-ios`
- 清理后重新构建：`flutter clean && flutter build ios --release --no-codesign`

### Q2: Extension无法启动

**A**: 检查以下几点:
- Bundle Identifier是否正确（主应用和Extension不同）
- Provisioning Profile是否包含Network Extension权限
- App Group配置是否一致
- 是否在真机上运行（模拟器有限制）

### Q3: VPN连接失败

**A**: 查看日志:
```bash
log stream --predicate 'subsystem == "com.vnt.app.tunnel"' --level debug
```

检查:
- 服务器地址和端口是否正确
- Token是否有效
- 网络连接是否正常

### Q4: 需要开发者账户吗？

**A**: 是的，Network Extension需要付费的Apple Developer账户（$99/年）。免费账户无法使用此功能。

### Q5: 如何调试Extension？

**A**: 
1. 在Xcode中选择`VntTunnelExtension` scheme
2. 运行Extension
3. 在主应用中触发VPN连接
4. Xcode会自动附加到Extension进程进行调试

## 下一步

1. 配置Bundle Identifier和证书
2. 运行 `flutter build ios --release --no-codesign`
3. 在Xcode中配置签名
4. 在真机上测试

## 获取帮助

如果遇到问题:
1. 检查Rust工具链是否安装
2. 查看Xcode控制台日志
3. 使用Console.app查看系统日志
4. 提交Issue到GitHub

祝你使用愉快！🎉
