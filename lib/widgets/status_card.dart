import 'package:flutter/material.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/utils/responsive_utils.dart';

/// 连接状态卡片
class StatusCard extends StatelessWidget {
  final bool isConnected;
  final int connectionCount;
  final VoidCallback? onDisconnectAll;

  const StatusCard({
    super.key,
    required this.isConnected,
    required this.connectionCount,
    this.onDisconnectAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: ResponsiveUtils.padding(context, all: 20),
      decoration: BoxDecoration(
        gradient: isConnected
            ? const LinearGradient(
                colors: [AppTheme.successColor, Color(0xFF2ECC71)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2D3748), const Color(0xFF1A202C)]
                    : [const Color(0xFF718096), const Color(0xFF4A5568)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(context.radius(20)),
        boxShadow: [
          BoxShadow(
            color: isConnected
                ? AppTheme.successColor.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // 状态图标
          Container(
            width: context.w(64),
            height: context.w(64),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(context.radius(16)),
            ),
            child: Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
              size: context.iconLarge,
            ),
          ),
          SizedBox(width: context.spacing(16)),

          // 状态文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? '已连接' : '未连接',
                  style: TextStyle(
                    fontSize: context.fontXLarge,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: context.spacing(4)),
                Text(
                  isConnected
                      ? '$connectionCount 个活动连接'
                      : '点击配置开始连接',
                  style: TextStyle(
                    fontSize: context.fontBody,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          // 断开按钮
          if (isConnected && onDisconnectAll != null)
            IconButton(
              onPressed: onDisconnectAll,
              icon: Container(
                width: context.w(40),
                height: context.w(40),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(context.radius(10)),
                ),
                child: Icon(
                  Icons.power_settings_new,
                  color: Colors.white,
                  size: context.iconSmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
