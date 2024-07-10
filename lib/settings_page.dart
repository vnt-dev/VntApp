import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vnt_app/data_persistence.dart';

import 'connect_log.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DataPersistence _dataPersistence = DataPersistence();

  bool _autoStart = false;
  bool _autoConnect = false;
  final List<(String, String)> _configNames = [];
  String _defaultKey = '';
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    _autoStart = await _dataPersistence.loadAutoStart() ?? false;
    _autoConnect = await _dataPersistence.loadAutoConnect() ?? false;
    _defaultKey = await _dataPersistence.loadDefaultKey() ?? '';
    var list = await _dataPersistence.loadData();
    var isExists = false;
    for (var conf in list) {
      _configNames.add((conf.itemKey, conf.configName));
      if (conf.itemKey == _defaultKey) {
        isExists = true;
      }
    }
    if (list.isNotEmpty && !isExists) {
      _defaultKey = list[0].itemKey;
    }
    setState(() {
      _autoConnect;
      _configNames;
      _autoStart;
      _defaultKey;
    });
  }

  // Future<bool> checkStartup() async {
  //   const String keyPath =
  //       r'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run';
  //   const String appName = 'VNTApp'; // 应用的名字

  //   try {
  //     // 使用 'reg query' 命令查询注册表项
  //     final result =
  //         await Process.run('reg', ['query', keyPath, '/v', appName]);

  //     // 输出命令结果，检查是否含有应用路径
  //     print(result.stdout);

  //     // 根据命令的输出结果确定是否成功设置
  //     return result.stdout.toString().contains(appName);
  //   } catch (e) {
  //     print('Failed to check startup setting: $e');
  //     return false;
  //   }
  // }

  // Future<void> setStartup(bool enable) async {
  //   final String executablePath = Platform.resolvedExecutable;
  //   const String keyPath =
  //       r'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run';
  //   const String appName = 'VNTApp';

  //   try {
  //     if (enable) {
  //       await Process.run('reg', [
  //         'add', keyPath,
  //         '/v', appName,
  //         '/t', 'REG_SZ',
  //         '/d', executablePath,
  //         '/f' // 强制覆盖同名键值
  //       ]);
  //     } else {
  //       await Process.run('reg', [
  //         'delete', keyPath,
  //         '/v', appName,
  //         '/f' // 强制删除
  //       ]);
  //     }
  //     print('Startup setting updated successfully.');
  //   } catch (e) {
  //     print('Failed to update startup setting: $e');
  //   }
  // }
  // Future<void> toggleStartup(bool enabled) async {
  //   String appPath = Platform.resolvedExecutable; // 获取当前执行文件的路径
  //   String startupPath =
  //       '${Platform.environment['APPDATA']!}\\Microsoft\\Windows\\Start Menu\\Programs\\Startup';
  //   String shortcutPath = '$startupPath\\YourAppName.lnk'; // 快捷方式的完整路径

  //   if (enabled) {
  //     // 使用Powershell创建快捷方式
  //     var createShortcut = '''
  //   \$WshShell = New-Object -ComObject WScript.Shell;
  //   \$Shortcut = \$WshShell.CreateShortcut("$shortcutPath");
  //   \$Shortcut.TargetPath = "$appPath";
  //   \$Shortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName("$appPath");
  //   \$Shortcut.IconLocation = "$appPath, 0";
  //   \$Shortcut.Save();
  //   ''';
  //     await Process.run('powershell', ['-command', createShortcut]);
  //     print('快捷方式已创建到启动文件夹');
  //   } else {
  //     // 从启动文件夹中删除快捷方式
  //     await Process.run(
  //         'powershell', ['-command', 'Remove-Item "$shortcutPath" -Force']);
  //     print('快捷方式已从启动文件夹删除');
  //   }
  // }
  Future<void> setStartupWithAdmin(bool enable) async {
    if (!Platform.isWindows) {
      return;
    }
    final String executablePath = Platform.resolvedExecutable;
    const String taskName = "VNTAppStartup";

    try {
      // 获取当前用户名
      final String username = Platform.environment['USERNAME'] ?? 'SYSTEM';

      if (enable) {
        // Command to create a task that runs at system startup with highest privileges
        List<String> args = [
          '/CREATE',
          '/F', // Force create, overwrite existing
          '/TN', taskName, // Task name
          '/TR', executablePath, // Task to run
          '/SC', 'ONLOGON', // Schedule type
          '/RL', 'HIGHEST', // Run with highest privileges
          '/IT', // Run only if the user is logged on
          '/RU', username, // Run as current user
        ];

        final result =
            await Process.run('SCHTASKS.EXE', args, runInShell: true);

        if (result.exitCode == 0) {
          print("Scheduled task created successfully.");
        } else {
          print("Error creating scheduled task: ${result.stderr}");
        }
        await modifyTaskSettings();
      } else {
        // Command to delete the task
        List<String> args = [
          '/DELETE',
          '/TN', taskName, // Task name
          '/F', // Force delete
        ];

        final result =
            await Process.run('SCHTASKS.EXE', args, runInShell: true);

        if (result.exitCode == 0) {
          print("Scheduled task deleted successfully.");
        } else {
          print("Error deleting scheduled task: ${result.stderr}");
        }
      }
    } catch (e) {
      print('Exception in setting up startup: $e');
    }
  }

  Future<void> modifyTaskSettings() async {
    // 构建PowerShell命令
    String psScript =
        r'$task = Get-ScheduledTask -TaskName "VNTAppStartup"; $task.Settings.DisallowStartIfOnBatteries = $false; Set-ScheduledTask -InputObject $task';

    // 运行PowerShell命令
    try {
      var result = await Process.run('powershell', ['-Command', psScript],
          runInShell: true);

      // 检查命令是否成功执行
      if (result.exitCode == 0) {
        print('Task settings modified successfully');
        print(result.stdout);
      } else {
        print('Error modifying task settings');
        print(result.stderr);
      }
    } on ProcessException catch (e) {
      print('Failed to run PowerShell script: $e');
    }
  }

  void openTaskScheduler() async {
    try {
      await Process.run('taskschd.msc', [], runInShell: true);
    } catch (e) {
      print('Failed to open Task Scheduler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: <Widget>[
          if (Platform.isWindows)
            ListTile(
              title: const Text('开机启动'),
              trailing: SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: Row(
                  children: [
                    Switch(
                      value: _autoStart,
                      onChanged: (bool value) async {
                        await setStartupWithAdmin(value);
                        await DataPersistence().saveAutoStart(value);

                        setState(() {
                          _autoStart = value;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Text('编辑任务计划'),
                      onPressed: () async {
                        openTaskScheduler();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ListTile(
            title: const Text('自动连接'),
            trailing: Switch(
              value: _autoConnect,
              onChanged: (bool value) async {
                await DataPersistence().saveAutoConnect(value);

                setState(() {
                  _autoConnect = value;
                });
              },
            ),
          ),
          ListTile(
            title: const Text('默认网络配置'),
            trailing: SizedBox(
              width: MediaQuery.of(context).size.width * 0.5, // 设置宽度为屏幕宽度的50%
              child: DropdownButton<String>(
                isExpanded: true, // 使下拉框扩展到最大宽度
                value: _defaultKey,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _defaultKey = newValue;
                    });
                    DataPersistence().saveDefaultKey(newValue);
                  }
                },
                items: _configNames
                    .map<DropdownMenuItem<String>>(((String, String) a) {
                  return DropdownMenuItem<String>(
                    value: a.$1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10), // 加入水平方向的padding
                      child: Text(a.$2),
                    ),
                  );
                }).toList(),
                underline: Container(
                  height: 0,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          ListTile(
            title: const Text('删除应用数据'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('确认删除应用数据？'),
                      content: const Text('这将删除所有应用数据，无法恢复。'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('取消'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('确认'),
                          onPressed: () async {
                            await DataPersistence().clear();
                            await setStartupWithAdmin(false);
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (!Platform.isAndroid)
            ListTile(
              title: const Text('应用日志'),
              trailing: IconButton(
                icon: const Icon(Icons.sms_failed),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LogPage(),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
