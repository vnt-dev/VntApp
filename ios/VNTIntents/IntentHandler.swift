import Intents

// MARK: - VPN连接快捷指令

class ConnectVPNIntentHandler: NSObject, ConnectVPNIntentHandling {
    
    func handle(intent: ConnectVPNIntent, completion: @escaping (ConnectVPNIntentResponse) -> Void) {
        // 检查是否有默认配置
        guard let defaults = UserDefaults(suiteName: "group.com.vnt.app"),
              let defaultKey = defaults.string(forKey: "flutter.default-key"),
              !defaultKey.isEmpty else {
            completion(ConnectVPNIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        // 发送连接请求到主应用
        defaults.set(true, forKey: "shortcut_connect_request")
        defaults.set(Date(), forKey: "shortcut_request_time")
        defaults.synchronize()
        
        // 等待连接结果（最多3秒）
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
            let connected = defaults.bool(forKey: "vpn_connected")
            if connected {
                completion(ConnectVPNIntentResponse.success(status: "已连接到VNT"))
            } else {
                completion(ConnectVPNIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
}

// MARK: - VPN断开快捷指令

class DisconnectVPNIntentHandler: NSObject, DisconnectVPNIntentHandling {
    
    func handle(intent: DisconnectVPNIntent, completion: @escaping (DisconnectVPNIntentResponse) -> Void) {
        guard let defaults = UserDefaults(suiteName: "group.com.vnt.app") else {
            completion(DisconnectVPNIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        // 发送断开请求到主应用
        defaults.set(true, forKey: "shortcut_disconnect_request")
        defaults.set(Date(), forKey: "shortcut_request_time")
        defaults.synchronize()
        
        // 等待断开结果（最多2秒）
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            let connected = defaults.bool(forKey: "vpn_connected")
            if !connected {
                completion(DisconnectVPNIntentResponse.success(status: "已断开VNT"))
            } else {
                completion(DisconnectVPNIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
}

// MARK: - Intent Handler

class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        if intent is ConnectVPNIntent {
            return ConnectVPNIntentHandler()
        } else if intent is DisconnectVPNIntent {
            return DisconnectVPNIntentHandler()
        }
        fatalError("Unhandled intent type: \(intent)")
    }
}
