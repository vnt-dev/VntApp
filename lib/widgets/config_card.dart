import 'package:flutter/material.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/network_config.dart';
import 'package:vnt_app/utils/responsive_utils.dart';

/// 配置卡片组件
class ConfigCard extends StatelessWidget {
  final NetworkConfig config;
  final bool isConnected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const ConfigCard({
    super.key,
    required this.config,
    required this.isConnected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radius(16)),
      child: Container(
        padding: ResponsiveUtils.padding(context, all: 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
          borderRadius: BorderRadius.circular(context.radius(16)),
          border: isConnected
              ? Border.all(color: AppTheme.successColor, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：名称和状态
            Row(
              children: [
                // 状态指示器
                Container(
                  width: context.w(12),
                  height: context.w(12),
                  decoration: BoxDecoration(
                    color: isConnected ? AppTheme.successColor : AppTheme.warningColor,
                    shape: BoxShape.circle,
                    boxShadow: isConnected
                        ? [
                            BoxShadow(
                              color: AppTheme.successColor.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                SizedBox(width: context.spacing(12)),

                // 配置名称
                Expanded(
                  child: Text(
                    config.configName,
                    style: TextStyle(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 更多操作按钮
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: context.iconSize(24),
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.radius(12)),
                  ),
                  color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'duplicate':
                        onDuplicate();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: context.iconSize(20), color: primaryColor),
                          SizedBox(width: context.spacing(12)),
                          Text(
                            '编辑',
                            style: TextStyle(
                              fontSize: context.sp(14),
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy_outlined, size: context.iconSize(20), color: AppTheme.infoColor),
                          SizedBox(width: context.spacing(12)),
                          Text(
                            '复制',
                            style: TextStyle(
                              fontSize: context.sp(14),
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outlined, size: context.iconSize(20), color: AppTheme.errorColor),
                          SizedBox(width: context.spacing(12)),
                          Text(
                            '删除',
                            style: TextStyle(
                              fontSize: context.sp(14),
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: context.spacing(12)),

            // 配置详情
            _buildInfoRow(
              context,
              isDark,
              Icons.vpn_key_outlined,
              'Token',
              _maskToken(config.token),
            ),
            SizedBox(height: context.spacing(8)),
            _buildInfoRow(
              context,
              isDark,
              Icons.dns_outlined,
              '服务器',
              config.serverAddress.isNotEmpty ? config.serverAddress : '默认服务器',
            ),
            SizedBox(height: context.spacing(8)),
            _buildInfoRow(
              context,
              isDark,
              Icons.computer_outlined,
              '设备名',
              config.deviceName.isNotEmpty ? config.deviceName : '自动',
            ),
            if (config.virtualIPv4.isNotEmpty) ...[
              SizedBox(height: context.spacing(8)),
              _buildInfoRow(
                context,
                isDark,
                Icons.language_outlined,
                '虚拟IP',
                config.virtualIPv4,
              ),
            ],

            SizedBox(height: context.spacing(16)),

            // 底部操作按钮
            Row(
              children: [
                // 连接状态标签
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacing(12),
                    vertical: context.spacing(6),
                  ),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppTheme.successColor.withOpacity(0.1)
                        : AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(context.radius(20)),
                  ),
                  child: Text(
                    isConnected ? '已连接' : '未连接',
                    style: TextStyle(
                      fontSize: context.fontSmall,
                      fontWeight: FontWeight.w500,
                      color: isConnected ? AppTheme.successColor : AppTheme.warningColor,
                    ),
                  ),
                ),
                const Spacer(),

                // 连接按钮
                ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? AppTheme.successColor : primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacing(20),
                      vertical: context.spacing(10),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.radius(10)),
                    ),
                    elevation: 0,
                  ),
                  child: Text(isConnected ? '查看' : '连接'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, bool isDark, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: context.iconSize(16),
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        ),
        SizedBox(width: context.spacing(8)),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: context.fontSmall,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: context.fontSmall,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _maskToken(String token) {
    if (token.length <= 4) return token;
    return '${token.substring(0, 2)}${'*' * (token.length - 4)}${token.substring(token.length - 2)}';
  }
}
