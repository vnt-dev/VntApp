import 'package:flutter/material.dart';

/// 主题状态管理 - 使用 InheritedWidget 模式
class ThemeProvider extends InheritedWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) setThemeMode;
  final Color customThemeColor;
  final void Function(Color) setCustomThemeColor;

  const ThemeProvider({
    super.key,
    required this.themeMode,
    required this.setThemeMode,
    required this.customThemeColor,
    required this.setCustomThemeColor,
    required super.child,
  });

  static ThemeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return themeMode != oldWidget.themeMode ||
        customThemeColor != oldWidget.customThemeColor;
  }
}
