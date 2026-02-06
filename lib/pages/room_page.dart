import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/network_config.dart';
import 'package:vnt_app/vnt/vnt_manager.dart';
import 'package:vnt_app/src/rust/api/vnt_api.dart';
import 'package:vnt_app/utils/toast_utils.dart';
import 'package:vnt_app/utils/responsive_utils.dart';
import 'package:json2yaml/json2yaml.dart';

/// 房间页面 - 显示已连接网络的设备列表、聊天、路由
class RoomPage extends StatefulWidget {
  final NetworkConfig? selectedConfig;
  final VoidCallback? onDisconnect;

  const RoomPage({
    super.key,
    this.selectedConfig,
    this.onDisconnect,
  });

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> with SingleTickerProviderStateMixin {
  Timer? _timer;
  List<RustPeerClientInfo> _devices = [];
  String? _currentIp;
  late TabController _tabController;

  // 延迟历史数据 - 用于绘制延迟趋势图
  final Map<String, List<int>> _latencyHistory = {};
  final int _maxHistoryLength = 30; // 保留最近30个数据点

  // 清空延迟历史数据（仅在手动断开连接时调用）
  void _clearLatencyHistory() {
    _latencyHistory.clear();
  }

  // 设备分组展开状态
  bool _onlineDevicesExpanded = true;
  bool _offlineDevicesExpanded = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _updateDevices();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateDevices();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _updateDevices() {
    if (!mounted) return;

    final allVnts = vntManager.map;
    List<RustPeerClientInfo> devices = [];
    String? currentIp;

    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        devices.addAll(vntBox.peerDeviceList());
        currentIp ??= vntBox.currentDevice()['virtualIp'];

        // 更新延迟历史数据
        for (var device in devices) {
          final route = vntBox.route(device.virtualIp);
          if (route != null && route.rt > 0 && route.rt < 9999) {
            if (!_latencyHistory.containsKey(device.virtualIp)) {
              _latencyHistory[device.virtualIp] = [];
            }
            _latencyHistory[device.virtualIp]!.add(route.rt);

            // 保持历史数据长度不超过最大值
            if (_latencyHistory[device.virtualIp]!.length > _maxHistoryLength) {
              _latencyHistory[device.virtualIp]!.removeAt(0);
            }
          }
        }
      }
    }

    // 按IP地址排序（从小到大）
    devices.sort((a, b) => _compareIpAddresses(a.virtualIp, b.virtualIp));

    setState(() {
      _devices = devices;
      _currentIp = currentIp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final hasConnection = vntManager.size() > 0;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 页面头部
            Padding(
              padding: EdgeInsets.all(isWideScreen ? context.spacingXLarge : context.spacingMedium),
              child: _buildHeader(isDark, isWideScreen, hasConnection),
            ),

            // Tab导航栏
            if (hasConnection)
              Container(
                margin: EdgeInsets.symmetric(horizontal: isWideScreen ? context.spacingXLarge : context.spacingMedium),
                child: TabBar(
                  controller: _tabController,
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(
                      color: primaryColor,
                      width: context.w(3),
                    ),
                    insets: EdgeInsets.symmetric(horizontal: isWideScreen ? context.spacing(40) : context.spacingLarge),
                  ),
                  labelColor: primaryColor,
                  unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  dividerColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  labelStyle: TextStyle(
                    fontSize: context.buttonFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: context.buttonFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: '设备'),
                    Tab(text: '聊天室'),
                    Tab(text: '路由'),
                  ],
                ),
              ),

            // Tab内容区域
            Expanded(
              child: hasConnection
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDevicesTab(isDark, isWideScreen),
                        _buildChatTab(isDark),
                        _buildRoutesTab(isDark, isWideScreen),
                      ],
                    )
                  : _buildNotConnectedView(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isWideScreen, bool hasConnection) {
    final primaryColor = Theme.of(context).primaryColor;
    // 获取当前连接的配置名称
    String? configName;
    if (hasConnection) {
      final allVnts = vntManager.map;
      for (var entry in allVnts.entries) {
        final vntBox = entry.value;
        if (!vntBox.isClosed()) {
          final netConfig = vntBox.getNetConfig();
          if (netConfig != null) {
            configName = netConfig.configName;
          }
          break;
        }
      }
    }

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
            Icons.meeting_room_outlined,
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
                '房间',
                style: TextStyle(
                  fontSize: context.fontXLarge,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              Text(
                hasConnection
                    ? (configName != null ? '已连接 $configName' : '已连接网络')
                    : '未连接',
                style: TextStyle(
                  fontSize: context.fontBody,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
        // 顶部图标栏
        if (hasConnection) ...[
          // 当前设备信息图标
          IconButton(
            onPressed: () => _showCurrentDeviceDialog(),
            icon: Icon(
              Icons.computer,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
            tooltip: '当前设备信息',
          ),
          // 网络配置详情图标
          IconButton(
            onPressed: () => _showConfigDialog(),
            icon: Icon(
              Icons.settings,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
            tooltip: '组网配置详情',
          ),
          // 断开连接图标
          IconButton(
            onPressed: () => _showDisconnectDialog(),
            icon: Icon(
              Icons.power_settings_new,
              color: Colors.red[400],
            ),
            tooltip: '断开连接',
          ),
        ],
      ],
    );
  }

  // 设备Tab
  Widget _buildDevicesTab(bool isDark, bool isWideScreen) {
    final primaryColor = Theme.of(context).primaryColor;
    // 分离在线和离线设备
    final onlineDevices = _devices.where((device) => device.status == 'Online').toList();
    final offlineDevices = _devices.where((device) => device.status != 'Online').toList();

    return RefreshIndicator(
      onRefresh: () async => _updateDevices(),
      color: primaryColor,
      child: _devices.isEmpty
          ? ListView(
              padding: EdgeInsets.all(isWideScreen ? context.spacingXLarge : context.spacingMedium),
              children: [_buildNoDevicesView(isDark)],
            )
          : ListView(
              padding: EdgeInsets.all(isWideScreen ? context.spacingXLarge : context.spacingMedium),
              children: [
                // 在线设备分组
                if (onlineDevices.isNotEmpty)
                  _buildDeviceGroup(
                    title: '在线设备',
                    count: onlineDevices.length,
                    devices: onlineDevices,
                    isExpanded: _onlineDevicesExpanded,
                    onToggle: () {
                      setState(() {
                        _onlineDevicesExpanded = !_onlineDevicesExpanded;
                      });
                    },
                    isDark: isDark,
                  ),

                // 离线设备分组
                if (offlineDevices.isNotEmpty) ...[
                  if (onlineDevices.isNotEmpty) SizedBox(height: context.spacingMedium),
                  _buildDeviceGroup(
                    title: '离线设备',
                    count: offlineDevices.length,
                    devices: offlineDevices,
                    isExpanded: _offlineDevicesExpanded,
                    onToggle: () {
                      setState(() {
                        _offlineDevicesExpanded = !_offlineDevicesExpanded;
                      });
                    },
                    isDark: isDark,
                  ),
                ],
              ],
            ),
    );
  }

  // 构建设备分组
  Widget _buildDeviceGroup({
    required String title,
    required int count,
    required List<RustPeerClientInfo> devices,
    required bool isExpanded,
    required VoidCallback onToggle,
    required bool isDark,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题栏
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(context.spacingXSmall),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacingSmall,
              vertical: context.spacingSmall,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(context.spacingXSmall),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  size: context.iconMedium,
                ),
                SizedBox(width: context.spacingXSmall),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: context.fontMedium,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                SizedBox(width: context.spacingXSmall),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacingXSmall,
                    vertical: context.spacingXXSmall,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(context.cardRadius),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: context.fontSmall,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 设备列表
        if (isExpanded) ...[
          SizedBox(height: context.cardSpacing),
          ...devices.map((device) => Padding(
            padding: EdgeInsets.only(bottom: context.cardSpacing),
            child: _buildDeviceCard(device, isDark),
          )),
        ],
      ],
    );
  }

  // 聊天Tab（暂时显示占位内容）
  Widget _buildChatTab(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: context.w(64),
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
          SizedBox(height: context.spacingMedium),
          Text(
            '聊天功能',
            style: TextStyle(
              fontSize: context.fontLarge,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          SizedBox(height: context.spacingXSmall),
          Text(
            '即将推出',
            style: TextStyle(
              fontSize: context.fontBody,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 路由Tab
  Widget _buildRoutesTab(bool isDark, bool isWideScreen) {
    final primaryColor = Theme.of(context).primaryColor;
    return RefreshIndicator(
      onRefresh: () async => _updateDevices(),
      color: primaryColor,
      child: ListView(
        padding: EdgeInsets.all(isWideScreen ? context.spacingXLarge : context.spacingMedium),
        children: _buildRouteList(isDark),
      ),
    );
  }

  // 构建路由列表
  List<Widget> _buildRouteList(bool isDark) {
    // 收集所有路由信息
    List<Map<String, dynamic>> allRoutes = [];

    final allVnts = vntManager.map;
    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        final routeList = vntBox.routeList();
        for (var routeEntry in routeList) {
          final destination = routeEntry.$1;
          final routes = routeEntry.$2;

          for (var route in routes) {
            allRoutes.add({
              'destination': destination,
              'route': route,
            });
          }
        }
      }
    }

    // 按IP地址排序（从小到大）
    allRoutes.sort((a, b) {
      return _compareIpAddresses(a['destination'], b['destination']);
    });

    // 构建Widget列表
    List<Widget> routeWidgets = [];
    for (var routeData in allRoutes) {
      routeWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRouteCard(routeData['destination'], routeData['route'], isDark),
        ),
      );
    }

    if (routeWidgets.isEmpty) {
      routeWidgets.add(_buildNoRoutesView(isDark));
    }

    return routeWidgets;
  }

  // 根据延迟值获取颜色
  Color _getLatencyColor(int latency) {
    if (latency <= 50) {
      return Colors.green;
    } else if (latency <= 100) {
      return Colors.lightGreen;
    } else if (latency <= 200) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // IP地址比较函数 - 用于排序
  int _compareIpAddresses(String ip1, String ip2) {
    try {
      // 分割IP地址的各个部分
      final parts1 = ip1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final parts2 = ip2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // 逐段比较
      for (int i = 0; i < 4 && i < parts1.length && i < parts2.length; i++) {
        if (parts1[i] != parts2[i]) {
          return parts1[i].compareTo(parts2[i]);
        }
      }
      return 0;
    } catch (e) {
      // 如果解析失败，使用字符串比较
      return ip1.compareTo(ip2);
    }
  }

  // 重新设计的设备卡片 - 根据UI设计图
  Widget _buildDeviceCard(RustPeerClientInfo device, bool isDark) {
    final isOnline = device.status == 'Online';
    final primaryColor = Theme.of(context).primaryColor;

    // 获取路由信息
    String p2pRelay = '';
    int rt = 0;
    String natType = '';
    String publicIp = '';

    final allVnts = vntManager.map;
    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        final route = vntBox.route(device.virtualIp);
        if (route != null) {
          p2pRelay = route.metric == 1 ? 'P2P' : '中继';
          rt = route.rt;
        }

        // 获取NAT信息
        final natInfo = vntBox.peerNatInfo(device.virtualIp);
        if (natInfo != null) {
          natType = natInfo.natType;
          if (natInfo.publicIps.isNotEmpty) {
            publicIp = natInfo.publicIps.first;
          }
        }
        break;
      }
    }

    // 获取延迟历史数据
    final latencyData = _latencyHistory[device.virtualIp] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: isOnline
            ? (isDark ? AppTheme.darkCardBackground : const Color(0xFFF5F5F5))
            : (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(context.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDeviceDetails(device),
          borderRadius: BorderRadius.circular(context.cardRadius),
          child: Padding(
            padding: ResponsiveUtils.padding(context, all: context.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：设备图标、名称、IP、P2P/中继标签
                Row(
                  children: [
                    // 设备图标
                    Container(
                      width: context.listItemIconContainerSize,
                      height: context.listItemIconContainerSize,
                      decoration: BoxDecoration(
                        color: isOnline ? primaryColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(context.cardRadius),
                      ),
                      child: Icon(
                        Icons.computer,
                        color: isOnline ? primaryColor : Colors.grey,
                        size: context.iconMedium,
                      ),
                    ),
                    SizedBox(width: context.spacingSmall),
                    // 设备名称和IP
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            style: TextStyle(
                              fontSize: context.fontMedium,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: context.spacingXXSmall),
                          Row(
                            children: [
                              Text(
                                device.virtualIp,
                                style: TextStyle(
                                  fontSize: context.fontSmall,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                              ),
                              SizedBox(width: context.spacingXXSmall),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: device.virtualIp));
                                  showTopToast(context, '${device.virtualIp} 已复制', isSuccess: true);
                                },
                                child: Icon(
                                  Icons.copy,
                                  size: context.iconXSmall,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // P2P/中继标签
                    if (p2pRelay.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spacingSmall,
                          vertical: context.spacingXSmall / 2,
                        ),
                        decoration: BoxDecoration(
                          color: p2pRelay == 'P2P'
                              ? Colors.green.withOpacity(0.15)
                              : Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(context.spacingXSmall),
                        ),
                        child: Text(
                          p2pRelay,
                          style: TextStyle(
                            fontSize: context.fontSmall,
                            fontWeight: FontWeight.w600,
                            color: p2pRelay == 'P2P'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: context.spacingSmall),

                // 延迟趋势图
                if (latencyData.isNotEmpty)
                  Container(
                    height: context.w(60),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(context.spacingXSmall),
                    ),
                    child: CustomPaint(
                      painter: _LatencyChartPainter(latencyData, primaryColor),
                      child: Container(),
                    ),
                  ),

                SizedBox(height: context.spacingSmall),

                // 底部信息行：当前延迟、状态、NAT类型、公网IP
                Row(
                  children: [
                    // 当前延迟
                    if (rt > 0 && rt < 9999)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spacingXSmall,
                          vertical: context.spacingXXSmall,
                        ),
                        decoration: BoxDecoration(
                          color: _getLatencyColor(rt).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(context.spacingXSmall / 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.speed,
                              size: context.iconXSmall,
                              color: _getLatencyColor(rt),
                            ),
                            SizedBox(width: context.spacingXXSmall),
                            Text(
                              '$rt ms',
                              style: TextStyle(
                                fontSize: context.fontXSmall,
                                fontWeight: FontWeight.w600,
                                color: _getLatencyColor(rt),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(width: 8),

                    // 状态指示
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.signal_cellular_alt,
                          size: 14,
                          color: isOnline ? primaryColor : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOnline ? '在线' : '离线',
                          style: TextStyle(
                            fontSize: context.fontXSmall,
                            color: isOnline ? primaryColor : Colors.grey,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // NAT类型图标
                    if (natType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              natType.contains('Cone') ? Icons.hub : Icons.device_hub,
                              size: 12,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              natType,
                              style: TextStyle(
                                fontSize: context.fontXSmall,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(width: 8),

                    // 公网IP
                    if (publicIp.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.public,
                              size: 12,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              publicIp.length > 15 ? '${publicIp.substring(0, 12)}...' : publicIp,
                              style: TextStyle(
                                fontSize: context.fontXSmall,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 路由卡片
  Widget _buildRouteCard(String destination, RustRoute route, bool isDark) {
    final isP2P = route.metric == 1;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 目标IP和P2P/中继标签
          Row(
            children: [
              Icon(
                Icons.route,
                size: 20,
                color: primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  destination,
                  style: TextStyle(
                    fontSize: context.fontMedium,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isP2P
                      ? Colors.green.withOpacity(0.15)
                      : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isP2P ? 'P2P' : '中继',
                  style: TextStyle(
                    fontSize: context.fontXSmall,
                    fontWeight: FontWeight.w600,
                    color: isP2P ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Metric和RT信息
          Row(
            children: [
              // Metric
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Metric',
                        style: TextStyle(
                          fontSize: context.fontXSmall,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${route.metric}',
                        style: TextStyle(
                          fontSize: context.fontMedium,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // RT
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RT',
                        style: TextStyle(
                          fontSize: context.fontXSmall,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${route.rt}',
                        style: TextStyle(
                          fontSize: context.fontMedium,
                          fontWeight: FontWeight.w600,
                          color: _getLatencyColor(route.rt),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 接口地址
          Row(
            children: [
              Icon(
                Icons.router,
                size: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  route.addr,
                  style: TextStyle(
                    fontSize: context.fontSmall,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 无路由视图
  Widget _buildNoRoutesView(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.route,
            size: 48,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无路由信息',
            style: TextStyle(
              fontSize: context.fontMedium,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionType(RustPeerClientInfo device, bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    // 获取设备的路由信息来判断连接类型
    String label = '未知';
    Color color = AppTheme.lightTextSecondary;

    // 尝试从 vntManager 获取路由信息
    final allVnts = vntManager.map;
    for (var entry in allVnts.entries) {
      if (entry.value.isClosed()) continue;
      final route = entry.value.route(device.virtualIp);
      if (route != null) {
        final protocol = route.protocol.toLowerCase();
        if (protocol.contains('p2p') || protocol.contains('udp') || protocol.contains('tcp')) {
          label = 'P2P';
          color = AppTheme.successColor;
        } else if (protocol.contains('relay') || protocol.contains('server')) {
          label = '中继';
          color = AppTheme.warningColor;
        } else {
          label = route.protocol;
          color = primaryColor;
        }
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: context.fontSmall,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildNotConnectedView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.link_off,
              size: 40,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '未加入任何组网',
            style: TextStyle(
              fontSize: context.fontLarge,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请先在配置页面连接一个网络',
            style: TextStyle(
              fontSize: context.fontBody,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDevicesView(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.devices_other,
            size: 48,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无其他设备',
            style: TextStyle(
              fontSize: context.fontMedium,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '等待其他设备加入网络',
            style: TextStyle(
              fontSize: context.fontBody,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetails(RustPeerClientInfo device) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = device.status == 'Online';
    final primaryColor = Theme.of(context).primaryColor;

    // 获取设备的详细信息
    String? natType;
    List<String> publicIps = [];
    String? localIpv4;
    String? ipv6;
    List<RustRoute> routeList = [];
    int currentRt = 0;
    double avgLatency = 0;

    final allVnts = vntManager.map;
    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        // 获取NAT信息
        final natInfo = vntBox.peerNatInfo(device.virtualIp);
        if (natInfo != null) {
          natType = natInfo.natType;
          publicIps = natInfo.publicIps;
          localIpv4 = natInfo.localIpv4;
          ipv6 = natInfo.ipv6;
        }

        // 获取路由信息
        final allRouteList = vntBox.routeList();
        for (var routes in allRouteList) {
          if (routes.$1 == device.virtualIp) {
            routeList = routes.$2;
            break;
          }
        }

        // 获取当前延迟
        final route = vntBox.route(device.virtualIp);
        if (route != null && route.rt > 0 && route.rt < 9999) {
          currentRt = route.rt;
        }

        break;
      }
    }

    // 按路由地址排序（从小到大）
    routeList.sort((a, b) => _compareIpAddresses(a.addr, b.addr));

    // 计算平均延迟
    final latencyData = _latencyHistory[device.virtualIp] ?? [];
    if (latencyData.isNotEmpty) {
      avgLatency = latencyData.reduce((a, b) => a + b) / latencyData.length;
    }

    showDialog(
      context: context,
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final isLandscape = screenSize.width > screenSize.height;
        final isMobile = screenSize.width < 600;

        // 根据屏幕方向和尺寸计算弹窗尺寸 - 移动端使用更紧凑的高度
        final dialogMaxWidth = isLandscape ? screenSize.width * 0.6 : screenSize.width * 0.9;
        final dialogMaxHeight = isMobile
            ? (isLandscape ? screenSize.height * 0.85 : screenSize.height * 0.7)
            : (isLandscape ? screenSize.height * 0.9 : screenSize.height * 0.8);
        final headerPadding = isLandscape ? 10.0 : (isMobile ? 14.0 : 20.0);
        final contentPadding = isLandscape ? 10.0 : (isMobile ? 14.0 : 20.0);
        final iconSize = isLandscape ? 38.0 : (isMobile ? 48.0 : 56.0);
        final titleFontSize = isLandscape ? 14.0 : (isMobile ? 16.0 : 18.0);
        final subtitleFontSize = isLandscape ? 11.0 : (isMobile ? 12.0 : 14.0);

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: dialogMaxHeight,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
              borderRadius: BorderRadius.circular(isLandscape ? 16 : 24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 头部
                Container(
                  padding: EdgeInsets.all(headerPadding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.15),
                        primaryColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(isLandscape ? 16 : 24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(isLandscape ? 10 : 14),
                        ),
                        child: Icon(
                          Icons.computer,
                          color: primaryColor,
                          size: iconSize * 0.5,
                        ),
                      ),
                      SizedBox(width: isLandscape ? 10 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                              ),
                            ),
                            SizedBox(height: isLandscape ? 2 : 4),
                            Text(
                              device.virtualIp,
                              style: TextStyle(
                                fontSize: subtitleFontSize,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          size: isLandscape ? 20 : 24,
                          color: primaryColor,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // 内容区域
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(contentPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 延迟监控
                        _buildSectionTitle(isDark, Icons.speed, '延迟概览', isLandscape, isMobile),
                        SizedBox(height: isLandscape ? 6 : (isMobile ? 8 : 12)),
                        Container(
                          padding: EdgeInsets.all(isLandscape ? 10 : (isMobile ? 12 : 16)),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                          ),
                          child: Column(
                            children: [
                              // 延迟图表
                              if (latencyData.isNotEmpty)
                                Container(
                                  height: isLandscape ? 60 : (isMobile ? 70 : 100),
                                  margin: EdgeInsets.only(bottom: isLandscape ? 8 : (isMobile ? 10 : 16)),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEEEEEE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Stack(
                                    children: [
                                      CustomPaint(
                                        painter: _LatencyChartPainter(latencyData, primaryColor),
                                        child: Container(),
                                      ),
                                      Positioned(
                                        top: isLandscape ? 3 : (isMobile ? 4 : 8),
                                        right: isLandscape ? 3 : (isMobile ? 4 : 8),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isLandscape ? 5 : (isMobile ? 6 : 8),
                                            vertical: isLandscape ? 2 : (isMobile ? 3 : 4),
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$currentRt ms',
                                            style: TextStyle(
                                              fontSize: isLandscape ? 9 : (isMobile ? 10 : 12),
                                              fontWeight: FontWeight.w600,
                                              color: _getLatencyColor(currentRt),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // 延迟统计
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.trending_down,
                                          size: isLandscape ? 14 : (isMobile ? 16 : 20),
                                          color: primaryColor,
                                        ),
                                        SizedBox(height: isLandscape ? 2 : (isMobile ? 3 : 4)),
                                        Text(
                                          '$currentRt ms',
                                          style: TextStyle(
                                            fontSize: isLandscape ? 12 : (isMobile ? 13 : 16),
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                          ),
                                        ),
                                        SizedBox(height: isLandscape ? 1 : 2),
                                        Text(
                                          '当前延迟',
                                          style: TextStyle(
                                            fontSize: isLandscape ? 9 : (isMobile ? 10 : 12),
                                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.bar_chart,
                                          size: isLandscape ? 14 : (isMobile ? 16 : 20),
                                          color: primaryColor,
                                        ),
                                        SizedBox(height: isLandscape ? 2 : (isMobile ? 3 : 4)),
                                        Text(
                                          '${avgLatency.toStringAsFixed(1)} ms',
                                          style: TextStyle(
                                            fontSize: isLandscape ? 12 : (isMobile ? 13 : 16),
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                          ),
                                        ),
                                        SizedBox(height: isLandscape ? 1 : 2),
                                        Text(
                                          '平均延迟',
                                          style: TextStyle(
                                            fontSize: isLandscape ? 9 : (isMobile ? 10 : 12),
                                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isLandscape ? 10 : (isMobile ? 12 : 20)),

                        // NAT信息
                        _buildSectionTitle(isDark, Icons.hub, 'NAT 信息', isLandscape, isMobile),
                        SizedBox(height: isLandscape ? 6 : (isMobile ? 8 : 12)),
                        Container(
                          padding: EdgeInsets.all(isLandscape ? 10 : (isMobile ? 12 : 16)),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                          ),
                          child: Column(
                            children: [
                              _buildInfoRow(isDark, 'NAT 类型', natType ?? '-', isLandscape: isLandscape, isMobile: isMobile),
                              if (publicIps.isNotEmpty) ...[
                                SizedBox(height: isLandscape ? 5 : (isMobile ? 6 : 8)),
                                _buildInfoRow(isDark, '公网 IP', publicIps.first, showCopyButton: true, isLandscape: isLandscape, isMobile: isMobile),
                              ],
                              if (localIpv4 != null && localIpv4.isNotEmpty) ...[
                                SizedBox(height: isLandscape ? 5 : (isMobile ? 6 : 8)),
                                _buildInfoRow(isDark, '本地 IPv4', localIpv4, showCopyButton: true, isLandscape: isLandscape, isMobile: isMobile),
                              ],
                              if (ipv6 != null && ipv6.isNotEmpty) ...[
                                SizedBox(height: isLandscape ? 5 : (isMobile ? 6 : 8)),
                                _buildInfoRow(isDark, 'IPv6', ipv6, showCopyButton: true, isLandscape: isLandscape, isMobile: isMobile),
                              ],
                            ],
                          ),
                        ),

                        SizedBox(height: isLandscape ? 10 : (isMobile ? 12 : 20)),

                        // 路由信息
                        _buildSectionTitle(isDark, Icons.route, '路由信息', isLandscape, isMobile),
                        SizedBox(height: isLandscape ? 6 : (isMobile ? 8 : 12)),
                        if (routeList.isEmpty)
                          Container(
                            padding: EdgeInsets.all(isLandscape ? 10 : (isMobile ? 12 : 16)),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                            ),
                            child: Center(
                              child: Text(
                                '暂无路由信息',
                                style: TextStyle(
                                  fontSize: isLandscape ? 11 : (isMobile ? 12 : 14),
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          ...routeList.map((route) {
                            final isP2P = route.metric == 1;
                            return Container(
                              margin: EdgeInsets.only(bottom: isLandscape ? 5 : (isMobile ? 6 : 8)),
                              padding: EdgeInsets.all(isLandscape ? 8 : (isMobile ? 10 : 12)),
                              decoration: BoxDecoration(
                                color: isP2P
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // P2P/中继标签
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isLandscape ? 5 : (isMobile ? 6 : 8),
                                          vertical: isLandscape ? 2 : (isMobile ? 3 : 4),
                                        ),
                                        decoration: BoxDecoration(
                                          color: isP2P
                                              ? Colors.green.withOpacity(0.2)
                                              : Colors.orange.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isP2P ? 'P2P' : 'Relay',
                                          style: TextStyle(
                                            fontSize: isLandscape ? 8 : (isMobile ? 9 : 11),
                                            fontWeight: FontWeight.w600,
                                            color: isP2P ? Colors.green : Colors.orange,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isLandscape ? 5 : (isMobile ? 6 : 8)),
                                      Text(
                                        'Metric: ${route.metric} | RT: ${route.rt}ms',
                                        style: TextStyle(
                                          fontSize: isLandscape ? 9 : (isMobile ? 10 : 12),
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isLandscape ? 3 : (isMobile ? 4 : 6)),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.router,
                                        size: isLandscape ? 11 : (isMobile ? 12 : 14),
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                      ),
                                      SizedBox(width: isLandscape ? 3 : (isMobile ? 4 : 6)),
                                      Expanded(
                                        child: Text(
                                          route.addr,
                                          style: TextStyle(
                                            fontSize: isLandscape ? 8 : (isMobile ? 9 : 11),
                                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(bool isDark, IconData icon, String title, [bool isLandscape = false, bool isMobile = false]) {
    return Row(
      children: [
        Icon(
          icon,
          size: isLandscape ? 14 : (isMobile ? 15 : 18),
          color: const Color(0xFF81C784),
        ),
        SizedBox(width: isLandscape ? 5 : (isMobile ? 6 : 8)),
        Text(
          title,
          style: TextStyle(
            fontSize: isLandscape ? 12 : (isMobile ? 13 : 15),
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(bool isDark, String label, String value, {bool showCopyButton = false, bool isLandscape = false, bool isMobile = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLandscape ? 10 : (isMobile ? 11 : 13),
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isLandscape ? 10 : (isMobile ? 11 : 13),
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showCopyButton && value != '-') ...[
                SizedBox(width: isLandscape ? 3 : (isMobile ? 4 : 6)),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    showTopToast(context, '$value 已复制', isSuccess: true);
                  },
                  child: Icon(
                    Icons.copy,
                    size: isLandscape ? 11 : (isMobile ? 12 : 14),
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 显示当前设备信息对话框
  void _showCurrentDeviceDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // 获取当前设备信息
    Map<String, dynamic>? deviceInfo;
    final allVnts = vntManager.map;
    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        deviceInfo = vntBox.currentDevice();
        deviceInfo['upStream'] = vntBox.upStream();
        deviceInfo['downStream'] = vntBox.downStream();
        break;
      }
    }

    if (deviceInfo == null) return;

    final info = json2yaml(deviceInfo);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: context.w(500),
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
            borderRadius: BorderRadius.circular(context.radius(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头部
              Container(
                padding: ResponsiveUtils.padding(context, all: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(context.radius(24))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: context.w(48),
                      height: context.w(48),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(context.radius(12)),
                      ),
                      child: Icon(
                        Icons.computer,
                        color: primaryColor,
                        size: context.iconSize(24),
                      ),
                    ),
                    SizedBox(width: context.spacing(12)),
                    Expanded(
                      child: Text(
                        '当前设备信息',
                        style: TextStyle(
                          fontSize: context.sp(18),
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        size: context.iconSize(24),
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // 内容
              Flexible(
                child: SingleChildScrollView(
                  padding: ResponsiveUtils.padding(context, all: 20),
                  child: SelectableText(
                    info ?? '',
                    style: TextStyle(
                      fontSize: context.sp(13),
                      fontFamily: 'monospace',
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
              ),

              // 底部按钮
              Padding(
                padding: ResponsiveUtils.padding(context, horizontal: 20, bottom: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor.withOpacity(0.15),
                      foregroundColor: primaryColor,
                      elevation: 0,
                      padding: ResponsiveUtils.padding(context, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.radius(12)),
                      ),
                    ),
                    child: Text(
                      '关闭',
                      style: TextStyle(
                        fontSize: context.sp(15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示网络配置详情对话框
  void _showConfigDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // 获取网络配置信息
    String? configInfo;
    final allVnts = vntManager.map;
    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        final netConfig = vntBox.getNetConfig();
        if (netConfig != null) {
          configInfo = json2yaml(netConfig.toJsonSimple());
        }
        break;
      }
    }

    if (configInfo == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: context.w(500),
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
            borderRadius: BorderRadius.circular(context.radius(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头部
              Container(
                padding: ResponsiveUtils.padding(context, all: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(context.radius(24))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: context.w(48),
                      height: context.w(48),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(context.radius(12)),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: primaryColor,
                        size: context.iconSize(24),
                      ),
                    ),
                    SizedBox(width: context.spacing(12)),
                    Expanded(
                      child: Text(
                        '网络配置',
                        style: TextStyle(
                          fontSize: context.sp(18),
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        size: context.iconSize(24),
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // 内容
              Flexible(
                child: SingleChildScrollView(
                  padding: ResponsiveUtils.padding(context, all: 20),
                  child: SelectableText(
                    configInfo!,
                    style: TextStyle(
                      fontSize: context.sp(13),
                      fontFamily: 'monospace',
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
              ),

              // 底部按钮
              Padding(
                padding: ResponsiveUtils.padding(context, horizontal: 20, bottom: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor.withOpacity(0.15),
                      foregroundColor: primaryColor,
                      elevation: 0,
                      padding: ResponsiveUtils.padding(context, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.radius(12)),
                      ),
                    ),
                    child: Text(
                      '关闭',
                      style: TextStyle(
                        fontSize: context.sp(15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示断开连接确认对话框
  void _showDisconnectDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 获取当前连接的配置名称
    String? configName;
    final allVnts = vntManager.map;
    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        final netConfig = vntBox.getNetConfig();
        if (netConfig != null) {
          configName = netConfig.configName;
        }
        break;
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: context.w(360)),
          padding: ResponsiveUtils.padding(context, all: 24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
            borderRadius: BorderRadius.circular(context.radius(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 警告图标
              Container(
                width: context.w(64),
                height: context.w(64),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(context.radius(32)),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: context.iconSize(36),
                ),
              ),
              SizedBox(height: context.spacing(20)),

              // 标题
              Text(
                '确认断开连接',
                style: TextStyle(
                  fontSize: context.sp(20),
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              SizedBox(height: context.spacing(12)),

              // 提示文本
              Text(
                configName != null ? '是否断开与 \'$configName\' 的组网连接?' : '是否断开当前组网连接?',
                style: TextStyle(
                  fontSize: context.sp(14),
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.spacing(24)),

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
                        padding: ResponsiveUtils.padding(context, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.radius(12)),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(fontSize: context.sp(14)),
                      ),
                    ),
                  ),
                  SizedBox(width: context.spacing(12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);

                        // 获取所有连接的key
                        final allVnts = vntManager.map;
                        final keys = allVnts.keys.toList();

                        // 断开所有连接
                        for (var key in keys) {
                          await vntManager.remove(key);
                        }

                        // 清空延迟历史数据
                        _clearLatencyHistory();

                        if (widget.onDisconnect != null) {
                          widget.onDisconnect!();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: ResponsiveUtils.padding(context, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.radius(12)),
                        ),
                      ),
                      child: Text(
                        '断开连接',
                        style: TextStyle(fontSize: context.sp(14)),
                      ),
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

// 延迟图表绘制器
class _LatencyChartPainter extends CustomPainter {
  final List<int> data;
  final Color color;

  _LatencyChartPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // 找到最大值和最小值
    final maxValue = data.reduce((a, b) => a > b ? a : b).toDouble();
    final minValue = data.reduce((a, b) => a < b ? a : b).toDouble();
    final range = maxValue - minValue;

    // 绘制路径
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final normalizedValue = range > 0 ? (data[i] - minValue) / range : 0.5;
      final y = size.height - (normalizedValue * size.height * 0.8) - (size.height * 0.1);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // 完成填充路径
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // 绘制填充和线条
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

