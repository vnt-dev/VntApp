import UIKit
import Flutter
import NetworkExtension
import WidgetKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // 注册iOS VPN方法通道
    if let controller = window?.rootViewController as? FlutterViewController {
      setupVPNMethodChannel(controller: controller)
    }
    
    // 检查Shortcuts请求
    VPNManager.shared.checkShortcutRequests()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    
    // 应用激活时检查Shortcuts请求
    VPNManager.shared.checkShortcutRequests()
  }
  
  private func setupVPNMethodChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(name: "com.vnt.app/vpn", binaryMessenger: controller.binaryMessenger)
    
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "startVPN":
        self?.startVPN(call: call, result: result)
      case "stopVPN":
        self?.stopVPN(result: result)
      case "getVPNStatus":
        self?.getVPNStatus(result: result)
      case "saveConfig":
        self?.saveConfig(call: call, result: result)
      case "setUpdateAvailable":
        self?.setUpdateAvailable(call: call, result: result)
      case "clearUpdateNotification":
        self?.clearUpdateNotification(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func startVPN(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let serverAddress = args["serverAddress"] as? String,
          let token = args["token"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
      return
    }
    
    let deviceName = args["deviceName"] as? String
    
    VPNManager.shared.connect(serverAddress: serverAddress, token: token, deviceName: deviceName) { error in
      if let error = error {
        result(FlutterError(code: "VPN_ERROR", message: error.localizedDescription, details: nil))
      } else {
        result(true)
      }
    }
  }
  
  private func stopVPN(result: @escaping FlutterResult) {
    VPNManager.shared.disconnect {
      result(true)
    }
  }
  
  private func getVPNStatus(result: @escaping FlutterResult) {
    VPNManager.shared.getStatus { statusResult in
      switch statusResult {
      case .success(let status):
        result(status)
      case .failure(let error):
        result(FlutterError(code: "STATUS_ERROR", message: error.localizedDescription, details: nil))
      }
    }
  }
  
  private func saveConfig(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let serverAddress = args["serverAddress"] as? String,
          let token = args["token"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
      return
    }
    
    VPNManager.shared.saveConfiguration(serverAddress: serverAddress, token: token)
    result(true)
  }
  
  private func setUpdateAvailable(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let message = args["message"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing message", details: nil))
      return
    }
    
    VPNManager.shared.setUpdateAvailable(message: message)
    result(true)
  }
  
  private func clearUpdateNotification(result: @escaping FlutterResult) {
    VPNManager.shared.clearUpdateNotification()
    result(true)
  }
}
