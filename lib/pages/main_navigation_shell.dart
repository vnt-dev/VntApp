import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/theme/theme_provider.dart';
import 'package:vnt_app/network_config.dart';
import 'package:vnt_app/data_persistence.dart';
import 'package:vnt_app/pages/dashboard_page.dart';
import 'package:vnt_app/pages/room_page.dart';
import 'package:vnt_app/pages/config_list_page.dart';
import 'package:vnt_app/pages/settings_page.dart';
import 'package:vnt_app/pages/about_page.dart';
import 'package:vnt_app/vnt/vnt_manager.dart';
import 'package:vnt_app/utils/toast_utils.dart';
import 'package:vnt_app/utils/responsive_utils.dart';
import 'dart:isolate';
import 'package:vnt_app/src/rust/api/vnt_api.dart';
import 'package:vnt_app/widgets/custom_title_bar.dart';
import 'package:vnt_app/system_tray_manager.dart';
import 'package:vnt_app/ios_vpn_service.dart';

/// 主导航框架 - 响应式布局，支持侧边栏和底部导航
class MainNavigationShell extends StatefulWidget {
  final VoidCallback? onThemeChanged;

  const MainNavigationShell({
    super.key,
    this.onThemeChanged,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;
  NetworkConfig? _selectedConfig;
  VoidCallback? _refreshConfigList;
  VoidCallback? _refreshSettings;

  // 导航项配置
  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: '仪表盘'),
    _NavItem(icon: Icons.meeting_room_outlined, activeIcon: Icons.meeting_room, label: '房间'),
    _NavItem(icon: Icons.folder_outlined, activeIcon: Icons.folder, label: '配置'),
    _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: '设置'),
    _NavItem(icon: Icons.info_outline, activeIcon: Icons.info, label: '关于'),
  ];

  @override
  void initState() {
    super.initState();
    _autoConnect();
  }

  /// 自动连接逻辑
  Future<void> _autoConnect() async {
    final dataPersistence = DataPersistence();

    // 检查是否从磁贴启动（仅 Android）
    bool isTileStart = false;
    if (Platform.isAndroid) {
      try {
        isTileStart = await VntAppCall.isTileStart();
      } catch (e) {
        debugPrint('检查磁贴启动状态失败: $e');
      }
    }

    // 如果不是从磁贴启动，检查自动连接设置
    if (!isTileStart) {
      final autoConnect = await dataPersistence.loadAutoConnect() ?? false;
      if (!autoConnect) return;
    }

    // 确定要连接的配置key
    String? targetKey;

    // 如果是从磁贴启动，先检查是否有磁贴配置key（长按磁贴选择的配置）
    if (isTileStart && Platform.isAndroid) {
      try {
        targetKey = await VntAppCall.getTileConfigKey();
        if (targetKey != null && targetKey.isNotEmpty) {
          debugPrint('从磁贴获取到选择的配置key: $targetKey');
        }
      } catch (e) {
        debugPrint('获取磁贴配置key失败: $e');
      }
    }

    // 如果没有磁贴配置key，使用默认配置
    if (targetKey == null || targetKey.isEmpty) {
      targetKey = await dataPersistence.loadDefaultKey();
      debugPrint('使用默认配置key: $targetKey');
    }

    if (targetKey == null || targetKey.isEmpty) {
      // 如果是从磁贴启动但没有配置，提示用户
      if (isTileStart && mounted) {
        showTopToast(context, '请先在配置页面设置默认配置', isSuccess: false);
      }
      return;
    }

    final configs = await dataPersistence.loadData();
    final config = configs.where((c) => c.itemKey == targetKey).firstOrNull;
    if (config == null) {
      if (isTileStart && mounted) {
        showTopToast(context, '配置不存在，请重新设置', isSuccess: false);
      }
      return;
    }

    // 直接连接选中的配置
    if (mounted) {
      _connectToConfigDirectly(config);
    }
  }

  /// 直接连接到指定配置（不跳转页面）
  Future<void> _connectToConfigDirectly(NetworkConfig config) async {
    if (vntManager.hasConnectionItem(config.itemKey)) {
      if (mounted) {
        showTopToast(context, '[${config.configName}] 已连接', isSuccess: true);
      }
      return;
    }

    if (vntManager.isConnecting()) {
      if (mounted) {
        showTopToast(context, '正在连接中，请稍后再试', isSuccess: false);
      }
      return;
    }

    // iOS使用VPN连接
    if (Platform.isIOS) {
      await _connectViaIOSVPN(config);
      return;
    }

    // 其他平台使用Rust直接连接
    // 显示连接中对话框
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text('正在连接 ${config.configName} ...'),
              ],
            ),
          );
        },
      );
    }

    final receivePort = ReceivePort();
    bool onece = true;

    receivePort.listen((msg) async {
      if (!mounted) return;

      if (msg is String) {
        if (msg == 'success') {
          if (onece) {
            onece = false;
            Navigator.of(context).pop(); // 关闭连接中对话框
            setState(() {
              _selectedConfig = config;
            });
            showTopToast(context, '[${config.configName}] 连接成功', isSuccess: true);
            // 连接成功，更新磁贴和小组件状态
            if (Platform.isAndroid) {
              VntAppCall.updateWidgetAndTile(true);
            }
            // 更新系统托盘
            await SystemTrayManager().updateMenu();
            await SystemTrayManager().updateTooltip();
          }
        } else if (msg == 'stop') {
          vntManager.remove(config.itemKey);
          if (onece) {
            onece = false;
            Navigator.of(context).pop(); // 关闭连接中对话框
          }
          // 统一显示"服务已停止"提示
          showTopToast(context, '[${config.configName}] 服务已停止', isSuccess: false);
          // 服务停止，更新磁贴和小组件状态
          if (Platform.isAndroid) {
            VntAppCall.updateWidgetAndTile(vntManager.hasConnection());
          }
          // 更新系统托盘
          await SystemTrayManager().updateMenu();
          await SystemTrayManager().updateTooltip();
        }
      } else if (msg is RustErrorInfo) {
        if (onece) {
          onece = false;
          Navigator.of(context).pop(); // 关闭连接中对话框
          vntManager.remove(config.itemKey);
        }
        _handleConnectionError(msg, config.configName);
        // 连接错误，更新磁贴和小组件状态
        if (Platform.isAndroid) {
          VntAppCall.updateWidgetAndTile(vntManager.hasConnection());
        }
        // 更新系统托盘
        await SystemTrayManager().updateMenu();
        await SystemTrayManager().updateTooltip();
      } else if (msg is RustConnectInfo) {
        if (onece && msg.count > BigInt.from(60)) {
          onece = false;
          Navigator.of(context).pop(); // 关闭连接中对话框
          vntManager.remove(config.itemKey);
          showTopToast(context, '[${config.configName}] 连接超时 ${msg.address}', isSuccess: false);
          // 连接超时，更新磁贴和小组件状态
          if (Platform.isAndroid) {
            VntAppCall.updateWidgetAndTile(vntManager.hasConnection());
          }
          // 更新系统托盘
          await SystemTrayManager().updateMenu();
          await SystemTrayManager().updateTooltip();
        }
      }
    });

    try {
      await vntManager.create(config, receivePort.sendPort);
    } catch (e) {
      debugPrint('dart catch e: $e');
      if (!mounted) return;

      Navigator.of(context).pop(); // 关闭连接中对话框
      var msg = e.toString();
      showTopToast(context, '连接失败 $msg', isSuccess: false);
    }
  }

  /// 处理连接错误
  void _handleConnectionError(RustErrorInfo errorInfo, String configName) {
    String errorMessage;
    switch (errorInfo.code) {
      case RustErrorType.tokenError:
        errorMessage = '[$configName] Token错误';
        break;
      case RustErrorType.disconnect:
        errorMessage = '[$configName] 连接断开';
        break;
      case RustErrorType.addressExhausted:
        errorMessage = '[$configName] 地址已用尽';
        break;
      case RustErrorType.ipAlreadyExists:
        errorMessage = '[$configName] IP已存在';
        break;
      case RustErrorType.invalidIp:
        errorMessage = '[$configName] 无效的IP';
        break;
      case RustErrorType.localIpExists:
        errorMessage = '[$configName] 本地IP已存在';
        break;
      default:
        errorMessage = '[$configName] 未知错误';
    }

    if (errorInfo.msg != null && errorInfo.msg!.isNotEmpty) {
      errorMessage += ': ${errorInfo.msg}';
    }

    if (mounted) {
      showTopToast(context, errorMessage, isSuccess: false);
    }
  }

  /// iOS VPN连接
  Future<void> _connectViaIOSVPN(NetworkConfig config) async {
    try {
      debugPrint('[iOS VPN] Starting VPN connection for: ${config.configName}');
      
      // 保存配置到App Group
      await IOSVPNService.saveConfig(
        serverAddress: config.serverAddress,
        token: config.token,
      );
      
      // 启动VPN
      final success = await IOSVPNService.startVPN(
        serverAddress: config.serverAddress,
        token: config.token,
        deviceName: config.deviceName,
      );
      
      if (success) {
        // iOS VPN连接成功，更新UI状态
        setState(() {
          _selectedConfig = config;
        });
        
        if (mounted) {
          showTopToast(context, '[${config.configName}] VPN连接成功', isSuccess: true);
        }
        
        debugPrint('[iOS VPN] Connection successful');
      } else {
        if (mounted) {
          showTopToast(context, '[${config.configName}] VPN连接失败，请确认已添加VPN权限', isSuccess: false);
        }
        debugPrint('[iOS VPN] Connection failed');
      }
    } catch (e) {
      debugPrint('[iOS VPN] Connection error: $e');
      if (mounted) {
        showTopToast(context, '[${config.configName}] VPN连接异常: $e', isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;
    final isMediumScreen = screenWidth > 600 && screenWidth <= 800;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: Column(
        children: [
          // 自定义标题栏（桌面平台）
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
            const CustomTitleBar(),

          // 主内容区域
          Expanded(
            child: Row(
              children: [
                // 侧边导航栏（宽屏显示）
                if (isWideScreen || isMediumScreen)
                  _buildSideNavigation(isDark, isWideScreen),

                // 主内容区域
                Expanded(
                  child: _buildPageContent(),
                ),
              ],
            ),
          ),
        ],
      ),
      // 底部导航栏（窄屏显示）
      bottomNavigationBar: (!isWideScreen && !isMediumScreen)
          ? _buildBottomNavigation(isDark)
          : null,
    );
  }

  Widget _buildSideNavigation(bool isDark, bool isExpanded) {
    final primaryColor = Theme.of(context).primaryColor;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // 根据屏幕高度自动缩放所有尺寸，避免太小或太大出现滚动
    // 基准高度：700px，高度越小缩放比例越小，高度越大缩放比例越大
    double heightScale;
    if (screenHeight >= 900) {
      heightScale = 1.2;  // 超大屏幕：放大20%
    } else if (screenHeight >= 700) {
      heightScale = 1.0;  // 标准屏幕：100%
    } else if (screenHeight >= 600) {
      heightScale = 0.85; // 中等屏幕：缩小15%
    } else if (screenHeight >= 500) {
      heightScale = 0.75; // 小屏幕：缩小25%
    } else {
      heightScale = 0.65; // 超小屏幕：缩小35%
    }

    // 根据屏幕高度动态调整导航栏宽度
    final sideNavWidth = 100.0 * heightScale;

    // 所有尺寸都基于高度缩放比例
    final logoPadding = 14.0 * heightScale;
    final logoSize = 48.0 * heightScale;
    final logoRadius = 12.0 * heightScale;
    final logoIconSize = 28.0 * heightScale;
    final logoSpacing = 8.0 * heightScale;
    final logoFontSize = 14.0 * heightScale;
    final navSpacing = 20.0 * heightScale;
    final navItemPadding = 8.0 * heightScale;
    final navItemVerticalPadding = 12.0 * heightScale;
    final navIconSize = 24.0 * heightScale;
    final navFontSize = 12.0 * heightScale;
    final navItemSpacing = 4.0 * heightScale;
    final navItemBottomMargin = 8.0 * heightScale;
    final themeTogglePadding = 8.0 * heightScale;
    final themeToggleVerticalPadding = 12.0 * heightScale;
    final bottomSpacing = 14.0 * heightScale;

    return Container(
      width: sideNavWidth,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Logo 区域
            Container(
              padding: EdgeInsets.all(logoPadding),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(logoRadius),
                    child: Image.asset(
                      'assets/ic_launcher.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // 如果图片加载失败，显示默认图标
                        return Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, primaryColor.withOpacity(0.7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(logoRadius),
                          ),
                          child: Icon(
                            Icons.hub,
                            color: Colors.white,
                            size: logoIconSize,
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: logoSpacing),
                  Text(
                    'VNT',
                    style: TextStyle(
                      fontSize: logoFontSize,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: navSpacing),

            // 导航项
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: navItemPadding),
                itemCount: _navItems.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedIndex == index;
                  final item = _navItems[index];

                  return Padding(
                    padding: EdgeInsets.only(bottom: navItemBottomMargin),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _selectedIndex = index),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: navItemPadding,
                            vertical: navItemVerticalPadding,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: primaryColor.withOpacity(0.3))
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? item.activeIcon : item.icon,
                                color: isSelected
                                    ? primaryColor
                                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                size: navIconSize,
                              ),
                              SizedBox(height: navItemSpacing),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: navFontSize,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected
                                      ? primaryColor
                                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 底部主题切换
            Padding(
              padding: EdgeInsets.symmetric(horizontal: themeTogglePadding),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final themeProvider = ThemeProvider.of(context);
                    if (themeProvider != null) {
                      themeProvider.setThemeMode(
                        isDark ? ThemeMode.light : ThemeMode.dark,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: themeTogglePadding,
                      vertical: themeToggleVerticalPadding,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          size: navIconSize,
                        ),
                        SizedBox(height: navItemSpacing),
                        Text(
                          isDark ? '日间' : '暗黑',
                          style: TextStyle(
                            fontSize: navFontSize,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: bottomSpacing),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = _selectedIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected
                              ? primaryColor
                              : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: context.fontXSmall,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? primaryColor
                                : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    final themeProvider = ThemeProvider.of(context);

    // 使用 IndexedStack 保持页面状态，避免切换时重建页面
    return IndexedStack(
      index: _selectedIndex,
      children: [
        // 0: 仪表盘
        DashboardPage(
          onNavigateToConfig: () => setState(() => _selectedIndex = 2),
          onNavigateToSettings: () => setState(() => _selectedIndex = 3),
          onDisconnect: () async {
            // 获取所有连接的key
            final keys = vntManager.map.keys.toList();

            // 断开所有连接
            for (var key in keys) {
              await vntManager.remove(key);
            }

            if (mounted) {
              setState(() => _selectedConfig = null);
            }

            // 更新 Android 磁贴和小组件
            if (Platform.isAndroid) {
              VntAppCall.updateWidgetAndTile(false);
            }

            // 更新系统托盘
            await SystemTrayManager().updateMenu();
            await SystemTrayManager().updateTooltip();
          },
          onConnect: () async {
            // 尝试连接默认配置
            debugPrint('Dashboard onConnect called');
            final dataPersistence = DataPersistence();
            final defaultKey = await dataPersistence.loadDefaultKey();
            debugPrint('Default key: $defaultKey');
            if (defaultKey != null && defaultKey.isNotEmpty) {
              final configs = await dataPersistence.loadData();
              final config = configs.where((c) => c.itemKey == defaultKey).firstOrNull;
              debugPrint('Found config: ${config?.configName}');
              if (config != null) {
                // 直接连接，不跳转页面
                debugPrint('Connecting to default config: ${config.configName}');
                _connectToConfigDirectly(config);
                return;
              }
            }
            // 没有默认配置，跳转到配置页面
            debugPrint('No default config found, navigating to config page');
            setState(() => _selectedIndex = 2);
          },
        ),
        // 1: 房间
        RoomPage(
          selectedConfig: _selectedConfig,
          onDisconnect: _selectedConfig != null
              ? () {
                  setState(() => _selectedConfig = null);
                }
              : null,
        ),
        // 2: 配置
        ConfigListPage(
          onConfigSelected: (config) {
            setState(() {
              _selectedConfig = config;
              _selectedIndex = 1; // 跳转到房间页面
            });
          },
          onRefreshCallback: (callback) {
            _refreshConfigList = callback;
          },
          onDataChanged: () {
            // 当配置数据改变时，刷新设置页面
            _refreshSettings?.call();
          },
        ),
        // 3: 设置
        SettingsPage(
          themeMode: themeProvider?.themeMode ?? ThemeMode.system,
          onThemeModeChanged: (mode) {
            themeProvider?.setThemeMode(mode);
          },
          onDataChanged: () {
            // 当设置页面的数据改变时，刷新配置列表
            _refreshConfigList?.call();
          },
          onRefreshCallback: (callback) {
            _refreshSettings = callback;
          },
        ),
        // 4: 关于
        const AboutPage(),
      ],
    );
  }
}

/// 导航项数据类
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
