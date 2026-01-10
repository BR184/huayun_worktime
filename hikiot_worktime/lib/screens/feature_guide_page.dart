import 'package:flutter/material.dart';
import '../core/theme/theme.dart';
import '../utils/haptic_utils.dart';

/// 功能说明页面
class FeatureGuidePage extends StatefulWidget {
  final bool showCloseButton;
  final VoidCallback? onClose;

  const FeatureGuidePage({Key? key, this.showCloseButton = true, this.onClose})
    : super(key: key);

  @override
  State<FeatureGuidePage> createState() => _FeatureGuidePageState();
}

class _FeatureGuidePageState extends State<FeatureGuidePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_FeatureItem> _features = [
    _FeatureItem(
      icon: Icons.today,
      color: AppColors.primary,
      title: '每日工时',
      points: [
        '查看今日上下班打卡时间',
        '实时计算当前工作时长',
        '预估各目标百分比的下班时间',
        '手动修改日期类型（出差/请假等）',
        '点击日期快速切换查看历史',
      ],
    ),
    _FeatureItem(
      icon: Icons.calendar_month,
      color: Colors.teal,
      title: '月度统计',
      points: [
        '查看日历视图的月度工时概览',
        '颜色区分工时达标情况',
        '统计本月累计工时和平均工时',
        '查看各目标百分比的完成进度',
        '手动标记加班日/出差/请假日期',
      ],
    ),
    _FeatureItem(
      icon: Icons.swipe_down,
      color: AppColors.warning,
      title: '下拉刷新',
      points: [
        '在任意页面下拉即可刷新数据',
        '自动同步服务器最新打卡记录',
        '保留你的手动修改标记',
        '智能缓存减少重复请求',
        '支持震动反馈（可在设置中调整）',
      ],
    ),
    _FeatureItem(
      icon: Icons.touch_app,
      color: Colors.purple,
      title: '日期操作',
      points: [
        '点击日历中的日期格子',
        '打开该日期的详情或类型选择页面',
        '可选类型：工作日/加班日/请假/出差/自定义',
        '可设置自定义上下班时间',
        '修改会自动保存',
      ],
    ),
    _FeatureItem(
      icon: Icons.event_note,
      color: Colors.indigo,
      title: '节假日管理',
      points: [
        '调用 https://timor.tech/api/holiday/year/{year} 获取法定节假日',
        '获取成功后覆盖本月的节假日标记',
        'API异常时降级为周一至五上班、周六日休息',
        '第三方数据可能与公司实际安排有差异',
        '如有出入请在日历中手动调整',
      ],
    ),
    _FeatureItem(
      icon: Icons.sync,
      color: Colors.cyan,
      title: '工时更新',
      points: [
        '海康API不支持按月批量获取工时',
        '快速更新：从今日向前逐日请求，遇到与缓存一致的数据即停止',
        '全量更新：强制刷新本月所有日期',
        '手动标记的日期不会被覆盖',
      ],
    ),
    _FeatureItem(
      icon: Icons.category,
      color: Colors.deepPurple,
      title: '工作日类型',
      points: [
        '工作日：按打卡计算工时，算总工时，算总天数',
        '加班日：周末/节假日上班，算总工时，不算总天数',
        '请假：计为0工时的工作日',
        '出差：无需打卡，固定计为8小时工时',
        '自定义：手动设置上下班时间',
        '非工作日：休息日，不算工时也不算天数',
      ],
    ),
    _FeatureItem(
      icon: Icons.push_pin,
      color: AppColors.error,
      title: '目标置顶',
      points: [
        '长按任意目标卡片可置顶',
        '置顶的目标显示在最前面',
        '再次长按取消置顶',
        '智能排序根据完成进度自动排列',
        '可在设置中开关智能排序',
      ],
    ),
    _FeatureItem(
      icon: Icons.notifications_active,
      color: Colors.amber,
      title: '打卡提醒',
      points: [
        '在设置中开启打卡提醒',
        '上班提醒：检测是否已打上班卡',
        '下班提醒：检测下班卡和工时情况',
        '自定义提醒时间',
        '节假日自动跳过',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticUtils.lightImpact();
    if (_currentPage < _features.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _close();
    }
  }

  void _close() {
    HapticUtils.mediumImpact();
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('功能说明'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: widget.showCloseButton
            ? IconButton(icon: const Icon(Icons.close), onPressed: _close)
            : null,
        automaticallyImplyLeading: widget.showCloseButton,
      ),
      body: Column(
        children: [
          // 页面指示器
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _features.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentPage == index
                        ? _features[index].color
                        : AppColors.border,
                  ),
                ),
              ),
            ),
          ),

          // 功能卡片
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                HapticUtils.selectionClick();
                setState(() => _currentPage = index);
              },
              itemCount: _features.length,
              itemBuilder: (context, index) {
                return _buildFeatureCard(_features[index]);
              },
            ),
          ),

          // 底部按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticUtils.lightImpact();
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('上一页'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _features[_currentPage].color,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage < _features.length - 1 ? '下一页' : '开始使用',
                      ),
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

  Widget _buildFeatureCard(_FeatureItem feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：图标 + 标题（横向排列，更紧凑）
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: feature.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(feature.icon, size: 28, color: feature.color),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    feature.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: feature.color,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 分隔线
              Divider(color: AppColors.divider, height: 1),

              const SizedBox(height: 16),

              // 功能点列表（主要内容区域）
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: feature.points.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: feature.color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: feature.color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature.points[index],
                            style: TextStyle(
                              fontSize: AppDimens.font,
                              height: 1.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> points;

  _FeatureItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.points,
  });
}
