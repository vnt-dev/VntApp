//
//  PacketTunnelProvider.swift
//  VntTunnelExtension
//
//  VNT iOS Network Extension Implementation
//  完整的iOS VPN实现，支持后台保活和异常清理
//

import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    // MARK: - Properties
    
    private let logger = OSLog(subsystem: "com.vnt.app.tunnel", category: "Tunnel")
    private var tunnelFd: Int32?
    private var isRunning = false
    private var tunnelQueue: DispatchQueue?
    private var keepAliveTimer: Timer?
    
    // MARK: - File Descriptor Retrieval
    
    /// 获取隧道文件描述符（iOS 16+推荐方法）
    /// 改编自WireGuard实现，适用于所有iOS版本
    private func getTunnelFileDescriptor() -> Int32? {
        var ctlInfo = ctl_info()
        withUnsafeMutablePointer(to: &ctlInfo.ctl_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
                _ = strcpy($0, "com.apple.net.utun_control")
            }
        }
        
        // 搜索文件描述符以找到utun套接字
        // 范围0...1024确保找到fd，实际上通常在低范围（<100）快速找到
        for fd: Int32 in 0...1024 {
            var addr = sockaddr_ctl()
            var ret: Int32 = -1
            var len = socklen_t(MemoryLayout.size(ofValue: addr))
            
            withUnsafeMutablePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    ret = getpeername(fd, $0, &len)
                }
            }
            
            if ret != 0 || addr.sc_family != AF_SYSTEM {
                continue
            }
            
            if ctlInfo.ctl_id == 0 {
                ret = ioctl(fd, CTLIOCGINFO, &ctlInfo)
                if ret != 0 {
                    continue
                }
            }
            
            if addr.sc_id == ctlInfo.ctl_id {
                os_log(.debug, log: logger, "Found tunnel fd: %{public}d", fd)
                return fd
            }
        }
        
        os_log(.error, log: logger, "Tunnel fd not found")
        return nil
    }
    
    // MARK: - Tunnel Lifecycle
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log(.info, log: logger, "Starting VNT tunnel...")
        
        // 初始化日志系统
        if let logDir = getLogDirectory() {
            logDir.withCString { ptr in
                let result = vnt_ios_init_log(ptr)
                if result == 0 {
                    os_log(.info, log: logger, "Log system initialized: %{public}@", logDir)
                } else {
                    os_log(.error, log: logger, "Failed to init log: %{public}d", result)
                }
            }
        }
        
        // 加载配置
        let config = loadConfiguration(from: options)
        
        // 创建隧道网络设置
        let tunnelSettings = createTunnelNetworkSettings(config: config)
        
        // 应用网络设置
        setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
            guard let self = self else {
                completionHandler(self?.createError(code: 1, message: "Self deallocated"))
                return
            }
            
            if let error = error {
                os_log(.error, log: self.logger, "Failed to set tunnel settings: %{public}@", error.localizedDescription)
                completionHandler(error)
                return
            }
            
            os_log(.info, log: self.logger, "Tunnel settings applied successfully")
            
            // 获取文件描述符
            guard let tunFd = self.getTunnelFileDescriptor() else {
                completionHandler(self.createError(code: 2, message: "Cannot locate tunnel file descriptor"))
                return
            }
            
            self.tunnelFd = tunFd
            self.isRunning = true
            os_log(.default, log: self.logger, "Starting tunnel with fd %{public}d", tunFd)
            
            // 设置日志级别
            vnt_ios_set_log_level(2) // Info级别
            
            // 在后台队列启动VNT
            let queue = DispatchQueue(label: "com.vnt.app.tunnel.worker", qos: .userInitiated)
            self.tunnelQueue = queue
            
            queue.async {
                os_log(.info, log: self.logger, "Starting VNT tunnel processing...")
                
                let result = config.serverAddress.withCString { serverPtr in
                    config.token.withCString { tokenPtr in
                        config.deviceName.withCString { namePtr in
                            vnt_ios_start_tunnel(tunFd, serverPtr, tokenPtr, namePtr, Int32(config.mtu))
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    if result == 0 {
                        os_log(.info, log: self.logger, "VNT tunnel started successfully")
                        
                        // 启动保活定时器
                        self.startKeepAlive()
                        
                        completionHandler(nil)
                    } else {
                        self.isRunning = false
                        let error = self.createError(code: Int(result), message: "VNT start failed with code: \(result)")
                        os_log(.error, log: self.logger, "VNT start failed: %{public}d", result)
                        completionHandler(error)
                    }
                }
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log(.default, log: logger, "Stopping tunnel: %{public}@", String(describing: reason))
        
        // 停止保活定时器
        stopKeepAlive()
        
        // 停止VNT
        if isRunning {
            vnt_ios_stop_tunnel()
            isRunning = false
        }
        
        tunnelFd = nil
        tunnelQueue = nil
        
        os_log(.info, log: logger, "Tunnel stopped successfully")
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        os_log(.debug, log: logger, "Received app message: %{public}d bytes", messageData.count)
        
        guard let handler = completionHandler else { return }
        
        // 解析消息
        if let message = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
           let command = message["command"] as? String {
            
            switch command {
            case "status":
                let status = vnt_ios_get_status()
                let response = ["status": status, "running": isRunning] as [String : Any]
                if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                    handler(responseData)
                } else {
                    handler(nil)
                }
                
            case "ping":
                let response = ["result": "pong"]
                if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                    handler(responseData)
                } else {
                    handler(nil)
                }
                
            default:
                handler(nil)
            }
        } else {
            handler(nil)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // 设备进入睡眠状态
        os_log(.info, log: logger, "Device entering sleep mode")
        completionHandler()
    }
    
    override func wake() {
        // 设备从睡眠状态唤醒
        os_log(.info, log: logger, "Device waking from sleep")
    }
    
    // MARK: - Keep Alive
    
    /// 启动保活定时器，防止系统杀死扩展
    private func startKeepAlive() {
        stopKeepAlive()
        
        os_log(.info, log: logger, "Starting keep-alive timer")
        
        // 每30秒发送一次保活信号
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.isRunning {
                let status = vnt_ios_get_status()
                os_log(.debug, log: self.logger, "Keep-alive: VNT status = %{public}d", status)
                
                // 如果VNT状态异常，尝试重启
                if status < 0 {
                    os_log(.warning, log: self.logger, "VNT instance lost, attempting recovery...")
                    // 这里可以添加恢复逻辑
                }
            }
        }
        
        // 确保定时器在主运行循环中运行
        if let timer = keepAliveTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// 停止保活定时器
    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        os_log(.info, log: logger, "Keep-alive timer stopped")
    }
    
    // MARK: - Configuration
    
    private struct VNTConfig {
        let serverAddress: String
        let token: String
        let deviceName: String
        let virtualIP: String
        let virtualNetmask: String
        let mtu: Int
        
        static let `default` = VNTConfig(
            serverAddress: "vnt.example.com:29872",
            token: "",
            deviceName: UIDevice.current.name,
            virtualIP: "10.26.0.2",
            virtualNetmask: "255.255.255.0",
            mtu: 1400
        )
    }
    
    private func loadConfiguration(from options: [String: NSObject]?) -> VNTConfig {
        // 优先从options读取
        if let options = options {
            return VNTConfig(
                serverAddress: options["serverAddress"] as? String ?? VNTConfig.default.serverAddress,
                token: options["token"] as? String ?? VNTConfig.default.token,
                deviceName: options["deviceName"] as? String ?? VNTConfig.default.deviceName,
                virtualIP: options["virtualIP"] as? String ?? VNTConfig.default.virtualIP,
                virtualNetmask: options["virtualNetmask"] as? String ?? VNTConfig.default.virtualNetmask,
                mtu: options["mtu"] as? Int ?? VNTConfig.default.mtu
            )
        }
        
        // 尝试从UserDefaults读取（App Group共享）
        if let defaults = UserDefaults(suiteName: "group.com.vnt.app") {
            return VNTConfig(
                serverAddress: defaults.string(forKey: "serverAddress") ?? VNTConfig.default.serverAddress,
                token: defaults.string(forKey: "token") ?? VNTConfig.default.token,
                deviceName: defaults.string(forKey: "deviceName") ?? VNTConfig.default.deviceName,
                virtualIP: defaults.string(forKey: "virtualIP") ?? VNTConfig.default.virtualIP,
                virtualNetmask: defaults.string(forKey: "virtualNetmask") ?? VNTConfig.default.virtualNetmask,
                mtu: defaults.integer(forKey: "mtu") != 0 ? defaults.integer(forKey: "mtu") : VNTConfig.default.mtu
            )
        }
        
        return .default
    }
    
    private func createTunnelNetworkSettings(config: VNTConfig) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.26.0.1")
        settings.mtu = NSNumber(value: config.mtu)
        
        // IPv4设置
        let ipv4Settings = NEIPv4Settings(addresses: [config.virtualIP], subnetMasks: [config.virtualNetmask])
        
        // 路由所有流量通过VPN
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        
        // 排除本地网络
        ipv4Settings.excludedRoutes = [
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0")
        ]
        
        settings.ipv4Settings = ipv4Settings
        
        // IPv6设置（保留本机IPv6网络）
        let ipv6Settings = NEIPv6Settings(addresses: ["fd00::1"], networkPrefixLengths: [64])
        ipv6Settings.includedRoutes = []
        settings.ipv6Settings = ipv6Settings
        
        // DNS设置（可选）
        // let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        // settings.dnsSettings = dnsSettings
        
        return settings
    }
    
    private func createError(code: Int, message: String) -> NSError {
        return NSError(
            domain: "com.vnt.app.tunnel",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
    
    private func getLogDirectory() -> String? {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.vnt.app") {
            let logDir = groupURL.appendingPathComponent("logs").path
            try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
            return logDir
        }
        return nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        os_log(.info, log: logger, "PacketTunnelProvider deallocating")
        stopKeepAlive()
        if isRunning {
            vnt_ios_stop_tunnel()
        }
    }
}
