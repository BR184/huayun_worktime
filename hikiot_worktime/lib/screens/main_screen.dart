import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'daily_hours_screen.dart';
import 'monthly_calendar_screen.dart';
import 'settings_screen.dart';
import '../utils/haptic_utils.dart';

/// 主框架页面 - 包含底部导航栏
class MainScreen extends StatefulWidget {
  final String token;

  const MainScreen({super.key, required this.token});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int? _pressedIndex; // 追踪当前按下的按钮

  final GlobalKey<MonthlyCalendarScreenState> _monthlyKey = GlobalKey();
  final GlobalKey<DailyHoursScreenState> _dailyKey = GlobalKey();

  void _onTabTap(int index) {
    setState(() {
      _currentIndex = index;
      _pressedIndex = null;
    });

    // 切换到每日页面时,刷新数据（包括从月度页面修改的手动标记）
    if (index == 0 && _dailyKey.currentState != null) {
      _dailyKey.currentState!.refreshData();
    }

    // 切换到每月页面时,从存储刷新数据（包括从每日页面修改的手动标记）
    if (index == 1 && _monthlyKey.currentState != null) {
      _monthlyKey.currentState!.refreshFromStorage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DailyHoursScreen(key: _dailyKey),
          MonthlyCalendarScreen(key: _monthlyKey, token: widget.token),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.today, '每日工时'),
                _buildNavItem(1, Icons.calendar_month, '月度统计'),
                _buildNavItem(2, Icons.settings, '设置'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建单个导航项 - 支持 Home 键风格的按压反馈
  Widget _buildNavItem(int index, IconData icon, String label) {
    final theme = Theme.of(context);
    final isSelected = _currentIndex == index;
    final isPressed = _pressedIndex == index;

    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.6);

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) async {
          setState(() => _pressedIndex = index);
          await HapticUtils.homeButtonDown();
        },
        onTapUp: (_) async {
          await HapticUtils.homeButtonUp();
          _onTabTap(index);
        },
        onTapCancel: () {
          setState(() => _pressedIndex = null);
          HapticUtils.lightImpact();
        },
        child: AnimatedScale(
          scale: isPressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : (isPressed
                        ? theme.colorScheme.primary.withOpacity(0.05)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: isSelected ? 26 : 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
