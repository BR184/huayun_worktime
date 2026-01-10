import 'package:flutter/material.dart';
import '../utils/haptic_utils.dart';

/// 模拟 iPhone 8 Home 键触感的按钮
/// 按下和松开都有独立的震动反馈，模拟真实物理按键的感觉
class HomeButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool isOutlined;
  final double? elevation;

  const HomeButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
    this.isOutlined = false,
    this.elevation,
  });

  @override
  State<HomeButton> createState() => _HomeButtonState();
}

class _HomeButtonState extends State<HomeButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTapDown(TapDownDetails details) async {
    setState(() => _isPressed = true);
    _controller.forward();
    // 按下时的震动 - 较强的触感
    await HapticUtils.homeButtonDown();
  }

  Future<void> _handleTapUp(TapUpDetails details) async {
    // 松开时的震动 - 轻微回弹感
    await HapticUtils.homeButtonUp();
    setState(() => _isPressed = false);
    _controller.reverse();
    // 执行回调
    widget.onPressed();
  }

  Future<void> _handleTapCancel() async {
    setState(() => _isPressed = false);
    _controller.reverse();
    // 取消时也给一个轻微反馈
    await HapticUtils.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultBgColor = widget.isOutlined
        ? Colors.transparent
        : theme.colorScheme.primary;
    final defaultFgColor = widget.isOutlined
        ? theme.colorScheme.primary
        : theme.colorScheme.onPrimary;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding:
              widget.padding ??
              const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: _isPressed
                ? (widget.backgroundColor ?? defaultBgColor).withValues(alpha: 0.8)
                : (widget.backgroundColor ?? defaultBgColor),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            border: widget.isOutlined
                ? Border.all(
                    color: widget.foregroundColor ?? defaultFgColor,
                    width: 1.5,
                  )
                : null,
            boxShadow: widget.isOutlined || _isPressed
                ? null
                : [
                    BoxShadow(
                      color: (widget.backgroundColor ?? defaultBgColor)
                          .withValues(alpha: 0.3),
                      blurRadius: widget.elevation ?? 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: widget.foregroundColor ?? defaultFgColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            child: IconTheme(
              data: IconThemeData(
                color: widget.foregroundColor ?? defaultFgColor,
                size: 18,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 带图标的 Home 键风格按钮
class HomeButtonIcon extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isOutlined;

  const HomeButtonIcon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return HomeButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      isOutlined: isOutlined,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
