import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/vnt/vnt_manager.dart';
import 'package:vnt_app/data_persistence.dart';
import 'package:vnt_app/network_config.dart';
import 'package:vnt_app/utils/toast_utils.dart';
import 'package:vnt_app/utils/responsive_utils.dart';
import 'package:fl_chart/fl_chart.dart';

/// 仪表盘页面
class DashboardPage extends StatefulWidget {
  final VoidCallback? onNavigateToConfig;
  final VoidCallback? onNavigateToSettings;
  final VoidCallback? onDisconnect;
  final VoidCallback? onConnect;

  const DashboardPage({
    super.key,
    this.onNavigateToConfig,
    this.onNavigateToSettings,
    this.onDisconnect,
    this.onConnect,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _timer;
  int _connectionCount = 0;
  int _deviceCount = 0;
  String _totalUpStream = '0B';
  String _totalDownStream = '0B';
  String _configName = '';
  String _virtualIp = '';
  String _deviceName = '';
  String _relayServer = '';
  int _avgLatency = 0;
  double _packetLoss = 0.0;
  bool _isEncrypted = false;
  String _encryptionAlgorithm = '';
  String _protocol = '';
  int _offlineDeviceCount = 0;
  bool _isVirtualIpAutoAssigned = false; // 虚拟IP是否为服务器自动分配
  String _natType = ''; // NAT类型

  // 默认配置
  String _defaultConfigKey = '';
  String _defaultConfigName = '';
  String? _lastPersistedDefaultKey; // 上次从持久化存储读取的defaultKey，用于检测变化
  final DataPersistence _dataPersistence = DataPersistence();

  // 网络速度数据
  String _currentUpSpeed = '0 B/s';
  String _currentDownSpeed = '0 B/s';
  List<double> _uploadSpeedHistory = [];
  List<double> _downloadSpeedHistory = [];
  double _maxUpSpeed = 0;
  double _maxDownSpeed = 0;

  // 峰值和平均速度
  double _peakUpSpeed = 0;
  double _peakDownSpeed = 0;
  double _avgUpSpeed = 0;
  double _avgDownSpeed = 0;
  double _totalUpSpeed = 0;
  double _totalDownSpeed = 0;
  int _speedSampleCount = 0;

  // 用于计算速率的上一次流量值
  double _lastUpBytes = 0;
  double _lastDownBytes = 0;
  bool _isFirstUpdate = true;

  // 网关连通性历史记录（用于计算丢包率）
  List<bool> _gatewayConnectivityHistory = [];
  // 跟踪已收集的连通性检查次数（用于跳过前10次的0或9999）
  int _connectivityCheckCount = 0;

  // Ping历史记录（最多保存100个）
  List<bool> _pingHistory = [];

  // 清空所有历史数据（仅在手动断开连接时调用）
  void _clearAllHistoryData() {
    _connectivityCheckCount = 0;
    _gatewayConnectivityHistory.clear();
    _pingHistory.clear();
    _uploadSpeedHistory.clear();
    _downloadSpeedHistory.clear();
    _maxUpSpeed = 0;
    _maxDownSpeed = 0;
    _peakUpSpeed = 0;
    _peakDownSpeed = 0;
    _avgUpSpeed = 0;
    _avgDownSpeed = 0;
    _totalUpSpeed = 0;
    _totalDownSpeed = 0;
    _speedSampleCount = 0;
    _lastUpBytes = 0;
    _lastDownBytes = 0;
    _isFirstUpdate = true;
  }

  @override
  void initState() {
    super.initState();
    _loadDefaultConfig();
    _updateStats();
    // 每2秒更新一次数据
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateStats();
      // 定期检查默认配置是否有变化
      _checkDefaultConfigChange();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 判断设备是否在线 - 不区分大小写，去掉空格和换行
  bool _isDeviceOnline(String status) {
    return status.trim().toLowerCase() == 'online';
  }

  // 加载默认配置（与设置页面逻辑完全一致）
  Future<void> _loadDefaultConfig() async {
    String defaultKey = await _dataPersistence.loadDefaultKey() ?? '';

    // 保存从持久化存储读取的defaultKey，用于后续检测变化
    _lastPersistedDefaultKey = defaultKey.isEmpty ? null : defaultKey;

    final configs = await _dataPersistence.loadData();

    // 检查默认配置是否存在于配置列表中
    bool isExists = false;
    for (var conf in configs) {
      if (conf.itemKey == defaultKey) {
        isExists = true;
        break;
      }
    }

    // 如果配置列表不为空，且默认配置不存在，则使用第一个配置
    if (configs.isNotEmpty && !isExists) {
      defaultKey = configs[0].itemKey;
      // 保存到持久化存储，确保其他地方可以读取到
      await _dataPersistence.saveDefaultKey(defaultKey);
      _lastPersistedDefaultKey = defaultKey;
    }

    // 根据最终的defaultKey查找配置名称
    if (defaultKey.isNotEmpty) {
      final config = configs.where((c) => c.itemKey == defaultKey).firstOrNull;
      if (config != null) {
        setState(() {
          _defaultConfigKey = defaultKey;
          _defaultConfigName = config.configName;
        });
        return;
      }
    }

    // 如果没有找到有效的默认配置，清空状态
    setState(() {
      _defaultConfigKey = '';
      _defaultConfigName = '';
    });
  }

  // 检查默认配置是否有变化（只检测持久化存储中的变化）
  Future<void> _checkDefaultConfigChange() async {
    final defaultKey = await _dataPersistence.loadDefaultKey();

    // 只有当持久化存储中的defaultKey真正变化时才重新加载
    // 避免因为"持久化存储是null但UI显示自动识别的第一个配置"而不断重新加载
    if (defaultKey != _lastPersistedDefaultKey) {
      await _loadDefaultConfig();
    }
  }

  // 处理连接操作
  Future<void> _handleConnect() async {
    debugPrint('_handleConnect called, defaultConfigKey: $_defaultConfigKey, defaultConfigName: $_defaultConfigName');
    if (_defaultConfigKey.isNotEmpty) {
      // 有默认配置，直接连接
      debugPrint('Has default config, calling onConnect');
      widget.onConnect?.call();
    } else {
      // 没有默认配置，跳转到配置页面
      debugPrint('No default config, calling onNavigateToConfig');
      widget.onNavigateToConfig?.call();
    }
  }

  void _updateStats() {
    if (!mounted) return;

    int deviceCount = 0;
    int offlineDeviceCount = 0;
    String upStream = '0B';
    String downStream = '0B';
    String configName = '';
    String virtualIp = '';
    String deviceName = '';
    String relayServer = '';
    String protocol = '';
    int totalLatency = 0;
    int latencyCount = 0;
    bool isEncrypted = false;
    String encryptionAlgorithm = '';
    String natType = ''; // NAT类型

    // 速率数据（直接使用状态变量，不创建新列表）
    String currentUpSpeed = '0 B/s';
    String currentDownSpeed = '0 B/s';
    double maxUpSpeed = _maxUpSpeed;
    double maxDownSpeed = _maxDownSpeed;

    final allVnts = vntManager.map;

    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        final devices = vntBox.peerDeviceList();
        deviceCount += devices.length;

        // 计算离线设备数
        for (var device in devices) {
          if (device.status != 'Online') {
            offlineDeviceCount++;
          }
        }

        // 获取总流量（直接使用API返回的字符串）
        upStream = vntBox.upStream();
        downStream = vntBox.downStream();

        // 解析流量字符串为字节数（用于计算速率）
        double currentUpBytes = _parseTrafficToBytes(upStream);
        double currentDownBytes = _parseTrafficToBytes(downStream);

        // 计算速率（当前流量 - 上次流量）/ 时间间隔
        // 时间间隔是2秒（定时器周期）
        if (!_isFirstUpdate) {
          double upSpeed = (currentUpBytes - _lastUpBytes) / 2.0;  // 字节/秒
          double downSpeed = (currentDownBytes - _lastDownBytes) / 2.0;

          // 如果速率为负（可能是重启或重置），设为0
          if (upSpeed < 0) upSpeed = 0;
          if (downSpeed < 0) downSpeed = 0;

          // 添加到历史记录（保持最近100个数据点）
          _uploadSpeedHistory.add(upSpeed);
          _downloadSpeedHistory.add(downSpeed);

          if (_uploadSpeedHistory.length > 100) {
            _uploadSpeedHistory.removeAt(0);
          }
          if (_downloadSpeedHistory.length > 100) {
            _downloadSpeedHistory.removeAt(0);
          }

          // 更新当前速率显示
          currentUpSpeed = _formatSpeed(upSpeed);
          currentDownSpeed = _formatSpeed(downSpeed);

          // 更新峰值速度
          if (upSpeed > _peakUpSpeed) {
            _peakUpSpeed = upSpeed;
          }
          if (downSpeed > _peakDownSpeed) {
            _peakDownSpeed = downSpeed;
          }

          // 累计速度用于计算平均值
          _totalUpSpeed += upSpeed;
          _totalDownSpeed += downSpeed;
          _speedSampleCount++;

          // 计算平均速度
          _avgUpSpeed = _totalUpSpeed / _speedSampleCount;
          _avgDownSpeed = _totalDownSpeed / _speedSampleCount;

          // 计算最大速率（用于图表Y轴）
          if (_uploadSpeedHistory.isNotEmpty) {
            maxUpSpeed = _uploadSpeedHistory.reduce((a, b) => a > b ? a : b);
          }
          if (_downloadSpeedHistory.isNotEmpty) {
            maxDownSpeed = _downloadSpeedHistory.reduce((a, b) => a > b ? a : b);
          }
        } else {
          _isFirstUpdate = false;
        }

        // 保存当前流量值，用于下次计算速率
        _lastUpBytes = currentUpBytes;
        _lastDownBytes = currentDownBytes;

        // 获取配置名
        final config = vntBox.getNetConfig();
        if (config != null) {
          configName = config.configName;
          isEncrypted = config.groupPassword.isNotEmpty;

          // 获取加密算法
          if (isEncrypted) {
            encryptionAlgorithm = config.encryptionAlgorithm.isNotEmpty
                ? config.encryptionAlgorithm.toUpperCase()
                : 'AES-GCM';
          }

          // 获取协议类型
          protocol = config.protocol.isNotEmpty ? config.protocol.toUpperCase() : 'UDP';

          // 获取用户配置的服务器地址（而不是解析后的地址）
          relayServer = config.serverAddress;

          // 判断虚拟IP是否为自动分配（配置中的virtualIPv4为空表示自动分配）
          _isVirtualIpAutoAssigned = config.virtualIPv4.isEmpty;
        }

        // 获取当前设备信息
        final currentDevice = vntBox.currentDevice();
        virtualIp = currentDevice['virtualIp'] ?? '';
        final virtualGateway = currentDevice['virtualGateway'] ?? '';

        // 获取NAT类型
        natType = currentDevice['natType'] ?? '';

        deviceName = config?.deviceName ?? '';

        // 计算平均延迟
        for (var device in devices) {
          final route = vntBox.route(device.virtualIp);
          if (route != null && route.rt > 0 && route.rt < 9999) {
            totalLatency += route.rt;
            latencyCount++;
          }
        }

        // 检查网关连通性（用于计算丢包率）
        if (virtualGateway.isNotEmpty) {
          final gatewayRoute = vntBox.route(virtualGateway);
          bool isConnected = false;
          bool shouldRecord = true;

          // route.rt > 0 且 < 9999 表示连通，0 或 9999 表示不通
          if (gatewayRoute != null && gatewayRoute.rt > 0 && gatewayRoute.rt < 9999) {
            isConnected = true;
            // 使用网关的延迟作为平均延迟（如果没有其他设备）
            if (latencyCount == 0) {
              totalLatency = gatewayRoute.rt;
              latencyCount = 1;
            }
          } else if (gatewayRoute != null && (gatewayRoute.rt == 0 || gatewayRoute.rt == 9999)) {
            // 前10次出现0或9999时不纳入统计（连接初始化阶段）
            if (_connectivityCheckCount < 10) {
              shouldRecord = false;
            }
          }

          // 增加检查计数
          _connectivityCheckCount++;

          // 只有shouldRecord为true时才添加到历史记录
          if (shouldRecord) {
            // 添加到历史记录（保持最近 50 个数据点）
            _gatewayConnectivityHistory.add(isConnected);
            if (_gatewayConnectivityHistory.length > 50) {
              _gatewayConnectivityHistory.removeAt(0);
            }

            // 同时添加到Ping历史（保持最近 100 个数据点）
            _pingHistory.add(isConnected);
            if (_pingHistory.length > 100) {
              _pingHistory.removeAt(0);
            }
          }
        }
      }
    }

    int avgLatency = latencyCount > 0 ? (totalLatency / latencyCount).round() : 0;

    // 计算丢包率：(不通次数 / 总次数) * 100
    double packetLoss = 0.0;
    if (_gatewayConnectivityHistory.isNotEmpty) {
      int failedCount = _gatewayConnectivityHistory.where((connected) => !connected).length;
      packetLoss = (failedCount / _gatewayConnectivityHistory.length) * 100;
    }

    setState(() {
      _connectionCount = vntManager.size();
      _deviceCount = deviceCount;
      _offlineDeviceCount = offlineDeviceCount;
      _totalUpStream = upStream;
      _totalDownStream = downStream;
      _configName = configName;
      _virtualIp = virtualIp;
      _deviceName = deviceName;
      _relayServer = relayServer;
      _protocol = protocol;
      _avgLatency = avgLatency;
      _isEncrypted = isEncrypted;
      _encryptionAlgorithm = encryptionAlgorithm;
      _packetLoss = packetLoss;
      _natType = natType;
      // 注意：_isVirtualIpAutoAssigned 已经在上面直接赋值了

      // 更新速率数据（历史数据已经在上面直接修改了状态变量）
      _currentUpSpeed = currentUpSpeed;
      _currentDownSpeed = currentDownSpeed;
      _maxUpSpeed = maxUpSpeed;
      _maxDownSpeed = maxDownSpeed;
      _lastUpBytes = _lastUpBytes;
      _lastDownBytes = _lastDownBytes;
    });
  }

  // 解析流量字符串为字节数
  // 支持多单位组合格式，例如 "1 GB 500 MB 200 KB 100 bytes"
  double _parseTrafficToBytes(String traffic) {
    if (traffic.isEmpty || traffic == '0B') return 0;

    double totalBytes = 0;

    // 提取所有数字和单位的组合
    final regex = RegExp(r'([\d.]+)\s*([A-Za-z]+)');
    final matches = regex.allMatches(traffic);

    for (var match in matches) {
      final value = double.tryParse(match.group(1) ?? '0') ?? 0;
      final unit = match.group(2)?.toUpperCase() ?? 'B';

      // 转换为字节并累加
      switch (unit) {
        case 'BYTES':
        case 'B':
          totalBytes += value;
          break;
        case 'KB':
          totalBytes += value * 1024;
          break;
        case 'MB':
          totalBytes += value * 1024 * 1024;
          break;
        case 'GB':
          totalBytes += value * 1024 * 1024 * 1024;
          break;
        case 'TB':
          totalBytes += value * 1024 * 1024 * 1024 * 1024;
          break;
      }
    }

    return totalBytes;
  }

  // 获取总上传字节数
  double get totalUpBytes => _parseTrafficToBytes(_totalUpStream);

  // 获取总下载字节数
  double get totalDownBytes => _parseTrafficToBytes(_totalDownStream);

  // 格式化速率显示（字节/秒 -> B/s, KB/s, MB/s）
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(2)} KB/s';
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final hasConnection = _connectionCount > 0;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _updateStats(),
          color: primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isWideScreen ? context.spacingXLarge : context.spacingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 页面头部（所有平台都显示）
                _buildHeader(isDark),
                const SizedBox(height: 16),

                // 连接状态卡片
                _buildConnectionStatusCard(isDark, hasConnection),
                const SizedBox(height: 20),

                // 网络速度、质量、流量统计
                if (isWideScreen)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSpeedCard(isDark)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildQualityCard(isDark)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTrafficCard(isDark)),
                    ],
                  )
                else ...[
                  _buildSpeedCard(isDark),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildQualityCard(isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTrafficCard(isDark)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // 信息卡片网格
                _buildInfoCardsGrid(isDark, isWideScreen, hasConnection),
                const SizedBox(height: 24),

                // 快捷操作
                _buildQuickActions(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Row(
      children: [
        Container(
          width: context.w(48),
          height: context.w(48),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(context.radius(12)),
          ),
          child: Icon(
            Icons.dashboard_outlined,
            color: Colors.white,
            size: context.iconSize(28),
          ),
        ),
        SizedBox(width: context.spacing(16)),
        Text(
          '仪表盘',
          style: TextStyle(
            fontSize: context.sp(28),
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatusCard(bool isDark, bool hasConnection) {
    final primaryColor = Theme.of(context).primaryColor;
    return InkWell(
      onTap: hasConnection ? () => _showConnectionDialog(isDark) : _handleConnect,
      borderRadius: BorderRadius.circular(context.radius(20)),
      child: Container(
        width: double.infinity,
        padding: ResponsiveUtils.padding(context, all: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasConnection
                ? (isDark
                    ? [HSLColor.fromColor(primaryColor).withLightness(0.25).toColor(),
                       HSLColor.fromColor(primaryColor).withLightness(0.20).toColor()]
                    : [HSLColor.fromColor(primaryColor).withLightness(0.35).toColor(),
                       HSLColor.fromColor(primaryColor).withLightness(0.30).toColor()])
                : [const Color(0xFFBDBDBD), const Color(0xFF9E9E9E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(context.radius(20)),
          boxShadow: [
            BoxShadow(
              color: (hasConnection ? primaryColor : Colors.grey)
                  .withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: context.w(56),
              height: context.w(56),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(context.radius(12)),
              ),
              child: Icon(
                hasConnection ? Icons.check_circle_outline : Icons.cloud_off_outlined,
                color: Colors.white,
                size: context.iconSize(32),
              ),
            ),
            SizedBox(width: context.spacing(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasConnection ? '已连接' : '未连接',
                    style: TextStyle(
                      fontSize: context.sp(28),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: context.spacing(4)),
                  Text(
                    hasConnection
                        ? (_configName.isNotEmpty ? _configName : '未知配置名')
                        : (_defaultConfigName.isNotEmpty ? '$_defaultConfigName (点击连接)' : '点击新建配置'),
                    style: TextStyle(
                      fontSize: context.sp(16),
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  if (hasConnection) ...[
                    SizedBox(height: context.spacing(8)),
                    Row(
                      children: [
                        Icon(Icons.link, color: Colors.white.withOpacity(0.9), size: context.iconSize(16)),
                        SizedBox(width: context.spacing(4)),
                        Text(
                          '$_connectionCount 个活动连接',
                          style: TextStyle(
                            fontSize: context.sp(14),
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (hasConnection)
              GestureDetector(
                onTap: () {
                  // 阻止事件冒泡到InkWell
                },
                child: IconButton(
                  onPressed: () {
                    // 显示断开连接确认对话框
                    _showConnectionDialog(isDark);
                  },
                  icon: Icon(Icons.power_settings_new, color: Colors.white, size: context.iconSize(28)),
                  tooltip: '断开连接',
                ),
              )
            else
              GestureDetector(
                onTap: () {
                  // 阻止事件冒泡到InkWell
                },
                child: IconButton(
                  onPressed: _handleConnect,
                  icon: Icon(Icons.play_arrow, color: Colors.white, size: context.iconSize(28)),
                  tooltip: '连接',
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 显示连接状态弹窗
  void _showConnectionDialog(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radius(20)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.w(400), // 限制最大宽度，响应式
            ),
            child: Container(
              padding: ResponsiveUtils.padding(context, all: 32),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardBackground : Colors.white,
                borderRadius: BorderRadius.circular(context.radius(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // VPN图标
                Container(
                  width: context.w(64),
                  height: context.w(64),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.vpn_lock,
                    color: primaryColor,
                    size: context.iconSize(32),
                  ),
                ),
                SizedBox(height: context.spacing(24)),
                // 标题
                Text(
                  '目前有 $_connectionCount 个活动连接',
                  style: TextStyle(
                    fontSize: context.sp(20),
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                SizedBox(height: context.spacing(12)),
                // 副标题
                Text(
                  '是否断开组网连接?',
                  style: TextStyle(
                    fontSize: context.sp(14),
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
                SizedBox(height: context.spacing(32)),
                // 按钮
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: context.spacing(16)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.radius(12)),
                          ),
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                        ),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: context.sp(16),
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: context.spacing(12)),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();

                          // 清空所有历史数据
                          _clearAllHistoryData();

                          // 调用断开连接回调
                          widget.onDisconnect?.call();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: context.spacing(16)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.radius(12)),
                          ),
                          backgroundColor: Colors.red,
                        ),
                        child: Text(
                          '断开',
                          style: TextStyle(
                            fontSize: context.sp(16),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
      },
    );
  }

  // 网络速度卡片（带折线图）
  Widget _buildSpeedCard(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return InkWell(
      onTap: () => _showNetworkSpeedDialog(isDark),
      borderRadius: BorderRadius.circular(ResponsiveUtils.getCardRadius(context)),
      child: Container(
        height: ResponsiveUtils.getCardHeight(context, baseHeight: 240.0),
        padding: ResponsiveUtils.getCardPadding(context),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardRadius(context)),
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
            Row(
              children: [
                Icon(Icons.speed, color: primaryColor, size: context.iconSize(20)),
                SizedBox(width: context.spacing(8)),
                Expanded(
                  child: Text(
                    '网络速度',
                    style: TextStyle(
                      fontSize: context.sp(16),
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing(16)),
            Expanded(
              child: _buildSpeedChart(isDark),
            ),
            SizedBox(height: context.spacing(12)),
            // 数值显示在折线图下方，上下两行
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.arrow_upward, color: Colors.red[400], size: context.iconSize(14)),
                    SizedBox(width: context.spacing(4)),
                    Flexible(
                      child: Text(
                        '上传: $_currentUpSpeed',
                        style: TextStyle(
                          fontSize: context.sp(12),
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.spacing(4)),
                Row(
                  children: [
                    Icon(Icons.arrow_downward, color: Colors.green[400], size: context.iconSize(14)),
                    SizedBox(width: context.spacing(4)),
                    Flexible(
                      child: Text(
                        '下载: $_currentDownSpeed',
                        style: TextStyle(
                          fontSize: context.sp(12),
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 网络速度折线图
  Widget _buildSpeedChart(bool isDark) {
    // 固定显示20个格子
    const int maxDisplayCount = 20;

    // 获取当前数据长度
    int dataLength = _uploadSpeedHistory.length;

    // 如果没有数据，返回空图表
    if (dataLength == 0) {
      return LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          lineTouchData: LineTouchData(enabled: false),
          minX: 0,
          maxX: (maxDisplayCount - 1).toDouble(),
          minY: 0,
          maxY: 10,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(maxDisplayCount, (i) => FlSpot(i.toDouble(), 0)),
              isCurved: true,
              color: Colors.red[400],
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.red[400]!.withOpacity(0.15),
              ),
            ),
            LineChartBarData(
              spots: List.generate(maxDisplayCount, (i) => FlSpot(i.toDouble(), 0)),
              isCurved: true,
              color: Colors.green[400],
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green[400]!.withOpacity(0.15),
              ),
            ),
          ],
        ),
        // 关键：禁用 fl_chart 的内置动画，避免数据更新时的卡顿
        duration: const Duration(milliseconds: 0),
      );
    }

    // 动态计算Y轴范围（使用所有可见数据点）
    double maxSpeedInRange = 0;
    for (int i = 0; i < dataLength; i++) {
      if (_uploadSpeedHistory[i] > maxSpeedInRange) {
        maxSpeedInRange = _uploadSpeedHistory[i];
      }
      if (_downloadSpeedHistory[i] > maxSpeedInRange) {
        maxSpeedInRange = _downloadSpeedHistory[i];
      }
    }

    // 动态调整Y轴范围，确保曲线始终可见
    double maxSpeed;
    if (maxSpeedInRange < 1) {
      // 极小值：设置最小刻度为 1
      maxSpeed = 1;
    } else if (maxSpeedInRange < 10) {
      // 小于 10：留出较大空间，便于观察小数值变化
      maxSpeed = maxSpeedInRange * 3;
    } else if (maxSpeedInRange < 100) {
      // 10-100：留出适中空间
      maxSpeed = maxSpeedInRange * 2.5;
    } else if (maxSpeedInRange < 1024) {
      // 100-1024：逐渐减少留白
      maxSpeed = maxSpeedInRange * 1.8;
    } else {
      // 大于 1024：较小留白
      maxSpeed = maxSpeedInRange * 1.4;
    }

    // 生成上传速度数据点
    List<FlSpot> uploadSpots = [];
    // 从右往左显示：最新数据在右边（x=19），最旧数据在左边（x=0）
    for (int i = 0; i < _uploadSpeedHistory.length; i++) {
      // X坐标 = 从右边开始的位置
      double xPos = (maxDisplayCount - _uploadSpeedHistory.length + i).toDouble();
      double yValue = _uploadSpeedHistory[i];
      uploadSpots.add(FlSpot(xPos, yValue));
    }

    // 生成下载速度数据点
    List<FlSpot> downloadSpots = [];
    for (int i = 0; i < _downloadSpeedHistory.length; i++) {
      double xPos = (maxDisplayCount - _downloadSpeedHistory.length + i).toDouble();
      double yValue = _downloadSpeedHistory[i];
      downloadSpots.add(FlSpot(xPos, yValue));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => isDark
                ? Colors.grey[800]!.withOpacity(0.9)
                : Colors.grey[700]!.withOpacity(0.9),
            tooltipRoundedRadius: 8,
            tooltipPadding: EdgeInsets.all(context.spacingXSmall),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final isUpload = spot.barIndex == 0;
                final speed = _formatSpeed(spot.y);
                return LineTooltipItem(
                  '${isUpload ? '上传' : '下载'}\n$speed',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: context.fontSmall,
                  ),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
        minX: 0,
        maxX: (maxDisplayCount - 1).toDouble(),
        minY: 0,
        maxY: maxSpeed,
        clipData: FlClipData.all(), // 裁剪超出范围的曲线
        lineBarsData: [
          LineChartBarData(
            spots: uploadSpots,
            isCurved: true,
            color: Colors.red[400],
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red[400]!.withOpacity(0.15),
            ),
          ),
          LineChartBarData(
            spots: downloadSpots,
            isCurved: true,
            color: Colors.green[400],
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green[400]!.withOpacity(0.15),
            ),
          ),
        ],
      ),
      // 禁用 fl_chart 的内置动画
      duration: const Duration(milliseconds: 0),
    );
  }

  // 网络质量卡片（带环形图）
  Widget _buildQualityCard(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return InkWell(
      onTap: () => _showNetworkQualityDialog(isDark),
      borderRadius: BorderRadius.circular(ResponsiveUtils.getCardRadius(context)),
      child: Container(
        height: ResponsiveUtils.getCardHeight(context, baseHeight: 240.0),
        padding: ResponsiveUtils.getCardPadding(context),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardRadius(context)),
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
          Row(
            children: [
              Icon(Icons.signal_cellular_alt, color: primaryColor, size: context.iconSize(20)),
              SizedBox(width: context.spacing(8)),
              Expanded(
                child: Text(
                  '网络质量',
                  style: TextStyle(
                    fontSize: context.sp(16),
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing(16)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 使用响应式工具计算环形图大小
                final chartSize = ResponsiveUtils.getPieChartSize(
                  context,
                  baseSize: 80.0,
                  minSize: 50.0,
                  maxSize: 100.0,
                );

                return Row(
                  children: [
                    // 环形图居左，响应式大小
                    SizedBox(
                      width: chartSize,
                      height: chartSize,
                      child: _buildQualityPieChart(context, isDark),
                    ),
                    // 使用Spacer推动文字描述到右边
                    const Spacer(),
                    // 文字描述整体靠右，但内部左对齐
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(context, '未连接', Colors.grey[300]!),
                        SizedBox(height: context.spacing(8)),
                        _buildLegendItem(context, '延迟', Colors.green[400]!),
                        SizedBox(height: context.spacing(8)),
                        _buildLegendItem(context, '丢包', Colors.red[400]!),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: context.spacing(12)),
          // 延迟和丢包上下两行显示，前面增加图标
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: context.iconSize(14), color: Colors.green[400]),
                  SizedBox(width: context.spacing(4)),
                  Flexible(
                    child: Text(
                      '延迟: ${_avgLatency > 0 ? '$_avgLatency ms' : '-- ms'}',
                      style: TextStyle(
                        fontSize: context.sp(12),
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacing(4)),
              Row(
                children: [
                  Icon(Icons.warning_amber_outlined, size: context.iconSize(14), color: Colors.red[400]),
                  SizedBox(width: context.spacing(4)),
                  Flexible(
                    child: Text(
                      '丢包: ${_packetLoss.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: context.sp(12),
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  // 网络质量环形图
  Widget _buildQualityPieChart(BuildContext context, bool isDark) {
    final hasConnection = _connectionCount > 0;

    // 计算环形图比例
    double goodValue = 0;
    double badValue = 0;

    if (hasConnection) {
      // 丢包率直接使用百分比
      badValue = _packetLoss.clamp(0, 100);
      // 延迟部分占据剩余比例
      goodValue = 100 - badValue;
    }

    // 使用响应式尺寸
    final centerRadius = ResponsiveUtils.getPieChartCenterRadius(context);
    final sectionRadius = ResponsiveUtils.getPieChartSectionRadius(context);

    // 当没有丢包时，不显示红色部分，全部显示为绿色
    if (hasConnection && badValue == 0) {
      return PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: centerRadius,
          sections: [
            PieChartSectionData(
              color: Colors.green[400],
              value: 100,
              title: '',
              radius: sectionRadius,
            ),
          ],
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: centerRadius,
        sections: [
          if (!hasConnection)
            PieChartSectionData(
              color: Colors.grey[300],
              value: 100,
              title: '',
              radius: sectionRadius,
            )
          else ...[
            if (goodValue > 0)
              PieChartSectionData(
                color: Colors.green[400],
                value: goodValue,
                title: '',
                radius: sectionRadius,
              ),
            if (badValue > 0)
              PieChartSectionData(
                color: Colors.red[400],
                value: badValue,
                title: '',
                radius: sectionRadius,
              ),
          ],
        ],
      ),
    );
  }

  // 流量统计卡片（带环形图）
  Widget _buildTrafficCard(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return InkWell(
      onTap: () => _showTrafficStatisticsDialog(isDark),
      borderRadius: BorderRadius.circular(ResponsiveUtils.getCardRadius(context)),
      child: Container(
        height: ResponsiveUtils.getCardHeight(context, baseHeight: 240.0),
        padding: ResponsiveUtils.getCardPadding(context),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardRadius(context)),
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
          Row(
            children: [
              Icon(Icons.pie_chart, color: primaryColor, size: context.iconSize(20)),
              SizedBox(width: context.spacing(8)),
              Expanded(
                child: Text(
                  '流量统计',
                  style: TextStyle(
                    fontSize: context.sp(16),
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing(16)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 使用响应式工具计算环形图大小
                final chartSize = ResponsiveUtils.getPieChartSize(
                  context,
                  baseSize: 80.0,
                  minSize: 50.0,
                  maxSize: 100.0,
                );

                return Row(
                  children: [
                    // 环形图居左，响应式大小
                    SizedBox(
                      width: chartSize,
                      height: chartSize,
                      child: _buildTrafficPieChart(context, isDark),
                    ),
                    // 使用Spacer推动文字描述到右边
                    const Spacer(),
                    // 文字描述整体靠右，但内部左对齐
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(context, '上传', Colors.cyan[400]!),
                        SizedBox(height: context.spacing(8)),
                        _buildLegendItem(context, '下载', Colors.blue[400]!),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: context.spacing(12)),
          // 上传下载上下两行显示
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.arrow_upward, size: context.iconSize(14), color: Colors.cyan[400]),
                  SizedBox(width: context.spacing(4)),
                  Flexible(
                    child: Text(
                      '上传: $_totalUpStream',
                      style: TextStyle(
                        fontSize: context.sp(12),
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacing(4)),
              Row(
                children: [
                  Icon(Icons.arrow_downward, size: context.iconSize(14), color: Colors.blue[400]),
                  SizedBox(width: context.spacing(4)),
                  Flexible(
                    child: Text(
                      '下载: $_totalDownStream',
                      style: TextStyle(
                        fontSize: context.sp(12),
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  // 显示流量统计详情弹窗
  void _showTrafficStatisticsDialog(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    // 获取所有设备的流量数据
    List<(String, BigInt, BigInt)> deviceTrafficList = [];

    final allVnts = vntManager.map;
    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        deviceTrafficList = vntBox.vntApi.streamAll();
        break; // 只取第一个连接的数据
      }
    }

    // 转换设备数据并计算总流量（使用设备流量总和）
    double totalBytes = 0;
    List<Map<String, dynamic>> deviceList = deviceTrafficList.map((item) {
      String ip = item.$1;
      double upBytes = item.$2.toDouble();
      double downBytes = item.$3.toDouble();
      double deviceTotal = upBytes + downBytes;
      totalBytes += deviceTotal;

      return {
        'ip': ip,
        'upBytes': upBytes,
        'downBytes': downBytes,
        'totalBytes': deviceTotal,
        'percentage': 0.0, // 稍后计算
        'upFormatted': _formatTraffic(upBytes),
        'downFormatted': _formatTraffic(downBytes),
        'totalFormatted': _formatTraffic(deviceTotal),
      };
    }).toList();

    // 计算百分比
    for (var device in deviceList) {
      device['percentage'] = totalBytes > 0 ? (device['totalBytes'] / totalBytes) * 100 : 0;
    }

    // 按总流量大小排序（从大到小）
    deviceList.sort((a, b) => b['totalBytes'].compareTo(a['totalBytes']));

    // 当设备数>=2时，调整百分比显示，避免出现100%和0.0%的不合理情况
    if (deviceList.length >= 2) {
      // 统计有流量的设备数量
      int devicesWithTraffic = deviceList.where((d) => d['totalBytes'] > 0).length;

      if (devicesWithTraffic >= 2) {
        for (var device in deviceList) {
          double percentage = device['percentage'];

          // 如果百分比>=99.9%，限制为99.9%（因为其他设备至少有0.1%）
          if (percentage >= 99.9) {
            device['percentage'] = 99.9;
          }
          // 如果百分比>0但<0.1%，至少显示0.1%
          else if (percentage > 0 && percentage < 0.1) {
            device['percentage'] = 0.1;
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.all(context.spacingLarge),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.spacingSmall),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.pie_chart,
                        color: primaryColor,
                        size: context.iconMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '流量统计详情',
                            style: TextStyle(
                              fontSize: context.fontLarge,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '↑ ${_formatTraffic(totalUpBytes)} ↓ ${_formatTraffic(totalDownBytes)}',
                            style: TextStyle(
                              fontSize: context.fontSmall,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // 内容区域
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.spacingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 三个统计卡片
                      Row(
                        children: [
                          // 总上传
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(context.spacingMedium),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.arrow_upward, color: Colors.green[400], size: 20),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatTraffic(totalUpBytes),
                                    style: TextStyle(
                                      fontSize: context.fontMedium,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[400],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '总上传',
                                    style: TextStyle(
                                      fontSize: context.fontSmall,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 总下载
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(context.spacingMedium),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.arrow_downward, color: Colors.blue[400], size: 20),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatTraffic(totalDownBytes),
                                    style: TextStyle(
                                      fontSize: context.fontMedium,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[400],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '总下载',
                                    style: TextStyle(
                                      fontSize: context.fontSmall,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 总计
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(context.spacingMedium),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.swap_vert, color: primaryColor, size: 20),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatTraffic(totalBytes),
                                    style: TextStyle(
                                      fontSize: context.fontMedium,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '总计',
                                    style: TextStyle(
                                      fontSize: context.fontSmall,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 设备流量分布标题
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4DD0E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.devices_other,
                            size: context.iconXSmall,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '设备流量分布',
                            style: TextStyle(
                              fontSize: context.fontMedium,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${deviceList.length} 设备',
                            style: TextStyle(
                              fontSize: context.fontBody,
                              color: const Color(0xFF4DD0E1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // 提示文字
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: context.iconXSmall,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '注：VNT 仅统计虚拟网络流量，无法追踪本地其他程序的流量',
                              style: TextStyle(
                                fontSize: context.fontXSmall,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 设备列表
                      if (deviceList.isEmpty)
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(context.spacingXLarge + context.spacingXSmall),
                            child: Text(
                              '暂无设备流量数据',
                              style: TextStyle(
                                fontSize: context.fontBody,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ),
                        )
                      else
                        ...deviceList.asMap().entries.map((entry) {
                          int index = entry.key;
                          Map<String, dynamic> device = entry.value;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(context.spacingMedium),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 设备信息行
                                Row(
                                  children: [
                                    // 序号
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFA726).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontSize: context.fontSmall,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFFFA726),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // IP地址
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            device['ip'],
                                            style: TextStyle(
                                              fontSize: context.fontBody,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            device['ip'],
                                            style: TextStyle(
                                              fontSize: context.fontXSmall,
                                              color: isDark ? Colors.white54 : Colors.black45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 百分比
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: context.spacingSmall, vertical: context.spacingXSmall / 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF81C784).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${device['percentage'].toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: context.fontBody,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF81C784),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // 进度条
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (device['percentage'] / 100).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF81C784)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 流量详情
                                Row(
                                  children: [
                                    Icon(Icons.arrow_upward, size: context.iconXSmall, color: Colors.green[400]),
                                    const SizedBox(width: 4),
                                    Text(
                                      device['upFormatted'],
                                      style: TextStyle(
                                        fontSize: context.fontSmall,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(Icons.arrow_downward, size: context.iconXSmall, color: Colors.blue[400]),
                                    const SizedBox(width: 4),
                                    Text(
                                      device['downFormatted'],
                                      style: TextStyle(
                                        fontSize: context.fontSmall,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(Icons.swap_vert, size: context.iconXSmall, color: primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      device['totalFormatted'],
                                      style: TextStyle(
                                        fontSize: context.fontSmall,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                      const SizedBox(height: 20),

                      // 关闭按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor.withOpacity(0.15),
                            foregroundColor: primaryColor,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: context.spacingMedium),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            '关闭',
                            style: TextStyle(
                              fontSize: context.fontMedium,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 格式化流量显示
  String _formatTraffic(double bytes) {
    if (bytes < 1024) {
      return '${bytes.toStringAsFixed(0)} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  // 流量统计环形图
  Widget _buildTrafficPieChart(BuildContext context, bool isDark) {
    // 解析流量数据，转换为字节数
    double upBytes = _parseTrafficToBytes(_totalUpStream);
    double downBytes = _parseTrafficToBytes(_totalDownStream);

    // 计算总流量
    double totalBytes = upBytes + downBytes;

    // 计算比例
    double upValue = totalBytes > 0 ? upBytes : 50;
    double downValue = totalBytes > 0 ? downBytes : 50;

    // 使用响应式尺寸
    final centerRadius = ResponsiveUtils.getPieChartCenterRadius(context);
    final sectionRadius = ResponsiveUtils.getPieChartSectionRadius(context);

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: centerRadius,
        sections: [
          PieChartSectionData(
            color: Colors.cyan[400],
            value: upValue,
            title: '',
            radius: sectionRadius,
          ),
          PieChartSectionData(
            color: Colors.blue[400],
            value: downValue,
            title: '',
            radius: sectionRadius,
          ),
        ],
      ),
    );
  }

  // 复制到剪贴板
  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    showTopToast(context, message, isSuccess: true);
  }

  // 图例项
  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      children: [
        Container(
          width: context.w(12),
          height: context.w(12),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: context.spacing(6)),
        Text(
          label,
          style: TextStyle(
            fontSize: context.sp(12),
            color: color,
          ),
        ),
      ],
    );
  }

  // 信息卡片网格
  Widget _buildInfoCardsGrid(bool isDark, bool isWideScreen, bool hasConnection) {
    return Column(
      children: [
        // 第一行：当前设备、当前配置
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                isDark,
                icon: Icons.computer,
                title: '当前设备',
                value: hasConnection ? _deviceName : '未连接',
                subtitle: hasConnection ? _natType : '',
                isNatType: true,
                onTap: hasConnection ? () => _showCurrentDeviceDialog(isDark) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                isDark,
                icon: Icons.settings_input_antenna,
                title: '当前配置',
                value: hasConnection ? _configName : '未连接',
                subtitle: hasConnection
                    ? (_isEncrypted ? '$_encryptionAlgorithm 加密' : '未加密')
                    : '',
                isEncrypted: hasConnection ? _isEncrypted : false,
                onTap: hasConnection ? () => _showConfigDialog(isDark) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 第二行：连接设备、虚拟IP
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                isDark,
                icon: Icons.devices_other,
                title: '连接设备',
                value: hasConnection ? '$_deviceCount 台' : '0 台',
                subtitle: hasConnection
                    ? '${_deviceCount - _offlineDeviceCount} 在线 / $_offlineDeviceCount 离线'
                    : '0 在线 / 0 离线',
                onlineCount: hasConnection ? _deviceCount - _offlineDeviceCount : 0,
                offlineCount: hasConnection ? _offlineDeviceCount : 0,
                onTap: () => _showDevicesDialog(isDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                isDark,
                icon: Icons.lan,
                title: '虚拟 IP',
                value: hasConnection ? _virtualIp : '未连接',
                subtitle: hasConnection
                    ? (_isVirtualIpAutoAssigned ? '服务器自动分配' : '用户静态指定')
                    : '',
                showCopyButton: hasConnection && _virtualIp.isNotEmpty,
                onCopy: () => _copyToClipboard(_virtualIp, '$_virtualIp 已复制'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 第三行：中继服务器（占满整行）
        _buildInfoCard(
          isDark,
          icon: Icons.router,
          title: '中继服务器',
          value: hasConnection ? _relayServer : '未连接',
          subtitle: '',
          showCopyButton: hasConnection && _relayServer.isNotEmpty,
          onCopy: () => _copyToClipboard(_relayServer, '$_relayServer 已复制'),
        ),
      ],
    );
  }

  // 信息卡片
  Widget _buildInfoCard(
    bool isDark, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    bool showCopyButton = false,
    VoidCallback? onCopy,
    VoidCallback? onTap,
    bool? isEncrypted,
    String protocol = '',
    int onlineCount = 0,
    int offlineCount = 0,
    bool isNatType = false, // 标识是否为NAT类型
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    Widget cardContent = Container(
      padding: EdgeInsets.all(context.spacingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        borderRadius: BorderRadius.circular(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: primaryColor,
                size: context.iconSmall,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: context.fontBody,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 显示协议标签（中继服务器卡片）
              if (protocol.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: context.spacingXSmall / 2, vertical: context.spacingXSmall / 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    protocol,
                    style: TextStyle(
                      fontSize: context.fontXSmall,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              if (showCopyButton)
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.all(context.spacingXSmall / 2),
                    child: Icon(
                      Icons.content_copy,
                      size: context.iconXSmall,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: context.fontMedium,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                // 当前配置卡片：显示加密图标
                if (isEncrypted != null)
                  Row(
                    children: [
                      Icon(
                        isEncrypted ? Icons.lock : Icons.lock_open,
                        size: 11,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: context.fontXSmall,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                // 连接设备卡片：显示在线/离线数量（带颜色）
                else if (onlineCount > 0 || offlineCount > 0)
                  Row(
                    children: [
                      Text(
                        '$onlineCount',
                        style: TextStyle(
                          fontSize: context.fontXSmall,
                          color: Colors.green[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' 在线 / ',
                        style: TextStyle(
                          fontSize: context.fontXSmall,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      Text(
                        '$offlineCount',
                        style: TextStyle(
                          fontSize: context.fontXSmall,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' 离线',
                        style: TextStyle(
                          fontSize: context.fontXSmall,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  )
                // NAT类型卡片：显示NAT类型图标
                else if (isNatType)
                  Row(
                    children: [
                      Icon(
                        subtitle.contains('Cone') ? Icons.hub : Icons.device_hub,
                        size: 11,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: context.fontXSmall,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: context.fontXSmall,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ],
          ),
        ],
      ),
    );

    // 如果有点击事件，用 InkWell 包装
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildQuickActions(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            isDark,
            icon: Icons.add_circle_outline,
            label: '新建配置',
            onTap: widget.onNavigateToConfig,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            isDark,
            icon: Icons.settings,
            label: '系统设置',
            onTap: widget.onNavigateToSettings,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    bool isDark, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.spacingLarge, horizontal: context.spacingMedium),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: primaryColor,
              size: context.iconMedium,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: context.fontMedium,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示网络速度监控弹窗
  void _showNetworkSpeedDialog(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.all(context.spacingLarge),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.spacingSmall),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.speed,
                        color: primaryColor,
                        size: context.iconMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '网络速度监控',
                            style: TextStyle(
                              fontSize: context.fontLarge,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '实时速度统计与分析',
                            style: TextStyle(
                              fontSize: context.fontSmall,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // 内容区域
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.spacingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 上传/下载速度卡片
                      Row(
                        children: [
                          // 上传速度
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(context.spacingMedium),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_upward,
                                        color: Colors.green[400],
                                        size: context.iconXSmall,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '上传速度',
                                        style: TextStyle(
                                          fontSize: context.fontSmall,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _currentUpSpeed.split(' ')[0],
                                    style: TextStyle(
                                      fontSize: context.fontXLarge,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[400],
                                      height: 1.0,
                                    ),
                                  ),
                                  Text(
                                    _currentUpSpeed.split(' ').length > 1 ? _currentUpSpeed.split(' ')[1] : 'B/s',
                                    style: TextStyle(
                                      fontSize: context.fontBody,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 下载速度
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(context.spacingMedium),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_downward,
                                        color: Colors.blue[400],
                                        size: context.iconXSmall,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '下载速度',
                                        style: TextStyle(
                                          fontSize: context.fontSmall,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _currentDownSpeed.split(' ')[0],
                                    style: TextStyle(
                                      fontSize: context.fontXLarge,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[400],
                                      height: 1.0,
                                    ),
                                  ),
                                  Text(
                                    _currentDownSpeed.split(' ').length > 1 ? _currentDownSpeed.split(' ')[1] : 'B/s',
                                    style: TextStyle(
                                      fontSize: context.fontBody,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 速度统计
                      Container(
                        padding: EdgeInsets.all(context.spacingMedium),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.bar_chart,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  size: context.iconXSmall,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '速度统计',
                                  style: TextStyle(
                                    fontSize: context.fontBody,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // 上传统计
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.green[400],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '上传',
                                        style: TextStyle(
                                          fontSize: context.fontSmall,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildSpeedStatItem('当前', _currentUpSpeed, isDark),
                                          ),
                                          Expanded(
                                            child: _buildSpeedStatItem('峰值', _formatSpeed(_peakUpSpeed), isDark),
                                          ),
                                          Expanded(
                                            child: _buildSpeedStatItem('平均', _formatSpeed(_avgUpSpeed), isDark),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // 下载统计
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[400],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '下载',
                                        style: TextStyle(
                                          fontSize: context.fontSmall,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildSpeedStatItem('当前', _currentDownSpeed, isDark),
                                          ),
                                          Expanded(
                                            child: _buildSpeedStatItem('峰值', _formatSpeed(_peakDownSpeed), isDark),
                                          ),
                                          Expanded(
                                            child: _buildSpeedStatItem('平均', _formatSpeed(_avgDownSpeed), isDark),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 连接状态
                      Container(
                        padding: EdgeInsets.all(context.spacingMedium),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.wifi,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  size: context.iconXSmall,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '连接状态',
                                  style: TextStyle(
                                    fontSize: context.fontBody,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildConnectionStatRow(
                              Icons.timer,
                              '平均延迟',
                              '${_avgLatency}ms',
                              isDark,
                              valueColor: _getLatencyColor(_avgLatency),
                            ),
                            const SizedBox(height: 8),
                            _buildConnectionStatRow(
                              Icons.warning_amber,
                              '丢包率',
                              '${_packetLoss.toStringAsFixed(2)}%',
                              isDark,
                              valueColor: _packetLoss > 5 ? Colors.red[400] : Colors.green[400],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 速度趋势图
                      Container(
                        padding: EdgeInsets.all(context.spacingMedium),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.show_chart,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  size: context.iconXSmall,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '速度趋势',
                                  style: TextStyle(
                                    fontSize: context.fontBody,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 120,
                              child: _buildSpeedChart(isDark),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 关闭按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor.withOpacity(0.15),
                            foregroundColor: primaryColor,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: context.spacingMedium),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            '关闭',
                            style: TextStyle(
                              fontSize: context.fontMedium,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 速度统计项
  Widget _buildSpeedStatItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.fontXSmall,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: context.fontBody,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  // 连接状态行
  Widget _buildConnectionStatRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: context.iconXSmall,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: context.fontBody,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: context.fontBody,
            fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  // 显示网络质量分析弹窗
  void _showNetworkQualityDialog(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    // 检查是否有连接
    final hasConnection = _connectionCount > 0;

    // 计算P2P和Relay数量
    int p2pCount = 0;
    int relayCount = 0;
    int totalOnlineDevices = 0;

    final allVnts = vntManager.map;
    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        final devices = vntBox.peerDeviceList();
        for (var device in devices) {
          if (_isDeviceOnline(device.status)) {
            totalOnlineDevices++;
            final route = vntBox.route(device.virtualIp);
            if (route != null) {
              if (route.metric == 1) {
                p2pCount++;
              } else {
                relayCount++;
              }
            }
          }
        }
      }
    }

    // 计算P2P百分比
    double p2pPercentage = totalOnlineDevices > 0 ? (p2pCount / totalOnlineDevices) * 100 : 0;

    // 计算综合得分（满分100）
    int qualityScore = hasConnection ? _calculateQualityScore(p2pPercentage, p2pCount, relayCount) : 0;

    // 根据得分确定评级和描述
    String rating;
    String ratingDescription;
    Color ratingColor;

    if (!hasConnection) {
      rating = '未连接';
      ratingDescription = '当前未连接到中继服务器，无法评估网络质量';
      ratingColor = Colors.grey[400]!;
    } else if (qualityScore >= 90) {
      rating = '优秀';
      ratingDescription = '网络状态极佳，延迟低、无明显丢包、中继服务器连接稳定，可以进行游戏、视频通话等对网络要求高的活动';
      ratingColor = Colors.green[400]!;
    } else if (qualityScore >= 70) {
      rating = '良好';
      ratingDescription = '网络状态良好，延迟适中、丢包率低，可以正常使用各类网络应用';
      ratingColor = Colors.blue[400]!;
    } else if (qualityScore >= 50) {
      rating = '一般';
      ratingDescription = '网络状态一般，存在一定延迟或丢包，中继时可能影响实时性要求高的应用体验';
      ratingColor = Colors.orange[400]!;
    } else {
      rating = '较差';
      ratingDescription = '网络状态较差，延迟高或丢包严重，建议切换网络环境或更换中继服务器';
      ratingColor = Colors.red[400]!;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.all(context.spacingLarge),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.spacingSmall),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.signal_cellular_alt,
                        color: primaryColor,
                        size: context.iconMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '网络质量分析',
                            style: TextStyle(
                              fontSize: context.fontLarge,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '延迟、丢包与连接模式综合评估',
                            style: TextStyle(
                              fontSize: context.fontSmall,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // 内容区域
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.spacingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 得分卡片
                      Container(
                        padding: EdgeInsets.all(context.spacingLarge),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F8E9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            // 得分圆环
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: CircularProgressIndicator(
                                      value: qualityScore / 100,
                                      strokeWidth: 10,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: AlwaysStoppedAnimation<Color>(ratingColor),
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$qualityScore',
                                        style: TextStyle(
                                          fontSize: context.fontXLarge * 1.5,
                                          fontWeight: FontWeight.bold,
                                          color: ratingColor,
                                          height: 1.0,
                                        ),
                                      ),
                                      Text(
                                        '分',
                                        style: TextStyle(
                                          fontSize: context.fontBody,
                                          color: isDark ? Colors.white54 : Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // 评级描述
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.sentiment_satisfied_alt,
                                        color: ratingColor,
                                        size: context.iconMedium,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        rating,
                                        style: TextStyle(
                                          fontSize: context.fontXLarge,
                                          fontWeight: FontWeight.bold,
                                          color: ratingColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    ratingDescription,
                                    style: TextStyle(
                                      fontSize: context.fontBody,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 详细指标标题
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF81C784),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '详细指标',
                            style: TextStyle(
                              fontSize: context.fontMedium,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 网络延迟
                      Container(
                        padding: EdgeInsets.all(context.spacingMedium),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(context.spacingSmall),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.timer_outlined,
                                    color: Colors.grey[600],
                                    size: context.iconMedium,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '网络延迟',
                                        style: TextStyle(
                                          fontSize: context.fontBody,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _avgLatency > 0
                                            ? (_avgLatency <= 50
                                                ? '延迟优秀，服务器响应迅速'
                                                : _avgLatency <= 100
                                                    ? '延迟良好，正常连接无影响'
                                                    : _avgLatency <= 200
                                                        ? '延迟较高，中继时可能影响实时应用'
                                                        : '延迟过高，中继效果差，建议优化网络')
                                            : '暂无延迟数据',
                                        style: TextStyle(
                                          fontSize: context.fontSmall,
                                          color: isDark ? Colors.white54 : Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _avgLatency > 0 ? '${_avgLatency}ms' : '--',
                                  style: TextStyle(
                                    fontSize: context.fontXLarge,
                                    fontWeight: FontWeight.bold,
                                    color: _avgLatency > 0
                                        ? (_avgLatency <= 50
                                            ? Colors.green[400]
                                            : _avgLatency <= 100
                                                ? Colors.orange[400]
                                                : Colors.red[400])
                                        : (isDark ? Colors.white70 : Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 延迟进度条
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 1.0, // 始终100%
                                minHeight: 8,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _avgLatency > 0
                                      ? (_avgLatency <= 50
                                          ? Colors.green[400]!
                                          : _avgLatency <= 100
                                              ? Colors.orange[400]!
                                              : Colors.red[400]!)
                                      : Colors.grey[300]!,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 丢包率
                      Container(
                        padding: EdgeInsets.all(context.spacingMedium),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(context.spacingSmall),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF81C784).withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.warning_amber_outlined,
                                    color: const Color(0xFF81C784),
                                    size: context.iconMedium,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '丢包率',
                                        style: TextStyle(
                                          fontSize: context.fontBody,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _packetLoss == 0
                                            ? '无丢包，服务器连接稳定'
                                            : _packetLoss <= 1
                                                ? '轻微丢包，对使用影响极小'
                                                : _packetLoss <= 2
                                                    ? '丢包率较低，基本不影响中继'
                                                    : _packetLoss <= 5
                                                        ? '丢包率偏高，中继时可能影响体验'
                                                        : '丢包严重，可能无法正常使用服务器中继',
                                        style: TextStyle(
                                          fontSize: context.fontSmall,
                                          color: isDark ? Colors.white54 : Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${_packetLoss.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    fontSize: context.fontXLarge,
                                    fontWeight: FontWeight.bold,
                                    color: _packetLoss == 0 ? Colors.green[400] : Colors.red[400],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 丢包率进度条
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _packetLoss == 0 ? 1.0 : (_packetLoss / 100).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _packetLoss == 0
                                      ? Colors.green[400]!
                                      : _packetLoss <= 2
                                          ? Colors.orange[400]!
                                          : Colors.red[400]!,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 连接模式
                      Container(
                        padding: EdgeInsets.all(context.spacingMedium),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(context.spacingSmall),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.hub_outlined,
                                    color: Colors.red[400],
                                    size: context.iconMedium,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    '连接模式',
                                    style: TextStyle(
                                      fontSize: context.fontBody,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // P2P和中继统计
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green[400],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'P2P: $p2pCount',
                                  style: TextStyle(
                                    fontSize: context.fontBody,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.orange[400],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '中继: $relayCount',
                                  style: TextStyle(
                                    fontSize: context.fontBody,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${p2pPercentage.toStringAsFixed(0)}% P2P',
                                  style: TextStyle(
                                    fontSize: context.fontBody,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[400],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 连接模式进度条
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  if (totalOnlineDevices > 0)
                                    Row(
                                      children: [
                                        if (p2pCount > 0)
                                          Expanded(
                                            flex: p2pCount,
                                            child: Container(
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: Colors.green[400],
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(4),
                                                  bottomLeft: Radius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (relayCount > 0)
                                          Expanded(
                                            flex: relayCount,
                                            child: Container(
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: Colors.orange[400],
                                                borderRadius: BorderRadius.only(
                                                  topRight: p2pCount == 0 ? const Radius.circular(4) : Radius.zero,
                                                  bottomRight: p2pCount == 0 ? const Radius.circular(4) : Radius.zero,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Ping历史
                      Container(
                        padding: EdgeInsets.all(context.spacingMedium),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.show_chart,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  size: context.iconXSmall,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Ping 历史',
                                  style: TextStyle(
                                    fontSize: context.fontBody,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Ping历史图表
                            Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _pingHistory.isEmpty
                                  ? Center(
                                      child: Text(
                                        '暂无数据',
                                        style: TextStyle(
                                          fontSize: context.fontSmall,
                                          color: isDark ? Colors.white54 : Colors.black45,
                                        ),
                                      ),
                                    )
                                  : Padding(
                                      padding: EdgeInsets.all(context.spacingXSmall),
                                      child: Row(
                                        children: List.generate(
                                          _pingHistory.length > 100 ? 100 : _pingHistory.length,
                                          (index) {
                                            bool isSuccess = _pingHistory[index];
                                            return Expanded(
                                              child: Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                                decoration: BoxDecoration(
                                                  color: isSuccess ? Colors.green[400] : Colors.red[400],
                                                  borderRadius: BorderRadius.circular(1),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            // 图例
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green[400],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '成功',
                                  style: TextStyle(
                                    fontSize: context.fontSmall,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red[400],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '失败',
                                  style: TextStyle(
                                    fontSize: context.fontSmall,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 关闭按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor.withOpacity(0.15),
                            foregroundColor: primaryColor,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: context.spacingMedium),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            '关闭',
                            style: TextStyle(
                              fontSize: context.fontMedium,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示当前设备信息弹窗
  void _showCurrentDeviceDialog(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    // 获取当前设备的详细信息
    Map<String, dynamic> deviceInfo = {};

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

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.all(context.spacingLarge),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.spacingSmall),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.computer,
                        color: primaryColor,
                        size: context.iconMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前设备信息',
                            style: TextStyle(
                              fontSize: context.fontLarge,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _deviceName,
                            style: TextStyle(
                              fontSize: context.fontSmall,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // 内容区域
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.spacingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 基本信息
                      _buildSectionTitle(isDark, '基本信息'),
                      _buildDeviceInfoItem(isDark, '虚拟 IP', deviceInfo['virtualIp'] ?? '--'),
                      _buildDeviceInfoItem(isDark, '虚拟网关', deviceInfo['virtualGateway'] ?? '--'),
                      _buildDeviceInfoItem(isDark, '虚拟网段', deviceInfo['virtualNetmask'] ?? '--'),
                      _buildDeviceInfoItem(isDark, '虚拟网络', deviceInfo['virtualNetwork'] ?? '--'),
                      _buildDeviceInfoItem(isDark, '广播地址', deviceInfo['broadcastIp'] ?? '--'),
                      _buildDeviceInfoItem(isDark, '连接状态', deviceInfo['status'] ?? '--'),

                      const SizedBox(height: 16),

                      // 网络信息
                      _buildSectionTitle(isDark, '网络信息'),
                      _buildDeviceInfoItem(isDark, 'NAT 类型', deviceInfo['natType'] ?? '--'),
                      _buildDeviceInfoItem(isDark, '公网 IP', (deviceInfo['publicIps'] as List?)?.join(', ') ?? '--'),
                      _buildDeviceInfoItem(isDark, '本地 IP', deviceInfo['localIpv4'] ?? '--'),
                      _buildDeviceInfoItem(isDark, 'IPv6', deviceInfo['ipv6'] ?? '--'),
                      _buildDeviceInfoItem(isDark, '服务器地址', deviceInfo['connectServer'] ?? '--'),

                      const SizedBox(height: 16),

                      // 流量统计
                      _buildSectionTitle(isDark, '流量统计'),
                      _buildDeviceInfoItem(isDark, '上传流量', deviceInfo['upStream'] ?? '0B'),
                      _buildDeviceInfoItem(isDark, '下载流量', deviceInfo['downStream'] ?? '0B'),
                    ],
                  ),
                ),
              ),

              // 关闭按钮
              Padding(
                padding: EdgeInsets.all(context.spacingLarge),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor.withOpacity(0.15),
                      foregroundColor: primaryColor,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: context.spacingMedium),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '关闭',
                      style: TextStyle(
                        fontSize: context.fontMedium,
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

  // 构建分组标题
  Widget _buildSectionTitle(bool isDark, String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacingSmall),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF64B5F6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: context.fontMedium,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // 构建设备信息项
  Widget _buildDeviceInfoItem(bool isDark, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(context.spacingMedium),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: context.fontBody,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: context.fontBody,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // 显示配置信息弹窗
  void _showConfigDialog(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    // 获取当前配置信息
    NetworkConfig? configNullable;

    final allVnts = vntManager.map;
    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        configNullable = vntBox.getNetConfig();
        break;
      }
    }

    if (configNullable == null) return;

    // 确保 config 非空
    final config = configNullable;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.all(context.spacingLarge),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.spacingSmall),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.settings_input_antenna,
                        color: primaryColor,
                        size: context.iconMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '配置详情',
                            style: TextStyle(
                              fontSize: context.fontLarge,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            config.configName,
                            style: TextStyle(
                              fontSize: context.fontSmall,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // 内容区域
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.spacingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 基本信息
                      _buildSectionTitle(isDark, '基本信息'),
                      _buildDeviceInfoItem(isDark, '配置名称', config.configName),
                      _buildDeviceInfoItem(isDark, '设备名称', config.deviceName),
                      _buildDeviceInfoItem(isDark, '虚拟 IP', config.virtualIPv4.isEmpty ? '自动分配' : config.virtualIPv4),
                      _buildDeviceInfoItem(isDark, '设备 ID', config.deviceID.isEmpty ? '自动生成' : config.deviceID),
                      _buildDeviceInfoItem(isDark, '本地 IPv4', config.localIpv4.isEmpty ? '自动识别' : config.localIpv4),

                      const SizedBox(height: 16),

                      // 服务器配置
                      _buildSectionTitle(isDark, '服务器配置'),
                      _buildDeviceInfoItem(isDark, '服务器地址', config.serverAddress),
                      _buildDeviceInfoItem(isDark, 'Token', config.token.isEmpty ? '未设置' : '********'),
                      _buildDeviceInfoItem(isDark, '连接协议', config.protocol.isEmpty ? 'UDP' : config.protocol.toUpperCase()),
                      _buildDeviceInfoItem(isDark, 'STUN 服务器', config.stunServers.isEmpty ? '默认' : config.stunServers.join(', ')),

                      const SizedBox(height: 16),

                      // 安全配置
                      _buildSectionTitle(isDark, '安全配置'),
                      _buildDeviceInfoItem(isDark, '组网密码', config.groupPassword.isEmpty ? '未设置' : '********'),
                      _buildDeviceInfoItem(isDark, '加密算法', config.encryptionAlgorithm.isEmpty ? '默认' : config.encryptionAlgorithm.toUpperCase()),
                      _buildDeviceInfoItem(isDark, '服务器加密', config.isServerEncrypted ? '已启用' : '未启用'),
                      _buildDeviceInfoItem(isDark, '数据指纹验证', config.dataFingerprintVerification ? '已启用' : '未启用'),

                      const SizedBox(height: 16),

                      // 网络配置
                      _buildSectionTitle(isDark, '网络配置'),
                      _buildDeviceInfoItem(isDark, 'MTU', config.mtu.toString()),
                      _buildDeviceInfoItem(isDark, '端口', config.ports.isEmpty ? '自动' : config.ports.join(', ')),
                      _buildDeviceInfoItem(isDark, '虚拟网卡名称', config.virtualNetworkCardName.isEmpty ? '默认' : config.virtualNetworkCardName),
                      _buildDeviceInfoItem(isDark, 'DNS', config.dns.isEmpty ? '未设置' : config.dns.join(', ')),

                      const SizedBox(height: 16),

                      // 高级配置
                      _buildSectionTitle(isDark, '高级配置'),
                      _buildDeviceInfoItem(isDark, '打洞模式', config.punchModel.isEmpty ? '默认' : config.punchModel),
                      _buildDeviceInfoItem(isDark, '通道类型', config.useChannelType.isEmpty ? '默认' : config.useChannelType),
                      _buildDeviceInfoItem(isDark, '压缩算法', config.compressor.isEmpty ? '未启用' : config.compressor),
                      _buildDeviceInfoItem(isDark, '优先延迟', config.firstLatency ? '已启用' : '未启用'),
                      _buildDeviceInfoItem(isDark, '禁用代理', config.noInIpProxy ? '是' : '否'),
                      _buildDeviceInfoItem(isDark, '允许 WireGuard', config.allowWg ? '是' : '否'),

                      if (config.inIps.isNotEmpty || config.outIps.isNotEmpty || config.portMappings.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSectionTitle(isDark, '路由与映射'),
                        if (config.inIps.isNotEmpty)
                          _buildDeviceInfoItem(isDark, '对端网段', config.inIps.join(', ')),
                        if (config.outIps.isNotEmpty)
                          _buildDeviceInfoItem(isDark, '本地网段', config.outIps.join(', ')),
                        if (config.portMappings.isNotEmpty)
                          _buildDeviceInfoItem(isDark, '端口映射', config.portMappings.join(', ')),
                      ],

                      if (config.simulatedPacketLossRate > 0 || config.simulatedLatency > 0) ...[
                        const SizedBox(height: 16),
                        _buildSectionTitle(isDark, '模拟测试'),
                        if (config.simulatedPacketLossRate > 0)
                          _buildDeviceInfoItem(isDark, '模拟丢包率', '${config.simulatedPacketLossRate}%'),
                        if (config.simulatedLatency > 0)
                          _buildDeviceInfoItem(isDark, '模拟延迟', '${config.simulatedLatency}ms'),
                      ],
                    ],
                  ),
                ),
              ),

              // 关闭按钮
              Padding(
                padding: EdgeInsets.all(context.spacingLarge),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor.withOpacity(0.15),
                      foregroundColor: primaryColor,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: context.spacingMedium),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '关闭',
                      style: TextStyle(
                        fontSize: context.fontMedium,
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

  // 计算网络质量综合得分
  int _calculateQualityScore(double p2pPercentage, int p2pCount, int relayCount) {
    int score = 100;

    // 延迟评分（最多扣30分）
    if (_avgLatency > 0) {
      if (_avgLatency > 200) {
        score -= 30;
      } else if (_avgLatency > 100) {
        score -= 20;
      } else if (_avgLatency > 50) {
        score -= 10;
      }
    }

    // 丢包率评分（最多扣40分）- 轻微丢包（≤1%）不扣分
    if (_packetLoss > 10) {
      score -= 40;
    } else if (_packetLoss > 5) {
      score -= 30;
    } else if (_packetLoss > 2) {
      score -= 20;
    } else if (_packetLoss > 1) {
      score -= 10;
    }
    // 丢包率 ≤ 1% 不扣分

    // P2P比例评分（最多扣30分）
    // 如果P2P和中继都为0，说明没有设备连接，不扣分
    if (p2pCount > 0 || relayCount > 0) {
      if (p2pPercentage < 30) {
        score -= 30;
      } else if (p2pPercentage < 50) {
        score -= 20;
      } else if (p2pPercentage < 70) {
        score -= 10;
      }
    }

    return score.clamp(0, 100);
  }

  // 比较IP地址大小（用于排序）
  int _compareIpAddresses(String ip1, String ip2) {
    List<int> parts1 = ip1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> parts2 = ip2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 4; i++) {
      if (parts1[i] != parts2[i]) {
        return parts1[i].compareTo(parts2[i]);
      }
    }
    return 0;
  }

  // 根据延迟值返回对应的颜色
  Color _getLatencyColor(int rtValue) {
    if (rtValue <= 0 || rtValue >= 9999) {
      return Colors.grey[400]!; // 无效延迟
    } else if (rtValue < 50) {
      return Colors.green[400]!; // 优秀：绿色
    } else if (rtValue < 100) {
      return Colors.lightGreen[400]!; // 良好：浅绿色
    } else if (rtValue < 200) {
      return Colors.yellow[700]!; // 一般：黄色
    } else if (rtValue < 300) {
      return Colors.orange[400]!; // 较差：橙色
    } else {
      return Colors.red[400]!; // 很差：红色
    }
  }

  // 显示设备列表弹窗
  void _showDevicesDialog(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    // 获取所有设备数据
    List<Map<String, dynamic>> deviceList = [];
    int onlineCount = 0;
    int offlineCount = 0;

    final allVnts = vntManager.map;
    for (var entry in allVnts.entries) {
      final vntBox = entry.value;
      if (!vntBox.isClosed()) {
        final devices = vntBox.peerDeviceList();
        for (var device in devices) {
          bool isOnline = _isDeviceOnline(device.status);
          if (isOnline) {
            onlineCount++;
          } else {
            offlineCount++;
          }

          // 获取路由信息
          final route = vntBox.route(device.virtualIp);
          String p2pRelay = '';
          String rt = '';
          int rtValue = 0;
          if (route != null) {
            p2pRelay = route.metric == 1 ? 'P2P' : 'Relay';
            rtValue = route.rt;
            rt = route.rt > 0 && route.rt < 9999 ? '${route.rt}ms' : '--';
          }

          // 获取NAT类型信息
          String natType = '';
          final natInfo = vntBox.peerNatInfo(device.virtualIp);
          if (natInfo != null) {
            natType = natInfo.natType;
          }

          deviceList.add({
            'name': device.name,
            'ip': device.virtualIp,
            'status': device.status,
            'isOnline': isOnline,
            'p2pRelay': p2pRelay,
            'rt': rt,
            'rtValue': rtValue,
            'natType': natType,
          });
        }
      }
    }

    // 排序：在线设备在前，离线设备在后，然后按IP地址排序
    deviceList.sort((a, b) {
      if (a['isOnline'] && !b['isOnline']) return -1;
      if (!a['isOnline'] && b['isOnline']) return 1;
      // 按IP地址排序
      return _compareIpAddresses(a['ip'], b['ip']);
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.all(context.spacingLarge),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.spacingSmall),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.devices_other,
                        color: primaryColor,
                        size: context.iconMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '组网设备',
                            style: TextStyle(
                              fontSize: context.fontLarge,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$onlineCount 在线 / ${deviceList.length} 总计',
                            style: TextStyle(
                              fontSize: context.fontSmall,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // 内容区域
              Flexible(
                child: deviceList.isEmpty
                    ? Padding(
                        padding: EdgeInsets.all(context.spacingXLarge + context.spacingMedium),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.devices_other_outlined,
                              size: 64,
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无设备',
                              style: TextStyle(
                                fontSize: context.fontMedium,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(context.spacingLarge),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 在线设备标题
                            if (onlineCount > 0) ...[
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.green[400],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '在线设备',
                                    style: TextStyle(
                                      fontSize: context.fontBody,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$onlineCount',
                                    style: TextStyle(
                                      fontSize: context.fontBody,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[400],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],

                            // 设备列表
                            ...deviceList.asMap().entries.map((entry) {
                              int index = entry.key;
                              Map<String, dynamic> device = entry.value;
                              bool isOnline = device['isOnline'];

                              // 如果是第一个离线设备，显示离线设备标题
                              bool showOfflineTitle = false;
                              if (!isOnline && (index == 0 || deviceList[index - 1]['isOnline'])) {
                                showOfflineTitle = true;
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 离线设备标题
                                  if (showOfflineTitle) ...[
                                    if (index > 0) const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[400],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '离线设备',
                                          style: TextStyle(
                                            fontSize: context.fontBody,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$offlineCount',
                                          style: TextStyle(
                                            fontSize: context.fontBody,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                  ],

                                  // 设备卡片
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: EdgeInsets.all(context.spacingMedium),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isOnline
                                            ? Colors.green[400]!.withOpacity(0.3)
                                            : Colors.grey[300]!.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 第一行：设备名和状态
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.computer,
                                              size: context.iconSmall,
                                              color: isOnline ? Colors.green[400] : Colors.grey[400],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                device['name'].isNotEmpty ? device['name'] : '未命名设备',
                                                style: TextStyle(
                                                  fontSize: context.fontMedium,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: context.spacingXSmall, vertical: context.spacingXSmall / 2),
                                              decoration: BoxDecoration(
                                                color: isOnline
                                                    ? Colors.green[400]!.withOpacity(0.2)
                                                    : Colors.grey[600]!.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isOnline ? '在线' : '离线',
                                                style: TextStyle(
                                                  fontSize: context.fontSmall,
                                                  fontWeight: FontWeight.bold,
                                                  color: isOnline ? Colors.green[400] : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // 第二行：IP地址
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.language,
                                              size: context.iconXSmall,
                                              color: isDark ? Colors.white54 : Colors.black45,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'IP: ',
                                              style: TextStyle(
                                                fontSize: context.fontBody,
                                                color: isDark ? Colors.white54 : Colors.black45,
                                              ),
                                            ),
                                            Text(
                                              device['ip'],
                                              style: TextStyle(
                                                fontSize: context.fontBody,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? Colors.white70 : Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () {
                                                Clipboard.setData(ClipboardData(text: device['ip']));
                                                showTopToast(context, '${device['ip']} 已复制', isSuccess: true);
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(context.spacingXSmall / 2),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.white.withOpacity(0.1)
                                                      : Colors.black.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Icon(
                                                  Icons.copy,
                                                  size: context.iconXSmall,
                                                  color: isDark ? Colors.white54 : Colors.black45,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (isOnline && device['p2pRelay'].isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          // 第三行：连接模式、NAT类型和延迟
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.swap_horiz,
                                                size: context.iconXSmall,
                                                color: isDark ? Colors.white54 : Colors.black45,
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: context.spacingXSmall, vertical: context.spacingXSmall / 4),
                                                decoration: BoxDecoration(
                                                  color: device['p2pRelay'] == 'P2P'
                                                      ? Colors.blue[400]!.withOpacity(0.2)
                                                      : Colors.orange[400]!.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  device['p2pRelay'],
                                                  style: TextStyle(
                                                    fontSize: context.fontXSmall,
                                                    fontWeight: FontWeight.bold,
                                                    color: device['p2pRelay'] == 'P2P'
                                                        ? Colors.blue[400]
                                                        : Colors.orange[400],
                                                  ),
                                                ),
                                              ),
                                              if (device['natType'].isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: context.spacingXSmall, vertical: context.spacingXSmall / 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.purple[400]!.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    device['natType'],
                                                    style: TextStyle(
                                                      fontSize: context.fontXSmall,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.purple[400],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: context.spacingXSmall, vertical: context.spacingXSmall / 4),
                                                decoration: BoxDecoration(
                                                  color: _getLatencyColor(device['rtValue']).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  device['rt'],
                                                  style: TextStyle(
                                                    fontSize: context.fontXSmall,
                                                    fontWeight: FontWeight.bold,
                                                    color: _getLatencyColor(device['rtValue']),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
              ),

              // 关闭按钮
              Padding(
                padding: EdgeInsets.all(context.spacingLarge),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor.withOpacity(0.15),
                      foregroundColor: primaryColor,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: context.spacingMedium),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '关闭',
                      style: TextStyle(
                        fontSize: context.fontMedium,
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
}
