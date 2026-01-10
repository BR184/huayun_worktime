import 'package:flutter/material.dart';
import '../core/theme/theme.dart';

/// 下拉刷新引导提示组件
/// 不遮挡页面，只显示浮动提示，让用户真正下拉刷新
class PullRefreshGuide extends StatefulWidget {
  final VoidCallback onCompleted;

  const PullRefreshGuide({Key? key, required this.onCompleted})
    : super(key: key);

  @override
  State<PullRefreshGuide> createState() => _PullRefreshGuideState();
}

class _PullRefreshGuideState extends State<PullRefreshGuide>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _pulseController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 弹跳动画 - 手指上下移动
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // 脉冲动画 - 呼吸效果
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0, end: 40).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 循环播放
    _bounceController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true, // 允许所有触摸事件穿透到下层页面
      child: Stack(
        children: [
          // 顶部提示卡片
          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: _buildGuideCard(),
                );
              },
            ),
          ),

          // 中间手指动画
          Positioned(
            top: MediaQuery.of(context).size.height * 0.38,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnimation.value),
                  child: Column(
                    children: [
                      // 向下箭头
                      Icon(
                        Icons.keyboard_double_arrow_down,
                        size: 48,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 8),
                      // 手指图标
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.touch_app,
                          size: 40,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 底部跳过按钮 - 这个需要可点击
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: IgnorePointer(
                ignoring: false, // 跳过按钮可点击
                child: ElevatedButton.icon(
                  onPressed: widget.onCompleted,
                  icon: const Icon(Icons.skip_next, size: 20),
                  label: const Text('我知道了'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 8,
                    shadowColor: AppColors.shadow,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDimens.borderRadiusLg,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppDimens.borderRadius,
            ),
            child: Icon(Icons.swipe_down, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '👋 欢迎使用！',
                  style: TextStyle(
                    fontSize: AppDimens.fontLg,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '向下拉动页面即可刷新数据',
                  style: TextStyle(fontSize: AppDimens.fontMd, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
