# Android 代码全面审查与修复进度

初始审查日期：2026-06-08
最近更新日期：2026-06-10
审查口径：按 `AGENTS.md` 要求，以 BUG、正确性、性能、可维护性、测试缺口和工程元数据为主；安全项只保留会影响 Android 发布或运行的严重问题。
审查范围：当前 Android-only 主工程，即 `hikiot_worktime/android` 与 `hikiot_worktime/lib`。
API 参考：见 `docs/hikiot_api_reference.md`。

## 当前基线

项目核心链路已经能跑通：WebView 登录获取 token，每日工时、月度统计、设置页、提醒服务都已改为复用统一服务层和 V2 考勤入口。

已完成的旧问题压缩说明：此前 A1-A13 已修复首屏初始化竞态、`teamNo/personNo` 混用、自动标记被误升级、恢复默认工时空字段、后台提醒旧 API、月度串行聚合、API 吞错、设置/提醒 key 分裂、多班次解析、自动请假误判、页面层直接写存储、token 调试读写和工具链升级等问题。相关能力已收敛到 `StorageService`、`SessionService`、`DailyAttendanceRepository`、`MonthlyAttendanceRepository`、`SettingsRepository`、`TeamContextService`、`ReminderCoordinator` 等服务层。

当前验证基线：

- `flutter analyze`：无问题。
- `flutter test`：78/78 通过。
- `flutter build apk --debug`：已验证可构建。
- Android `release` 不再默认使用 debug 签名；WebView 调试只在非 release 构建打开；明文流量已关闭。

仍不属于代码侧可凭空完成的事项：正式 release keystore 注入。该项需要用户提供 keystore 或 CI 注入方案。

## 2026-06-10 复审发现

### R1 多团队初始化不能静默选择第一个团队

严重程度：P1
状态：已修复

问题：

- `TeamContextService.initialize()` 在多团队且无有效已保存团队时，如果 `chooseTeam` 返回 `null`，会 fallback 到 `teams.first`。
- 月度页团队选择对话框存在重复弹窗保护，异常路径可能返回 `null`。
- 这会在用户未明确选择时激活并保存第一个团队，违反“不能凭变量名或默认值推断真实业务语义”的项目规则。

目标：

- 多团队场景下，除非只有一个团队，否则必须有明确团队选择。
- 选择器返回 `null` 时抛出 `TeamSelectionRequiredException`，不再静默落到第一个团队。
- 已用测试覆盖 saved team 缺失、saved team 失效、选择器取消路径。

### R2 月度缓存后的后台静默刷新缺少异常兜底

严重程度：P2
状态：已修复

问题：

- 月度页从本地持久化缓存加载后，会启动 `_monthlyRepository.smartQuickUpdate(...).then(...)`。
- 该异步链没有 `catchError`，而仓储内部 daily API 失败会抛异常。
- 页面只校验月份，没有把发起刷新时的团队上下文一起作为回写条件。

目标：

- 后台静默刷新失败不再形成未处理异步错误。
- 新增 `MonthlyAttendanceBackgroundUpdateResult` 与 `smartQuickUpdateSafely()`，失败时返回 `error/stackTrace`，页面保留当前缓存数据并输出 `debugPrint`。
- 回写前同时校验 `teamNo`、`personNo`、月份和 widget mounted 状态。

### R3 每日预计完成时间忽略自定义午休时长

严重程度：P2
状态：已修复

问题：

- 工时计算器支持 `lunchStartMinutes/lunchEndMinutes` 动态配置。
- 每日页预计完成时间仍使用 `WorkTimeCalculator.defaultLunchDurationMinutes` 固定 60 分钟。
- 用户修改午休时间后，实际工时和预计完成时间会不一致。

目标：

- `WorkTimeCalculator.getLunchDeductionMinutes()` 已改为使用当前 `lunchDurationMinutes`。
- 每日预计完成时间改为调用统一扣除方法，不再直接写死默认 60 分钟。
- 已补自定义午休时长测试，避免后续再写回固定常量。

### R4 三大页面仍然过大，重复逻辑仍需继续拆分

严重程度：P2
状态：代码侧复审项已完成

问题：

- `monthly_calendar_screen.dart`、`daily_hours_screen.dart`、`settings_screen.dart` 仍是 2000 行以上大文件。
- 目标进度排序、团队选择弹窗、部分提示和视图拼装仍在页面层重复。
- 这违反 `AGENTS.md` 的“相似相溶”“再一再而不再三”和单一职责要求。

目标：

- 已新增并扩展 `TargetProgressHelper`，把每日和月度目标列表、智能排序、置顶移动等纯逻辑从页面层抽出。
- 已新增 `TeamSelectionDialog`，月度页和设置页不再各自维护团队选择弹窗。
- 已用测试覆盖每日目标排序、月度目标排序、置顶目标、团队选择、当前团队标记和取消行为。
- 三个页面仍然较大，但当前复审中明确指出的重复逻辑已经收口；后续新增功能继续优先放到 service/helper/widget 层。

## 本轮修复结果

1. R1：补 `TeamContextService` 选择器取消/返回 null 测试，修复为必须明确选团队。
2. R2：补月度静默刷新异常测试，新增安全刷新结果并在页面侧做上下文回写保护。
3. R3：补自定义午休扣除测试，修复固定 60 分钟的问题。
4. R4：扩展 `TargetProgressHelper`，新增 `TeamSelectionDialog`，收口每日/月度目标排序与团队选择弹窗重复逻辑。

## 当前剩余事项

代码侧复审项已完成。

外部事项：

- 正式 release 仍需要 keystore、签名密码和签名配置注入方式。没有这些材料时，代码只能避免 debug 签名，不能生成可信正式签名。

## 验收标准

- 新增/修改测试必须先失败再修复。
- 每个修复批次至少跑对应定向测试。
- 本轮收尾已跑 `flutter analyze`、`flutter test`。
- 本文档与 `docs/操作记录.md` 已同步更新。
