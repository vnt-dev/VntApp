# iOS Widget 和 Shortcuts 实现说明

## 功能概述

### 1. 桌面小组件 (Widget)
- **小尺寸 (1x1)**: 显示VPN状态图标和连接状态
- **中尺寸 (2x1)**: 显示详细信息，包括配置名称和更新提示
- **更新提示**: 红色角标提醒有新版本可用
- **自动刷新**: 每5分钟自动更新状态

### 2. Siri快捷指令 (Shortcuts)
- **连接VPN**: 使用默认配置快速连接
- **断开VPN**: 快速断开VPN连接
- **语音控制**: 支持"嘿Siri，连接VPN"

## 文件结构

```
ios/
├── VNTWidget/                      # Widget扩展
│   ├── VNTWidget.swift            # Widget主实现
│   ├── Info.plist                 # Widget配置
│   └── VNTWidget.entitlements     # Widget权限
│
├── VNTIntents/                     # Shortcuts扩展
│   ├── IntentHandler.swift        # Intent处理器
│   ├── Intents.intentdefinition   # Intent定义
│   ├── Info.plist                 # Intents配置
│   └── VNTIntents.entitlements    # Intents权限
│
└── Runner/
    ├── VPNManager.swift           # 添加Widget/Shortcuts支持
    └── AppDelegate.swift          # 添加Shortcuts请求检查
```

## Xcode配置步骤

### 1. 添加Widget Extension

1. **创建Widget Extension**:
   - File → New → Target
   - 选择 "Widget Extension"
   - Product Name: `VNTWidget`
   - Bundle Identifier: `com.vnt.app.widget`
   - 勾选 "Include Configuration Intent"

2. **添加文件**:
   - 将 `ios/VNTWidget/VNTWidget.swift` 添加到VNTWidget target
   - 替换自动生成的文件

3. **配置权限**:
   - 选择VNTWidget target
   - Signing & Capabilities → + Capability
   - 添加 "App Groups"
   - 勾选 `group.com.vnt.app`

### 2. 添加Intents Extension

1. **创建Intents Extension**:
   - File → New → Target
   - 选择 "Intents Extension"
   - Product Name: `VNTIntents`
   - Bundle Identifier: `com.vnt.app.intents`

2. **添加文件**:
   - 将 `ios/VNTIntents/IntentHandler.swift` 添加到VNTIntents target
   - 将 `ios/VNTIntents/Intents.intentdefinition` 添加到项目

3. **配置权限**:
   - 选择VNTIntents target
   - Signing & Capabilities → + Capability
   - 添加 "App Groups"
   - 勾选 `group.com.vnt.app`

### 3. 配置主应用

1. **添加WidgetKit框架**:
   - 选择Runner target
   - General → Frameworks, Libraries, and Embedded Content
   - 添加 `WidgetKit.framework` (Optional)

2. **更新Info.plist**:
   ```xml
   <key>NSUserActivityTypes</key>
   <array>
       <string>ConnectVPNIntent</string>
       <string>DisconnectVPNIntent</string>
   </array>
   ```

## Flutter集成

### 更新Widget状态

```dart
// 在Flutter中调用
await platform.invokeMethod('setUpdateAvailable', {
  'message': '发现新版本 v1.2.0'
});

// 清除更新提示
await platform.invokeMethod('clearUpdateNotification');
```

### 示例代码

```dart
class IOSWidgetService {
  static const platform = MethodChannel('com.vnt.app/vpn');
  
  // 设置更新提示
  static Future<void> setUpdateAvailable(String message) async {
    try {
      await platform.invokeMethod('setUpdateAvailable', {
        'message': message,
      });
    } catch (e) {
      print('Failed to set update: $e');
    }
  }
  
  // 清除更新提示
  static Future<void> clearUpdateNotification() async {
    try {
      await platform.invokeMethod('clearUpdateNotification');
    } catch (e) {
      print('Failed to clear update: $e');
    }
  }
}
```

## App Group共享数据

Widget和Shortcuts通过App Group与主应用共享数据：

### 共享的键值

| 键名 | 类型 | 说明 |
|------|------|------|
| `vpn_connected` | Bool | VPN连接状态 |
| `vpn_status` | String | 状态文本 |
| `config_name` | String | 配置名称 |
| `has_update` | Bool | 是否有更新 |
| `update_message` | String | 更新提示消息 |
| `serverAddress` | String | 服务器地址 |
| `token` | String | 认证令牌 |
| `shortcut_connect_request` | Bool | Shortcut连接请求 |
| `shortcut_disconnect_request` | Bool | Shortcut断开请求 |

## 使用说明

### 添加Widget到桌面

1. 长按主屏幕空白处
2. 点击左上角 "+" 按钮
3. 搜索 "VNT"
4. 选择小尺寸或中尺寸Widget
5. 添加到主屏幕

### 添加Siri快捷指令

1. 打开"快捷指令"应用
2. 点击 "+" 创建新快捷指令
3. 添加操作 → 搜索 "VNT"
4. 选择"连接VNT"或"断开VNT"
5. 设置快捷指令名称（如"连接VNT"）
6. 可选：录制Siri短语

### 语音控制

- "嘿Siri，连接VNT"
- "嘿Siri，断开VNT"

## 更新提示功能

### 检测更新

在Flutter应用中检测到新版本时：

```dart
// 检查更新
final hasUpdate = await checkForUpdates();
if (hasUpdate) {
  await IOSWidgetService.setUpdateAvailable('发现新版本 v1.2.0');
}
```

### Widget显示

- **小尺寸**: 右上角红色圆点
- **中尺寸**: 黄色更新提示文字和图标

### 清除提示

用户更新后清除提示：

```dart
await IOSWidgetService.clearUpdateNotification();
```

## 注意事项

1. **iOS版本要求**:
   - Widget: iOS 14.0+
   - Shortcuts: iOS 12.0+

2. **权限配置**:
   - 所有target必须配置相同的App Group
   - Bundle ID必须正确配置

3. **签名**:
   - Widget和Intents扩展需要单独签名
   - 使用相同的开发者账号

4. **测试**:
   - Widget在模拟器上可能显示不正常
   - 建议在真机上测试

5. **刷新频率**:
   - Widget每5分钟自动刷新
   - 状态变化时立即刷新
   - 系统可能限制刷新频率

## 故障排除

### Widget不显示

1. 检查App Group配置是否正确
2. 确认Widget target已正确添加
3. 重新安装应用

### Shortcuts不工作

1. 检查Intents.intentdefinition是否正确
2. 确认App Group权限
3. 重启"快捷指令"应用

### 更新提示不显示

1. 确认调用了`setUpdateAvailable`
2. 检查App Group数据是否写入
3. 手动刷新Widget

## 参考资料

- [WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [SiriKit Documentation](https://developer.apple.com/documentation/sirikit)
- [App Groups](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
