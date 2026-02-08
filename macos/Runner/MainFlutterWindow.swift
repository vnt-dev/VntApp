import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // ✅ 配置窗口样式，使用 macOS 原生标题栏
    self.styleMask = [
      .titled,         // 标题栏
      .closable,       // 可关闭
      .miniaturizable, // 可最小化
      .resizable       // 可调整大小
    ]

    // ✅ macOS 原生全屏与最大化支持
    self.collectionBehavior = [
      .fullScreenPrimary,       // 支持全屏
      .fullScreenAllowsTiling,  // 支持平铺（最大化）
      .managed                 // 让系统管理窗口位置
    ]

    // ✅ 设置窗口标题
    self.title = "VNT App"

    // ✅ 启用缩放（最大化）按钮
    self.standardWindowButton(.zoomButton)?.isEnabled = true
    self.standardWindowButton(.miniaturizeButton)?.isEnabled = true

    // 设置最小尺寸
    self.minSize = NSSize(width: 800, height: 600)

    // 窗口居中显示
    self.center()

    // 注册 Flutter 插件
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // ✅ 处理窗口大小变化
  override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    super.setFrame(frameRect, display: flag)
    
    // 保存窗口大小到 UserDefaults
    UserDefaults.standard.set([
      "width": frameRect.width,
      "height": frameRect.height
    ], forKey: "window_size")
  }

  // ✅ 拦截关闭按钮
  override func performClose(_ sender: Any?) {
    if let flutterViewController = self.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "vnt_app/window",
        binaryMessenger: flutterViewController.engine.binaryMessenger
      )
      channel.invokeMethod("onCloseButtonClicked", arguments: nil)
    }
    // 不调用 super.performClose，阻止默认关闭
  }

  // ✅ 允许窗口响应最小化
  override func miniaturize(_ sender: Any?) {
    // 可以在这里添加自定义逻辑
    super.miniaturize(sender)
  }

  // ✅ 允许窗口响应最大化/缩放
  override func zoom(_ sender: Any?) {
    // 可以在这里添加自定义逻辑
    super.zoom(sender)
  }

  // 确保窗口可以成为主窗口
  override var canBecomeMain: Bool { true }

  // 确保窗口可以成为关键窗口
  override var canBecomeKey: Bool { true }

  // 允许窗口接受鼠标事件
  override var acceptsFirstResponder: Bool { true }
}
