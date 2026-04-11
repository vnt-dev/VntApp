import 'package:flutter/material.dart';
import 'package:vnt_app/theme/app_theme.dart';
import 'package:vnt_app/utils/toast_utils.dart';
import 'package:vnt_app/utils/responsive_utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// 关于页面
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  // 硬编码版本号
  final String _version = '1.2.17';
  final String _buildNumber = '1';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveUtils.padding(context,
            all: isWideScreen ? 24 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 页面头部
              _buildHeader(isDark, isWideScreen),
              SizedBox(height: context.spacingXLarge),

              // 应用信息卡片
              _buildAppInfoCard(isDark),
              SizedBox(height: context.spacingMedium),

              // 基于开源项目卡片
              _buildOpenSourceCard(isDark),
              SizedBox(height: context.spacingMedium),

              // 功能特性卡片
              _buildFeaturesCard(isDark),
              SizedBox(height: context.spacingMedium),

              // 联系我们卡片
              _buildContactCard(isDark),
              SizedBox(height: context.spacing(32)),

              // 许可证卡片
              _buildLicenseCard(isDark),
              SizedBox(height: context.spacingMedium),
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
          width: context.w(48),
          height: context.w(48),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(context.cardRadius),
          ),
          child: Icon(
            Icons.info_outlined,
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
                '关于',
                style: TextStyle(
                  fontSize: context.fontXLarge,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              Text(
                '应用信息与帮助',
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

  // 应用信息卡片
  Widget _buildAppInfoCard(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      padding: ResponsiveUtils.padding(context, all: 32),
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
          // APP图标
          ClipRRect(
            borderRadius: BorderRadius.circular(context.cardRadius),
            child: Image.asset(
              'assets/ic_launcher.png',
              width: context.w(80),
              height: context.w(80),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // 如果图片加载失败，显示默认图标
                return Container(
                  width: context.w(80),
                  height: context.w(80),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB2F5EA),
                    borderRadius: BorderRadius.circular(context.cardRadius),
                  ),
                  child: Icon(
                    Icons.hub_rounded,
                    color: const Color(0xFF319795),
                    size: context.iconXLarge,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: context.spacingLarge),

          // 应用名称
          Text(
            'VNT APP',
            style: TextStyle(
              fontSize: context.fontXLarge,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          SizedBox(height: context.spacingXSmall),

          // 版本号 - 可点击跳转到GitHub
          InkWell(
            onTap: () => _launchUrl('https://github.com/lmq8267/VntApp'),
            borderRadius: BorderRadius.circular(context.cardRadius),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingMedium,
                vertical: context.spacingXSmall,
              ),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(context.cardRadius),
              ),
              child: Text(
                'v$_version',
                style: TextStyle(
                  fontSize: context.fontBody,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          SizedBox(height: context.spacingLarge),

          // 应用描述
          Text(
            '一个简单、高效、能快速组建虚拟局域网的工具',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.fontMedium,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 基于开源项目卡片
  Widget _buildOpenSourceCard(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      padding: ResponsiveUtils.padding(context, all: 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.code_rounded,
                color: primaryColor,
                size: context.iconMedium,
              ),
              SizedBox(width: context.spacingSmall),
              Text(
                '项目开源地址',
                style: TextStyle(
                  fontSize: context.fontLarge,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacingMedium),
          Text(
            'VNT 是一个高性能、跨平台的虚拟组网工具',
            style: TextStyle(
              fontSize: context.fontBody,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          SizedBox(height: context.spacingMedium),
          InkWell(
            onTap: () => _launchUrl('https://github.com/vnt-dev/vnt'),
            borderRadius: BorderRadius.circular(context.spacingXSmall),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingMedium,
                vertical: context.spacingSmall,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(context.spacingXSmall),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    color: primaryColor,
                    size: context.iconSmall,
                  ),
                  SizedBox(width: context.spacingSmall),
                  Expanded(
                    child: Text(
                      'https://github.com/vnt-dev/vnt',
                      style: TextStyle(
                        fontSize: context.fontBody,
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.open_in_new_rounded,
                    color: primaryColor,
                    size: context.iconSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 功能特性卡片
  Widget _buildFeaturesCard(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      padding: ResponsiveUtils.padding(context, all: 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star_rounded,
                color: primaryColor,
                size: context.iconMedium,
              ),
              SizedBox(width: context.spacingSmall),
              Text(
                '功能特性',
                style: TextStyle(
                  fontSize: context.fontLarge,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacingLarge),
          _buildFeatureItem(
            isDark,
            icon: Icons.wifi_rounded,
            iconColor: primaryColor,
            iconBgColor: primaryColor.withOpacity(0.15),
            title: '虚拟组网',
            subtitle: '轻松创建安全的虚拟局域网',
          ),
          SizedBox(height: context.spacingMedium),
          _buildFeatureItem(
            isDark,
            icon: Icons.speed_rounded,
            iconColor: primaryColor,
            iconBgColor: primaryColor.withOpacity(0.15),
            title: '高性能',
            subtitle: '基于 Rust 构建，性能卓越',
          ),
          SizedBox(height: context.spacingMedium),
          _buildFeatureItem(
            isDark,
            icon: Icons.devices_rounded,
            iconColor: primaryColor,
            iconBgColor: primaryColor.withOpacity(0.15),
            title: '跨平台',
            subtitle: '支持 Windows、macOS、Linux、ios',
          ),
          SizedBox(height: context.spacingMedium),
          _buildFeatureItem(
            isDark,
            icon: Icons.lock_rounded,
            iconColor: primaryColor,
            iconBgColor: primaryColor.withOpacity(0.15),
            title: '安全加密',
            subtitle: '端到端加密，保护数据安全',
          ),
        ],
      ),
    );
  }

  // 功能特性项
  Widget _buildFeatureItem(
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: context.w(48),
          height: context.w(48),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(context.cardRadius),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: context.iconMedium,
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
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              SizedBox(height: context.spacing(2)),
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
      ],
    );
  }

  // 联系我们卡片
  Widget _buildContactCard(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      padding: ResponsiveUtils.padding(context, all: 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.contact_support_rounded,
                color: primaryColor,
                size: context.iconMedium,
              ),
              SizedBox(width: context.spacingSmall),
              Text(
                '联系我们',
                style: TextStyle(
                  fontSize: context.fontLarge,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacingMedium),

          // 问题反馈
          _buildContactItem(
            isDark,
            icon: Icons.bug_report_rounded,
            title: '问题反馈',
            subtitle: '报告问题或提出建议',
            onTap: () => _launchUrl('https://github.com/vnt-dev/vnt/issues'),
          ),
          SizedBox(height: context.spacingSmall),

          // 官方文档
          _buildContactItem(
            isDark,
            icon: Icons.description_rounded,
            title: '官方文档',
            subtitle: '查看使用文档和教程',
            onTap: () => _launchUrl('http://rustvnt.com'),
          ),
          SizedBox(height: context.spacingSmall),

          // QQ群
          _buildContactItem(
            isDark,
            icon: Icons.group_rounded,
            title: 'QQ群',
            subtitle: '点击加入QQ群交流',
            trailing: Text(
              '1060550456',
              style: TextStyle(
                fontSize: context.fontBody,
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
            ),
            onTap: () => _launchUrl('http://qm.qq.com/cgi-bin/qm/qr?_wv=1027&k=O7Thrz1oW12eJtNnGicZB16O4CF1P6-9&authKey=0Mdrbl88lqI3tlipW1cZiz2MsNP2Mle7zn91MPQMSWqIKDvaf5e5s6ErCHeb07MN&noverify=0&group_code=1060550456'),
          ),
        ],
      ),
    );
  }

  // 许可证卡片
  Widget _buildLicenseCard(bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      padding: ResponsiveUtils.padding(context, all: 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: primaryColor,
                size: context.iconMedium,
              ),
              SizedBox(width: context.spacingSmall),
              Text(
                '许可证',
                style: TextStyle(
                  fontSize: context.fontLarge,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacingMedium),
          Text(
            'VNT 项目遵循 Apache License 2.0 开源许可证',
            style: TextStyle(
              fontSize: context.fontBody,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 联系项
  Widget _buildContactItem(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.cardRadius),
      child: Container(
        padding: ResponsiveUtils.padding(context, all: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(context.cardRadius),
        ),
        child: Row(
          children: [
            Container(
              width: context.w(40),
              height: context.w(40),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(context.radius(10)),
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: context.iconSmall,
              ),
            ),
            SizedBox(width: context.spacingSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: context.buttonFontSize,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  SizedBox(height: context.spacing(2)),
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
            if (trailing != null) trailing
            else Icon(
              Icons.open_in_new_rounded,
              size: context.iconSmall,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // 打开URL
  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        showTopToast(context, '无法打开链接: $e', isSuccess: false);
      }
    }
  }
}
