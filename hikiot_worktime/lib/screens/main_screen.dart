import 'package:flutter/material.dart';
import '../core/theme/theme.dart';
import 'daily_hours_screen.dart';
import 'monthly_calendar_screen.dart';
import 'settings_screen.dart';
import '../utils/startup_refresh_coordinator.dart';

/// 主框架页面 - 包含底部导航栏
class MainScreen extends StatefulWidget {
  final String token;

  const MainScreen({super.key, required this.token});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final GlobalKey<MonthlyCalendarScreenState> _monthlyKey = GlobalKey();
  final GlobalKey<DailyHoursScreenState> _dailyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 应用启动时自动刷新数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupRefresh();
    });
  }

  Future<void> _runStartupRefresh() async {
    await StartupRefreshCoordinator.run(
      initializeSession: () async {
        await _monthlyKey.currentState?.initializeUserContext();
      },
      refreshDaily: () async {
        await _dailyKey.currentState?.refreshData();
      },
      refreshMonthly: () async {
        await _monthlyKey.currentState?.smartUpdate();
      },
      isMounted: () => mounted,
    );
  }

  Future<void> _onTabTap(int index) async {
    setState(() {
      _currentIndex = index;
    });

    // 切换到每日页面时,刷新数据（包括从月度页面修改的手动标记）
    if (index == 0 && _dailyKey.currentState != null) {
      _dailyKey.currentState!.refreshData();
    }

    // 切换到每月页面时,从存储刷新数据（包括从每日页面修改的手动标记）
    if (index == 1 && _monthlyKey.currentState != null) {
      final selectedDate = _dailyKey.currentState?.selectedDate;
      await _monthlyKey.currentState!.refreshFromStorage();
      if (selectedDate != null) {
        await _monthlyKey.currentState!.refreshDateData(selectedDate);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DailyHoursScreen(key: _dailyKey, autoLoad: false),
          MonthlyCalendarScreen(
            key: _monthlyKey,
            token: widget.token,
            autoInitialize: false,
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => _onTabTap(index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today_rounded),
              label: '每日',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: '月度',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}
