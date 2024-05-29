import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:json2yaml/json2yaml.dart';
import 'connected_page.dart';
import 'network_config_input_page.dart';
import 'custom_app_bar.dart';
import 'data_persistence.dart';
import 'network_config.dart';
import 'about_page.dart';
import 'dart:async';
import 'settings_page.dart';
import 'src/rust/api/vnt_api.dart';
import 'widgets/color_changing_button.dart';
import 'package:vnt_app/src/rust/frb_generated.dart';
import 'vnt/vnt_api.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

final SystemTray systemTray = SystemTray();
final AppWindow appWindow = AppWindow();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 确保Flutter框架已初始化
  try {
    await copyLogConfig();
  } catch (e) {
    debugPrint('copyLogConfig catch $e');
  }
  await RustLib.init(); // 初始化Rust库
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    final windowSize = await DataPersistence().loadWindowSize();
    windowManager.setTitle('VNT app');
    if (windowSize != null) {
      await windowManager.setSize(windowSize);
    }

    windowManager.waitUntilReadyToShow().then((_) async {
      await appWindow.show();
    });
  }

  runApp(const VntApp());
}

class VntApp extends StatelessWidget {
  const VntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

Future<void> initSystemTray() async {
  String path =
      Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';

  await systemTray.initSystemTray(
    title: "VNT",
    toolTip: "VNT",
    iconPath: path,
  );
  final Menu menu = Menu();
  menu.buildFrom([
    MenuItemLabel(
      label: '打开',
      onClicked: (menuItem) {
        appWindow.show();
      },
    ),
    MenuItemLabel(
      label: '隐藏',
      onClicked: (menuItem) {
        appWindow.hide();
      },
    ),
    MenuItemLabel(
      label: '退出',
      onClicked: (menuItem) {
        windowManager.setPreventClose(false);
        appWindow.close();
      },
    ),
  ]);
  await systemTray.setContextMenu(menu);
  systemTray.registerSystemTrayEventHandler((eventName) {
    // debugPrint("eventName: $eventName");
    if (eventName == kSystemTrayEventClick) {
      Platform.isWindows ? windowManager.show() : systemTray.popUpContextMenu();
    } else if (eventName == kSystemTrayEventRightClick) {
      Platform.isWindows ? systemTray.popUpContextMenu() : windowManager.show();
    }
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  final DataPersistence _dataPersistence = DataPersistence();
  List<NetworkConfig> _configs = [];
  bool _connected = false;
  NetworkConfig? connectedConfig;
  bool rememberChoice = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      copyAppropriateDll();
      initSystemTray();
      DataPersistence().loadCloseApp().then((isClose) {
        if (!(isClose ?? false)) {
          windowManager.setPreventClose(true);
        }
      });

      windowManager.addListener(this);
    }

    _loadData().then((v) {
      loadConnect();
    });
  }

  void loadConnect() async {
    var connectItemKey = await _dataPersistence.loadAutoConnect();
    if (connectItemKey != null && connectItemKey.isNotEmpty) {
      for (var conf in _configs) {
        if (conf.itemKey == connectItemKey) {
          _connect(conf);
          break;
        }
      }
    }
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
        windowManager.setPreventClose(false);
        appWindow.close();
      } else {
        appWindow.hide();
      }
    }
  }

  Future<bool?> _showCloseConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('确认关闭'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('你确定要关闭应用吗？'),
                  Row(
                    children: [
                      Checkbox(
                        value: rememberChoice,
                        onChanged: (bool? value) {
                          setState(() {
                            rememberChoice = value ?? false;
                          });
                        },
                      ),
                      const Text('记住此操作', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('隐藏到托盘', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('关闭应用', style: TextStyle(fontSize: 12)),
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

  Future<void> _loadData() async {
    List<NetworkConfig> configs = await _dataPersistence.loadData();
    setState(() {
      _configs = configs;
    });
  }

  void _addOrEditConfig(NetworkConfig? config, int index) async {
    if (_connected && config != null && connectedConfig != null) {
      if (config.itemKey == connectedConfig?.itemKey) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先断开连接再编辑配置')),
        );
        return;
      }
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NetworkConfigInputPage(config: config),
      ),
    );

    if (result != null && result is NetworkConfig) {
      setState(() {
        if (index >= 0) {
          _configs[index] = result;
        } else {
          _configs.add(result);
        }
      });
      _dataPersistence.saveData(_configs);
    }
  }

  void _connect(NetworkConfig config) {
    if (_connected) {
      // 不能重复连接
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('连接配置项[${connectedConfig?.configName}]'),
            content: const Text("已经建立了连接，如需多开请开多个窗口，并注意网段、虚拟网卡不要冲突"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (connectedConfig != null) {
                    connectDetailPage(connectedConfig!);
                  }
                },
                child: const Text('查看连接'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.close),
              ),
            ],
          );
        },
      );
      return;
    }
    connectedConfig = config;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min, // 使内容尽可能紧凑
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 20), // 添加一些垂直间距
                ElevatedButton(
                  onPressed: () {
                    VntApiUtils.close();
                  },
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        );
      },
    );

    _connectVnt(config);
  }

  void _connectVnt(NetworkConfig config) async {
    var onece = true;
    ReceivePort receivePort = ReceivePort();
    receivePort.listen((msg) async {
      if (msg is String) {
        if (msg == 'success') {
          if (onece) {
            onece = false;
            Navigator.of(context).pop();
            connectDetailPage(config);
          }
        } else if (msg == 'stop') {
          _closeVnt();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('VNT服务停止')),
          );
        }
      } else if (msg is RustErrorInfo) {
        if (onece) {
          //没成功就失败的，就断开不重试了
          onece = false;
          Navigator.of(context).pop();
          _closeVnt();
        }
        switch (msg.code) {
          case RustErrorType.tokenError:
            _closeVnt();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('token错误')),
            );
            break;
          case RustErrorType.disconnect:
            //断开连接
            break;
          case RustErrorType.addressExhausted:
            _closeVnt();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('IP地址用尽')),
            );
            break;
          case RustErrorType.ipAlreadyExists:
            _closeVnt();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('和其他设备的虚拟IP冲突')),
            );
            break;
          case RustErrorType.invalidIp:
            _closeVnt();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('虚拟IP地址无效')),
            );
            break;
          case RustErrorType.localIpExists:
            _closeVnt();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('虚拟IP地址和本地IP冲突')),
            );
            break;
          default:
            _closeVnt();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('未知错误 ${msg.msg}')),
            );
        }
      } else if (msg is RustConnectInfo) {
        if (onece && msg.count > 60) {
          onece = false;
          Navigator.of(context).pop();
          _closeVnt();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('连接超时 ${msg.address}')),
          );
        }
      }
    });
    try {
      await VntApiUtils.open(config, receivePort.sendPort);
    } catch (e) {
      debugPrint('dart catch e: $e');
      Navigator.of(context).pop();
      var msg = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
          '连接失败 $msg',
          textAlign: TextAlign.left,
          overflow: TextOverflow.ellipsis,
          maxLines: 6,
        )),
      );
    }
  }

  void connectDetailPage(NetworkConfig config) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectDetailPage(config: config),
      ),
    );
    if (result == null || (result is bool && !result)) {
      setState(() {
        _connected = true;
      });
    } else {
      _closeVnt();
    }
  }

  void _closeVnt() {
    VntApiUtils.close();
    setState(() {
      _connected = false;
    });
  }

  void _seeConnected() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('连接配置项[${connectedConfig?.configName}]'),
          actions: [
            TextButton(
              onPressed: () {
                _closeVnt();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
              child: const Text('断开连接'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (connectedConfig != null) {
                  connectDetailPage(connectedConfig!);
                }
              },
              child: const Text('查看连接'),
            ),
          ],
        );
      },
    );
  }

  void _deleteConfig(int index) {
    if (_connected && connectedConfig != null) {
      if (_configs[index].itemKey == connectedConfig?.itemKey) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先断开连接再删除')),
        );
        return;
      }
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('是否删除配置[${_configs[index].configName}]'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _configs.removeAt(index);
                });
                _dataPersistence.saveData(_configs);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
              child: const Text('确认删除'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Icon(Icons.close),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAboutPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutPage()),
    );
  }

  _showConfigDialog(NetworkConfig config) {
    var conf = json2yaml(config.toJsonSimple());
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('组网配置'),
          content: SelectableText(conf),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Icon(Icons.close),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Tooltip(
                  message: '设置',
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => SettingsPage()),
                      );
                      _loadData();
                    },
                  ))),
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Tooltip(
                    message: '隐藏到托盘',
                    child: IconButton(
                      icon: const Icon(Icons.push_pin_outlined,
                          color: Colors.white),
                      onPressed: () {
                        appWindow.hide();
                      },
                    ))),
          if (_connected)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Tooltip(
                    message: 'VNT网络',
                    child: ColorChangingButton(
                      icon: Icons.attractions,
                      colors: const [Colors.white, Colors.yellow],
                      onPressed: _seeConnected,
                    ))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Tooltip(
                  message: '关于VNT',
                  child: IconButton(
                    icon: const Icon(Icons.info, color: Colors.white),
                    onPressed: _navigateToAboutPage,
                  ))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Tooltip(
                  message: '添加配置',
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => _addOrEditConfig(null, -1),
                  ))),
        ],
      ),
      body: _configs.isEmpty
          ? const Center(
              child: Text(
                '点击右上角添加一个组网配置',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _configs.length,
              itemBuilder: (context, index) {
                return Container(
                  color: index % 2 == 0 ? Colors.grey[200] : Colors.white,
                  child: ListTile(
                    title: InkWell(
                        onTap: () {
                          _showConfigDialog(_configs[index]);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _configs[index].configName,
                              textAlign: TextAlign.left,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              'IP:${_configs[index].virtualIPv4.isEmpty ? '自动分配' : _configs[index].virtualIPv4}',
                              textAlign: TextAlign.left,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              _configs[index].deviceName,
                              textAlign: TextAlign.left,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        )),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                            padding: const EdgeInsets.only(right: 3.0),
                            child: Tooltip(
                                message: '连接',
                                child: IconButton(
                                  icon: const Icon(Icons.link),
                                  onPressed: () => _connect(_configs[index]),
                                ))),
                        Padding(
                            padding: const EdgeInsets.only(right: 3.0),
                            child: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _addOrEditConfig(_configs[index], index),
                            )),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteConfig(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

String getArchitecture() {
  if (Platform.isWindows) {
    return Platform.environment['PROCESSOR_ARCHITECTURE']!.toLowerCase();
  }
  return 'unknown';
}

Future<void> copyAppropriateDll() async {
  if (!Platform.isWindows) {
    return;
  }

  final arch = getArchitecture();
  String dllPath;

  switch (arch) {
    case 'x86_64':
    case 'amd64':
      dllPath = 'windows/dlls/amd64/wintun.dll';
      break;
    case 'arm':
      dllPath = 'windows/dlls/arm/wintun.dll';
      break;
    case 'aarch64':
    case 'arm64':
      dllPath = 'windows/dlls/arm64/wintun.dll';
      break;
    case 'i386':
    case 'i686':
    case 'x86':
      dllPath = 'windows/dlls/x86/wintun.dll';
      break;
    default:
      throw UnsupportedError('Unsupported architecture: $arch');
  }

  final dllFile = File('wintun.dll');

  final byteData = await rootBundle.load(dllPath);
  await dllFile.writeAsBytes(byteData.buffer
      .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
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
