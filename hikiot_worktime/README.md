# Hikiot Worktime (海康自动工时)

这是一个基于 Flutter 开发的移动应用，旨在自动同步海康互联 (Hikiot) 的考勤数据，并提供精准的个人工时管理、统计和提醒功能。

## 面向开发者 (Developer Guide)

本文档描述了程序的内部架构、核心逻辑以及所使用的海康互联私有 API。

### 项目架构

项目遵循标准的 Flutter 层级结构，核心逻辑位于 `lib/` 目录下：

- **`core/`**: 包含全局常量 (`AppConstants`, `ApiConstants`)、主题配置和基础组件。
- **`services/`**: 业务服务层。
    - `HikiotApiClient`: 封装 Rest API 请求。
    - `StorageService`: 基于 `SharedPreferences` 的本地数据持久化，包含考勤缓存、标记和设置。
    - `PunchReminderService`: 背景提醒逻辑，基于本地通知和 WorkManager。
- **`utils/`**: 工具类。
    - `AttendanceParser`: 核心解析逻辑，负责将海康 V2 API 的复杂 JSON 转换为应用内部的 `AttendanceData`。
    - `WorkTimeCalculator`: 工时计算逻辑，支持午休扣除、严谨的浮点数处理（保留两位截断）。
    - `DateHelper`: 统一的日期处理和“工作日期”判定（支持午夜跨天判定）。
    - `HolidayUtils`: 节假日同步与判定逻辑。
- **`screens/`**: UI 页面，包含每日详情、月度日历、统计分析和设置等。

---

### 海康互联 API 规范

应用通过抓包获取并使用了海康互联的移动端私有 API。

#### 1. 基础配置
- **Base URL**: `https://api.hikiot.com`
- **Headers**:
    - `Authorization`: `Bearer {TOKEN}`
    - `UNI-Request-Source`: `1` (移动端)
    - `appNo`: `__UNI__89A1A02`
    - `terminal`: `1`
    - `versionCode`: `1778` (当前使用的版本号)

#### 2. 核心 Endpoint
- **每日考勤 (V2)**: `GET /api-attendance/v1/statistics/v2/individual/single/daily?date={yyyy-MM-dd}&ID=myStatic`
    - 这是该应用获取数据的核心。返回包含照片、打卡状态、位置和**班次信息**的 `dailyDetail`。
- **账户详情**: `GET /api-saas/v1/account/detail`
    - 用于验证 Token 有效性并获取 `personNo` 等基础信息。
- **月度统计**: `GET /api-attendance/v1/statistics/myAttendance?month={yyyy-MM}&ID=myStatic`
    - 注意：当前应用由于需要照片和更细致的状态，主要采用对具体月份天数并发循环调用“每日考勤 API”的方式来填充数据。
- **请假/异常记录**: `GET /api-attendance/leaveRecord/getTodayRecords?date={yyyy-MM-dd}`
    - 用于获取当天的请假、出差等特殊记录。

#### 3. 关键字段逻辑
- **班次判定 (Shift)**:
    - 响应中的 `dailyDetail.shiftId == -1` 或 `dailyDetail.shiftName` 包含 "休息" 即判定为原生休息日/节假日。
    - 正常工作日会有关联的 `shiftId` 且 `shiftName` 包含时间段（如 `(08:30-17:30)`）。
- **打卡状态**:
    - `clockInStatusType == 1`: 迟到。
    - `clockOffStatusType == 4`: 早退。
- **照片 URL**: 提取自 `remoteClockInInfo.photo` 和 `remoteClockOffInfo.photo`。

---

### 重要技术特性

#### 1. 智能数据同步 (Smart Sync)
应用不会盲目刷新所有数据。`HikiotApiClient.getMonthlyAttendance` 采用了“遇到缓存一致即停止”的机制（在快速更新模式下），并结合 `isManual` 标记保护用户的手动修改不被服务器数据覆盖。

#### 2. 工时计算逻辑 (`WorkTimeCalculator`)
- **严谨显示**: 遵循 `int` 原样输出，`double` 两位截断 (`truncate`) 原则，避免 `8.009` 显示为 `8.01` 而导致的不满 8 小时误报。
- **由于存在 24:00 之后的打卡**: 应用通过 `DateHelper.getWorkDate()` 处理凌晨下班逻辑，确保凌晨 1 点打卡仍计入前一天的工时。

#### 3. 约束条件
- **最早日期**: `2025-08-20` (`AppConstants.earliestDate`)，早于此日期的数据无法查询。
- **未来禁用**: 禁止选择未来日期。

### 开发环境
- **Flutter SDK**: 建议 3.x 或更高版本。
- **依赖管理**: 使用 `pubspec.yaml` 中的标准库（如 `dio` 用于网络通讯，`shared_preferences` 用于本地存储，`flutter_local_notifications` 用于提醒）。

---
*注：本 README 基于 2026-01-10 的代码版本汇总生成。*
