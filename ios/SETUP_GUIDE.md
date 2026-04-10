# iOS Widget & Intents 快速配置指南

## 方法一：使用脚本（推荐用于了解步骤）

```bash
cd ios
./setup_extensions.sh
```

脚本会显示详细的手动配置步骤。

## 方法二：手动配置（最可靠）

### 1. 添加Widget Extension

1. 打开 `ios/Runner.xcodeproj`
2. 点击项目导航器中的项目名称
3. 点击底部的 `+` 按钮（或 Editor → Add Target）
4. 选择 `Widget Extension`
5. 配置：
   - Product Name: `VNTWidget`
   - Bundle Identifier: `com.vnt.app.widget`
   - 取消勾选 "Include Configuration Intent"
6. 点击 Finish

7. **删除自动生成的文件**，添加我们的文件：
   - 删除 `VNTWidget/VNTWidget.swift`（自动生成的）
   - 右键 VNTWidget 文件夹 → Add Files to "Runner"
   - 选择 `ios/VNTWidget/VNTWidget.swift`
   - 选择 `ios/VNTWidget/Info.plist`
   - 选择 `ios/VNTWidget/VNTWidget.entitlements`
   - 确保 "Add to targets" 勾选了 VNTWidget

8. **配置权限**：
   - 选择 VNTWidget target
   - Signing & Capabilities
   - 点击 `+ Capability`
   - 添加 `App Groups`
   - 勾选 `group.com.vnt.app`

9. **配置Info.plist**：
   - 选择 VNTWidget target
   - Build Settings
   - 搜索 "Info.plist File"
   - 设置为 `VNTWidget/Info.plist`

### 2. 添加Intents Extension

1. 继续在同一个项目中
2. 点击底部的 `+` 按钮
3. 选择 `Intents Extension`
4. 配置：
   - Product Name: `VNTIntents`
   - Bundle Identifier: `com.vnt.app.intents`
5. 点击 Finish

6. **删除自动生成的文件**，添加我们的文件：
   - 删除 `VNTIntents/IntentHandler.swift`（自动生成的）
   - 右键 VNTIntents 文件夹 → Add Files to "Runner"
   - 选择 `ios/VNTIntents/IntentHandler.swift`
   - 选择 `ios/VNTIntents/Info.plist`
   - 选择 `ios/VNTIntents/Intents.intentdefinition`
   - 选择 `ios/VNTIntents/VNTIntents.entitlements`
   - 确保 "Add to targets" 勾选了 VNTIntents

7. **配置权限**：
   - 选择 VNTIntents target
   - Signing & Capabilities
   - 点击 `+ Capability`
   - 添加 `App Groups`
   - 勾选 `group.com.vnt.app`

8. **配置Info.plist**：
   - 选择 VNTIntents target
   - Build Settings
   - 搜索 "Info.plist File"
   - 设置为 `VNTIntents/Info.plist`

### 3. 配置主应用

1. 选择 Runner target
2. General → Frameworks, Libraries, and Embedded Content
3. 点击 `+`
4. 添加 `WidgetKit.framework`（设置为 Optional）

### 4. 编译测试

1. 选择 Runner scheme
2. Product → Build
3. 确保没有编译错误

### 5. 在设备上测试

1. 连接真机（Widget在模拟器上可能显示不正常）
2. 运行应用
3. 长按主屏幕 → 点击 `+` → 搜索 "VNT"
4. 添加Widget到主屏幕

## 验证

### Widget验证
- 主屏幕应该能看到VNT Widget
- Widget显示VPN连接状态
- 状态变化时Widget自动更新

### Shortcuts验证
- 打开"快捷指令"应用
- 创建新快捷指令
- 搜索"VNT"
- 应该能看到"连接VNT"和"断开VNT"

## 故障排除

### Widget不显示
1. 检查App Groups配置是否正确
2. 确认Bundle ID正确
3. 重新安装应用
4. 重启设备

### Shortcuts不工作
1. 检查Intents.intentdefinition是否正确添加
2. 确认App Groups权限
3. 重新安装应用

### 编译错误
1. 确认所有文件都添加到正确的target
2. 检查Info.plist路径设置
3. Clean Build Folder (Shift + Cmd + K)
4. 重新编译

## 注意事项

1. **签名**：所有targets需要使用相同的开发者账号
2. **Bundle ID**：
   - 主应用: `com.vnt.app`
   - Widget: `com.vnt.app.widget`
   - Intents: `com.vnt.app.intents`
3. **App Groups**：所有targets必须使用 `group.com.vnt.app`
4. **iOS版本**：Widget需要iOS 14.0+，Shortcuts需要iOS 12.0+

## 参考文档

详细说明请查看：`ios/WIDGET_SHORTCUTS_README.md`
