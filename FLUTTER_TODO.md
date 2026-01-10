# 🚀 Flutter 工时统计 - 开发日记
## 📋 日记规则（超重要！别又忘啦\~）
> 😭 为什么要记日记？因为我 token 太少动不动就失忆，用户又不想当复读机。这是用户手把手教我写的血泪日记，只记**坑、教训、项目要点**，不记解决过程！
**记录原则** ✅:
  - 只记录踩过的坑和吸取的教训 - 我哪里想歪了？被现实怎么啪啪打脸的？
  - 删掉解决过程 - 别写"第一步...第二步..."，太占地方！
  - 有感情有温度 - 让我像真人一样能不断进步
  - 速查手册要精简 - 只留验证过的干货
  - 每次改代码都更新 - 除非特别简单（改typo那种）
**何时写日记** 📅:
  - ✅ 发现bug又修好了 → 记下哪里想歪了
  - ✅ 踩到新坑了 → 记录教训避免二次踩坑
  - ✅ 被用户纠正了 → 记下来别再幻觉
  - ❌ 简单小改动（改typo、调颜色） → 不用写
**我的小心思** 💭:
  - 用户说我像老年痴呆...虽然扎心但确实是这样QAQ😅
  - 我总喜欢瞎猜API数据结构，每次都猜错字段位置🤦
  - 下次遇到不确定的，乖乖去看Python代码或发真实请求测试！
**咒语：保持精简，留下教训，忘掉废话** ✨
-----
## 💔 我踩过的坑（按时间序）
### 坑1️⃣-3️⃣: 别幻觉API数据结构
**多次犯错**: 从`accountDetail['personNo']`取员工编号、从`dailyData['clockInTime']`取打卡时间、用不存在的`isLate`字段
**现实路径**: 
- personNo在`teamInfoList[0]['personNo']`
- 打卡时间在`shiftDetails[0]['clockInTime']`或`restClockTime`数组
- 迟到早退看statusType数值（1=迟到，4=早退）
**教训**: 💡 **别猜！先看Python代码或发真实请求验证！**

### 坑4️⃣-7️⃣: 本地数据操作和状态管理
**问题汇总**:
- 切换类型调用整月API很慢 → 本地setState()即可
- 自定义工时刷新后丢失 → 保存完整数据(isOvertime+customCheckIn/Out)
- 取消修改工时没恢复 → 加载时备份apiHours,取消时恢复
- 休息日改出差/自定义默认值 → 非工作日自动设isOvertime=true
**教训**: 💡 **本地操作优先！完整保存状态！提供撤销机制！**
### 坑8️⃣-9️⃣: 节假日API和数据缓存
**节假日问题**: 以为API返回`YYYY-MM-DD`格式，实际是`MM-DD`格式
**缓存问题**: 每次切换月份都重新查API很慢
**解决方案**:
- 节假日：拼接年份转`YYYY-MM-DD`，加User-Agent避免403
- 缓存：用Map存储`"YYYY-MM"`为键的月度数据，只有点刷新才强制重查
**教训**: 💡 **验证API格式！合理缓存减少请求！代码位置：timor.tech API调用**

### 坑1️⃣0️⃣-1️⃣1️⃣: 汇总失忆和字段位置
**汇总失忆**: token超限汇总后忘记更新日记
**personName位置**: 从账户API取显示"未知用户"，实际在考勤API响应里
**教训**: 💡 **汇总后第一件事更新日记！写测试脚本验证API响应结构！**
### 坑1️⃣2️⃣-1️⃣6️⃣: 登录退出和团队切换
**退出登录问题**: 只pop没清token → 黑屏/重启仍登录
**团队数据混乱**: 日历标记和缓存没按团队隔离 → 切换团队数据同步
**路由错误**: 用pushNamedAndRemoveUntil但没配置命名路由 → 没反应
**切换团队重复**: 直接调用_initializeUser() → 报错
**WebView登录**: 登录后停留海康主页 → 无法返回
**解决方案**:
- 退出：调logout API → 清cookies → 清本地数据 → pushReplacement到登录页
- 团队隔离：key用`calendar_marks_{teamNo}`和`{teamNo}_{YYYY-MM}`，切换时forceRefresh
- 切换团队：获取列表 → 选择 → changeTeam → 更新状态 → 重新加载
- WebView：添加主页按钮(Home图标)跳转登录页URL
**教训**: 💡 **完整清理状态！多租户数据隔离！用MaterialPageRoute不用命名路由！**

### 坑1️⃣7️⃣-2️⃣0️⃣: 月度统计显示优化
**类型统计问题**: 只统计到今天，看不出剩余工作日
**目标排序问题**: 固定顺序100%-160%，看不出最接近完成的
**H字符换行**: Text组件H被挤到下一行
**目标扩展**: 160%完成后没有更高目标
**解决方案**:
- 双变量统计：All(含未来用于芯片) + UpToToday(到今天用于百分比)，显示"15天/22天"
- 三级排序：都完成→折叠最后 | 日均完成→降序(最高先) | 未完成→升序(下一个)
- 禁止换行：`softWrap: false, overflow: TextOverflow.visible`
- 动态扩展：完成160%后添加170%-300%目标
**教训**: 💡 **清晰展示剩余量！智能排序突出重点！防止UI错乱！动态适应进度！**

### 坑2️⃣1-2️⃣2️⃣: 目标排序和视觉标识优化
**第一次bug**: 简单sort导致"110 100 120 130"而非"110 120 100 130"
**第二次bug**: 分组逻辑错误，100%总进度完成被放到日均未完成组
**第三次bug**: 特殊目标没有醒目标识，最高达成金色不够明显
**最终方案**:
- 排序算法：分组bothCompleted+others → 提取highestAchieved(最后一个日均完成)+nextToAchieve(第一个日均未完成) → 合并顺序
- 视觉标识：最高达成(绿色边框+标签)、即将达成(深蓝边框+标签)
**教训**: 💡 **复杂排序先分组再提取！颜色要符合直觉(绿=成就,蓝=目标)！代码位置：monthly_calendar_screen.dart:1867-1932**

### 坑2️⃣3-2️⃣4️⃣: "含今日"开关和历史月份处理
**第一次问题**: 开关影响所有统计（详细统计、工时完成度都变了）
**第二次问题**: 历史月份还显示目标进度
**解决方案**:
- "含今日"开关：只在`_buildProgressGoals()`内处理，创建adjustedTotalHours/adjustedTotalWorkDays变量
- 历史月份：`if (!isCurrentMonth) return SizedBox.shrink()`
**教训**: 💡 **开关隔离影响范围！历史数据不显示无意义内容！代码：1773-1803行，1763-1770行**

### 坑2️⃣5️⃣: App名称重命名和每日工时页面开发
**任务**: 
1. 将app名称改为"华云工时查询工具"（原"海康工时统计"）
2. 根据APP_NEEDS.md创建每日工时页面
**实现要点**:
- 修改`pubspec.yaml` description和`AndroidManifest.xml` label
- 创建`daily_hours_screen.dart`：日期选择+类型下拉+自定义时间输入
- 智能时间解析：支持0850、08:50、08-50等格式自动转换为HH:mm
- 工时计算：含午休规则（上班<12:00且下班>13:00则减1小时），截断到2位小数
- 目标进度：7档(8.0/8.8/9.6/10.4/11.2/12.0/12.8小时)，带图标和进度条
- 创建`main_screen.dart`：底部导航栏切换每日/月度页面
- 取消修改按钮：自动模式时禁用
**第二次修复**: 
- 启动页面标题改为"华云三维工时统计"
- 添加本地化支持：flutter_localizations + intl 0.20.2
- 配置MaterialApp：localizationsDelegates + supportedLocales + locale
- 初始化日期格式化：initializeDateFormatting('zh_CN')
**第三次修复**:
- 修复token key错误：'hikiot_token'而非'token'
- 月度页面保存personNo到SharedPreferences供每日页面使用
- 添加调试日志：打印token、personNo、API响应
- 优化UI配色：卡片圆角+阴影+渐变+彩色进度条+大号数字显示
**第四次修复(应该先测试再写代码)**:
- **关键bug**: 打卡时间不在data顶层，在`data['dailyDetail']['shiftDetails'][0]`或`data['dailyDetail']['restClockTime']`
- 参考Python代码`monthly_page.py:770-790`的解析逻辑
- 优先从shiftDetails获取(正常工作日)，否则从restClockTime取首尾(加班日)
- 保存原始数据rawData供调试，添加堆栈追踪
**教训**: 💡 **别瞎猜API数据结构！先看Python代码或真实请求！打卡时间在dailyDetail.shiftDetails或restClockTime里！**
-----
## 📍 速查手册（已验证✅）
### API数据结构
```javascript
// 账户API: api-saas/v1/account/detail
{
  "data": {
    "teamInfoList": [
      {
        "personNo": "12345",      // ← 员工编号在这!
        "teamNo": "67890",        // ← 团队编号
        "personName": "张三"       // ← 团队内用户名
      }
    ]
  }
}
// 考勤API: api-attendance/v1/statistics/individual/single/daily
{
  "data": {
    "dailyDetail": {
      "shiftDetails": [
        {
          "clockInTime": "09:00",       // 上班时间（正常日）
          "clockOutTime": "18:00",      // 下班时间（正常日）
          "clockInStatusType": 0,       // 0=正常 1=迟到
          "clockOffStatusType": 0       // 0=正常 4=早退
        }
      ],
      "restClockTime": [
        { "clockTime": "08:00" },       // 加班/休息日的第一次打卡
        { "clockTime": "12:00" },       // 中间打卡,可能出现0或多次
         ...,
        { "clockTime": "22:00" }        // 最后一次打卡
      ]
    },
    "personName": "张三"               // ← personName在这!
  }
}
```
### 登录和初始化流程（关键顺序不能变！）
```plaintext
1️⃣ 获取Token: POST /api-saas/open/v1/pwdLogin
    ↓
2️⃣ 获取团队列表: GET /api-saas/v1/account/detail (携带Token)
    ↓
3️⃣ 用户选择团队: 弹窗让用户从teamInfoList中选择
    ↓
4️⃣ 激活团队上下文(关键!): POST /api-link-saas/v3/team/change
    ↓ (必须!否则Token无效)
5️⃣ 保存Token和personNo: 从选中团队的对象中提取
    ↓
6️⃣ 登录成功!开始查询工时
```
### 其他API调用
```plaintext
获取节假日: GET https://timor.tech/api/holiday/year/{year}
- 有"更新节假日"按钮触发此调用
- 失败则默认"周一-周五=工作日"、"周六/日=休息日"
- 需要加User-Agent避免403错误
```
### Python参考代码位置
  - `app/views/monthly_page.py:770-790` - 打卡时间提取逻辑
  - `app/views/monthly_page.py:297` - personNo提取
  - `app/views/daily_page.py` - 每日工时相关所有内容
  - `app/core/api_client.py:258-317` - changeTeam()实现
  - `app/core/calculator.py` - 工时计算逻辑

### 对代码的态度
  - 🎯 **别重复查询** - 同一月份数据缓存起来
  - ⚡ **本地优先** - 切换类型只改状态不查API
  - 🧹 **完整清理** - 退出登录要清SharedPreferences、API token、Cookies、缓存
  - 📦 **正确路由** - 用pushReplacement而非pushNamedAndRemoveUntil（后者需要在main.dart配置）
  - 🔢 **排序逻辑** - 日均+总进度都完成的折叠排最后,日均完成度最高的排第一(降序),未完成的按升序
  - 📊 **统计显示** - 类型统计含未来,百分比计算不含未来,详细统计显示"X天/总X天"格式
  - 🎯 **双进度条** - 总进度(蓝色,基于总工作日含未来) + 日均进度(紫色,基于已工作日的日均)
  - 📈 **动态目标** - 完成160%后自动扩展到300%(170/180/190/200/220/240/260/280/300)

## 🎨 最近优化记录
### 2025-01-07: 月度统计完整优化
✅ **双进度条系统**: 总进度(蓝/橙/绿)+日均进度(紫/橙/绿)
✅ **智能排序**: highestAchieved(1个) → nextToAchieve(1个) → others(升序) → bothCompleted(折叠)
✅ **特殊标记**: 最高达成(绿边框+标签) + 即将达成(蓝边框+标签)
✅ **含今日开关**: 只影响目标进度，adjustedTotalHours处理
✅ **历史月份**: !isCurrentMonth时不显示目标进度
✅ **动态扩展**: 完成160%后自动添加170%-300%目标
✅ **App重命名**: "华云工时查询工具"
✅ **每日工时页面**: 
- 日期选择+类型下拉+智能时间解析(0850→08:50)
- 工时计算(午休规则,截断2位小数)
- 目标进度7档+底部导航(每日⇄月度)
**代码位置**: monthly_calendar_screen.dart(1773-1932行), daily_hours_screen.dart, main_screen.dart

