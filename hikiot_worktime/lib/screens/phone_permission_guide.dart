import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/device_brand_service.dart';
import '../utils/haptic_utils.dart';

/// 手机品牌权限设置指南
class PhonePermissionGuide extends StatefulWidget {
  const PhonePermissionGuide({super.key});

  @override
  State<PhonePermissionGuide> createState() => _PhonePermissionGuideState();
}

class _PhonePermissionGuideState extends State<PhonePermissionGuide> {
  String _brand = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _detectBrand();
  }

  Future<void> _detectBrand() async {
    final brand = await DeviceBrandService().loadBrand();
    if (!mounted) return;
    setState(() {
      _brand = brand;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('权限设置指南'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBrandHeader(),
                  const SizedBox(height: 16),
                  _buildWarningCard(),
                  const SizedBox(height: 24),
                  ..._buildGuideSteps(),
                  const SizedBox(height: 24),
                  _buildQuickSettingsButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildBrandHeader() {
    final brandInfo = _getBrandInfo();
    return Card(
      color: brandInfo['color'] as Color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(brandInfo['icon'] as IconData, size: 40, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '检测到 ${brandInfo['name']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '请按以下步骤设置权限',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '国产手机对后台应用限制严格，必须完成以下设置才能保证提醒正常工作',
              style: TextStyle(fontSize: 13, color: Colors.orange[900]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGuideSteps() {
    final steps = _getStepsForBrand();
    return steps.asMap().entries.map((entry) {
      final index = entry.key;
      final step = entry.value;
      return _buildStepCard(index + 1, step);
    }).toList();
  }

  Widget _buildStepCard(int number, Map<String, dynamic> step) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['title'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step['path'] as String,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      if (step['action'] != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            step['action'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSettingsButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              HapticUtils.lightImpact();
              // 使用 permission_handler 打开应用详情设置
              await openAppSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('打开应用设置'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '如果上述按钮无法跳转，请手动进入设置页面',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Map<String, dynamic> _getBrandInfo() {
    switch (_brand) {
      case 'xiaomi':
      case 'redmi':
      case 'poco':
        return {
          'name': '小米/Redmi',
          'icon': Icons.phone_android,
          'color': Colors.orange[700]!,
        };
      case 'huawei':
      case 'honor':
        return {
          'name': '华为/荣耀',
          'icon': Icons.phone_android,
          'color': Colors.red[700]!,
        };
      case 'oppo':
      case 'realme':
      case 'oneplus':
        return {
          'name': 'OPPO/realme/一加',
          'icon': Icons.phone_android,
          'color': Colors.green[700]!,
        };
      case 'vivo':
      case 'iqoo':
        return {
          'name': 'vivo/iQOO',
          'icon': Icons.phone_android,
          'color': Colors.blue[700]!,
        };
      case 'samsung':
        return {
          'name': '三星',
          'icon': Icons.phone_android,
          'color': Colors.indigo[700]!,
        };
      default:
        return {
          'name': '安卓手机',
          'icon': Icons.phone_android,
          'color': Colors.grey[700]!,
        };
    }
  }

  List<Map<String, dynamic>> _getStepsForBrand() {
    switch (_brand) {
      case 'xiaomi':
      case 'redmi':
      case 'poco':
        return [
          {
            'title': '开启自启动权限',
            'path': '设置 → 应用设置 → 应用管理 → 华云工时 → 权限 → 自启动',
            'action': '开启',
          },
          {
            'title': '设置无限制省电',
            'path': '设置 → 省电与电池 → (右上角齿轮⚙️) → 应用智能省电 → 华云工时',
            'action': '选择 "无限制"',
          },
          {
            'title': '锁定后台应用',
            'path': '打开最近任务视图 → 长按华云工时卡片 → 点击 🔒 图标',
            'action': '锁定后清理内存时不被杀掉',
          },
          {
            'title': '允许后台弹出界面',
            'path': '设置 → 应用设置 → 应用管理 → 华云工时 → 权限管理 → 后台弹出界面',
            'action': '选择 "始终允许"',
          },
          {
            'title': '允许通知',
            'path': '设置 → 通知与状态栏 → 应用通知管理 → 华云工时',
            'action': '开启通知并允许悬浮/锁屏',
          },
        ];
      case 'huawei':
      case 'honor':
        return [
          {
            'title': '应用启动管理',
            'path': '设置 → 应用和服务 → 应用启动管理 → 华云工时',
            'action': '关闭 "自动管理"，手动开启 "允许自启动"、"允许关联启动"、"允许后台活动"',
          },
          {
            'title': '关闭电池优化',
            'path': '设置 → 电池 → 更多电池设置 → 休眠时始终保持网络连接',
            'action': '开启',
          },
          {
            'title': '锁定后台',
            'path': '打开最近任务视图 → 找到华云工时卡片 → 向下滑动卡片',
            'action': '卡片右上角出现 🔒 即为锁定成功',
          },
          {
            'title': '允许通知',
            'path': '设置 → 通知和状态栏 → 华云工时',
            'action': '开启 "允许通知" 并设为 "重要"',
          },
        ];
      case 'oppo':
      case 'realme':
      case 'oneplus':
        // ColorOS 12/13/14 路径大改，整合了耗电管理
        return [
          {
            'title': '允许完全后台行为',
            'path': '设置 → 应用 → 应用管理 → 华云工时 → 耗电管理',
            'action': '开启 "允许完全后台行为" (或 "允许自启动" & "允许后台活动")',
          },
          {
            'title': '关闭休眠冻结',
            'path': '设置 → 电池 → 更多设置 → 耗电异常优化',
            'action': '找到华云工时 → 选择 "不优化"',
          },
          {
            'title': '锁定后台',
            'path': '打开最近任务视图 → 点击华云工时卡片右上角 "⋮" → 锁定',
            'action': '锁定后任务卡片会有 🔒 标记',
          },
          {
            'title': '允许通知',
            'path': '设置 → 通知与状态栏 → 华云工时',
            'action': '开启通知并允许横幅/锁屏',
          },
        ];
      case 'vivo':
      case 'iqoo':
        return [
          {
            'title': '允许后台高耗电',
            'path': '设置 → 电池 → 后台耗电管理 → 华云工时',
            'action': '开启 "允许后台高耗电"',
          },
          {
            'title': '自启动管理',
            'path': 'i管家 → 应用管理 → 权限管理 → 自启动',
            'action': '开启华云工时',
          },
          {
            'title': '锁定后台',
            'path': '打开最近任务视图 → 点击华云工时卡片右上角 "▼" 或长按 → 锁定',
            'action': '锁定后不会被一键清理',
          },
          {
            'title': '允许通知',
            'path': '设置 → 通知与状态栏 → 应用通知管理 → 华云工时',
            'action': '开启全部通知权限',
          },
        ];
      case 'samsung':
        return [
          {
            'title': '设置不受限制',
            'path': '设置 → 应用程序 → 华云工时 → 电池',
            'action': '选择 "不受限制" (Unrestricted)',
          },
          {
            'title': '从休眠列表移除',
            'path': '设置 → 电池和设备维护 → 电池 → 后台使用限制 → 深度休眠应用程序',
            'action': '点击右上角 "+" → 添加华云工时', // 这里逻辑其实是确保不在列表里，但通常直接设为不限制更简单
          },
          {'title': '允许自启动', 'path': '智能管理器 → 自动运行应用程序', 'action': '开启华云工时'},
          {
            'title': '锁定后台',
            'path': '打开最近任务 → 点击图标 → 保持打开 (Keep open)',
            'action': '防止被系统清理',
          },
        ];
      default:
        // 针对原生安卓或通用机型的兜底策略
        return [
          {
            'title': '电池优化设置',
            'path': '设置 → 应用 → 华云工时 → 电池',
            'action': '选择 "无限制" 或 "不优化"',
          },
          {'title': '开启自启动', 'path': '手机管家/设置 → 权限管理 → 自启动', 'action': '开启'},
          {'title': '锁定后台', 'path': '最近任务列表 → 长按或下拉应用卡片', 'action': '锁定应用'},
          {'title': '允许通知', 'path': '设置 → 应用 → 华云工时 → 通知', 'action': '开启通知'},
        ];
    }
  }
}
