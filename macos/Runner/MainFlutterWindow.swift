import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 配置窗口样式，确保支持所有标准窗口功能
    self.styleMask = [
      .titled,           // 标题栏
      .closable,         // 可关闭
      .miniaturizable,   // 可最小化
      .resizable,        // 可调整大小
      .fullSizeContentView // 全尺寸内容视图（用于自定义标题栏）
    ]

    // 设置窗口标题栏样式
    self.titlebarAppearsTransparent = true  // 标题栏透明
    self.titleVisibility = .hidden          // 隐藏标题文本

    // 允许通过背景拖动窗口（配合 Flutter 的自定义标题栏）
    self.isMovableByWindowBackground = true

    // 设置最小尺寸
    self.minSize = NSSize(width: 800, height: 600)

    // 设置窗口的初始位置和大小
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // 确保窗口可以成为主窗口
  override var canBecomeMain: Bool {
    return true
  }

  // 确保窗口可以成为关键窗口
  override var canBecomeKey: Bool {
    return true
  }

  // 允许窗口接受鼠标事件
  override var acceptsFirstResponder: Bool {
    return true
  }
}
