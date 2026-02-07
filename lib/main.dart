import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vnt_app/src/rust/frb_generated.dart';
import 'package:vnt_app/src/rust/api/vnt_api.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/theme/theme_provider.dart';
import 'package:vnt_app/pages/main_navigation_shell.dart';
import 'package:vnt_app/data_persistence.dart';
import 'package:vnt_app/vnt/vnt_manager.dart';
import 'package:vnt_app/utils/responsive_utils.dart';
import 'package:vnt_app/network_config.dart';
import 'package:vnt_app/system_tray_manager.dart';

final SystemTray systemTray = SystemTray();
final AppWindow appWindow = AppWindow();

/// 检测是否是 Windows 10 或更高版本
bool isWindows10OrGreater() {
  if (!Platform.isWindows) return false;

  try {
    final version = Platform.operatingSystemVersion;
    // Windows 版本格式: "Microsoft Windows [Version 10.0.19045.5247]"
    // Windows 7: 6.1, Windows 8: 6.2, Windows 8.1: 6.3, Windows 10: 10.0
    final match = RegExp(r'(\d+)\.(\d+)').firstMatch(version);
    if (match != null) {
      final major = int.parse(match.group(1)!);
      return major >= 10;
    }
  } catch (e) {
    debugPrint('检测 Windows 版本失败: $e');
  }

  // 默认返回 true，使用自定义标题栏
  return true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // macOS 启动时提权检查
  // 这样用户双击 app 后只需输入一次密码，后续使用完全无感
  if (Platform.isMacOS) {
    final needsRestart = await MacOSPrivilegeManager.checkAndRequestPrivilegeOnStartup();
    if (needsRestart) {
      // app 正在以管理员权限重新启动，当前进程将退出
      return;
    }
  }

  try {
    await copyLogConfig();
  } catch (e) {
    debugPrint('copyLogConfig catch $e');
  }

  try {
    await copyAppropriateDll();
  } catch (e) {
    debugPrint('copyAppropriateDll catch $e');
  }

  await RustLib.init();

  // 初始化日志系统，所有平台统一使用log4rs
  try {
    String logDir;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // 移动平台和 macOS：使用应用文档目录
      final appDocDir = await getApplicationDocumentsDirectory();
      logDir = '${appDocDir.path}/logs';
      debugPrint('应用数据目录: ${appDocDir.path}');
    } else {
      // Windows/Linux 桌面平台：使用当前目录
      logDir = 'logs';
    }

    // 确保日志目录存在
    final logsDirectory = Directory(logDir);
    if (!await logsDirectory.exists()) {
      await logsDirectory.create(recursive: true);
      debugPrint('创建日志目录: $logDir');
    }

    // 调用Rust层初始化日志
    initLogWithPath(logDir: logDir);
    debugPrint('日志系统初始化成功，日志目录: $logDir');
  } catch (e) {
    debugPrint('初始化日志系统失败: $e');
  }

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    // macOS 使用系统原生标题栏（保留所有原生窗口功能）
    if (Platform.isMacOS) {
      // macOS 专用配置 - 使用系统标题栏
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1000, 700),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal, // macOS 使用系统标题栏
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        // 加载保存的窗口大小
        final windowSize = await DataPersistence().loadWindowSize();
        if (windowSize != null) {
          await windowManager.setSize(windowSize);
        }

        // 设置窗口标题
        await windowManager.setTitle('VNT App');

        // 显示窗口
        await appWindow.show();
      });
    } else {
      // Windows 和 Linux 保持原有逻辑
      final windowSize = await DataPersistence().loadWindowSize();
      windowManager.setTitle('VNT App');

      // 只在 Windows 10+ 上使用自定义标题栏，Windows 7 使用系统标题栏
      if (!Platform.isWindows || isWindows10OrGreater()) {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      }

      if (windowSize != null) {
        await windowManager.setSize(windowSize);
      }

      windowManager.waitUntilReadyToShow().then((_) async {
        await appWindow.show();
      });
    }
  }

  if (Platform.isAndroid) {
    VntAppCall.init();
  }

  runApp(const VntApp());
}

class VntApp extends StatefulWidget {
  const VntApp({super.key});

  @override
  State<VntApp> createState() => _VntAppState();
}

class _VntAppState extends State<VntApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _customThemeColor = AppTheme.primaryColor; // 默认主题色

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadCustomThemeColor();
  }

  Future<void> _loadThemeMode() async {
    final savedMode = await DataPersistence().loadThemeMode();
    if (savedMode != null && mounted) {
      setState(() {
        _themeMode = savedMode;
      });
    }
  }

  Future<void> _loadCustomThemeColor() async {
    final savedColor = await DataPersistence().loadCustomThemeColor();
    if (savedColor != null && mounted) {
      setState(() {
        _customThemeColor = savedColor;
      });
    }
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    DataPersistence().saveThemeMode(mode);
  }

  void _setCustomThemeColor(Color color) {
    setState(() {
      _customThemeColor = color;
    });
    DataPersistence().saveCustomThemeColor(color);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      themeMode: _themeMode,
      setThemeMode: _setThemeMode,
      customThemeColor: _customThemeColor,
      setCustomThemeColor: _setCustomThemeColor,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VNT App',
        theme: AppTheme.createLightTheme(_customThemeColor),
        darkTheme: AppTheme.createDarkTheme(_customThemeColor),
        themeMode: _themeMode,
        home: PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (didPop) return;
            if (Platform.isAndroid) {
              VntAppCall.moveTaskToBack();
            }
          },
          child: const MainApp(),
        ),
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WindowListener {
  bool rememberChoice = false;

  @override
  void initState() {
    super.initState();

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      initSystemTray();
      DataPersistence().loadCloseApp().then((isClose) {
        if (!(isClose ?? false)) {
          windowManager.setPreventClose(true);
        }
      });
      windowManager.addListener(this);
    }

    // 设置Android启动回调
    // 当从磁贴点击启动时，自动连接指定配置或默认配置
    VntAppCall.setStartCall((String? configKey) async {
      try {
        final dataPersistence = DataPersistence();

        // 如果没有指定配置key，尝试从磁贴获取
        String? targetKey = configKey;
        if (targetKey == null || targetKey.isEmpty) {
          // 检查是否从磁贴长按选择了配置
          targetKey = await VntAppCall.getTileConfigKey();
          debugPrint('从磁贴获取配置key: $targetKey');
        }

        // 如果还是没有，使用默认配置
        if (targetKey == null || targetKey.isEmpty) {
          targetKey = await dataPersistence.loadDefaultKey();
          if (targetKey == null || targetKey.isEmpty) {
            debugPrint('磁贴启动：未设置默认配置');
            return;
          }
        }

        final configs = await dataPersistence.loadData();
        final config = configs.where((c) => c.itemKey == targetKey).firstOrNull;

        if (config == null) {
          debugPrint('磁贴启动：配置不存在 (key: $targetKey)');
          return;
        }

        // 如果当前已有连接，先断开所有连接
        if (vntManager.hasConnection()) {
          debugPrint('磁贴启动：检测到已有连接，先断开所有连接');
          await vntManager.removeAll();
          // 等待更长时间确保断开完成和VPN资源释放
          await Future.delayed(const Duration(milliseconds: 1000));
          debugPrint('磁贴启动：断开完成，准备连接新配置');
        }

        // 检查是否正在连接
        if (vntManager.isConnecting()) {
          debugPrint('磁贴启动：正在连接中，跳过');
          return;
        }

        // 开始连接
        debugPrint('磁贴启动：开始连接配置 [${config.configName}] (key: ${config.itemKey})');
        final receivePort = ReceivePort();

        receivePort.listen((msg) {
          if (msg is String) {
            if (msg == 'success') {
              debugPrint('磁贴启动：连接成功');
              // 连接成功，更新磁贴和小组件状态
              VntAppCall.updateWidgetAndTile(true);
              // 更新Windows托盘
              if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
                SystemTrayManager().updateMenu();
                SystemTrayManager().updateTooltip();
              }
            } else if (msg == 'stop') {
              vntManager.remove(config.itemKey);
              debugPrint('磁贴启动：连接失败或停止');
              // 连接停止，更新磁贴和小组件状态
              VntAppCall.updateWidgetAndTile(vntManager.hasConnection());
              // 更新Windows托盘
              if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
                SystemTrayManager().updateMenu();
                SystemTrayManager().updateTooltip();
              }
            }
          } else if (msg is RustErrorInfo) {
            vntManager.remove(config.itemKey);
            debugPrint('磁贴启动：连接错误 - ${msg.msg}');
            // 连接错误，更新磁贴和小组件状态
            VntAppCall.updateWidgetAndTile(vntManager.hasConnection());
            // 更新Windows托盘
            if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
              SystemTrayManager().updateMenu();
              SystemTrayManager().updateTooltip();
            }
          }
        });

        await vntManager.create(config, receivePort.sendPort);
        debugPrint('磁贴启动：VntBox��建完成，等待连接结果');
      } catch (e) {
        debugPrint('磁贴启动连接失败: $e');
        // 连接异常，更新磁贴和小组件状态
        VntAppCall.updateWidgetAndTile(vntManager.hasConnection());
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResize() async {
    final size = await windowManager.getSize();
    DataPersistence().saveWindowSize(size);
  }

  @override
  void onWindowClose() async {
    var isClose = await DataPersistence().loadCloseApp();
    if (isClose == null) {
      final shouldClose = await _showCloseConfirmationDialog();
      isClose = shouldClose;
    }
    if (isClose != null) {
      if (isClose) {
        // 退出应用：先断开连接再关闭
        await vntManager.removeAll();
        windowManager.setPreventClose(false);
        appWindow.close();
      } else {
        // 隐藏窗口：不断开连接
        appWindow.hide();
      }
    }
  }

  Future<bool?> _showCloseConfirmationDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                '确认关闭',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '你确定要关闭应用吗？',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: rememberChoice,
                        onChanged: (bool? value) {
                          setState(() {
                            rememberChoice = value ?? false;
                          });
                        },
                        activeColor: primaryColor,
                      ),
                      Text(
                        '记住此操作',
                        style: TextStyle(
                          fontSize: context.fontXSmall,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    '隐藏到托盘',
                    style: TextStyle(
                      fontSize: context.fontXSmall,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('退出应用', style: TextStyle(fontSize: context.fontXSmall)),
                ),
              ],
            );
          },
        );
      },
    );

    if (rememberChoice && result != null) {
      DataPersistence().saveCloseApp(result);
    }
    return result;
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationShell(onThemeChanged: _onThemeChanged);
  }
}

Future<void> initSystemTray() async {
  String path = Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';

  // 初始化系统托盘
  await systemTray.initSystemTray(
    title: "VNT",
    toolTip: "VNT - Virtual Network Tool",
    iconPath: path,
  );

  // 初始化 SystemTrayManager，传入全局的 systemTray 实例
  final trayManager = SystemTrayManager();
  trayManager.initialize(systemTray);

  // 更新菜单
  await trayManager.updateMenu();

  // 注册事件处理器
  systemTray.registerSystemTrayEventHandler((eventName) {
    if (eventName == kSystemTrayEventClick) {
      Platform.isWindows ? windowManager.show() : systemTray.popUpContextMenu();
    } else if (eventName == kSystemTrayEventRightClick) {
      Platform.isWindows ? systemTray.popUpContextMenu() : windowManager.show();
    }
  });
}

String getArchitecture() {
  if (Platform.isWindows) {
    return Platform.environment['PROCESSOR_ARCHITECTURE']!.toLowerCase();
  }
  return 'unknown';
}

Future<void> copyAppropriateDll() async {
  if (!Platform.isWindows) return;

  final arch = getArchitecture();
  String dllPath;

  switch (arch) {
    case 'x86_64':
    case 'amd64':
      dllPath = 'dlls/amd64/wintun.dll';
      break;
    case 'arm':
      dllPath = 'dlls/arm/wintun.dll';
      break;
    case 'aarch64':
    case 'arm64':
      dllPath = 'dlls/arm64/wintun.dll';
      break;
    case 'i386':
    case 'i686':
    case 'x86':
      dllPath = 'dlls/x86/wintun.dll';
      break;
    default:
      throw UnsupportedError('Unsupported architecture: $arch');
  }

  final dllFile = File('wintun.dll');
  final sourceFile = File(dllPath);
  await sourceFile.copy(dllFile.path);
}

Future<void> copyLogConfig() async {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
    return;
  }
  final logConfigFile = File('logs/log4rs.yaml');
  if (!logConfigFile.parent.existsSync()) {
    await logConfigFile.parent.create();
  }

  if (await logConfigFile.exists()) {
    debugPrint('日志配置已存在');
    return;
  }

  final byteData = await rootBundle.load('assets/log4rs.yaml');
  await logConfigFile.writeAsBytes(byteData.buffer
      .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
}
