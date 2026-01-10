import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/hikiot_api_client.dart';
import '../services/token_expired_service.dart';
import '../utils/work_time_calculator.dart';

/// 工时统计页面
class StatisticsScreen extends StatefulWidget {
  final String token;

  const StatisticsScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final HikiotApiClient _apiClient = HikiotApiClient();
  bool _isLoading = true;
  String? _error;

  // 用户信息
  Map<String, dynamic>? _accountDetail;
  String? _personNo;

  // 月度统计
  Map<String, dynamic>? _monthlyStats;

  // 选中的月份
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _apiClient.setToken(widget.token);
    _loadData();
  }

  /// 加载数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 获取账户信息
      final accountDetail = await _apiClient.getAccountDetail();

      if (accountDetail == null) {
        // Token失效，弹出对话框引导用户重新登录
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          await TokenExpiredService.handleTokenExpired(context);
          return;
        }
        throw Exception('无法获取账户信息，可能Token已失效');
      }


      // 获取团队列表并切换团队（激活Token）
      final teamInfoList = accountDetail['teamInfoList'] as List<dynamic>?;

      if (teamInfoList == null || teamInfoList.isEmpty) {
        throw Exception('该账号没有关联任何团队');
      }

      // 选择第一个团队
      final firstTeam = teamInfoList[0] as Map<String, dynamic>;

      final teamNo = firstTeam['teamNo'] as String?;
      if (teamNo == null) {
        throw Exception('团队信息不完整');
      }

      final teamChanged = await _apiClient.changeTeam(teamNo);
      if (!teamChanged) {
        throw Exception('切换团队失败，Token可能无法正常使用');
      }

      final personNo = firstTeam['personNo'] as String?;

      if (personNo == null || personNo.isEmpty) {
        throw Exception('未找到员工编号，团队: ${firstTeam['teamName']}');
      }

      // 获取月度统计
      final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
      final monthlyStats = await _apiClient.getMonthlyAttendance(
        monthStr,
        personNo,
      );

      setState(() {
        _accountDetail = accountDetail;
        _personNo = personNo;
        _monthlyStats = monthlyStats;
        _isLoading = false;
      });
    } catch (e) {
      // 检查是否是Token失效导致的错误
      if (mounted && TokenExpiredService.isTokenExpiredError(e)) {
        setState(() {
          _isLoading = false;
        });
        await TokenExpiredService.handleTokenExpired(context);
        return;
      }

      setState(() {
        _error = '数据加载失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 选择月份
  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工时统计'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadData, child: const Text('重试')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserCard(),
                    const SizedBox(height: 16),
                    _buildMonthSelector(),
                    const SizedBox(height: 16),
                    _buildMonthlyStatsCard(),
                    const SizedBox(height: 16),
                    _buildAttendanceChart(),
                    const SizedBox(height: 16),
                    _buildAttendanceList(),
                  ],
                ),
              ),
            ),
    );
  }

  /// 用户信息卡片
  Widget _buildUserCard() {
    if (_accountDetail == null) return const SizedBox.shrink();

    final userName = _accountDetail!['userName'] ?? '未知';
    final orgName = _accountDetail!['orgName'] ?? '未知';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    orgName,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 月份选择器
  Widget _buildMonthSelector() {
    final monthStr = DateFormat('yyyy年MM月').format(_selectedMonth);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _selectMonth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthStr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.calendar_today),
            ],
          ),
        ),
      ),
    );
  }

  /// 月度统计卡片
  Widget _buildMonthlyStatsCard() {
    if (_monthlyStats == null) return const SizedBox.shrink();

    final workDays = _monthlyStats!['workDays'] ?? 0;
    final totalHours = WorkTimeCalculator.formatHours(_monthlyStats!['totalHours'] ?? 0.0);
    final avgHours = WorkTimeCalculator.formatHours(_monthlyStats!['avgHours'] ?? 0.0);
    final lateCount = _monthlyStats!['lateCount'] ?? 0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '月度统计',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('出勤天数', '$workDays', '天', Colors.blue),
                _buildStatItem('总工时', totalHours, '小时', Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('平均工时', avgHours, '小时/天', Colors.orange),
                _buildStatItem('迟到', '$lateCount', '次', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 统计项
  Widget _buildStatItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                unit,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 出勤图表
  Widget _buildAttendanceChart() {
    if (_monthlyStats == null || _monthlyStats!['dailyRecords'] == null) {
      return const SizedBox.shrink();
    }

    final records = _monthlyStats!['dailyRecords'] as List<dynamic>;
    if (records.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '每日工时',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}h');
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() % 5 == 0) {
                            return Text('${value.toInt()}日');
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: records
                          .asMap()
                          .entries
                          .map(
                            (entry) => FlSpot(
                              entry.key.toDouble(),
                              (entry.value['hours'] ?? 0.0).toDouble(),
                            ),
                          )
                          .toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 出勤记录列表
  Widget _buildAttendanceList() {
    if (_monthlyStats == null || _monthlyStats!['dailyRecords'] == null) {
      return const SizedBox.shrink();
    }

    final records = _monthlyStats!['dailyRecords'] as List<dynamic>;
    if (records.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text('本月暂无出勤记录', style: TextStyle(color: Colors.grey[600])),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '出勤明细',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: records.length > 10 ? 10 : records.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = records[index];
              return _buildAttendanceItem(record);
            },
          ),
          if (records.length > 10)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // TODO: 显示完整列表
                  },
                  child: const Text('查看更多'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 出勤记录项
  Widget _buildAttendanceItem(Map<String, dynamic> record) {
    final date = record['date'] ?? '';
    final checkIn = record['checkIn'] ?? '--:--';
    final checkOut = record['checkOut'] ?? '--:--';
    final hours = WorkTimeCalculator.formatHours(record['hours'] ?? 0.0);
    final isLate = record['isLate'] ?? false;
    final isEarlyLeave = record['isEarlyLeave'] ?? false;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isLate || isEarlyLeave ? Colors.red : Colors.green,
        child: Text(
          date.split('-').last,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Row(
        children: [
          Text(date),
          if (isLate) ...[
            const SizedBox(width: 8),
            const Chip(
              label: Text('迟到', style: TextStyle(fontSize: 10)),
              backgroundColor: Colors.red,
              labelStyle: TextStyle(color: Colors.white),
              padding: EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ],
          if (isEarlyLeave) ...[
            const SizedBox(width: 8),
            const Chip(
              label: Text('早退', style: TextStyle(fontSize: 10)),
              backgroundColor: Colors.orange,
              labelStyle: TextStyle(color: Colors.white),
              padding: EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
      subtitle: Text('$checkIn - $checkOut'),
      trailing: Text(
        '${hours}h',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
