import 'package:flutter/material.dart';
import 'package:vnt_app/utils/responsive_utils.dart';

// 全局活跃 Toast 列表
final List<_ToastInfo> _activeToasts = [];

/// 显示顶部提示消息
/// [message] 提示内容
/// [isSuccess] true为成功（绿色），false为错误（红色）
void showTopToast(BuildContext context, String message, {bool isSuccess = true}) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;
  late _ToastInfo toastInfo;

  overlayEntry = OverlayEntry(
    builder: (context) => _TopToast(
      message: message,
      isSuccess: isSuccess,
      toastInfo: toastInfo,
      onDismiss: () {
        _activeToasts.remove(toastInfo);
        overlayEntry.remove();
      },
    ),
  );

  toastInfo = _ToastInfo(overlayEntry);
  _activeToasts.add(toastInfo);
  overlay.insert(overlayEntry);
}

/// Toast 信息
class _ToastInfo {
  final OverlayEntry entry;

  _ToastInfo(this.entry);
}

/// 顶部提示组件
class _TopToast extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final _ToastInfo toastInfo;
  final VoidCallback onDismiss;

  const _TopToast({
    required this.message,
    required this.isSuccess,
    required this.toastInfo,
    required this.onDismiss,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    // 开始淡入动画
    _controller.forward();

    // 3秒后自动淡出
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 计算当前 Toast 在列表中的索引
    final index = _activeToasts.indexOf(widget.toastInfo);
    // 每个 Toast 的高度约为 62px（padding + content），间距为 8px
    final topOffset = index * 70.0;

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: widget.isSuccess
                          ? const Color(0xFF4CAF50) // 绿色
                          : const Color(0xFFF44336), // 红色
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isSuccess ? Icons.check_circle : Icons.error,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: context.fontSmall,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
