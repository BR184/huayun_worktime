import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/hikiot_api_client.dart';
import 'login_screen.dart';
import 'package:intl/intl.dart';

class WorktimeScreen extends StatefulWidget {
  const WorktimeScreen({super.key});

  @override
  State<WorktimeScreen> createState() => _WorktimeScreenState();
}

class _WorktimeScreenState extends State<WorktimeScreen>
    with SingleTickerProviderStateMixin {
  String? token;
  Map<String, dynamic>? userInfo;
  Map<String, dynamic>? todayData;
  bool isLoading = true;
  late TabController _tabController;

  HikiotApiClient? apiClient;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDataAndInit();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDataAndInit() async {
    setState(() => isLoading = true);

    // 加载Token
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('hikiot_token');

    if (token == null) {
      // 没有Token，跳转到登录页
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
      return;
    }

    // 初始化API客户端
    apiClient = HikiotApiClient(token: token);

    // 获取用户信息
    userInfo = await apiClient!.getAccountDetail();

    // 获取今日数据（需要teamId，这里先用mock数据）
    if (userInfo != null) {
      // TODO: 从用户信息中获取teamId
      // todayData = await apiClient!.getDailyAttendance(
      //   DateFormat('yyyy-MM-dd').format(DateTime.now()),
      //   teamId
      // );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工时统计'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '今日工时'),
            Tab(text: '本月统计'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataAndInit,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildTodayTab(), _buildMonthTab()],
            ),
    );
  }

  Widget _buildTodayTab() {
    if (userInfo == null) {
      return const Center(child: Text('无法获取用户信息'));
    }

    return RefreshIndicator(
      onRefresh: _loadDataAndInit,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户信息卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue,
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userInfo!['registerPhone'] ?? '用户',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '今天是 ${DateFormat('yyyy年MM月dd日').format(DateTime.now())}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 今日工时统计
          const Text(
            '今日工时',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '应出勤',
                  '8.0',
                  '小时',
                  Colors.blue,
                  Icons.access_time,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '实际工时',
                  '0.0',
                  '小时',
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '迟到',
                  '0',
                  '次',
                  Colors.orange,
                  Icons.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('早退', '0', '次', Colors.red, Icons.logout),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 提示信息
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '下拉刷新获取最新数据',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthTab() {
    return RefreshIndicator(
      onRefresh: _loadDataAndInit,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${DateFormat('yyyy年MM月').format(DateTime.now())} 统计',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildStatCard(
            '本月累计工时',
            '0.0',
            '小时',
            Colors.blue,
            Icons.calendar_today,
          ),

          const SizedBox(height: 12),

          _buildStatCard(
            '本月出勤天数',
            '0',
            '天',
            Colors.green,
            Icons.event_available,
          ),

          const SizedBox(height: 24),

          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '功能开发中，敬请期待',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    unit,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('hikiot_token');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }
}
