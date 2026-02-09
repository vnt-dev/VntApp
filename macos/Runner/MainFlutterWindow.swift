import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 配置窗口样式
    // 由于macOS安全限制，以root权限运行时最小化和最大化按钮会失效
    // 因此只保留关闭按钮，但仍允许调整窗口大小（通过拖拽边框）
    self.styleMask = [
      .titled,           // 标题栏
      .closable,         // 可关闭（红色按钮）
      .resizable         // 可调整大小（允许拖拽边框调整窗口大小）
    ]
    // 保留窗口可调整大小的功能
    self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    self.standardWindowButton(.zoomButton)?.isHidden = true

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
