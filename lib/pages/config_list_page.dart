import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/theme/color_utils.dart';
import 'package:vnt_app/network_config.dart';
import 'package:vnt_app/data_persistence.dart';
import 'package:vnt_app/vnt/vnt_manager.dart';
import 'package:vnt_app/network_config_input_page.dart';
import 'package:vnt_app/src/rust/api/vnt_api.dart';
import 'package:vnt_app/utils/toast_utils.dart';
import 'package:vnt_app/utils/responsive_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vnt_app/file_saver.dart';
import 'package:vnt_app/system_tray_manager.dart';

/// 配置列表页面
class ConfigListPage extends StatefulWidget {
  final Function(NetworkConfig)? onConfigSelected;
  final Function(VoidCallback)? onRefreshCallback;
  final VoidCallback? onDataChanged;

  const ConfigListPage({
    super.key,
    this.onConfigSelected,
    this.onRefreshCallback,
    this.onDataChanged,
  });

  @override
  State<ConfigListPage> createState() => _ConfigListPageState();
}

class _ConfigListPageState extends State<ConfigListPage> {
  final DataPersistence _dataPersistence = DataPersistence();
  List<NetworkConfig> _configs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
    // 将刷新方法传递给父组件
    widget.onRefreshCallback?.call(_loadConfigs);
  }

  @override
  void didUpdateWidget(ConfigListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当页面重新显示时，重新加载配置
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    setState(() => _isLoading = true);
    try {
      final configs = await _dataPersistence.loadData();
      setState(() {
        _configs = configs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadConfigs,
          color: primaryColor,
          child: CustomScrollView(
            slivers: [
              // 页面头部
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(isWideScreen ? context.spacingXLarge : context.spacingMedium),
                  child: _buildHeader(isDark, isWideScreen),
                ),
              ),

              // 操作按钮行
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isWideScreen ? context.spacingXLarge : context.spacingMedium),
                  child: _buildActionRow(isDark),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: context.spacingMedium)),

              // 配置列表
              _isLoading
                  ? SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                        ),
                      ),
                    )
                  : _configs.isEmpty
                      ? SliverFillRemaining(
                          child: _buildEmptyView(isDark),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWideScreen ? context.spacingXLarge : context.spacingMedium,
                          ),
                          sliver: SliverReorderableList(
                            itemBuilder: (context, index) {
                              final config = _configs[index];
                              return ReorderableDelayedDragStartListener(
                                key: ValueKey(config.itemKey),
                                index: index,
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: context.cardSpacing),
                                  child: _buildConfigCard(config, index, isDark),
                                ),
                              );
                            },
                            itemCount: _configs.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (oldIndex < newIndex) {
                                  newIndex -= 1;
                                }
                                final item = _configs.removeAt(oldIndex);
                                _configs.insert(newIndex, item);
                              });
                              // 保存新的排序
                              _dataPersistence.saveData(_configs);
                              // 通知设置页面刷新配置列表
                              widget.onDataChanged?.call();
                            },
                            proxyDecorator: (child, index, animation) {
                              // 拖动时的视觉效果 - 提供明显的反馈
                              return AnimatedBuilder(
                                animation: animation,
                                builder: (BuildContext context, Widget? child) {
                                  final double animValue = Curves.easeInOut.transform(animation.value);
                                  final double elevation = lerpDouble(0, 8, animValue)!;
                                  final double scale = lerpDouble(1, 1.05, animValue)!;
                                  return Transform.scale(
                                    scale: scale,
                                    child: Material(
                                      elevation: elevation,
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(context.cardRadius),
                                      child: Opacity(
                                        opacity: 0.9,
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child: child,
                              );
                            },
                          ),
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isWideScreen) {
    final primaryColor = Theme.of(context).primaryColor;
    return Row(
      children: [
        Container(
          width: context.iconXLarge,
          height: context.iconXLarge,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(context.cardRadius),
          ),
          child: Icon(
            Icons.folder_outlined,
            color: Colors.white,
            size: context.iconLarge,
          ),
        ),
        SizedBox(width: context.spacingMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '配置管理',
                style: TextStyle(
                  fontSize: context.fontXLarge,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              Text(
                '${_configs.length} 个配置',
                style: TextStyle(
                  fontSize: context.fontBody,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildSmallActionButton(
            isDark,
            Icons.add,
            '新建配置',
            () => _addOrEditConfig(null, -1),
          ),
        ),
        SizedBox(width: context.cardSpacing),
        Expanded(
          child: _buildSmallActionButton(
            isDark,
            Icons.file_download_outlined,
            '导入配置',
            _importSingleConfig,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallActionButton(
    bool isDark,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final primaryColor = Theme.of(context).primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.cardRadius),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: context.spacingSmall,
          horizontal: context.spacingMedium,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
          borderRadius: BorderRadius.circular(context.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: context.iconSmall, color: primaryColor),
            SizedBox(width: context.spacingXSmall),
            Text(
              label,
              style: TextStyle(
                fontSize: context.fontBody,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: context.w(80),
            height: context.w(80),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(context.cardRadius),
            ),
            child: Icon(
              Icons.folder_open,
              size: context.iconXLarge,
              color: primaryColor,
            ),
          ),
          SizedBox(height: context.spacingLarge),
          Text(
            '暂无配置',
            style: TextStyle(
              fontSize: context.fontLarge,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          SizedBox(height: context.spacingXSmall),
          Text(
            '点击上方按钮新建或导入一个组网配置',
            style: TextStyle(
              fontSize: context.fontBody,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard(NetworkConfig config, int index, bool isDark) {
    final isConnected = vntManager.hasConnectionItem(config.itemKey);
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isConnected
            ? (isDark
                ? ColorUtils.backgroundForDarkMode(primaryColor) // 暗黑模式：使用主题色生成的暗色背景
                : ColorUtils.backgroundForLightMode(primaryColor)) // 日间模式：使用主题色生成的浅色背景
            : (isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground),
        borderRadius: BorderRadius.circular(context.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: ResponsiveUtils.padding(context, all: context.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：配置名称和状态指示器
            Row(
              children: [
                // 状态指示器
                Container(
                  width: context.w(12),
                  height: context.w(12),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? primaryColor
                        : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: context.spacingSmall),
                // 配置名称
                Expanded(
                  child: Text(
                    config.configName,
                    style: TextStyle(
                      fontSize: context.fontLarge,
                      fontWeight: FontWeight.bold,
                      color: (isConnected && isDark)
                          ? Colors.white // 暗黑模式下已连接配置使用白色文字
                          : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 已连接标签
                if (isConnected)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacingSmall,
                      vertical: context.spacingXSmall / 2,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(context.cardRadius),
                    ),
                    child: Text(
                      '已连接',
                      style: TextStyle(
                        fontSize: context.fontSmall,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.spacingMedium),

            // 配置信息列表
            _buildConfigInfoRow(
              isDark,
              isConnected,
              Icons.computer_outlined,
              '设备名称',
              config.deviceName,
            ),
            SizedBox(height: context.spacingXSmall),
            _buildConfigInfoRow(
              isDark,
              isConnected,
              Icons.location_on_outlined,
              '虚拟 IP',
              config.virtualIPv4.isEmpty ? '自动分配' : config.virtualIPv4,
            ),
            SizedBox(height: context.spacingXSmall),
            _buildConfigInfoRow(
              isDark,
              isConnected,
              Icons.dns_outlined,
              '服务器',
              config.serverAddress,
            ),
            SizedBox(height: context.spacingMedium),

            // 底部操作按钮
            Row(
              children: [
                // 连接/断开按钮
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleConnection(config),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected
                          ? Colors.white.withOpacity(0.9)
                          : (isDark
                              ? HSLColor.fromColor(primaryColor).withLightness(0.25).toColor()
                              : HSLColor.fromColor(primaryColor).withLightness(0.35).toColor()),
                      foregroundColor: isConnected
                          ? const Color(0xFFE53E3E)
                          : Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: context.spacingSmall),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.spacingXSmall),
                      ),
                    ),
                    icon: Icon(
                      isConnected ? Icons.link_off : Icons.link,
                      size: context.iconSmall,
                    ),
                    label: Text(
                      isConnected ? '断开连接' : '连接',
                      style: TextStyle(
                        fontSize: context.fontBody,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: context.spacingXSmall),
                // 导出按钮（已连接和未连接都显示）
                _buildIconButton(
                  isDark,
                  isConnected,
                  Icons.file_upload_outlined,
                  () => _exportSingleConfig(config),
                ),
                // 未连接时显示编辑和删除按钮
                if (!isConnected) ...[
                  SizedBox(width: context.spacingXSmall),
                  // 编辑按钮
                  _buildIconButton(
                    isDark,
                    isConnected,
                    Icons.edit_outlined,
                    () => _addOrEditConfig(config, index),
                  ),
                  SizedBox(width: context.spacingXSmall),
                  // 删除按钮
                  _buildIconButton(
                    isDark,
                    isConnected,
                    Icons.delete_outline,
                    () => _showDeleteDialog(config, index),
                    color: AppTheme.errorColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 配置信息行
  Widget _buildConfigInfoRow(
    bool isDark,
    bool isConnected,
    IconData icon,
    String label,
    String value,
  ) {
    // 暗黑模式下已连接配置使用更亮的颜色
    final textColor = (isConnected && isDark)
        ? Colors.white.withOpacity(0.7) // 暗黑模式已连接：半透明白色
        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary);

    final valueColor = (isConnected && isDark)
        ? Colors.white // 暗黑模式已连接：纯白色
        : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary);

    return Row(
      children: [
        Icon(
          icon,
          size: context.iconSmall,
          color: textColor,
        ),
        SizedBox(width: context.spacingXSmall),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: context.fontBody,
            color: textColor,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: context.fontBody,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(bool isDark, IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingSmall,
          vertical: context.spacingXSmall,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(context.spacingXSmall),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: context.iconXSmall,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            SizedBox(width: context.spacingXSmall),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: context.fontSmall,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    bool isDark,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radius(10)),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.spacing(10)),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(context.radius(10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: context.iconSmall, color: color),
            SizedBox(width: context.spacingXSmall),
            Text(
              label,
              style: TextStyle(
                fontSize: context.fontBody,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(
    bool isDark,
    bool isConnected,
    IconData icon,
    VoidCallback onTap, {
    Color? color,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final buttonColor = color ?? primaryColor;
    final bgColor = isConnected
        ? Colors.white.withOpacity(0.9)
        : (isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.spacingXSmall),
      child: Container(
        width: context.w(40),
        height: context.w(40),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.spacingXSmall),
        ),
        child: Icon(icon, size: context.iconSmall, color: buttonColor),
      ),
    );
  }

  // 添加或编辑配置
  void _addOrEditConfig(NetworkConfig? config, int index) async {
    if (config != null) {
      if (vntManager.hasConnectionItem(config.itemKey)) {
        showTopToast(context, '正在连接中的配置不能编辑', isSuccess: false);
        return;
      }
    }

    // 使用对话框形式显示配置页面
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxWidth = context.w(600);
    final maxHeight = context.w(800);
    final insetPadding = context.spacingMedium;
    final dialogRadius = context.dialogRadius;
    final result = await showDialog<NetworkConfig>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(insetPadding),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
              borderRadius: BorderRadius.circular(dialogRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: NetworkConfigInputPage(config: config),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        if (index >= 0) {
          _configs[index] = result;
        } else {
          _configs.add(result);
        }
      });
      _dataPersistence.saveData(_configs);
      // 通知设置页面刷新配置列表
      widget.onDataChanged?.call();
      // 同步更新通知栏、磁贴、小组件（新建/编辑可能影响默认配置）
      VntAppCall.updateWidgetAndTile(false);
      // 更新系统托盘（配置列表变化）
      SystemTrayManager().updateMenu();
    }
  }

  // 切换连接状态
  Future<void> _toggleConnection(NetworkConfig config) async {
    final isConnected = vntManager.hasConnectionItem(config.itemKey);

    if (isConnected) {
      // 断开连接 - 显示确认弹窗
      _showDisconnectDialog(config);
    } else {
      // 建立连接
      await _connectVnt(config);
    }
  }

  // 连接VNT
  Future<void> _connectVnt(NetworkConfig config) async {
    // 检查是否已有连接
    if (vntManager.hasConnection()) {
      if (!vntManager.supportMultiple()) {
        var lastConnectedConfig = vntManager.getOne()?.networkConfig;
        _showAlreadyConnectedDialog(lastConnectedConfig);
        return;
      }
    }

    // 显示连接中对话框
    _showConnectingDialog(config);

    var onece = true;
    ReceivePort receivePort = ReceivePort();
    var itemKey = config.itemKey;
    var configName = config.configName;

    receivePort.listen((msg) async {
      if (msg is String) {
        if (msg == 'success') {
          if (onece) {
            onece = false;
            Navigator.of(context).popUntil((route) => route.isFirst);
            setState(() {});
            widget.onConfigSelected?.call(config);
            // 更新 Android 磁贴和小组件
            if (Platform.isAndroid) {
              VntAppCall.updateWidgetAndTile(true);
            }
            // 更新系统托盘
            SystemTrayManager().updateMenu();
            SystemTrayManager().updateTooltip();
          }
        } else if (msg == 'stop') {
          vntManager.remove(itemKey);
          if (onece) {
            onece = false;
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          // 统一显示"服务已停止"提示
          showTopToast(context, '[$configName] 服务已停止', isSuccess: false);
          setState(() {});
          // 更新 Android 磁贴和小组件
          if (Platform.isAndroid) {
            VntAppCall.updateWidgetAndTile(vntManager.hasConnection());
          }
          // 更新系统托盘
          SystemTrayManager().updateMenu();
          SystemTrayManager().updateTooltip();
        }
      } else if (msg is RustErrorInfo) {
        if (onece) {
          onece = false;
          Navigator.of(context).popUntil((route) => route.isFirst);
          vntManager.remove(itemKey);
        }
        _handleConnectionError(msg, configName, itemKey);
        // 更新 Android 磁贴和小组件
        if (Platform.isAndroid) {
          VntAppCall.updateWidgetAndTile(vntManager.hasConnection());
        }
        // 更新系统托盘
        SystemTrayManager().updateMenu();
        SystemTrayManager().updateTooltip();
      } else if (msg is RustConnectInfo) {
        if (onece && msg.count > BigInt.from(60)) {
          onece = false;
          Navigator.of(context).pop();
          vntManager.remove(itemKey);
          showTopToast(context, '[$configName] 连接超时 ${msg.address}', isSuccess: false);
          // 更新 Android 磁贴和小组件
          if (Platform.isAndroid) {
            VntAppCall.updateWidgetAndTile(vntManager.hasConnection());
          }
          // 更新系统托盘
          SystemTrayManager().updateMenu();
          SystemTrayManager().updateTooltip();
        }
      }
    });

    try {
      await vntManager.create(config, receivePort.sendPort);
    } catch (e) {
      debugPrint('dart catch e: $e');
      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
      var msg = e.toString();
      showTopToast(context, '连接失败 $msg', isSuccess: false);
    }
  }

  void _showConnectingDialog(NetworkConfig config) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryColor),
                const SizedBox(height: 20),
                Text(
                  '正在连接...',
                  style: TextStyle(
                    fontSize: context.fontMedium,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    vntManager.remove(config.itemKey);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAlreadyConnectedDialog(NetworkConfig? lastConnectedConfig) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '连接配置项[${lastConnectedConfig?.configName}]',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          content: Text(
            '已经建立了连接',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  void _handleConnectionError(RustErrorInfo msg, String configName, String itemKey) {
    vntManager.remove(itemKey);
    setState(() {});

    String errorMsg;
    switch (msg.code) {
      case RustErrorType.tokenError:
        errorMsg = '[$configName] token错误';
        break;
      case RustErrorType.addressExhausted:
        errorMsg = '[$configName] IP地址用尽';
        break;
      case RustErrorType.ipAlreadyExists:
        errorMsg = '[$configName] 当前配置和其他设备的虚拟IP冲突';
        break;
      case RustErrorType.invalidIp:
        errorMsg = '[$configName] 虚拟IP地址无效';
        break;
      case RustErrorType.localIpExists:
        errorMsg = '[$configName] 虚拟IP地址和本地IP冲突';
        break;
      default:
        errorMsg = '[$configName] 发生未知错误: ${msg.msg}';
    }

    showTopToast(context, errorMsg, isSuccess: false);
  }

  // 导出单个配置
  Future<void> _exportSingleConfig(NetworkConfig config) async {
    try {
      if (Platform.isAndroid) {
        final directory = await getTemporaryDirectory();
        final fileName = '${config.configName}_${DateTime.now().millisecondsSinceEpoch}.json';
        final filePath = '${directory.path}/$fileName';

        await _dataPersistence.exportSingleConfig(filePath, config);

        // 验证临时文件是否创建成功
        final tempFile = File(filePath);
        if (!await tempFile.exists()) {
          throw Exception('临时文件创建失败');
        }

        final success = await FileSaver.copyFile(
          sourceFilePath: filePath,
          fileName: fileName,
          mimeType: 'application/json',
        );

        // 清理临时文件
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        if (mounted) {
          if (success) {
            showTopToast(context, '导出成功: $fileName', isSuccess: true);
          } else {
            showTopToast(context, '导出已取消', isSuccess: false);
          }
        }
      } else {
        String? path = await FilePicker.platform.saveFile(
          dialogTitle: '选择保存位置',
          fileName: '${config.configName}_${DateTime.now().millisecondsSinceEpoch}.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (path == null) return;

        await _dataPersistence.exportSingleConfig(path, config);

        if (mounted) {
          showTopToast(context, '导出成功: $path', isSuccess: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, '导出失败: $e', isSuccess: false);
      }
    }
  }

  // 导入单个配置
  Future<void> _importSingleConfig() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result != null) {
        final filePath = result.files.single.path!;

        final file = File(filePath);
        final content = await file.readAsString();
        final jsonData = jsonDecode(content);

        // 检查是否是全局备份文件
        if (jsonData.containsKey('configs')) {
          if (mounted) {
            showTopToast(context, '这是全局备份文件，请在设置页面的"恢复备份数据"中导入', isSuccess: false);
          }
          return;
        }

        await _dataPersistence.importSingleConfig(filePath);
        if (mounted) {
          showTopToast(context, '导入成功', isSuccess: true);
          // 重新加载配置列表以实时显示导入的配置
          await _loadConfigs();
          // 同步更新通知栏、磁贴、小组件（导入可能影响默认配置）
          VntAppCall.updateWidgetAndTile(false);
          // 更新系统托盘（配置列表变化）
          SystemTrayManager().updateMenu();
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, '导入失败: $e', isSuccess: false);
      }
    }
  }

  // 显示删除确认对话框
  void _showDeleteDialog(NetworkConfig config, int index) {
    if (vntManager.hasConnectionItem(config.itemKey)) {
      showTopToast(context, '正在连接中的配置不能删除', isSuccess: false);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '删除配置',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        content: Text(
          '确定要删除 "${config.configName}" 吗？此操作不可恢复。',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _configs.removeAt(index);
              });
              _dataPersistence.saveData(_configs);
              // 通知设置页面刷新配置列表
              widget.onDataChanged?.call();
              // 同步更新通知栏、磁贴、小组件（删除可能影响默认配置）
              VntAppCall.updateWidgetAndTile(false);
              // 更新系统托盘（配置列表变化）
              SystemTrayManager().updateMenu();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // 显示断开连接确认对话框
  void _showDisconnectDialog(NetworkConfig config) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 警告图标
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // 标题
              Text(
                '确认断开连接',
                style: TextStyle(
                  fontSize: context.fontLarge,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // 提示文本
              Text(
                '是否断开与 \'${config.configName}\' 的组网连接?',
                style: TextStyle(
                  fontSize: context.fontBody,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // 按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        side: BorderSide(
                          color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);

                        // 执行断开连接
                        await vntManager.remove(config.itemKey);

                        // 更新状态
                        if (mounted) {
                          setState(() {});
                        }

                        // 更新 Android 磁贴和小组件
                        if (Platform.isAndroid) {
                          VntAppCall.updateWidgetAndTile(vntManager.hasConnection());
                        }

                        // 更新系统托盘
                        SystemTrayManager().updateMenu();
                        SystemTrayManager().updateTooltip();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('断开连接'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
