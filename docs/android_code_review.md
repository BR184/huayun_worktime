# Android 代码全面审查与修复进度

初始审查日期：2026-06-08
最近更新日期：2026-06-10
审查口径：按 `AGENTS.md` 要求，以 BUG、正确性、性能、可维护性、测试缺口和工程元数据为主；安全项只保留会影响 Android 发布或运行的严重问题。
审查范围：当前 Android-only 主工程，即 `hikiot_worktime/android` 与 `hikiot_worktime/lib`。
API 参考：见 `docs/hikiot_api_reference.md`。

## 当前结论

项目核心链路可以跑通：WebView 登录获取 token，进入每日工时、月度统计、设置页，再通过海康互联 API 拉取考勤数据并本地缓存。

但代码的主要风险不是单个 lint，而是业务状态和数据口径长期没有收敛：token、teamNo、personNo、日历标记、自动标记、手动标记、提醒数据源和月度缓存分散在多个页面和服务里读写。继续直接堆功能会放大“修 A 坏 B”的概率。

截至 2026-06-10，审查中能由代码侧直接修复的项目已完成：A1-A13 均已落地。核心数据口径收敛到 `StorageService` / `SessionService` / `DailyAttendanceRepository` / `MonthlyAttendanceRepository` / `SettingsRepository` / `TeamContextService` 等服务层；提醒权限和 exact alarm 调度由 `ReminderCoordinator` 闭环；WebView 调试、开发者工具、明文流量、debug 签名等发布态风险已做代码侧限制；`CLAUDE.md` 已补齐并与 `AGENTS.md` 保持一致。当前 `flutter test`、`flutter analyze`、debug APK 构建均通过。

仍不属于代码侧可凭空完成的事项只有正式 release keystore 注入。另有 Flutter 构建提示：`android_alarm_manager_plus` 当前最新可解析版本仍会应用旧 Kotlin Gradle Plugin，当前版本可构建，但未来 Flutter 版本可能要求该插件迁移到 Built-in Kotlin；`flutter pub outdated` 未显示该插件存在可升级版本。

## 已完成修复

### F1 首屏初始化竞态已收敛

原问题：
- `DailyHoursScreen` 在自己的 `initState` 里直接加载数据。
- `MonthlyCalendarScreen` 也在自己的 `initState` 里初始化团队上下文。
- `MainScreen` 又在 post-frame 同时触发每日刷新和月度智能更新。
- 冷启动或首次登录时，每日页可能先于 `teamNo/personNo` 写入而空跑。

修复：
- 新增 `StartupRefreshCoordinator`：`hikiot_worktime/lib/utils/startup_refresh_coordinator.dart`。
- `MainScreen` 现在按顺序执行：月度页初始化团队上下文 -> 每日页刷新 -> 月度页智能更新。
- `DailyHoursScreen` 增加 `autoLoad` 参数，默认保持旧行为；在 `MainScreen` 中关闭首屏自动抢跑。
- `MonthlyCalendarScreen` 增加 `autoInitialize` 参数，默认保持旧行为；在 `MainScreen` 中关闭自动初始化，由主框架统一编排。

测试：
- `test/utils/startup_refresh_coordinator_test.dart`

### F2 `teamNo/personNo` 混用已修复

原问题：
- 每日页多处把 `personNo` 当成 `teamNo` 使用，导致日历标记可能写到 `calendar_marks_{personNo}`。
- 月度页读取的是 `calendar_marks_{teamNo}`，因此每日页和月度页可能互相看不到同一份标记。

修复：
- `StorageService` 新增统一 session 读写入口：
  - `saveTeamContext`
  - `loadTeamNo`
  - `loadPersonNo`
- 每日页不再直接读取 `StorageKeys.teamNo/personNo`，改为走 `StorageService`。
- 月度页初始化完成后通过 `StorageService.saveTeamContext()` 保存当前团队上下文。
- 每日页 `_autoUpdateTodayHours()`、保存标记、恢复默认都改为读取 `teamNo`，不再误用 `personNo`。

测试：
- `test/services/storage_service_test.dart`

### F3 自动标记被误升级为手动标记已修复

原问题：
- 每日页自动识别请假/加班时保存 `isManual: false`。
- 月度页应用 saved marks 时强制 `isManual = true`。
- 自动标记一旦经过月度页加载，就会被当成用户手动修改，后续智能修正被跳过。

修复：
- 新增 `CalendarMarkMerge`：`hikiot_worktime/lib/utils/calendar_mark_merge.dart`。
- 月度页和每日页统一通过 `CalendarMarkMerge.applyMark()` 应用标记。
- 合并时保留 mark 自身的 `isManual` 原值。
- 自定义、出差、请假、自动标记的工时处理集中到同一个 helper。

测试：
- `test/utils/calendar_mark_merge_test.dart`

### F4 恢复默认工时读取空字段已修复

原问题：
- 每日页 `_attendanceData` 只保存 `checkInTime/checkOutTime/photoUrl`。
- 恢复默认时读取 `_attendanceData['hours']`，这个字段不存在，可能把工时恢复成 `null`。

修复：
- `_attendanceData` 写入时增加 `hours`。
- 每日页恢复默认改为调用 `CalendarMarkMerge.restoreDefault()`。
- 月度页恢复默认也改为调用同一个 helper。
- 恢复默认优先使用实时 attendance hours，其次使用 `apiHours`，最后回落到 `0.0`。

测试：
- `test/utils/calendar_mark_merge_test.dart`

### F5 已触碰文件的局部清理

修复：
- 清理 `main_screen.dart` 重复 import。
- 清理 `daily_hours_screen.dart` 已无用 import。
- 删除每日页不再使用的 `_personNo` 字段。

结果：
- `flutter analyze` 问题数从此前的 43/44 降到 39。
- 后续批次继续清理后，当前已清零，见“验证记录”。

### F6 后台提醒已改为复用 V2 考勤入口

原问题：
- 前台每日页使用 V2 接口：`/api-attendance/v1/statistics/v2/individual/single/daily`。
- `PunchReminderService` 仍硬编码旧接口：`/api-attendance/v1/statistics/individual/single/daily?personNo=...`。
- 提醒服务还手写了一套 headers，包括 `authPerm`、`deviceid`、`devicename` 等旧移动端兼容字段。

修复：
- 新增 `ReminderAttendanceFetcher`：`hikiot_worktime/lib/services/reminder_attendance_fetcher.dart`。
- `PunchReminderService` 改为通过 `ReminderAttendanceFetcher` 获取今日考勤。
- `ReminderAttendanceFetcher` 默认复用 `HikiotApiClient.getDailyAttendance()`，也就是当前前台同一套 V2 daily API。
- token 缺失、personNo 缺失、token 失效、网络失败分别保留为提醒服务能理解的 `data/tokenExpired` 状态。
- 移除提醒服务中旧 daily URL、旧 headers 和直接 `http.get` 逻辑。

测试：
- `test/services/reminder_attendance_fetcher_test.dart`

### F7 月度聚合已改为并发受限与局部失败容错

原问题：
- `HikiotApiClient.getMonthlyAttendance()` 对整月逐日串行调用 daily API。
- 任意异常都在外层 catch 里返回 `null`，导致上层只知道“整月失败”。
- token 失效、网络失败、单日无数据等状态没有区分。

修复：
- 新增 `MonthlyAttendanceAggregator`：`hikiot_worktime/lib/services/monthly_attendance_aggregator.dart`。
- `HikiotApiClient.getMonthlyAttendance()` 改为委托聚合器。
- 聚合器默认最多 6 个并发 daily 请求，避免整月 28-31 天串行等待。
- 单日返回 `null` 或普通异常时记录到 `failedDates`，不再拖垮整月。
- `TokenExpiredException` 仍向上抛出，不会被当成普通网络失败吞掉。
- 聚合器输出保持旧结构：`workDays`、`totalHours`、`avgHours`、`lateCount`、`dailyRecords`、`personName`，并新增 `failedDates`。

测试：
- `test/services/monthly_attendance_aggregator_test.dart`

### F8 设置 schema 新旧并存已收敛

原问题：
- 旧设置 JSON 使用 `lunch_break`、`day_change_hour`。
- 新常量使用 `lunch_start_time`、`lunch_end_time`、`cross_day_minutes`。
- 设置页仍读写 `lunchStartTime/lunchEndTime`，启动阶段的工时计算器和跨天日期工具又各自解析不同 key。

修复：
- `StorageService.loadSettings()` 现在会把旧 JSON、驼峰 key、`StorageKeys` 蛇形 key 规范化成同一份设置。
- `StorageService.saveSettings()` 同时保存规范化 JSON 和启动工具直接读取的标量 key。
- `WorkTimeCalculator.initialize()` 改为通过 `StorageService.loadSettings()` 获取午休配置。
- `DateHelper.initialize()` 改为通过 `StorageService.loadSettings()` 获取跨天时间。
- `DateHelper.saveCrossDayMinutes()` 改为使用 `StorageKeys.crossDayMinutes`，不再手写重复 key。

测试：
- `test/services/storage_service_test.dart`

### F9 API 客户端吞错已收敛

原问题：
- `getAccountDetail()`、`changeTeam()`、`logout()` 把 HTTP 状态、业务错误、JSON 解析错误、网络异常压成 `null/false`。
- `getMonthlyAttendance()` 外层仍保留 `catch -> null`，导致调用方无法区分 token 失效、网络失败、解析失败、业务失败。
- 客户端直接使用静态 `http.get/post`，错误路径很难稳定测试。

修复：
- `HikiotApiClient` 支持注入 `http.Client`，便于用 `MockClient` 覆盖失败路径。
- HTTP 401/403 统一抛出 `TokenExpiredException`。
- 非 200 HTTP 状态抛出 `ApiException.fromResponse()`。
- 业务 `code != 0` 抛出 `ApiException`，并保留业务 code/message。
- JSON 格式错误抛出 `ParseException`。
- 网络或底层请求失败抛出 `NetworkException`。
- `getMonthlyAttendance()` 不再兜底返回 `null`，token 失效、月份校验错误、网络失败分别保留异常语义。

测试：
- `test/services/hikiot_api_client_test.dart`

### F10 提醒设置 key 已收敛

原问题：
- 设置页和通知服务使用 `morning_alarm_*`、`evening_alarm_*`。
- `StorageKeys` 中定义的是 `morning_reminder_*`、`evening_reminder_*`。
- 闹钟回调、取消、重排各自直接读写 `SharedPreferences`，导致新旧 key 长期并存，后续迁移和排错都容易失真。

修复：
- `StorageService` 新增 `ReminderSettings`、`loadReminderSettings()`、`saveMorningReminder()`、`saveEveningReminder()`。
- `loadReminderSettings()` 先读取规范 key，再兼容旧 `morning_alarm_*` / `evening_alarm_*` key，并在加载后回写两套 key。
- `NotificationService` 的调度、取消、开机/回调重排统一走 `StorageService`。
- `SettingsScreen` 加载提醒开关和提醒时间时统一走 `StorageService.loadReminderSettings()`。
- 旧 key 只保留在 `StorageService` 的迁移兼容层，不再散落在设置页和通知服务里。

测试：
- `test/services/storage_service_test.dart`

### F11 多班次考勤解析已修复

原问题：
- `AttendanceParser` 对 V2 API 的 `shiftDetails` 只读取第一个元素。
- 多班次、多段打卡、跨天下班时，后续班段里的下班时间和照片会被丢掉。
- 后台提醒、每日页、月度聚合都复用该解析器，因此这是共享数据口径问题。

修复：
- `AttendanceParser` 现在遍历全部 `shiftDetails`。
- 上班卡取最早有效 `clockInTime`，并保留该打卡对应的 `remoteClockInInfo.photo`。
- 下班卡取最晚有效 `clockOffTime`，并保留该打卡对应的 `remoteClockOffInfo.photo`。
- 对凌晨下班做相对最早上班时间的跨天展开，避免 `00:30` 被误判为早于 `23:30`。
- 迟到和早退状态合并所有班段，只要任一班段命中就保留异常状态。

测试：
- `test/utils/attendance_parser_test.dart`

### F12 自动请假推断已增加数据来源状态

原问题：
- 过去工作日、工时 0、无上班卡时会自动推断为请假。
- 旧缓存、默认月历格、API 失败后的空数据也可能表现成“工时 0 + 无上班卡”。
- 因此缓存缺失或接口失败时，页面有机会把未知状态误写成请假。

修复：
- `SmartDayTypeHelper` 新增 `DayDataSourceStatus`。
- 默认状态为 `unknown`，不会触发自动请假。
- API 成功返回并解析过的日期标记为 `apiConfirmed`。
- 自动请假只在 `apiConfirmed + 过去工作日 + 工时 0 + 无上班卡` 时触发。
- 每日页、月度页、月度聚合器都在真实 API 成功路径写入 `dataSourceStatus=apiConfirmed`。
- 月度默认数据和旧缓存缺字段时保持 `unknown`，避免把“未知”当成“已确认无打卡”。

测试：
- `test/utils/smart_day_type_helper_test.dart`

### F13 静态分析基线已清零

原问题：
- 项目在多轮功能修复后仍残留 `flutter analyze` warning/info。
- 主要集中在未使用 import、废弃 `Switch.activeColor`、多余 `toList()`、不明确的异步弹窗 `BuildContext` 使用、构造函数 super 参数等。

修复：
- 清理已触碰文件中的未使用 import、重复 import、废弃 API 和样式 lint。
- `Switch.activeColor` 替换为 `activeThumbColor`。
- 每日编辑弹窗把异步保存/恢复回调改为 `Future<void>`，等待落盘完成后再关闭弹窗。
- 每日、月度编辑弹窗和免责声明弹窗补齐 `context.mounted`/`mounted` 生命周期防护。
- 设置页跨天时间选择在震动、选择器返回、保存配置后均做 `mounted` 检查。
- 异常类、功能引导页、下拉刷新引导、图片预览等文件完成低风险 Dart 语法清理。

结果：
- `flutter analyze` 当前无问题。

### F14 页面层存储 key 已继续收口

原问题：
- 启动页、登录页、每日页、免责声明弹窗、设置页仍直接读写 `SharedPreferences`。
- 页面层散落 `hikiot_token`、`onboarding_completed`、`disclaimer_shown`、`debug_tools_enabled`、`extended_target_range`、`current_team_no`、`current_team_name` 等 key。
- `StorageKeys.disclaimerAccepted` 已存在，但实际页面写的是旧 key `disclaimer_shown`，老用户升级后容易重复弹免责声明。
- 设置页读取 `current_team_name/current_user_name`，但月度初始化主路径只写 `teamNo/personNo/user_name`，团队展示信息来源不稳定。

修复：
- `StorageKeys` 新增 `teamName`、`extendedTargetRange`、`debugToolsEnabled`。
- `StorageService` 新增：
  - `load/saveOnboardingCompleted`
  - `load/saveDisclaimerAccepted`
  - `load/saveExtendedTargetRange`
  - `load/saveDebugToolsEnabled`
  - `loadTeamName`
- `StorageService.saveTeamContext()` 支持保存 `teamName`，并兼容回写旧 `current_team_no/current_team_name`。
- `StorageService.loadUserName()` 兼容旧 `current_user_name`。
- 免责声明读取旧 `disclaimer_shown` 后回写新 `disclaimer_accepted`，保存时两套 key 同步。
- 启动页、登录页、每日页、免责声明弹窗、设置页和 token 失效服务改为通过 `StorageService` 读写 token、引导、调试开关、扩展目标和团队展示信息。
- 月度页初始化团队上下文时同步保存团队名和用户名，设置页展示信息不再依赖孤立旧 key。

测试：
- `test/services/storage_service_test.dart`

### F15 提醒权限和 exact alarm 调度已闭环

原问题：
- 设置页开启提醒时只检查通知权限。
- `requestExactAlarmPermission()` 的返回值被忽略，Android 12+ 未授权时 UI 仍可能显示已开启，但闹钟实际不会准时触发。
- 设置页直接拼权限、调度、取消逻辑，后续很容易两套提醒流程不一致。

修复：
- 新增 `ReminderCoordinator`：`hikiot_worktime/lib/services/reminder_coordinator.dart`。
- `ReminderCoordinator` 统一返回 `ReminderToggleResult`，区分已开启、已关闭、通知权限拒绝、精确闹钟权限拒绝。
- `SettingsScreen` 开关上班/下班提醒、修改提醒时间后的重排，都改为通过 `ReminderCoordinator`。
- 权限被拒时不会调度闹钟，并会把 UI 和存储状态回落到关闭。

测试：
- `test/services/reminder_coordinator_test.dart`

### F16 会话与 token 过期处理已继续收口

原问题：
- `ErrorHandler` 和 `TokenExpiredService` 各自维护一套 token 过期弹窗、登出、跳转登录页流程。
- 这会让后续改退出登录、清 WebView cookie 或本地 token 时出现两套逻辑漂移。

修复：
- `ErrorHandler` 的 token 过期分支改为复用 `TokenExpiredService.handleTokenExpired()`。
- `ErrorHandler.isTokenExpiredError()` 改为委托 `TokenExpiredService.isTokenExpiredError()`。
- `SessionService` 继续作为远程 logout、WebView cookie 清理、本地认证信息清理的统一入口。

### F17 发布态风险已做代码侧限制

原问题：
- Android WebView 调试在所有构建类型中开启。
- 设置页 release 中仍可打开开发者工具、复制 token、生成无效 token。
- Android 主 manifest 全局允许明文流量。
- release build 默认使用 debug 签名。

修复：
- `main.dart` 改为仅在 `!kReleaseMode` 时开启 WebView 调试。
- `SettingsScreen` 的开发者工具区域仅在非 release 构建渲染。
- `AndroidManifest.xml` 的 `usesCleartextTraffic` 改为 `false`。
- `build.gradle.kts` 移除 release 默认 debug 签名，只保留注释说明正式签名应由 CI 或本机 keystore 注入。

说明：
- 当前 debug APK 仍正常构建并使用 Android Debug 证书，便于手机测试。
- 正式 release 仍需要提供 keystore/signing config，不能由代码自动凭空生成可信签名。

### F18 工程元数据与明显页面 BUG 已修正

修复：
- 补齐 `CLAUDE.md`，并与 `AGENTS.md` 内容保持一致。
- 设置页团队选择弹窗改为用 `teamNo` 对比当前 `_teamNo`，不再把团队编号和团队名称混比。
- 午休时间选择入口补齐 `await`，避免异步保存路径被悬空。
- 对当前修改/新增文本文件做 UTF-8 和 LF 行尾归一化；`git diff --check` 当前无尾随空白错误。

### F19 大页面职责已继续拆分

原问题：
- `daily_hours_screen.dart`、`monthly_calendar_screen.dart`、`settings_screen.dart` 仍把 UI、API、存储、业务合并、权限、导航、错误处理混在页面里。
- 前序已经抽出部分 helper，但每日/月份/设置页面仍有页面直接读写日历标记、拼保存数据、计算恢复默认结果的路径。

修复：
- 每日页新增并接入 `DailyAttendanceRepository.saveManualMark()` 与 `restoreDefaultMark()`，页面不再直接读写 `calendar_marks_{teamNo}`，也不再自己调用 `CalendarMarkMerge.restoreDefault()`。
- 月度页新增并接入 `MonthlyAttendanceRepository.saveDaySettings()` 与 `restoreDefaultType()`，页面不再直接保存/删除日历标记，也不再重复计算自定义工时和恢复默认行。
- 设置页补齐 `SettingsRepository.loadToken()` 与 `saveTokenForDebug()`，团队切换后的 token 读取、复制 token、生成无效 token 均走 repository，不再绕过设置服务层。
- 现有 `DailyAttendanceRepository`、`MonthlyAttendanceRepository`、`MonthlyAttendanceMergeService`、`SettingsRepository`、`TeamContextService` 均有测试覆盖并已接入页面。

测试：
- `test/services/daily_attendance_repository_test.dart`
- `test/services/monthly_attendance_repository_test.dart`
- `test/services/settings_repository_test.dart`

### F20 Gradle/AGP/Kotlin 工具链已完成升级验证

原问题：
- Flutter 3.44.1 构建时提示旧 Gradle/AGP/Kotlin 组合未来会被弃用。
- 早前升级尝试曾因 Gradle 分发包下载卡住导致无法完成验证。

修复：
- 当前 Android wrapper 使用 Gradle `8.14.3`。
- Android Gradle Plugin 已为 `8.11.1`。
- Kotlin Android Gradle plugin 已为 `2.2.20`。
- 本机 Gradle wrapper 分发包和 Gradle 插件缓存已经可用，`flutter build apk --debug` 可直接通过。

说明：
- debug APK 构建仍会提示 `android_alarm_manager_plus` 应用旧 Kotlin Gradle Plugin。`flutter pub outdated` 未显示该插件有可升级版本，因此该项属于上游插件兼容提醒，不是当前代码可直接消除的构建失败。

## 验证记录

使用命令：

```powershell
D:\Environments\flutter\bin\flutter.bat test
D:\Environments\flutter\bin\flutter.bat analyze
D:\Environments\flutter\bin\flutter.bat build apk --debug
git -c safe.directory=D:/liuxuhao/projects/auto_worktime diff --check
```

结果：
- `flutter test`：67/67 通过。
- `flutter analyze`：无问题，命令退出码 0。
- `flutter build apk --debug`：通过，产物为 `hikiot_worktime/build/app/outputs/flutter-apk/app-debug.apk`。
- `git diff --check`：无空白错误；仅有 Git 对 LF/CRLF 自动转换的提示。
- `.\gradlew.bat --version`：Gradle `8.14.3`，JVM `17.0.17`。
- `flutter pub outdated`：未显示 `android_alarm_manager_plus` 有可升级版本；仅提示 `flutter_local_notifications` 等依赖有 major 版本可解析。
- debug APK 构建仍提示 `android_alarm_manager_plus` 当前会应用旧 Kotlin Gradle Plugin，未来 Flutter 版本可能要求上游插件迁移到 Built-in Kotlin。

当前测试覆盖：
- `StartupRefreshCoordinator`：启动顺序与 mounted 保护。
- `DailyAttendanceRepository`：每日数据加载、缺团队/缺 token 状态、自动加班标记保存、手动标记保存、恢复默认。
- `StorageService`：team/person session 统一读写；旧设置 JSON 到新设置 key 的迁移；设置保存时同步 JSON 与标量 key；提醒设置新旧 key 迁移与同步。
- `StorageService`：onboarding、免责声明、调试工具、扩展目标、团队展示信息的统一读写与旧 key 兼容。
- `SettingsRepository`：设置页快照、午休设置、目标设置、开关设置、提醒时间、token 调试读写。
- `TeamContextService`：团队初始化、团队选择、切换当前团队时不重复调用 changeTeam、仅加载团队候选。
- `HikiotApiClient`：401/403、业务错误、解析失败不再被吞成 `null/false`。
- `CalendarMarkMerge`：自动标记不变手动、自定义工时、恢复默认回到 API/实时工时。
- `ReminderAttendanceFetcher`：提醒服务复用统一 daily loader，区分缺 token、缺 personNo、token 失效、网络不可用。
- `ReminderCoordinator`：通知权限拒绝、exact alarm 权限拒绝、开启调度、关闭取消。
- `MonthlyAttendanceAggregator`：月度并发聚合、单日失败容错、token 失效不吞。
- `MonthlyAttendanceRepository` / `MonthlyAttendanceMergeService`：月度缓存、API 合并、手动日期设置保存、恢复默认、持久化缓存。
- `AttendanceParser`：多班次取最早上班和最晚下班，跨天凌晨下班不被丢弃。
- `SmartDayTypeHelper`：未确认来源的空工作日不自动请假；API 确认后的空工作日仍会自动请假。

## 仍待处理问题

当前审查计划内没有代码侧待修复项。

外部或上游事项：
- 正式 release 需要 keystore、签名密码和签名配置注入方式。
- `android_alarm_manager_plus` 当前最新可解析版本仍触发 Flutter 的旧 KGP 插件警告；等上游插件支持 Built-in Kotlin 后再升级。

## 发布阻断项

代码侧阻断项已大多处理：

1. release 不再默认使用 debug 签名。
2. WebView 调试仅非 release 开启。
3. 开发者工具仅非 release 渲染。
4. `AndroidManifest.xml` 不再全局允许明文流量。
5. exact alarm 权限已闭环，拒绝时不会把提醒显示为已开启。

仍需外部材料：
- 正式 release 需要 keystore、签名密码和签名配置注入方式。没有这些材料时，代码只能避免 debug 签名，不能生成可信正式签名。

## 下一步建议

1. 手机实测 debug APK，重点测登录、团队选择、每日手动标记、月度手动标记、提醒开关和跨天工时。
2. 准备 release keystore 后补正式签名配置。
3. 后续新增功能继续优先放到 repository/service/helper 层，页面只负责展示和用户交互。
