import 'dart:io';
import 'package:flutter/material.dart';

/// 响应式工具类
/// 根据平台和屏幕尺寸自动计算缩放比例，确保在不同设备上显示合适
class ResponsiveUtils {
  /// 获取全局缩放比例
  /// Windows桌面端：保持较大尺寸
  /// Android移动端：根据屏幕尺寸自动缩小
  static double getScaleFactor(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    final isPortrait = height > width;

    // 判断是否为桌面平台（Windows、Linux、macOS）
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    if (isDesktop) {
      // 桌面平台：基于宽度的缩放
      if (width >= 1920) {
        return 1.2; // 2K及以上屏幕：放大20%
      } else if (width >= 1440) {
        return 1.1; // 1440p屏幕：放大10%
      } else if (width >= 1280) {
        return 1.0; // 1280p屏幕：标准大小
      } else if (width >= 1024) {
        return 0.95; // 1024p屏幕：略微缩小
      } else {
        return 0.9; // 小屏幕桌面：缩小10%
      }
    } else {
      // 移动平台（Android、iOS）：基于屏幕密度和尺寸的缩放
      final shortestSide = width < height ? width : height;

      if (isPortrait) {
        // 竖屏模式：基于宽度
        if (width >= 600) {
          return 0.85; // 平板竖屏：缩小15%
        } else if (width >= 480) {
          return 0.75; // 大屏手机：缩小25%
        } else if (width >= 400) {
          return 0.7; // 标准手机：缩小30%
        } else if (width >= 360) {
          return 0.65; // 中等手机：缩小35%
        } else {
          return 0.6; // 小屏手机：缩小40%
        }
      } else {
        // 横屏模式：基于高度
        if (height >= 600) {
          return 0.85; // 平板横屏：缩小15%
        } else if (height >= 480) {
          return 0.75; // 大屏手机横屏：缩小25%
        } else if (height >= 400) {
          return 0.7; // 标准手机横屏：缩小30%
        } else if (height >= 360) {
          return 0.65; // 中等手机横屏：缩小35%
        } else {
          return 0.6; // 小屏手机横屏：缩小40%
        }
      }
    }
  }

  /// 获取字体缩放比例（比整体缩放稍微保守一些，确保可读性）
  static double getFontScaleFactor(BuildContext context) {
    final scaleFactor = getScaleFactor(context);
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    if (isDesktop) {
      return scaleFactor; // 桌面端字体跟随整体缩放
    } else {
      // 移动端字体缩放比例稍微保守一些，避免字体太小
      return scaleFactor + 0.1; // 比整体缩放多10%
    }
  }

  /// 响应式字体大小
  static double sp(BuildContext context, double size) {
    return size * getFontScaleFactor(context);
  }

  /// 响应式宽度/高度
  static double w(BuildContext context, double size) {
    return size * getScaleFactor(context);
  }

  /// 响应式图标大小
  static double iconSize(BuildContext context, double size) {
    return size * getScaleFactor(context);
  }

  /// 响应式圆角
  static double radius(BuildContext context, double size) {
    return size * getScaleFactor(context);
  }

  /// 响应式间距
  static double spacing(BuildContext context, double size) {
    return size * getScaleFactor(context);
  }

  /// 响应式内边距
  static EdgeInsets padding(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    final scale = getScaleFactor(context);

    if (all != null) {
      return EdgeInsets.all(all * scale);
    }

    return EdgeInsets.only(
      left: (left ?? horizontal ?? 0) * scale,
      top: (top ?? vertical ?? 0) * scale,
      right: (right ?? horizontal ?? 0) * scale,
      bottom: (bottom ?? vertical ?? 0) * scale,
    );
  }

  /// 判断是否为桌面平台
  static bool isDesktop() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  /// 判断是否为移动平台
  static bool isMobile() {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// 判断是否为平板（基于屏幕尺寸）
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.width < size.height ? size.width : size.height;
    return shortestSide >= 600;
  }

  /// 判断是否为横屏
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }

  /// 获取环状图大小（专门为PieChart优化）
  static double getPieChartSize(BuildContext context, {
    double baseSize = 100.0,
    double minSize = 50.0,
    double maxSize = 120.0,
  }) {
    final scale = getScaleFactor(context);
    final size = baseSize * scale;
    return size.clamp(minSize, maxSize);
  }

  /// 获取环状图中心空白半径
  static double getPieChartCenterRadius(BuildContext context, {double baseRadius = 30.0}) {
    final scale = getScaleFactor(context);
    return baseRadius * scale;
  }

  /// 获取环状图扇形半径
  static double getPieChartSectionRadius(BuildContext context, {double baseRadius = 20.0}) {
    final scale = getScaleFactor(context);
    return baseRadius * scale;
  }

  /// 获取卡片高度
  static double getCardHeight(BuildContext context, {double baseHeight = 200.0}) {
    final scale = getScaleFactor(context);
    return baseHeight * scale;
  }

  /// 获取卡片内边距
  static EdgeInsets getCardPadding(BuildContext context) {
    return padding(context, all: 16.0);
  }

  /// 获取卡片圆角
  static double getCardRadius(BuildContext context) {
    return radius(context, 12.0);
  }
}

/// 设计系统常量 - 统一的尺寸标准
/// 所有页面应该使用这些标准值，确保一致性
class DesignSystem {
  // ==================== 字体大小 ====================
  /// 超大标题字体 (页面主标题)
  static const double fontSizeXLarge = 20.0;

  /// 大标题字体 (卡片标题、弹窗标题)
  static const double fontSizeLarge = 18.0;

  /// 副标题字体 (次要标题)
  static const double fontSizeMedium = 16.0;

  /// 正文字体 (主要内容)
  static const double fontSizeBody = 14.0;

  /// 小字体 (辅助信息)
  static const double fontSizeSmall = 12.0;

  /// 超小字体 (次要信息)
  static const double fontSizeXSmall = 11.0;

  // ==================== 图标大小 ====================
  /// 超大图标 (页面主要图标、弹窗图标)
  static const double iconSizeXLarge = 48.0;

  /// 大图标 (卡片图标)
  static const double iconSizeLarge = 32.0;

  /// 标准图标 (按钮图标、列表图标)
  static const double iconSizeMedium = 24.0;

  /// 小图标 (辅助图标)
  static const double iconSizeSmall = 20.0;

  /// 超小图标 (装饰图标)
  static const double iconSizeXSmall = 16.0;

  // ==================== 间距 ====================
  /// 超大间距 (页面顶部间距、大区块间距)
  static const double spacingXLarge = 24.0;

  /// 大间距 (卡片间距、区块间距)
  static const double spacingLarge = 20.0;

  /// 标准间距 (元素间距)
  static const double spacingMedium = 16.0;

  /// 中等间距 (小元素间距)
  static const double spacingSmall = 12.0;

  /// 小间距 (紧凑间距)
  static const double spacingXSmall = 8.0;

  /// 超小间距 (最小间距)
  static const double spacingXXSmall = 4.0;

  // ==================== 卡片 ====================
  /// 卡片内边距
  static const double cardPadding = 16.0;

  /// 卡片圆角
  static const double cardRadius = 12.0;

  /// 卡片间距
  static const double cardSpacing = 12.0;

  /// 小卡片内边距
  static const double cardPaddingSmall = 12.0;

  // ==================== 页面布局 ====================
  /// 页面水平边距
  static const double pageHorizontalPadding = 16.0;

  /// 页面垂直间距
  static const double pageVerticalSpacing = 12.0;

  /// 页面顶部间距
  static const double pageTopSpacing = 16.0;

  // ==================== 顶部标题栏 ====================
  /// 顶部标题字体大小
  static const double appBarTitleSize = 18.0;

  /// 顶部标题图标大小
  static const double appBarIconSize = 24.0;

  /// 顶部标题高度
  static const double appBarHeight = 56.0;

  // ==================== 按钮 ====================
  /// 按钮内边距（垂直）
  static const double buttonPaddingVertical = 14.0;

  /// 按钮内边距（水平）
  static const double buttonPaddingHorizontal = 24.0;

  /// 按钮圆角
  static const double buttonRadius = 12.0;

  /// 按钮字体大小
  static const double buttonFontSize = 15.0;

  // ==================== 弹窗 ====================
  /// 弹窗最大宽度
  static const double dialogMaxWidth = 400.0;

  /// 弹窗内边距
  static const double dialogPadding = 24.0;

  /// 弹窗圆角
  static const double dialogRadius = 20.0;

  /// 弹窗标题字体
  static const double dialogTitleSize = 18.0;

  /// 弹窗内容字体
  static const double dialogContentSize = 14.0;

  // ==================== 列表项 ====================
  /// 列表项高度
  static const double listItemHeight = 72.0;

  /// 列表项内边距
  static const double listItemPadding = 16.0;

  /// 列表项图标容器大小
  static const double listItemIconContainerSize = 48.0;

  /// 列表项图标大小
  static const double listItemIconSize = 24.0;
}

/// BuildContext扩展，方便使用响应式工具
extension ResponsiveExtension on BuildContext {
  /// 获取缩放比例
  double get scale => ResponsiveUtils.getScaleFactor(this);

  /// 获取字体缩放比例
  double get fontScale => ResponsiveUtils.getFontScaleFactor(this);

  /// 响应式字体大小
  double sp(double size) => ResponsiveUtils.sp(this, size);

  /// 响应式宽度/高度
  double w(double size) => ResponsiveUtils.w(this, size);

  /// 响应式图标大小
  double iconSize(double size) => ResponsiveUtils.iconSize(this, size);

  /// 响应式圆角
  double radius(double size) => ResponsiveUtils.radius(this, size);

  /// 响应式间距
  double spacing(double size) => ResponsiveUtils.spacing(this, size);

  /// 是否为桌面平台
  bool get isDesktop => ResponsiveUtils.isDesktop();

  /// 是否为移动平台
  bool get isMobile => ResponsiveUtils.isMobile();

  /// 是否为平板
  bool get isTablet => ResponsiveUtils.isTablet(this);

  /// 是否为横屏
  bool get isLandscape => ResponsiveUtils.isLandscape(this);

  // ==================== 设计系统便捷访问 ====================
  // 字体大小
  double get fontXLarge => sp(DesignSystem.fontSizeXLarge);
  double get fontLarge => sp(DesignSystem.fontSizeLarge);
  double get fontMedium => sp(DesignSystem.fontSizeMedium);
  double get fontBody => sp(DesignSystem.fontSizeBody);
  double get fontSmall => sp(DesignSystem.fontSizeSmall);
  double get fontXSmall => sp(DesignSystem.fontSizeXSmall);

  // 图标大小
  double get iconXLarge => iconSize(DesignSystem.iconSizeXLarge);
  double get iconLarge => iconSize(DesignSystem.iconSizeLarge);
  double get iconMedium => iconSize(DesignSystem.iconSizeMedium);
  double get iconSmall => iconSize(DesignSystem.iconSizeSmall);
  double get iconXSmall => iconSize(DesignSystem.iconSizeXSmall);

  // 间距
  double get spacingXLarge => spacing(DesignSystem.spacingXLarge);
  double get spacingLarge => spacing(DesignSystem.spacingLarge);
  double get spacingMedium => spacing(DesignSystem.spacingMedium);
  double get spacingSmall => spacing(DesignSystem.spacingSmall);
  double get spacingXSmall => spacing(DesignSystem.spacingXSmall);
  double get spacingXXSmall => spacing(DesignSystem.spacingXXSmall);

  // 卡片
  double get cardPadding => w(DesignSystem.cardPadding);
  double get cardRadius => radius(DesignSystem.cardRadius);
  double get cardSpacing => spacing(DesignSystem.cardSpacing);
  double get cardPaddingSmall => w(DesignSystem.cardPaddingSmall);

  // 页面布局
  double get pageHorizontalPadding => w(DesignSystem.pageHorizontalPadding);
  double get pageVerticalSpacing => spacing(DesignSystem.pageVerticalSpacing);
  double get pageTopSpacing => spacing(DesignSystem.pageTopSpacing);

  // 顶部标题栏
  double get appBarTitleSize => sp(DesignSystem.appBarTitleSize);
  double get appBarIconSize => iconSize(DesignSystem.appBarIconSize);
  double get appBarHeight => w(DesignSystem.appBarHeight);

  // 按钮
  double get buttonPaddingVertical => w(DesignSystem.buttonPaddingVertical);
  double get buttonPaddingHorizontal => w(DesignSystem.buttonPaddingHorizontal);
  double get buttonRadius => radius(DesignSystem.buttonRadius);
  double get buttonFontSize => sp(DesignSystem.buttonFontSize);

  // 弹窗
  double get dialogMaxWidth => w(DesignSystem.dialogMaxWidth);
  double get dialogPadding => w(DesignSystem.dialogPadding);
  double get dialogRadius => radius(DesignSystem.dialogRadius);
  double get dialogTitleSize => sp(DesignSystem.dialogTitleSize);
  double get dialogContentSize => sp(DesignSystem.dialogContentSize);

  // 列表项
  double get listItemHeight => w(DesignSystem.listItemHeight);
  double get listItemPadding => w(DesignSystem.listItemPadding);
  double get listItemIconContainerSize => w(DesignSystem.listItemIconContainerSize);
  double get listItemIconSize => iconSize(DesignSystem.listItemIconSize);
}
