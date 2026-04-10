import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vnt_app/theme/app_theme.dart';

/// 检测是否是 Windows 10 或更高版本
bool _isWindows10OrGreater() {
  if (!Platform.isWindows) return false;

  try {
    final version = Platform.operatingSystemVersion;
    final match = RegExp(r'(\d+)\.(\d+)').firstMatch(version);
    if (match != null) {
      final major = int.parse(match.group(1)!);
      return major >= 10;
    }
  } catch (e) {
    debugPrint('检测 Windows 版本失败: $e');
  }

  return true;
}

/// 自定义标题栏组件
/// 包含窗口控制按钮：最小化、最大化、置顶、关闭
class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> {
  bool _isMaximized = false;
  bool _isAlwaysOnTop = false;

  @override
  void initState() {
    super.initState();
    _checkWindowState();
  }

  Future<void> _checkWindowState() async {
    final isMaximized = await windowManager.isMaximized();
    final isAlwaysOnTop = await windowManager.isAlwaysOnTop();
    if (mounted) {
      setState(() {
        _isMaximized = isMaximized;
        _isAlwaysOnTop = isAlwaysOnTop;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // macOS 使用系统原生标题栏和三色按钮，不显示自定义标题栏
    if (Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    // Windows 7 使用系统标题栏，不显示自定义标题栏
    if (Platform.isWindows && !_isWindows10OrGreater()) {
      return const SizedBox.shrink();
    }

    if (!Platform.isWindows && !Platform.isLinux) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.darkCardBackground : AppTheme.lightCardBackground;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 可拖动区域
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) {
                windowManager.startDragging();
              },
              onDoubleTap: () async {
                if (_isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
                _checkWindowState();
              },
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    // 应用图标
                    Image.asset(
                      'assets/ic_launcher.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.hub,
                          size: 20,
                          color: Theme.of(context).primaryColor,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // 应用标题
                    Text(
                      'VNT App',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 窗口控制按钮
          _buildWindowButton(
            icon: Icons.remove,
            tooltip: '最小化',
            onPressed: () {
              windowManager.minimize();
            },
            isDark: isDark,
          ),
          _buildWindowButton(
            icon: _isMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
            tooltip: _isMaximized ? '还原' : '最大化',
            onPressed: () async {
              if (_isMaximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
              _checkWindowState();
            },
            isDark: isDark,
          ),
          _buildWindowButton(
            icon: _isAlwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
            tooltip: _isAlwaysOnTop ? '取消置顶' : '窗口置顶',
            onPressed: () async {
              await windowManager.setAlwaysOnTop(!_isAlwaysOnTop);
              _checkWindowState();
            },
            isDark: isDark,
            isActive: _isAlwaysOnTop,
          ),
          _buildWindowButton(
            icon: Icons.close,
            tooltip: '关闭',
            onPressed: () {
              windowManager.close();
            },
            isDark: isDark,
            isCloseButton: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDark,
    bool isCloseButton = false,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: isCloseButton
              ? Colors.red.withOpacity(0.8)
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
          child: Container(
            width: 46,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 16,
              color: isActive
                  ? Theme.of(context).primaryColor
                  : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
