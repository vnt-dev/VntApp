import 'package:flutter/material.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/utils/responsive_utils.dart';

/// 设备卡片组件 - 用于房间页面显示设备列表
class DeviceCard extends StatelessWidget {
  final String name;
  final String virtualIp;
  final String? realIp;
  final String status;
  final bool isOnline;
  final bool isCurrentDevice;
  final VoidCallback? onTap;

  const DeviceCard({
    super.key,
    required this.name,
    required this.virtualIp,
    this.realIp,
    required this.status,
    this.isOnline = false,
    this.isCurrentDevice = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: context.spacing(16),
        vertical: context.spacing(6),
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radius(12)),
        side: isCurrentDevice
            ? BorderSide(color: primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radius(12)),
        child: Padding(
          padding: ResponsiveUtils.padding(context, all: 16),
          child: Row(
            children: [
              // 设备图标
              Container(
                width: context.w(48),
                height: context.w(48),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppTheme.successColor.withOpacity(0.1)
                      : (isDark ? Colors.grey[800] : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(context.radius(12)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _getDeviceIcon(),
                        color: isOnline
                            ? AppTheme.successColor
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        size: context.iconSize(26),
                      ),
                    ),
                    // 在线状态指示点
                    Positioned(
                      right: context.w(4),
                      top: context.w(4),
                      child: Container(
                        width: context.w(10),
                        height: context.w(10),
                        decoration: BoxDecoration(
                          color: isOnline ? AppTheme.successColor : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkCardBackground
                                : AppTheme.lightCardBackground,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.spacing(12)),
              // 设备信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: context.sp(16),
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentDevice)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.spacing(8),
                              vertical: context.spacing(2),
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(context.radius(4)),
                            ),
                            child: Text(
                              '本机',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: context.sp(11),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: context.spacing(4)),
                    Row(
                      children: [
                        Icon(
                          Icons.lan,
                          size: context.iconSize(14),
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                        SizedBox(width: context.spacing(4)),
                        Text(
                          virtualIp,
                          style: TextStyle(
                            fontSize: context.sp(13),
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    if (realIp != null && realIp!.isNotEmpty) ...[
                      SizedBox(height: context.spacing(2)),
                      Row(
                        children: [
                          Icon(
                            Icons.public,
                            size: context.iconSize(14),
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                          SizedBox(width: context.spacing(4)),
                          Expanded(
                            child: Text(
                              realIp!,
                              style: TextStyle(
                                fontSize: context.sp(12),
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // 状态标签
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing(10),
                  vertical: context.spacing(4),
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(context.radius(6)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: context.sp(12),
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon() {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('phone') || lowerName.contains('android') || lowerName.contains('ios')) {
      return Icons.phone_android;
    } else if (lowerName.contains('mac') || lowerName.contains('imac')) {
      return Icons.desktop_mac;
    } else if (lowerName.contains('linux')) {
      return Icons.computer;
    } else if (lowerName.contains('windows') || lowerName.contains('pc')) {
      return Icons.desktop_windows;
    }
    return Icons.devices;
  }

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case '直连':
      case 'direct':
      case 'p2p':
        return AppTheme.successColor;
      case '中继':
      case 'relay':
        return AppTheme.warningColor;
      case '离线':
      case 'offline':
        return Colors.grey;
      default:
        return AppTheme.infoColor;
    }
  }
}

/// 设备列表头部组件
class DeviceListHeader extends StatelessWidget {
  final int totalCount;
  final int onlineCount;
  final VoidCallback? onRefresh;

  const DeviceListHeader({
    super.key,
    required this.totalCount,
    required this.onlineCount,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing(16),
        vertical: context.spacing(12),
      ),
      child: Row(
        children: [
          Text(
            '设备列表',
            style: TextStyle(
              fontSize: context.sp(18),
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
          ),
          SizedBox(width: context.spacing(12)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing(8),
              vertical: context.spacing(4),
            ),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(context.radius(12)),
            ),
            child: Text(
              '$onlineCount/$totalCount 在线',
              style: TextStyle(
                fontSize: context.sp(12),
                color: AppTheme.successColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          if (onRefresh != null)
            IconButton(
              onPressed: onRefresh,
              icon: Icon(
                Icons.refresh,
                size: context.iconSize(24),
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
              tooltip: '刷新',
            ),
        ],
      ),
    );
  }
}
