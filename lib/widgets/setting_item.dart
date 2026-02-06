import 'package:flutter/material.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/utils/responsive_utils.dart';

/// 设置项组件 - 用于设置页面
class SettingItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showArrow;
  final bool enabled;

  const SettingItem({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showArrow = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final effectiveIconColor = iconColor ?? primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing(16),
            vertical: context.spacing(14),
          ),
          child: Row(
            children: [
              Container(
                width: context.w(40),
                height: context.w(40),
                decoration: BoxDecoration(
                  color: effectiveIconColor.withOpacity(enabled ? 0.1 : 0.05),
                  borderRadius: BorderRadius.circular(context.radius(10)),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? effectiveIconColor
                      : effectiveIconColor.withOpacity(0.5),
                  size: context.iconSmall,
                ),
              ),
              SizedBox(width: context.spacing(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: context.fontMedium,
                        fontWeight: FontWeight.w500,
                        color: enabled
                            ? (isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.lightTextPrimary)
                            : (isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary),
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: context.spacing(2)),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: context.fontSmall,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (showArrow && trailing == null)
                Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  size: context.iconSmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置开关项组件
class SettingSwitchItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  const SettingSwitchItem({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return SettingItem(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      showArrow: false,
      enabled: enabled,
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: primaryColor,
      ),
      onTap: enabled && onChanged != null
          ? () => onChanged!(!value)
          : null,
    );
  }
}

/// 设置分组标题
class SettingGroupTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;

  const SettingGroupTitle({
    super.key,
    required this.title,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding ?? EdgeInsets.fromLTRB(
        context.spacing(16),
        context.spacing(24),
        context.spacing(16),
        context.spacing(8),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: context.fontSmall,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 设置分组容器
class SettingGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const SettingGroup({
    super.key,
    this.title,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) SettingGroupTitle(title: title!),
        Container(
          margin: margin ?? EdgeInsets.symmetric(horizontal: context.spacing(16)),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkCardBackground
                : AppTheme.lightCardBackground,
            borderRadius: BorderRadius.circular(context.radius(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.radius(12)),
            child: Column(
              children: _buildChildrenWithDividers(context),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChildrenWithDividers(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> result = [];

    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(Divider(
          height: 1,
          thickness: 1,
          indent: 70,
          color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
        ));
      }
    }

    return result;
  }
}
