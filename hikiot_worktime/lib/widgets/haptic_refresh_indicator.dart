import 'package:flutter/material.dart';
import '../utils/haptic_utils.dart';

/// 🎮 极致触感下拉刷新组件
/// 设计理念：模拟拉弓射箭的物理体验
/// - 蓄力阶段：像拉弓一样，越拉越紧，震动间隔越来越短，力度越来越强
/// - 释放阶段：像箭矢射出，一次干脆利落的强烈冲击
/// - 边界碰撞：像弹珠撞击边框，清脆有力
class HapticRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double displacement;
  final Color? color;
  final Color? backgroundColor;

  const HapticRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.displacement = 40.0,
    this.color,
    this.backgroundColor,
  });

  @override
  State<HapticRefreshIndicator> createState() => _HapticRefreshIndicatorState();
}

class _HapticRefreshIndicatorState extends State<HapticRefreshIndicator> {
  bool _isRefreshing = false;
  double _totalOverscroll = 0.0;

  // 🏹 蓄力阶段设计：模拟拉弓的渐进张力
  static const List<double> _chargingThresholds = [15, 35, 55, 70, 82, 92];
  int _lastThresholdIndex = -1;

  // 边界碰撞检测
  bool _wasAtTop = true;
  bool _wasAtBottom = false;

  /// 🎯 释放爆发
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    // 使用 HapticUtils 的释放震动（会根据模式自动调整）
    await HapticUtils.pullRefreshRelease();

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _isRefreshing = false;
        _totalOverscroll = 0.0;
        _lastThresholdIndex = -1;
      }
    }
  }

  /// 🏹 蓄力震动
  void _handleOverscroll(double overscroll) {
    if (_isRefreshing) return;

    _totalOverscroll += overscroll.abs();

    for (int i = _lastThresholdIndex + 1; i < _chargingThresholds.length; i++) {
      if (_totalOverscroll >= _chargingThresholds[i]) {
        _lastThresholdIndex = i;
        HapticUtils.chargingImpact(i);
        break;
      }
    }
  }

  /// 🎱 边界碰撞检测
  void _handleBoundaryCollision(ScrollMetrics metrics, double velocity) {
    final isAtTop = metrics.pixels <= metrics.minScrollExtent;
    final isAtBottom = metrics.pixels >= metrics.maxScrollExtent;
    final speed = velocity.abs();

    if (isAtTop && !_wasAtTop && speed > 200) {
      HapticUtils.boundaryImpact(speed);
    }

    if (isAtBottom && !_wasAtBottom && speed > 200) {
      HapticUtils.boundaryImpact(speed);
    }

    _wasAtTop = isAtTop;
    _wasAtBottom = isAtBottom;
  }

  void _resetState() {
    if (!_isRefreshing) {
      _totalOverscroll = 0.0;
      _lastThresholdIndex = -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final velocity = (notification.dragDetails?.primaryDelta ?? 0) * 20;
          _handleBoundaryCollision(notification.metrics, velocity);
        }

        if (notification is OverscrollNotification) {
          if (notification.overscroll < 0) {
            _handleOverscroll(notification.overscroll);
          }
          final speed = notification.velocity.abs();
          if (speed > 200) {
            HapticUtils.boundaryImpact(speed);
          }
        }

        if (notification is ScrollEndNotification) {
          _resetState();
        }

        return false;
      },
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        displacement: widget.displacement,
        color: widget.color ?? Theme.of(context).colorScheme.primary,
        backgroundColor: widget.backgroundColor,
        child: widget.child,
      ),
    );
  }
}
