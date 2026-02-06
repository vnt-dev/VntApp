import 'dart:ui';
import 'dart:math' as math;

/// 颜色工具类，用于从主题色派生其他颜色
class ColorUtils {
  /// 将 Color 转换为 HSL 颜色空间
  /// 返回 [hue, saturation, lightness]，范围分别为 [0-360, 0-1, 0-1]
  static List<double> _colorToHSL(Color color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;

    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final delta = max - min;

    // 计算亮度
    final lightness = (max + min) / 2.0;

    // 计算饱和度
    double saturation = 0.0;
    if (delta != 0.0) {
      saturation = lightness > 0.5
          ? delta / (2.0 - max - min)
          : delta / (max + min);
    }

    // 计算色相
    double hue = 0.0;
    if (delta != 0.0) {
      if (max == r) {
        hue = ((g - b) / delta + (g < b ? 6.0 : 0.0)) / 6.0;
      } else if (max == g) {
        hue = ((b - r) / delta + 2.0) / 6.0;
      } else {
        hue = ((r - g) / delta + 4.0) / 6.0;
      }
    }

    return [hue * 360.0, saturation, lightness];
  }

  /// 将 HSL 颜色空间转换为 Color
  /// hue: 0-360, saturation: 0-1, lightness: 0-1
  static Color _hslToColor(double hue, double saturation, double lightness,
      [double opacity = 1.0]) {
    final h = hue / 360.0;
    final s = saturation.clamp(0.0, 1.0);
    final l = lightness.clamp(0.0, 1.0);

    double hueToRgb(double p, double q, double t) {
      if (t < 0.0) t += 1.0;
      if (t > 1.0) t -= 1.0;
      if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
      if (t < 1.0 / 2.0) return q;
      if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
      return p;
    }

    double r, g, b;

    if (s == 0.0) {
      r = g = b = l;
    } else {
      final q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
      final p = 2.0 * l - q;
      r = hueToRgb(p, q, h + 1.0 / 3.0);
      g = hueToRgb(p, q, h);
      b = hueToRgb(p, q, h - 1.0 / 3.0);
    }

    return Color.fromARGB(
      (opacity * 255).round(),
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
    );
  }

  /// 生成浅色版本（用于设备卡片、Tab指示器等）
  /// amount: 变亮的程度，0-1，默认 0.2
  static Color lighten(Color color, [double amount = 0.2]) {
    final hsl = _colorToHSL(color);
    final newLightness = (hsl[2] + amount).clamp(0.0, 1.0);
    return _hslToColor(hsl[0], hsl[1], newLightness, color.opacity);
  }

  /// 生成深色版本（用于梯度色、状态指示器等）
  /// amount: 变暗的程度，0-1，默认 0.1
  static Color darken(Color color, [double amount = 0.1]) {
    final hsl = _colorToHSL(color);
    final newLightness = (hsl[2] - amount).clamp(0.0, 1.0);
    return _hslToColor(hsl[0], hsl[1], newLightness, color.opacity);
  }

  /// 为日间模式生成背景色（已连接配置背景）
  /// 策略：高亮度（0.85-0.92）+ 低饱和度（0.3-0.5）
  static Color backgroundForLightMode(Color color) {
    final hsl = _colorToHSL(color);
    // 保持色相，降低饱和度，提高亮度
    final newSaturation = (hsl[1] * 0.4).clamp(0.3, 0.5);
    final newLightness = 0.88;
    return _hslToColor(hsl[0], newSaturation, newLightness);
  }

  /// 为暗黑模式生成背景色（已连接配置背景，确保不会太亮）
  /// 策略：低亮度（0.12-0.15）+ 中等饱和度（0.3-0.5）
  static Color backgroundForDarkMode(Color color) {
    final hsl = _colorToHSL(color);
    // 保持色相，适度降低饱和度，大幅降低亮度
    final newSaturation = (hsl[1] * 0.5).clamp(0.3, 0.5);
    final newLightness = 0.12; // 确保暗黑模式下不会太亮
    return _hslToColor(hsl[0], newSaturation, newLightness);
  }

  /// 为暗黑模式生成更暗的主题色（用于按钮、图标等）
  /// 策略：降低亮度到0.35-0.45，保持饱和度
  static Color darkenForDarkMode(Color color) {
    final hsl = _colorToHSL(color);
    final newLightness = (hsl[2] * 0.7).clamp(0.35, 0.45);
    return _hslToColor(hsl[0], hsl[1], newLightness);
  }
}
