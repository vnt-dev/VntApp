import WidgetKit
import SwiftUI
import Intents

// MARK: - Widget Entry

struct VNTWidgetEntry: TimelineEntry {
    let date: Date
    let isConnected: Bool
    let statusText: String
    let configName: String?
    let hasUpdate: Bool
    let updateMessage: String?
}

// MARK: - Widget Provider

struct VNTWidgetProvider: IntentTimelineProvider {
    
    func placeholder(in context: Context) -> VNTWidgetEntry {
        VNTWidgetEntry(
            date: Date(),
            isConnected: false,
            statusText: "未连接",
            configName: nil,
            hasUpdate: false,
            updateMessage: nil
        )
    }
    
    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (VNTWidgetEntry) -> Void) {
        let entry = loadCurrentStatus()
        completion(entry)
    }
    
    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<VNTWidgetEntry>) -> Void) {
        let currentEntry = loadCurrentStatus()
        
        // 每5分钟更新一次
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func loadCurrentStatus() -> VNTWidgetEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.vnt.app") else {
            return VNTWidgetEntry(
                date: Date(),
                isConnected: false,
                statusText: "未连接",
                configName: nil,
                hasUpdate: false,
                updateMessage: nil
            )
        }
        
        let isConnected = defaults.bool(forKey: "vpn_connected")
        let statusText = defaults.string(forKey: "vpn_status") ?? "未连接"
        let configName = defaults.string(forKey: "config_name")
        let hasUpdate = defaults.bool(forKey: "has_update")
        let updateMessage = defaults.string(forKey: "update_message")
        
        return VNTWidgetEntry(
            date: Date(),
            isConnected: isConnected,
            statusText: statusText,
            configName: configName,
            hasUpdate: hasUpdate,
            updateMessage: updateMessage
        )
    }
}

// MARK: - Small Widget View (1x1)

struct VNTWidgetSmallView: View {
    var entry: VNTWidgetEntry
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: entry.isConnected ? 
                    [Color(red: 0.2, green: 0.6, blue: 0.9), Color(red: 0.1, green: 0.4, blue: 0.7)] :
                    [Color(red: 0.4, green: 0.4, blue: 0.4), Color(red: 0.3, green: 0.3, blue: 0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 4) {
                Text("VNT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                
                Image(systemName: entry.isConnected ? "checkmark.shield.fill" : "xmark.shield")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                
                Text(entry.statusText)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(4)
            
            // 更新提示角标
            if entry.hasUpdate {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .padding(4)
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Medium Widget View (2x1)

struct VNTWidgetMediumView: View {
    var entry: VNTWidgetEntry
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: entry.isConnected ? 
                    [Color(red: 0.2, green: 0.6, blue: 0.9), Color(red: 0.1, green: 0.4, blue: 0.7)] :
                    [Color(red: 0.4, green: 0.4, blue: 0.4), Color(red: 0.3, green: 0.3, blue: 0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack(spacing: 12) {
                // 左侧图标
                VStack {
                    Image(systemName: entry.isConnected ? "checkmark.shield.fill" : "xmark.shield")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .frame(width: 60)
                
                // 右侧信息
                VStack(alignment: .leading, spacing: 4) {
                    Text("VNT")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(entry.statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    if let configName = entry.configName {
                        Text(configName)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    // 更新提示
                    if entry.hasUpdate, let message = entry.updateMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 10))
                            Text(message)
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                        .foregroundColor(.yellow)
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
            }
            .padding(12)
        }
    }
}

// MARK: - Widget Configuration

@main
struct VNTWidget: Widget {
    let kind: String = "VNTWidget"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: VNTWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                VNTWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                VNTWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("VNT 状态")
        .description("显示VNT连接状态和更新提示")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct VNTWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: VNTWidgetEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            VNTWidgetSmallView(entry: entry)
        case .systemMedium:
            VNTWidgetMediumView(entry: entry)
        default:
            VNTWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Preview

struct VNTWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VNTWidgetEntryView(entry: VNTWidgetEntry(
                date: Date(),
                isConnected: true,
                statusText: "已连接",
                configName: "默认配置",
                hasUpdate: true,
                updateMessage: "有新版本"
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            VNTWidgetEntryView(entry: VNTWidgetEntry(
                date: Date(),
                isConnected: false,
                statusText: "未连接",
                configName: nil,
                hasUpdate: false,
                updateMessage: nil
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}
