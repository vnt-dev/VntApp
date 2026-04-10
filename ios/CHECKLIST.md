# iOS Implementation Checklist

完整的iOS实现检查清单，确保所有组件都已正确配置。

## ✅ 文件清单

### Rust代码

- [x] `/vnt-Redir/vnt/src/ios_ffi.rs` - iOS FFI接口实现
- [x] `/vnt-Redir/vnt/src/lib.rs` - 导出ios_ffi模块
- [x] `/vnt-Redir/vnt/Cargo.toml` - iOS依赖配置

### Swift代码

- [x] `/ios/VntTunnelExtension/PacketTunnelProvider.swift` - Network Extension实现
- [x] `/ios/VntTunnelExtension/VNT-Bridging-Header.h` - FFI桥接头文件
- [x] `/ios/Runner/AppDelegate.swift` - 主应用委托（含Method Channel）
- [x] `/ios/Runner/VPNManager.swift` - VPN管理器

### 配置文件

- [x] `/ios/VntTunnelExtension/Info.plist` - Extension配置
- [x] `/ios/VntTunnelExtension/VntTunnelExtension.entitlements` - Extension权限
- [x] `/ios/Runner/Runner.entitlements` - 主应用权限

### Dart代码

- [x] `/lib/ios_vpn_service.dart` - Flutter iOS VPN服务

### 构建脚本

- [x] `/build-ios.sh` - iOS编译脚本

### 文档

- [x] `/ios/VntTunnelExtension/README.md` - 完整实现文档
- [x] `/ios/QUICKSTART.md` - 快速开始指南
- [x] `/ios/CHECKLIST.md` - 本检查清单

## ✅ 功能清单

### 核心功能

- [x] 从文件描述符创建TUN设备
- [x] VNT核心集成
- [x] 网络数据包处理
- [x] 服务器连接和认证

### iOS特性

- [x] Network Extension集成
- [x] 后台保活机制
- [x] 异常清理和恢复
- [x] 网络切换处理
- [x] 睡眠/唤醒处理

### Flutter集成

- [x] Method Channel通信
- [x] VPN启动/停止
- [x] 状态查询
- [x] 配置保存/加载

### 日志和调试

- [x] 完整的日志系统
- [x] 多级别日志支持
- [x] Console.app集成
- [x] 调试信息输出

## ✅ 配置检查

### Xcode项目配置

#### 主应用Target (Runner)

- [ ] Team已选择
- [ ] Bundle Identifier已设置
- [ ] Provisioning Profile已配置
- [ ] Capabilities已添加:
  - [ ] Network Extensions
  - [ ] App Groups (group.com.vnt.app)
- [ ] Runner.entitlements已配置
- [ ] VPNManager.swift已添加到项目
- [ ] AppDelegate.swift已更新

#### Extension Target (VntTunnelExtension)

- [ ] Team已选择
- [ ] Bundle Identifier已设置 (主应用ID + .tunnel)
- [ ] Provisioning Profile已配置
- [ ] Capabilities已添加:
  - [ ] Network Extensions (Packet Tunnel Provider)
  - [ ] App Groups (group.com.vnt.app)
- [ ] VntTunnelExtension.entitlements已配置
- [ ] PacketTunnelProvider.swift已添加
- [ ] VNT-Bridging-Header.h已配置
- [ ] VntCore.xcframework已添加
- [ ] Build Settings配置:
  - [ ] Bridging Header路径
  - [ ] Library Search Paths

### Apple Developer配置

- [ ] 付费开发者账户已激活
- [ ] App ID已创建（主应用）
- [ ] App ID已创建（Extension）
- [ ] App Group已创建 (group.com.vnt.app)
- [ ] App Group已添加到两个App ID
- [ ] Network Extensions已启用（两个App ID）
- [ ] Development Provisioning Profile已创建（主应用）
- [ ] Development Provisioning Profile已创建（Extension）
- [ ] 证书已下载并安装

### 编译环境

- [ ] Rust已安装
- [ ] iOS工具链已安装:
  - [ ] aarch64-apple-ios
  - [ ] x86_64-apple-ios
  - [ ] aarch64-apple-ios-sim
- [ ] Xcode Command Line Tools已安装
- [ ] Flutter已安装并配置

## ✅ 编译检查

### Rust编译

```bash
# 运行编译脚本
./build-ios.sh

# 检查输出
ls -la ios/VntTunnelExtension/lib/device/libvnt.a
ls -la ios/VntTunnelExtension/lib/simulator/libvnt.a
ls -la ios/VntTunnelExtension/lib/VntCore.xcframework/
```

- [ ] 编译脚本执行成功
- [ ] device/libvnt.a已生成
- [ ] simulator/libvnt.a已生成
- [ ] VntCore.xcframework已生成

### Xcode编译

```bash
# 清理构建
cd ios
xcodebuild clean -workspace Runner.xcworkspace -scheme Runner

# 编译主应用
xcodebuild build -workspace Runner.xcworkspace -scheme Runner -configuration Debug

# 编译Extension
xcodebuild build -workspace Runner.xcworkspace -scheme VntTunnelExtension -configuration Debug
```

- [ ] 主应用编译成功
- [ ] Extension编译成功
- [ ] 无链接错误
- [ ] 无符号未找到错误

### Flutter编译

```bash
# 编译iOS应用（不签名）
flutter build ios --no-codesign

# 或使用Flutter运行
flutter run -d <device-id>
```

- [ ] Flutter编译成功
- [ ] 可以安装到设备
- [ ] 应用可以启动

## ✅ 运行时检查

### 应用启动

- [ ] 应用可以正常启动
- [ ] UI正常显示
- [ ] 无崩溃
- [ ] 日志正常输出

### VPN功能

- [ ] 可以启动VPN连接
- [ ] Extension正常启动
- [ ] 文件描述符获取成功
- [ ] VNT核心启动成功
- [ ] 网络设置应用成功
- [ ] 可以看到VPN图标（状态栏）

### 连接测试

- [ ] 可以连接到服务器
- [ ] 认证成功
- [ ] 获取虚拟IP
- [ ] 可以ping通虚拟网关
- [ ] 可以访问虚拟网络中的其他设备

### 稳定性测试

- [ ] 后台运行稳定
- [ ] 网络切换正常（WiFi ↔ 蜂窝）
- [ ] 睡眠/唤醒正常
- [ ] 长时间运行无崩溃
- [ ] 内存使用正常（<50MB）

### 日志检查

```bash
# 查看Extension日志
log stream --predicate 'subsystem == "com.vnt.app.tunnel"' --level debug

# 查看所有VNT日志
log show --predicate 'subsystem CONTAINS "vnt"' --last 1h
```

- [ ] 可以看到Extension日志
- [ ] 可以看到Rust日志
- [ ] 日志内容正常
- [ ] 无错误或警告

## ✅ 测试场景

### 基本场景

- [ ] 启动VPN
- [ ] 停止VPN
- [ ] 查询状态
- [ ] 重启VPN

### 网络场景

- [ ] WiFi环境下连接
- [ ] 蜂窝网络环境下连接
- [ ] WiFi切换到蜂窝网络
- [ ] 蜂窝网络切换到WiFi
- [ ] 网络中断后恢复

### 应用场景

- [ ] 应用切换到后台
- [ ] 应用从后台恢复
- [ ] 应用被系统杀死后重启
- [ ] 设备重启后恢复连接

### 异常场景

- [ ] 服务器不可达
- [ ] 认证失败
- [ ] 网络超时
- [ ] Extension崩溃恢复
- [ ] 内存压力下的表现

## ✅ 性能检查

### 内存使用

- [ ] Extension内存 < 50MB
- [ ] 主应用内存正常
- [ ] 无内存泄漏
- [ ] 长时间运行内存稳定

### CPU使用

- [ ] 空闲时CPU < 5%
- [ ] 传输数据时CPU < 20%
- [ ] 无CPU占用异常

### 电池消耗

- [ ] 后台运行电池消耗合理
- [ ] 无异常耗电
- [ ] 与其他VPN应用相当

### 网络性能

- [ ] 延迟正常（< 50ms增加）
- [ ] 吞吐量正常（> 10Mbps）
- [ ] 无丢包或丢包率低（< 1%）

## ✅ 发布准备

### 代码准备

- [ ] 所有调试代码已移除
- [ ] 日志级别设置为Info或Warn
- [ ] 版本号已更新
- [ ] 构建号已更新

### 证书准备

- [ ] Distribution Certificate已创建
- [ ] Distribution Provisioning Profile已创建（主应用）
- [ ] Distribution Provisioning Profile已创建（Extension）
- [ ] 证书已安装到Xcode

### 文档准备

- [ ] 隐私政策已准备
- [ ] 使用说明已准备
- [ ] 截图已准备
- [ ] App Store描述已准备

### 测试准备

- [ ] 所有功能已测试
- [ ] 所有场景已测试
- [ ] TestFlight测试已完成
- [ ] 用户反馈已收集

## ✅ 提交检查

### Archive准备

```bash
# 创建Archive
xcodebuild archive \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive
```

- [ ] Archive创建成功
- [ ] 包含主应用和Extension
- [ ] 签名正确
- [ ] 无警告或错误

### 上传准备

- [ ] App Store Connect账户已准备
- [ ] App信息已填写
- [ ] 截图已上传
- [ ] 描述已填写
- [ ] 审核信息已填写

### 审核准备

- [ ] VPN用途说明已准备
- [ ] 隐私政策链接已提供
- [ ] 测试账号已提供（如需要）
- [ ] 审核注意事项已说明

## 📝 注意事项

### 重要提示

1. **开发者账户**: 必须使用付费的Apple Developer账户
2. **真机测试**: Network Extension在模拟器上功能受限
3. **Bundle ID**: 主应用和Extension的Bundle ID必须不同
4. **App Group**: 必须正确配置，用于数据共享
5. **权限**: Network Extensions权限必须在App ID中启用

### 常见错误

1. **编译错误**: 检查Rust库是否已编译
2. **链接错误**: 检查Library Search Paths配置
3. **运行时错误**: 检查Bundle ID和权限配置
4. **连接失败**: 检查服务器地址和Token

### 调试技巧

1. 使用Console.app查看系统日志
2. 使用Xcode调试Extension
3. 检查网络设置是否正确应用
4. 验证文件描述符是否获取成功

## 🎉 完成

当所有检查项都完成后，你的iOS实现就完整了！

如有问题，请参考:
- [完整文档](VntTunnelExtension/README.md)
- [快速开始](QUICKSTART.md)
- GitHub Issues

祝你成功！🚀
