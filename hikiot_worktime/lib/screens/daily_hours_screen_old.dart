import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/hikiot_api_client.dart';

class DailyHoursScreen extends StatefulWidget {
  const DailyHoursScreen({super.key});

  @override
  State<DailyHoursScreen> createState() => _DailyHoursScreenState();
}

class _DailyHoursScreenState extends State<DailyHoursScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedType = '工作日';
  final List<String> _workTypes = ['工作日', '加班日', '出差', '休息', '请假', '自定义'];

  // 考勤数据
  Map<String, dynamic>? _attendanceData;
  bool _isLoading = false;

  // 自定义时间控制器
  final TextEditingController _checkInController = TextEditingController();
  final TextEditingController _checkOutController = TextEditingController();

  // 是否为自动模式
  bool _isAutoMode = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('zh_CN', null);
    _loadDailyData();
  }

  @override
  void dispose() {
    _checkInController.dispose();
    _checkOutController.dispose();
    super.dispose();
  }

  /// 加载每日数据
  Future<void> _loadDailyData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // 先尝试从本地加载
      final savedData = prefs.getString('daily_$dateKey');
      if (savedData != null) {
        final data = json.decode(savedData);
        setState(() {
          _selectedType = data['type'] ?? '工作日';
          _isAutoMode = data['isAuto'] ?? true;
          if (!_isAutoMode) {
            _checkInController.text = data['checkIn'] ?? '';
            _checkOutController.text = data['checkOut'] ?? '';
          }
        });
      }

      // 如果是今天或过去日期,从API获取考勤数据
      if (!_selectedDate.isAfter(DateTime.now())) {
        await _fetchAttendanceData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载数据失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 从API获取考勤数据
  Future<void> _fetchAttendanceData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('hikiot_token');
      final personNo = prefs.getString('personNo');

      if (token == null || personNo == null) {
        print('每日工时: token=$token, personNo=$personNo');
        return;
      }

      final apiClient = HikiotApiClient(token: token);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await apiClient.getDailyAttendance(dateStr, personNo);

      print('每日工时API响应: $data');

      if (mounted && data != null) {
        // 解析打卡时间 - 参考Python代码的逻辑
        final dailyDetail = data['dailyDetail'] as Map<String, dynamic>?;
        String? clockIn;
        String? clockOut;

        if (dailyDetail != null) {
          // 优先从 shiftDetails 获取（正常工作日）
          final shiftDetails = dailyDetail['shiftDetails'] as List?;
          if (shiftDetails != null && shiftDetails.isNotEmpty) {
            final firstShift = shiftDetails[0] as Map<String, dynamic>;
            clockIn = firstShift['clockInTime'] as String?;
            clockOut = firstShift['clockOffTime'] as String?;
          }
          // 如果没有 shiftDetails，从 restClockTime 获取（加班日/休息日）
          else {
            final restClockTime = dailyDetail['restClockTime'] as List?;
            if (restClockTime != null && restClockTime.length >= 2) {
              clockIn =
                  (restClockTime.first as Map<String, dynamic>)['clockTime']
                      as String?;
              clockOut =
                  (restClockTime.last as Map<String, dynamic>)['clockTime']
                      as String?;
            }
          }
        }

        print('解析后的打卡时间: 上班=$clockIn, 下班=$clockOut');

        setState(() {
          _attendanceData = {
            'checkInTime': clockIn,
            'checkOutTime': clockOut,
            'location': dailyDetail?['address'] ?? '未知',
            'rawData': data, // 保存原始数据供调试
          };

          if (_isAutoMode && clockIn != null && clockOut != null) {
            // 自动模式下使用API数据
            _checkInController.text = _formatTime(clockIn);
            _checkOutController.text = _formatTime(clockOut);
          }
        });
      }
    } catch (e, stack) {
      print('获取每日考勤数据失败: $e');
      print('堆栈: $stack');
      // 静默失败,不影响本地数据显示
    }
  }

  /// 格式化时间 (HH:mm:ss -> HH:mm)
  String _formatTime(dynamic time) {
    if (time == null || time.toString().isEmpty) return '';
    final timeStr = time.toString();
    if (timeStr.contains(':')) {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return '${parts[0]}:${parts[1]}';
      }
    }
    return timeStr;
  }

  /// 智能解析时间输入 (支持 0850, 850, 08:50, 08-50 等格式)
  String _parseTimeInput(String input) {
    if (input.isEmpty) return '';

    // 移除所有非数字字符
    final digits = input.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) return '';

    // 根据位数解析
    String hour, minute;
    if (digits.length == 3) {
      // 850 -> 08:50
      hour = digits.substring(0, 1).padLeft(2, '0');
      minute = digits.substring(1);
    } else if (digits.length == 4) {
      // 0850 -> 08:50
      hour = digits.substring(0, 2);
      minute = digits.substring(2);
    } else if (digits.length == 2) {
      // 08 -> 08:00
      hour = digits;
      minute = '00';
    } else if (digits.length == 1) {
      // 8 -> 08:00
      hour = digits.padLeft(2, '0');
      minute = '00';
    } else {
      return input; // 无法解析,返回原值
    }

    // 验证有效性
    final h = int.tryParse(hour);
    final m = int.tryParse(minute);
    if (h == null || m == null || h > 23 || m > 59) {
      return input; // 无效时间
    }

    return '$hour:$minute';
  }

  /// 计算工时
  double _calculateHours() {
    final checkIn = _checkInController.text;
    final checkOut = _checkOutController.text;

    if (checkIn.isEmpty || checkOut.isEmpty) return 0.0;

    try {
      final inParts = checkIn.split(':');
      final outParts = checkOut.split(':');

      if (inParts.length != 2 || outParts.length != 2) return 0.0;

      final inHour = int.parse(inParts[0]);
      final inMin = int.parse(inParts[1]);
      final outHour = int.parse(outParts[0]);
      final outMin = int.parse(outParts[1]);

      final inMinutes = inHour * 60 + inMin;
      final outMinutes = outHour * 60 + outMin;

      double totalMinutes = (outMinutes - inMinutes).toDouble();

      // 午休规则: 上班<12:00 && 下班>13:00 则减去1小时
      if (inMinutes < 12 * 60 && outMinutes > 13 * 60) {
        totalMinutes -= 60;
      }

      // 转换为小时,截断到2位小数(不四舍五入)
      final hours = totalMinutes / 60;
      return (hours * 100).truncateToDouble() / 100;
    } catch (e) {
      return 0.0;
    }
  }

  /// 保存自定义数据
  Future<void> _saveCustomData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final data = {
        'type': _selectedType,
        'isAuto': _isAutoMode,
        'checkIn': _checkInController.text,
        'checkOut': _checkOutController.text,
        'hours': _calculateHours(),
        'savedAt': DateTime.now().toIso8601String(),
      };

      await prefs.setString('daily_$dateKey', json.encode(data));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  /// 选择日期
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadDailyData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = _calculateHours();

    return Scaffold(
      appBar: AppBar(
        title: const Text('每日工时'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDailyData,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期选择
                  _buildDateSelector(),
                  const SizedBox(height: 20),

                  // 类型选择
                  _buildTypeSelector(),
                  const SizedBox(height: 20),

                  // 时间输入
                  if (_selectedType == '自定义' || _selectedType == '出差')
                    _buildCustomTimeInput(),

                  if (_selectedType != '自定义' && _selectedType != '出差')
                    _buildAttendanceInfo(),

                  const SizedBox(height: 20),

                  // 工时显示
                  _buildHoursDisplay(hours),
                  const SizedBox(height: 20),

                  // 目标进度
                  _buildTargetProgress(hours),
                  const SizedBox(height: 20),

                  // 操作按钮
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.calendar_today, color: Colors.blue[700]),
        title: Text(
          DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(_selectedDate),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        trailing: Icon(Icons.arrow_drop_down, color: Colors.blue[700]),
        onTap: _selectDate,
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '工作类型',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: _workTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                    if (value == '自定义' || value == '出差') {
                      _isAutoMode = false;
                    } else {
                      _isAutoMode = true;
                      if (_attendanceData != null) {
                        _checkInController.text = _formatTime(
                          _attendanceData!['checkInTime'],
                        );
                        _checkOutController.text = _formatTime(
                          _attendanceData!['checkOutTime'],
                        );
                      }
                    }
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTimeInput() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_calendar, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  '自定义时间',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '支持格式: 0850, 08:50, 08-50',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _checkInController,
                    decoration: const InputDecoration(
                      labelText: '上班时间',
                      hintText: '0850',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final parsed = _parseTimeInput(value);
                      if (parsed != value) {
                        _checkInController.value = TextEditingValue(
                          text: parsed,
                          selection: TextSelection.collapsed(
                            offset: parsed.length,
                          ),
                        );
                      }
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _checkOutController,
                    decoration: const InputDecoration(
                      labelText: '下班时间',
                      hintText: '1730',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final parsed = _parseTimeInput(value);
                      if (parsed != value) {
                        _checkOutController.value = TextEditingValue(
                          text: parsed,
                          selection: TextSelection.collapsed(
                            offset: parsed.length,
                          ),
                        );
                      }
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceInfo() {
    if (_attendanceData == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  '暂无考勤数据',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '请先在月度统计页面完成初始化',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  '考勤详情',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('上班打卡', _formatTime(_attendanceData!['checkInTime'])),
            const SizedBox(height: 8),
            _buildInfoRow(
              '下班打卡',
              _formatTime(_attendanceData!['checkOutTime']),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('打卡地点', _attendanceData!['location'] ?? '未知'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildHoursDisplay(double hours) {
    Color hoursColor;
    String statusText;
    IconData statusIcon;

    if (hours >= 8.0) {
      hoursColor = Colors.green[600]!;
      statusText = '达标';
      statusIcon = Icons.check_circle;
    } else if (hours >= 6.0) {
      hoursColor = Colors.orange[600]!;
      statusText = '不足';
      statusIcon = Icons.warning_amber_rounded;
    } else if (hours > 0) {
      hoursColor = Colors.red[600]!;
      statusText = '严重不足';
      statusIcon = Icons.error;
    } else {
      hoursColor = Colors.grey[600]!;
      statusText = '未打卡';
      statusIcon = Icons.help_outline;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: hoursColor.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              hoursColor.withOpacity(0.15),
              hoursColor.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_filled, size: 36, color: hoursColor),
                const SizedBox(width: 12),
                Text(
                  '${hours.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: hoursColor,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '小时',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: hoursColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, size: 16, color: hoursColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: hoursColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetProgress(double hours) {
    final targets = [
      {
        'target': 8.0,
        'label': '标准工时',
        'icon': Icons.work_outline,
        'color': Colors.blue,
      },
      {
        'target': 8.8,
        'label': '110%',
        'icon': Icons.trending_up,
        'color': Colors.teal,
      },
      {
        'target': 9.6,
        'label': '120%',
        'icon': Icons.stars,
        'color': Colors.green,
      },
      {
        'target': 10.4,
        'label': '130%',
        'icon': Icons.emoji_events,
        'color': Colors.orange,
      },
      {
        'target': 11.2,
        'label': '140%',
        'icon': Icons.military_tech,
        'color': Colors.deepOrange,
      },
      {
        'target': 12.0,
        'label': '150%',
        'icon': Icons.workspace_premium,
        'color': Colors.purple,
      },
      {
        'target': 12.8,
        'label': '160%+',
        'icon': Icons.diamond,
        'color': Colors.pink,
      },
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  '目标进度',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...targets.map((target) {
              final targetHours = target['target'] as double;
              final label = target['label'] as String;
              final icon = target['icon'] as IconData;
              final targetColor = target['color'] as MaterialColor;
              final isCompleted = hours >= targetHours;
              final progress = (hours / targetHours).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: isCompleted
                              ? targetColor[700]
                              : Colors.grey[400],
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isCompleted
                                  ? targetColor[700]
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(
                              isCompleted ? targetColor[600] : targetColor[300],
                            ),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 45,
                          child: Text(
                            '${(progress * 100).toInt()}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCompleted
                                  ? targetColor[700]
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isAutoMode
                ? null
                : () {
                    setState(() {
                      _isAutoMode = true;
                      if (_attendanceData != null) {
                        _checkInController.text = _formatTime(
                          _attendanceData!['checkInTime'],
                        );
                        _checkOutController.text = _formatTime(
                          _attendanceData!['checkOutTime'],
                        );
                      }
                    });
                  },
            icon: const Icon(Icons.restore),
            label: const Text('取消修改'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveCustomData,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }
}
