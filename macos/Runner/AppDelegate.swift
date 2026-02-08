import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // 返回 false，不要在窗口关闭时自动退出应用
    // 让 Flutter 端通过 windowManager 控制应用的退出
    // 这样可以支持"隐藏到托盘"功能
    return false
  }
}
