import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vnt_app/data_persistence.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vnt_app/file_saver.dart';

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

  // 导出所有配置
  Future<void> _exportAllConfigs() async {
    try {
      if (Platform.isAndroid) {
        // Android：先保存到临时文件，然后调用系统文件选择器
        final directory = await getTemporaryDirectory();
        final fileName = 'vnt_backup_${DateTime.now().millisecondsSinceEpoch}.json';
        final filePath = '${directory.path}/$fileName';

        debugPrint('开始导出配置到临时文件: $filePath');
        await _dataPersistence.exportAllConfigs(filePath);

        // 调用系统文件选择器让用户选择保存位置
        final success = await FileSaver.copyFile(
          sourceFilePath: filePath,
          fileName: fileName,
          mimeType: 'application/json',
        );

        // 清理临时文件
        final tempFile = File(filePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('备份成功: $fileName')),
            );
          }
        }
      } else {
        // Windows：使用文件选择器
        String? path = await FilePicker.platform.saveFile(
          dialogTitle: '选择保存位置',
          fileName: 'vnt_backup_${DateTime.now().millisecondsSinceEpoch}.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (path == null) {
          debugPrint('用户取消了文件保存');
          return;
        }

        debugPrint('开始导出配置到: $path');
        await _dataPersistence.exportAllConfigs(path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('备份成功: $path')),
          );
        }
      }
    } catch (e) {
      debugPrint('导出配置失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e')),
        );
      }
    }
  }

  // 导入所有配置
  Future<void> _importAllConfigs() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      // 用户取消选择
      if (result == null) {
        debugPrint('用户取消了文件选择');
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        throw Exception('无法获取文件路径');
      }

      // 读取文件内容检测类型
      final file = File(filePath);
      final content = await file.readAsString();
      final jsonData = jsonDecode(content);

      // 检查是否是单个配置文件
      if (jsonData.containsKey('config') && !jsonData.containsKey('configs')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('这是单个组网配置文件，请在主页的导入按钮中导入'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      debugPrint('开始导入配置从: $filePath');
      await _dataPersistence.importAllConfigs(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('恢复成功')),
        );
        _configNames.clear();
        _loadData();
      }
    } catch (e) {
      debugPrint('导入配置失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e')),
        );
      }
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
            title: const Text('备份所有配置'),
            trailing: IconButton(
              icon: const Icon(Icons.backup),
              onPressed: _exportAllConfigs,
            ),
          ),
          ListTile(
            title: const Text('恢复备份数据'),
            trailing: IconButton(
              icon: const Icon(Icons.restore),
              onPressed: _importAllConfigs,
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
