//
//  VPNManager.swift
//  Runner
//
//  VPN管理器 - 用于主应用与Network Extension通信
//

import Foundation
import NetworkExtension
import WidgetKit

class VPNManager {
    
    static let shared = VPNManager()
    
    var status: NEVPNStatus = .invalid
    var isConnected: Bool = false
    
    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    
    private init() {
        setupStatusObserver()
        loadManager()
    }
    
    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Setup
    
    private func setupStatusObserver() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let connection = notification.object as? NEVPNConnection {
                self.status = connection.status
                self.isConnected = (connection.status == .connected)
                
                let statusText = self.statusString(connection.status)
                print("[VPN] Status changed: \(statusText)")
                
                // 更新Widget
                self.updateWidgetStatus(connected: self.isConnected, status: statusText)
            }
        }
    }
    
    private func loadManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[VPN] Failed to load managers: \(error)")
                return
            }
            
            if let manager = managers?.first {
                self.manager = manager
                self.status = manager.connection.status
                self.isConnected = (manager.connection.status == .connected)
                print("[VPN] Manager loaded, status: \(self.statusString(manager.connection.status))")
            } else {
                print("[VPN] No existing manager found")
            }
        }
    }
    
    // MARK: - VPN Control
    
    func connect(serverAddress: String, token: String, deviceName: String? = nil, completion: @escaping (Error?) -> Void) {
        print("[VPN] Connecting to \(serverAddress)...")
        
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[VPN] Failed to load preferences: \(error)")
                completion(error)
                return
            }
            
            let manager = managers?.first ?? NETunnelProviderManager()
            self.manager = manager
            
            // 配置VPN
            let protocolConfig = NETunnelProviderProtocol()
            protocolConfig.providerBundleIdentifier = "com.vnt.app.tunnel" // 需要替换为实际的Bundle ID
            protocolConfig.serverAddress = serverAddress
            
            // 传递配置选项
            protocolConfig.providerConfiguration = [
                "serverAddress": serverAddress as NSObject,
                "token": token as NSObject,
                "deviceName": (deviceName ?? UIDevice.current.name) as NSObject,
                "virtualIP": "10.26.0.2" as NSObject,
                "virtualNetmask": "255.255.255.0" as NSObject,
                "mtu": 1400 as NSObject
            ]
            
            manager.protocolConfiguration = protocolConfig
            manager.localizedDescription = "VNT"
            manager.isEnabled = true
            
            // 保存配置
            manager.saveToPreferences { error in
                if let error = error {
                    print("[VPN] Failed to save preferences: \(error)")
                    completion(error)
                    return
                }
                
                // 重新加载以获取最新配置
                manager.loadFromPreferences { error in
                    if let error = error {
                        print("[VPN] Failed to reload preferences: \(error)")
                        completion(error)
                        return
                    }
                    
                    // 启动VPN
                    do {
                        try manager.connection.startVPNTunnel()
                        print("[VPN] VPN tunnel started")
                        
                        // 更新Widget状态
                        self.updateWidgetStatus(connected: true, status: "连接中...")
                        
                        completion(nil)
                    } catch {
                        print("[VPN] Failed to start VPN tunnel: \(error)")
                        completion(error)
                    }
                }
            }
        }
    }
    
    // MARK: - 连接默认配置
    
    func connectDefaultConfig(completion: @escaping (Error?) -> Void) {
        // 从SharedPreferences读取默认配置key
        guard let defaults = UserDefaults(suiteName: "group.com.vnt.app"),
              let defaultKey = defaults.string(forKey: "flutter.default-key"),
              !defaultKey.isEmpty else {
            let error = NSError(domain: "VPNManager", code: -1, 
                              userInfo: [NSLocalizedDescriptionKey: "未设置默认配置"])
            print("[VPN] No default config set")
            completion(error)
            return
        }
        
        print("[VPN] Loading default config with key: \(defaultKey)")
        
        // 从配置列表中查找对应的配置
        guard let configData = defaults.data(forKey: "flutter.config_\(defaultKey)") else {
            let error = NSError(domain: "VPNManager", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "默认配置不存在"])
            print("[VPN] Default config not found: \(defaultKey)")
            completion(error)
            return
        }
        
        // 解析配置JSON
        do {
            if let config = try JSONSerialization.jsonObject(with: configData) as? [String: Any],
               let serverAddress = config["server_address"] as? String,
               let token = config["token"] as? String {
                
                let deviceName = config["device_name"] as? String
                print("[VPN] Connecting to default config: \(serverAddress)")
                
                // 使用解析出的配置连接
                connect(serverAddress: serverAddress, token: token, deviceName: deviceName, completion: completion)
            } else {
                let error = NSError(domain: "VPNManager", code: -3,
                                  userInfo: [NSLocalizedDescriptionKey: "配置格式错误"])
                completion(error)
            }
        } catch {
            print("[VPN] Failed to parse config: \(error)")
            completion(error)
        }
    }
    
    func disconnect(completion: @escaping () -> Void) {
        print("[VPN] Disconnecting...")
        
        guard let manager = manager else {
            print("[VPN] No manager available")
            completion()
            return
        }
        
        manager.connection.stopVPNTunnel()
        
        // 更新Widget状态
        updateWidgetStatus(connected: false, status: "未连接")
        
        completion()
    }
    
    func getStatus(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let manager = manager,
              let session = manager.connection as? NETunnelProviderSession else {
            completion(.failure(NSError(domain: "VPNManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active session"])))
            return
        }
        
        let message = try? JSONSerialization.data(withJSONObject: ["command": "status"])
        
        guard let messageData = message else {
            completion(.failure(NSError(domain: "VPNManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create message"])))
            return
        }
        
        do {
            try session.sendProviderMessage(messageData) { response in
                if let response = response,
                   let json = try? JSONSerialization.jsonObject(with: response) as? [String: Any] {
                    completion(.success(json))
                } else {
                    completion(.failure(NSError(domain: "VPNManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Helpers
    
    private func statusString(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid:
            return "Invalid"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .reasserting:
            return "Reasserting"
        case .disconnecting:
            return "Disconnecting"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Configuration Storage
    
    func saveConfiguration(serverAddress: String, token: String) {
        if let defaults = UserDefaults(suiteName: "group.com.vnt.app") {
            defaults.set(serverAddress, forKey: "serverAddress")
            defaults.set(token, forKey: "token")
            defaults.set(UIDevice.current.name, forKey: "deviceName")
            defaults.synchronize()
            print("[VPN] Configuration saved to App Group")
        }
    }
    
    func loadConfiguration() -> (serverAddress: String?, token: String?) {
        if let defaults = UserDefaults(suiteName: "group.com.vnt.app") {
            let serverAddress = defaults.string(forKey: "serverAddress")
            let token = defaults.string(forKey: "token")
            return (serverAddress, token)
        }
        return (nil, nil)
    }
    
    // MARK: - Widget Support
    
    private func updateWidgetStatus(connected: Bool, status: String) {
        if let defaults = UserDefaults(suiteName: "group.com.vnt.app") {
            defaults.set(connected, forKey: "vpn_connected")
            defaults.set(status, forKey: "vpn_status")
            defaults.synchronize()
            
            // 通知Widget刷新
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    
    func setUpdateAvailable(message: String) {
        if let defaults = UserDefaults(suiteName: "group.com.vnt.app") {
            defaults.set(true, forKey: "has_update")
            defaults.set(message, forKey: "update_message")
            defaults.synchronize()
            
            // 刷新Widget显示更新提示
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    
    func clearUpdateNotification() {
        if let defaults = UserDefaults(suiteName: "group.com.vnt.app") {
            defaults.set(false, forKey: "has_update")
            defaults.removeObject(forKey: "update_message")
            defaults.synchronize()
            
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    
    // MARK: - Shortcuts Support
    
    func checkShortcutRequests() {
        guard let defaults = UserDefaults(suiteName: "group.com.vnt.app") else { return }
        
        // 检查连接请求
        if defaults.bool(forKey: "shortcut_connect_request") {
            defaults.set(false, forKey: "shortcut_connect_request")
            defaults.synchronize()
            
            // 使用默认配置连接
            connectDefaultConfig { error in
                if let error = error {
                    print("[Shortcut] Connect failed: \(error)")
                }
            }
        }
        
        // 检查断开请求
        if defaults.bool(forKey: "shortcut_disconnect_request") {
            defaults.set(false, forKey: "shortcut_disconnect_request")
            defaults.synchronize()
            
            disconnect {
                print("[Shortcut] Disconnected")
            }
        }
    }
}
