import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/theme/theme_provider.dart';
import 'package:vnt_app/data_persistence.dart';
import 'package:vnt_app/utils/toast_utils.dart';
import 'package:vnt_app/utils/responsive_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vnt_app/file_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:vnt_app/connect_log.dart';
import 'package:vnt_app/vnt/vnt_manager.dart';
import 'package:vnt_app/system_tray_manager.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeModeChanged;
  final VoidCallback? onDataChanged;
  final void Function(VoidCallback)? onRefreshCallback;

  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.onDataChanged,
    this.onRefreshCallback,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
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
    // 注册刷新回调，让配置页面可以通知设置页面刷新
    widget.onRefreshCallback?.call(_loadData);
  }

  Future<void> _loadData() async {
    _autoStart = await _dataPersistence.loadAutoStart() ?? false;
    _autoConnect = await _dataPersistence.loadAutoConnect() ?? false;
    _defaultKey = await _dataPersistence.loadDefaultKey() ?? '';

    var list = await _dataPersistence.loadData();
    var isExists = false;
    _configNames.clear();
    for (var conf in list) {
      _configNames.add((conf.itemKey, conf.configName));
      if (conf.itemKey == _defaultKey) {
        isExists = true;
      }
    }
    if (list.isNotEmpty && !isExists) {
      _defaultKey = list[0].itemKey;
      // 保存到持久化存储，确保仪表盘等其他地方可以读取到
      await _dataPersistence.saveDefaultKey(_defaultKey);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setStartupWithAdmin(bool enable) async {
    if (!Platform.isWindows) {
      return;
    }
    final String executablePath = Platform.resolvedExecutable;
    const String taskName = "VNTAppStartup";

    try {
      final String username = Platform.environment['USERNAME'] ?? 'SYSTEM';

      if (enable) {
        List<String> args = [
          '/CREATE',
          '/F',
          '/TN', taskName,
          '/TR', executablePath,
          '/SC', 'ONLOGON',
          '/RL', 'HIGHEST',
          '/IT',
          '/RU', username,
        ];

        final result = await Process.run('SCHTASKS.EXE', args, runInShell: true);

        if (result.exitCode == 0) {
          debugPrint("Scheduled task created successfully.");
        } else {
          debugPrint("Error creating scheduled task: ${result.stderr}");
        }
        await _modifyTaskSettings();
      } else {
        List<String> args = [
          '/DELETE',
          '/TN', taskName,
          '/F',
        ];

        final result = await Process.run('SCHTASKS.EXE', args, runInShell: true);

        if (result.exitCode == 0) {
          debugPrint("Scheduled task deleted successfully.");
        } else {
          debugPrint("Error deleting scheduled task: ${result.stderr}");
        }
      }
    } catch (e) {
      debugPrint('Exception in setting up startup: $e');
    }
  }

  Future<void> _modifyTaskSettings() async {
    String psScript =
        r'$task = Get-ScheduledTask -TaskName "VNTAppStartup"; $task.Settings.DisallowStartIfOnBatteries = $false; Set-ScheduledTask -InputObject $task';

    try {
      var result = await Process.run('powershell', ['-Command', psScript],
          runInShell: true);

      if (result.exitCode == 0) {
        debugPrint('Task settings modified successfully');
      } else {
        debugPrint('Error modifying task settings: ${result.stderr}');
      }
    } on ProcessException catch (e) {
      debugPrint('Failed to run PowerShell script: $e');
    }
  }

  void _openTaskScheduler() async {
    try {
      await Process.run('taskschd.msc', [], runInShell: true);
    } catch (e) {
      debugPrint('Failed to open Task Scheduler: $e');
    }
  }

  // 导出所有配置
  Future<void> _exportAllConfigs() async {
    try {
      if (Platform.isAndroid) {
        final directory = await getTemporaryDirectory();
        final fileName = 'vnt_backup_${DateTime.now().millisecondsSinceEpoch}.json';
        final filePath = '${directory.path}/$fileName';

        debugPrint('开始导出配置到临时文件: $filePath');
        await _dataPersistence.exportAllConfigs(filePath);

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
            showTopToast(context, '备份成功: $fileName', isSuccess: true);
          } else {
            showTopToast(context, '备份已取消', isSuccess: false);
          }
        }
      } else if (Platform.isIOS) {
        // iOS使用Share Sheet分享文件
        final tempDir = await getTemporaryDirectory();
        final fileName = 'vnt_backup_${DateTime.now().millisecondsSinceEpoch}.json';
        final filePath = '${tempDir.path}/$fileName';

        debugPrint('iOS: 开始导出配置到临时文件: $filePath');
        await _dataPersistence.exportAllConfigs(filePath);

        // 验证临时文件是否创建成功
        final tempFile = File(filePath);
        if (!await tempFile.exists()) {
          throw Exception('临时文件创建失败');
        }

        // 使用Share Sheet分享文件
        try {
          final box = context.findRenderObject() as RenderBox?;
          final result = await Share.shareXFiles(
            [XFile(filePath)],
            sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
          );
          
          if (mounted) {
            if (result.status == ShareResultStatus.success) {
              showTopToast(context, '配置已备份', isSuccess: true);
            } else if (result.status == ShareResultStatus.dismissed) {
              showTopToast(context, '操作已取消', isSuccess: false);
            }
          }
        } catch (e) {
          debugPrint('分享文件失败: $e');
          if (mounted) {
            showTopToast(context, '分享失败: $e', isSuccess: false);
          }
        }

        // 延迟清理临时文件，给系统时间复制
        Future.delayed(const Duration(seconds: 5), () async {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        });
      } else {
        // Windows/macOS/Linux
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
          showTopToast(context, '备份成功: $path', isSuccess: true);
        }
      }
    } catch (e) {
      debugPrint('导出配置失败: $e');
      if (mounted) {
        showTopToast(context, '备份失败: $e', isSuccess: false);
      }
    }
  }

  // 导入所有配置
  Future<void> _importAllConfigs() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null) {
        debugPrint('用户取消了文件选择');
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        throw Exception('无法获取文件路径');
      }

      final file = File(filePath);
      final content = await file.readAsString();
      final jsonData = jsonDecode(content);

      if (jsonData.containsKey('config') && !jsonData.containsKey('configs')) {
        if (mounted) {
          showTopToast(context, '这是单个组网配置文件，请在配置页面的导入按钮中导入', isSuccess: false);
        }
        return;
      }

      debugPrint('开始导入配置从: $filePath');
      await _dataPersistence.importAllConfigs(filePath);

      if (mounted) {
        showTopToast(context, '恢复成功', isSuccess: true);
        // 重新加载数据以实时显示恢复的配置
        await _loadData();
        // 通知配置列表页面刷新
        widget.onDataChanged?.call();
        // 同步更新通知栏、磁贴、小组件（恢复备份会重置默认配置）
        VntAppCall.updateWidgetAndTile(false);
        // 更新系统托盘（配置列表变化）
        SystemTrayManager().updateMenu();
      }
    } catch (e) {
      debugPrint('导入配置失败: $e');
      if (mounted) {
        showTopToast(context, '恢复失败: $e', isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 页面头部
              _buildHeader(isDark, isWideScreen),
              SizedBox(height: context.spacingLarge),

              // 外观设置
              _buildSectionTitle(isDark, '外观'),
              SizedBox(height: context.spacingSmall),
              _buildAppearanceSettings(isDark),
              SizedBox(height: context.spacingLarge),

              // 应用设置
              _buildSectionTitle(isDark, '应用'),
              SizedBox(height: context.spacingSmall),
              _buildAppSettings(isDark),
              SizedBox(height: context.spacingLarge),

              // 数据管理
              _buildSectionTitle(isDark, '数据管理'),
              SizedBox(height: context.spacingSmall),
              _buildDataSettings(isDark),

              // 日志（所有平台）
              SizedBox(height: context.spacingLarge),
              _buildSectionTitle(isDark, '调试'),
              SizedBox(height: context.spacingSmall),
              _buildDebugSettings(isDark),
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
            Icons.settings_outlined,
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
                '设置',
                style: TextStyle(
                  fontSize: context.fontXLarge,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              Text(
                '自定义应用设置',
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

  Widget _buildSectionTitle(bool isDark, String title) {
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: EdgeInsets.only(left: context.spacingXSmall / 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: context.fontBody,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildAppearanceSettings(bool isDark) {
    final themeProvider = ThemeProvider.of(context);
    final customColor = themeProvider?.customThemeColor ?? AppTheme.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        borderRadius: BorderRadius.circular(context.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildThemeSelector(isDark),
          _buildDivider(isDark),
          _buildColorSelector(isDark, customColor),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: ResponsiveUtils.padding(context, all: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: context.listItemIconContainerSize,
                height: context.listItemIconContainerSize,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(context.cardRadius),
                ),
                child: Icon(
                  Icons.brightness_6,
                  color: primaryColor,
                  size: context.iconSmall,
                ),
              ),
              SizedBox(width: context.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '主题模式',
                      style: TextStyle(
                        fontSize: context.fontMedium,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    Text(
                      '选择应用的外观主题',
                      style: TextStyle(
                        fontSize: context.fontSmall,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacingMedium),
          Row(
            children: [
              _buildThemeOption(
                isDark,
                '浅色',
                Icons.light_mode,
                ThemeMode.light,
              ),
              SizedBox(width: context.spacingSmall),
              _buildThemeOption(
                isDark,
                '深色',
                Icons.dark_mode,
                ThemeMode.dark,
              ),
              SizedBox(width: context.spacingSmall),
              _buildThemeOption(
                isDark,
                '跟随系统',
                Icons.settings_suggest,
                ThemeMode.system,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(bool isDark, String label, IconData icon, ThemeMode mode) {
    final isSelected = widget.themeMode == mode;
    final primaryColor = Theme.of(context).primaryColor;

    return Expanded(
      child: InkWell(
        onTap: () {
          widget.onThemeModeChanged(mode);
        },
        borderRadius: BorderRadius.circular(context.cardRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: context.spacingSmall),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withOpacity(0.1)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(context.cardRadius),
            border: isSelected
                ? Border.all(color: primaryColor.withOpacity(0.5))
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? primaryColor
                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                size: context.iconMedium,
              ),
              SizedBox(height: context.spacingXSmall),
              Text(
                label,
                style: TextStyle(
                  fontSize: context.fontSmall,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppSettings(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        borderRadius: BorderRadius.circular(context.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 开机自启（Windows 和 Android）
          if (Platform.isWindows || Platform.isAndroid) ...[
            _buildSettingItem(
              isDark,
              icon: Icons.play_circle_outline,
              title: '开机自启',
              subtitle: Platform.isWindows
                  ? '系统启动时自动运行应用'
                  : '下次开机时自动启动应用',
              trailing: Platform.isWindows
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: _autoStart,
                          onChanged: (value) async {
                            await _setStartupWithAdmin(value);
                            await _dataPersistence.saveAutoStart(value);
                            setState(() {
                              _autoStart = value;
                            });
                          },
                          activeColor: Theme.of(context).primaryColor,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.edit_calendar,
                            size: context.iconSmall,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                          onPressed: _openTaskScheduler,
                          tooltip: '编辑任务计划',
                        ),
                      ],
                    )
                  : Switch(
                      value: _autoStart,
                      onChanged: (value) async {
                        await _dataPersistence.saveAutoStart(value);
                        setState(() {
                          _autoStart = value;
                        });
                        if (mounted) {
                          showTopToast(
                            context,
                            value ? '开机自启已启用' : '开机自启已关闭',
                            isSuccess: true,
                          );
                        }
                      },
                      activeColor: Theme.of(context).primaryColor,
                    ),
            ),
            _buildDivider(isDark),
          ],
          _buildSettingItem(
            isDark,
            icon: Icons.autorenew,
            title: '自动连接',
            subtitle: '启动时自动连接默认配置',
            trailing: Switch(
              value: _autoConnect,
              onChanged: (value) async {
                await _dataPersistence.saveAutoConnect(value);
                setState(() {
                  _autoConnect = value;
                });
              },
              activeColor: Theme.of(context).primaryColor,
            ),
          ),
          _buildDivider(isDark),
          _buildDefaultConfigSelector(isDark),
          // 桌面端: 重置关闭行为
          if (Platform.isWindows || Platform.isLinux) ...[
            _buildDivider(isDark),
            _buildSettingItem(
              isDark,
              icon: Icons.close,
              title: '重置关闭行为',
              subtitle: '清除"记住此操作"，下次关闭时重新询问',
              trailing: TextButton(
                onPressed: () async {
                  await _dataPersistence.saveCloseApp(null);
                  if (mounted) {
                    showTopToast(context, '已重置，下次关闭时将重新询问', isSuccess: true);
                  }
                },
                child: Text('重置'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultConfigSelector(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: ResponsiveUtils.padding(context, all: 16),
      child: Row(
        children: [
          Container(
            width: context.listItemIconContainerSize,
            height: context.listItemIconContainerSize,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(context.cardRadius),
            ),
            child: Icon(
              Icons.star_outline,
              color: primaryColor,
              size: context.iconSmall,
            ),
          ),
          SizedBox(width: context.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '默认配置',
                  style: TextStyle(
                    fontSize: context.fontMedium,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                Text(
                  '自动连接时使用的配置',
                  style: TextStyle(
                    fontSize: context.fontSmall,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_configNames.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: context.spacingSmall),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(context.cardRadius),
              ),
              child: DropdownButton<String>(
                value: _defaultKey.isNotEmpty ? _defaultKey : null,
                underline: const SizedBox(),
                dropdownColor: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
                borderRadius: BorderRadius.circular(context.cardRadius),
                style: TextStyle(
                  fontSize: context.fontBody,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _defaultKey = newValue;
                    });
                    _dataPersistence.saveDefaultKey(newValue);
                    // 更新通知栏、磁贴、小组件显示最新配置
                    VntAppCall.updateWidgetAndTile(false);
                    // 更新系统托盘（默认配置变化）
                    SystemTrayManager().updateMenu();
                  }
                },
                items: _configNames.asMap().entries.map<DropdownMenuItem<String>>((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  // 只有当前项的key等于_defaultKey，且是第一个匹配的项时才显示勾
                  final isSelected = item.$1 == _defaultKey &&
                      _configNames.indexWhere((e) => e.$1 == _defaultKey) == index;
                  return DropdownMenuItem<String>(
                    value: item.$1,
                    child: Text(
                      isSelected ? '✓ ${item.$2}' : item.$2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Text(
              '暂无配置',
              style: TextStyle(
                fontSize: context.fontBody,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataSettings(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        borderRadius: BorderRadius.circular(context.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingItem(
            isDark,
            icon: Icons.backup_outlined,
            title: '备份所有配置',
            subtitle: '将所有配置导出为文件',
            onTap: _exportAllConfigs,
          ),
          _buildDivider(isDark),
          _buildSettingItem(
            isDark,
            icon: Icons.restore,
            title: '恢复备份数据',
            subtitle: '从备份文件恢复配置',
            onTap: _importAllConfigs,
          ),
          _buildDivider(isDark),
          _buildSettingItem(
            isDark,
            icon: Icons.delete_outline,
            title: '清除所有数据',
            subtitle: '删除所有配置和缓存',
            iconColor: AppTheme.errorColor,
            onTap: _showClearDataDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildDebugSettings(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        borderRadius: BorderRadius.circular(context.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingItem(
            isDark,
            icon: Icons.article_outlined,
            title: '应用日志',
            subtitle: '查看应用运行日志',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LogPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: ResponsiveUtils.padding(context, all: 16),
        child: Row(
          children: [
            Container(
              width: context.listItemIconContainerSize,
              height: context.listItemIconContainerSize,
              decoration: BoxDecoration(
                color: (iconColor ?? primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(context.cardRadius),
              ),
              child: Icon(
                icon,
                color: iconColor ?? primaryColor,
                size: context.iconSmall,
              ),
            ),
            SizedBox(width: context.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: context.fontMedium,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: context.fontSmall,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 72,
      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
    );
  }

  Widget _buildColorSelector(bool isDark, Color currentColor) {
    return InkWell(
      onTap: () => _showColorPicker(currentColor),
      child: Padding(
        padding: ResponsiveUtils.padding(context, all: 16),
        child: Row(
          children: [
            Container(
              width: context.listItemIconContainerSize,
              height: context.listItemIconContainerSize,
              decoration: BoxDecoration(
                color: currentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(context.cardRadius),
              ),
              child: Icon(
                Icons.color_lens_outlined,
                color: currentColor,
                size: context.iconSmall,
              ),
            ),
            SizedBox(width: context.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '主题颜色',
                    style: TextStyle(
                      fontSize: context.fontMedium,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  Text(
                    '自定义应用主题颜色',
                    style: TextStyle(
                      fontSize: context.fontSmall,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: context.iconLarge,
              height: context.iconLarge,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(context.spacingXSmall),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                  width: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showColorPicker(Color currentColor) async {
    final themeProvider = ThemeProvider.of(context);
    if (themeProvider == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color selectedColor = currentColor;

    final result = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        isDark: isDark,
        initialColor: selectedColor,
        onColorChanged: (color) => selectedColor = color,
      ),
    );

    if (result != null) {
      themeProvider.setCustomThemeColor(result);
      if (mounted) {
        showTopToast(context, '主题颜色已更新', isSuccess: true);
      }
    }
  }

  void _showClearDataDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.cardRadius)),
        title: Text(
          '清除所有数据',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        content: Text(
          '确定要清除所有数据吗？此操作将删除所有配置，且不可恢复。',
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
            onPressed: () async {
              Navigator.pop(context);
              await _dataPersistence.clear();
              await _setStartupWithAdmin(false);
              if (mounted) {
                showTopToast(context, '数据已清除', isSuccess: true);
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final bool isDark;
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const _ColorPickerDialog({
    required this.isDark,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> with SingleTickerProviderStateMixin {
  late Color selectedColor;
  late double hue;
  late double saturation;
  late double opacity;
  late TabController _tabController;

  // 预设颜色
  final List<Map<String, dynamic>> presetColors = [
    {'name': '青色', 'color': const Color(0xFF00BFA5)},
    {'name': '蓝色', 'color': const Color(0xFF2196F3)},
    {'name': '紫色', 'color': const Color(0xFF9C27B0)},
    {'name': '粉色', 'color': const Color(0xFFE91E63)},
    {'name': '红色', 'color': const Color(0xFFF44336)},
    {'name': '橙色', 'color': const Color(0xFFFF9800)},
    {'name': '黄色', 'color': const Color(0xFFFFC107)},
    {'name': '绿色', 'color': const Color(0xFF4CAF50)},
    {'name': '深蓝', 'color': const Color(0xFF1976D2)},
    {'name': '深紫', 'color': const Color(0xFF7B1FA2)},
    {'name': '深红', 'color': const Color(0xFFC62828)},
    {'name': '深绿', 'color': const Color(0xFF388E3C)},
    {'name': '靛蓝', 'color': const Color(0xFF3F51B5)},
    {'name': '棕色', 'color': const Color(0xFF795548)},
    {'name': '灰色', 'color': const Color(0xFF607D8B)},
    {'name': '黑色', 'color': const Color(0xFF212121)},
  ];

  @override
  void initState() {
    super.initState();
    selectedColor = widget.initialColor;
    _tabController = TabController(length: 2, vsync: this);
    _updateHSV();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateHSV() {
    final hsv = HSVColor.fromColor(selectedColor);
    hue = hsv.hue;
    saturation = hsv.saturation;
    opacity = selectedColor.opacity;
  }

  void _updateColorFromHSV() {
    selectedColor = HSVColor.fromAHSV(opacity, hue, saturation, 1.0).toColor();
    widget.onColorChanged(selectedColor);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    // 移动端使用更紧凑的高度
    final maxHeight = isMobile ? screenHeight * 0.7 : screenHeight * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: context.spacingMedium),
        constraints: BoxConstraints(
          maxWidth: context.w(450),
          maxHeight: maxHeight,
        ),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(context.dialogRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: ResponsiveUtils.padding(context, all: context.spacingMedium),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    selectedColor.withOpacity(0.15),
                    selectedColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(context.dialogRadius),
                  topRight: Radius.circular(context.dialogRadius),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(context.spacingSmall),
                    decoration: BoxDecoration(
                      color: selectedColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(context.cardRadius),
                    ),
                    child: Icon(
                      Icons.palette,
                      color: selectedColor,
                      size: context.iconMedium,
                    ),
                  ),
                  SizedBox(width: context.spacingSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择主题颜色',
                          style: TextStyle(
                            fontSize: context.fontLarge,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(height: context.spacingXSmall / 2),
                        Text(
                          '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                          style: TextStyle(
                            fontSize: context.fontSmall,
                            fontFamily: 'monospace',
                            color: widget.isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            // TAB栏
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingMedium,
                vertical: context.spacingSmall,
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: selectedColor,
                unselectedLabelColor: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                indicatorColor: selectedColor,
                dividerColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                tabs: const [
                  Tab(text: '预设颜色'),
                  Tab(text: '自定义'),
                ],
              ),
            ),
            // 内容区域
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPresetTab(),
                  _buildCustomTab(),
                ],
              ),
            ),
            // 底部按钮
            Padding(
              padding: ResponsiveUtils.padding(context, all: context.spacingMedium),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        side: BorderSide(
                          color: widget.isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2),
                        ),
                        padding: EdgeInsets.symmetric(vertical: context.spacingSmall),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.buttonRadius),
                        ),
                      ),
                      child: Text('取消', style: TextStyle(fontSize: context.fontBody)),
                    ),
                  ),
                  SizedBox(width: context.spacingSmall),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, selectedColor),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: context.spacingSmall),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.buttonRadius),
                        ),
                      ),
                      child: Text('确定', style: TextStyle(fontSize: context.fontBody)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMedium,
          vertical: context.spacingSmall,
        ),
        child: Wrap(
          spacing: context.spacingSmall,
          runSpacing: context.spacingSmall,
          children: presetColors.map((preset) {
            final color = preset['color'] as Color;
            final name = preset['name'] as String;
            final isSelected = selectedColor.value == color.value;
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedColor = color;
                  _updateHSV();
                  widget.onColorChanged(selectedColor);
                });
              },
              child: Container(
                width: context.w(56),
                height: context.w(56),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(context.cardRadius),
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // 颜色名称放在底部，避免被勾选图标遮挡
                    Positioned(
                      bottom: 2,
                      left: 0,
                      right: 0,
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.fontXSmall,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 勾选图标放在右上角
                    if (isSelected)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: context.iconSmall,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomTab() {
    final red = selectedColor.red;
    final green = selectedColor.green;
    final blue = selectedColor.blue;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMedium,
          vertical: context.spacingMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 颜色预览
            Container(
              width: double.infinity,
              height: context.w(70),
              decoration: BoxDecoration(
                color: selectedColor,
                borderRadius: BorderRadius.circular(context.cardRadius),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '颜色预览效果',
                  style: TextStyle(
                    fontSize: context.fontBody,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: context.spacingMedium),

            // 色相滚动条
            _buildSlider(
              label: '色相',
              value: hue,
              max: 360,
              displayValue: hue.toInt().toString(),
              onChanged: (val) {
                setState(() {
                  hue = val;
                  _updateColorFromHSV();
                });
              },
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
            ),
            SizedBox(height: context.spacingSmall),

            // 饱和度滚动条
            _buildSlider(
              label: '饱和度',
              value: saturation,
              max: 1,
              displayValue: (saturation * 100).toInt().toString(),
              onChanged: (val) {
                setState(() {
                  saturation = val;
                  _updateColorFromHSV();
                });
              },
              gradient: LinearGradient(
                colors: [
                  HSVColor.fromAHSV(1, hue, 0, 1.0).toColor(),
                  HSVColor.fromAHSV(1, hue, 1, 1.0).toColor(),
                ],
              ),
            ),
            SizedBox(height: context.spacingSmall),

            // 透明度滚动条
            _buildSlider(
              label: '透明度',
              value: opacity,
              max: 1,
              displayValue: (opacity * 100).toInt().toString(),
              onChanged: (val) {
                setState(() {
                  opacity = val;
                  _updateColorFromHSV();
                });
              },
              gradient: LinearGradient(
                colors: [
                  selectedColor.withOpacity(0),
                  selectedColor.withOpacity(1),
                ],
              ),
            ),
            SizedBox(height: context.spacingMedium),

            // 颜色值显示
            Container(
              padding: EdgeInsets.all(context.spacingSmall),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(context.buttonRadius),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '颜色值',
                        style: TextStyle(
                          fontSize: context.fontSmall,
                          color: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      Text(
                        '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                        style: TextStyle(
                          fontSize: context.fontSmall,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: widget.isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.spacingXSmall),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RGB',
                        style: TextStyle(
                          fontSize: context.fontSmall,
                          color: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      Text(
                        'R:$red G:$green B:$blue',
                        style: TextStyle(
                          fontSize: context.fontSmall,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: widget.isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
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
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
    required Gradient gradient,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: context.fontSmall,
                color: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: context.fontSmall,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: widget.isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: context.spacingXSmall / 2),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: context.iconMedium,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(context.cardRadius),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                ),
              ),
            ),
            SizedBox(
              height: context.iconMedium,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 24,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withOpacity(0.2),
                ),
                child: Slider(
                  value: value,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
