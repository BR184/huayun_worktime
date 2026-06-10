# 海康互联 API 勘探与修复准备文档

勘探日期：2026-06-09
用途：为后续 Android 端修复、重构和测试补齐提供 API 事实依据。
敏感信息处理：本文件不记录 token、姓名、手机号、团队名、团队编号、人员编号、照片 URL 等可识别信息。

## 总体结论

当前 token 可用，核心接口均可访问：

- `account/detail` 可获取账号信息、在线团队和团队列表。
- `team/change` 可切换团队上下文，并返回当前团队对应的 `teamNo/personNo`。
- 每日考勤 V2 接口可直接按 token 查询当前团队上下文下的个人日考勤，不需要在 query 中传 `personNo`。
- 每日考勤 V2 接口按 query 里的 `date=yyyy-MM-dd` 返回单个自然日 `dailyDetail`；2026-06-10 只读探测未发现跨日期归属、上一日打卡引用或跨天时间段字段，APP 不应自行猜测把凌晨打卡自动并入上一日。
- 旧每日考勤接口仍可访问，但字段比 V2 少，尤其缺少照片信息，不应继续作为提醒服务的数据源。
- 月度接口返回的是简表数组，不是当前代码里需要的完整每日工时明细。
- token 无效时，至少 `account/detail` 和每日 V2 会返回 HTTP 401，而不一定返回业务 JSON `code = 999999`。

## 鉴权与通用请求头

推荐统一由 `HikiotApiClient` 生成请求头，不要在页面或提醒服务中硬编码。

必要头：

```text
Authorization: Bearer <token>
token: <token>
www_token: <token>
appNo: __UNI__89A1A02
terminal: 1
versionCode: 1778
Accept: application/json, text/plain, */*
Content-Type: application/json
User-Agent: Mozilla/5.0 (Linux; Android 12; wv) AppleWebKit/537.36
Origin: https://www.hikiot.com
Referer: https://www.hikiot.com/
```

注意：

- 当前 `team/change` 的请求体里使用 `terminal = 2` 可以成功。
- 旧提醒服务里使用 `terminal = 2`、`authPerm`、`deviceid` 等硬编码头也能访问旧接口，但这属于兼容残留，应合并到统一客户端后逐步移除。

## 推荐调用流程

1. WebView 登录后提取 `www_token`，保存到 `StorageKeys.token`。
2. 调用 `GET /api-saas/v1/account/detail`。
3. 从 `data.teamInfoList` 中选择团队。优先匹配 `data.onLineTeamNo` 或本地保存的 `selected_team`。
4. 调用 `POST /api-link-saas/v3/team/change` 激活团队上下文。
5. 保存返回或选中团队里的 `teamNo/personNo`。所有本地考勤缓存、手动标记都必须按 `teamNo` 命名空间隔离。
6. 每日页、月度页、提醒服务统一使用每日 V2 接口解析当天数据。

## 接口清单

### 账户详情

```text
GET https://api.hikiot.com/api-saas/v1/account/detail
```

成功响应：

```text
HTTP 200
code: 0
data: object
```

`data` 主要字段：

```text
id
accountNo
nickName
phone
registerPhone
email
avatarUrl
accountStatus
terminal
lastLoginTime
onLineTeamNo
teamInfoList
```

`teamInfoList[]` 主要字段：

```text
teamNo
teamName
teamCode
personNo
owner
isPersonal
isUpgrade
scene
personState
isPro
viewType
isExpire
authStatus
```

修复注意：

- `teamNo` 和 `personNo` 都是稳定业务标识，但用途不同。
- 本地日历标记、月度缓存应使用 `teamNo` 隔离，不应使用 `personNo`。
- 账号可能有多个团队，启动链路不能假设 `teamInfoList[0]` 就是用户想看的团队。

### 切换团队

```text
POST https://api.hikiot.com/api-link-saas/v3/team/change
Content-Type: application/json

{
  "teamNo": "<teamNo>",
  "terminal": 2
}
```

成功响应：

```text
HTTP 200
code: 0
data: object
```

`data` 主要字段：

```text
teamNo
personNo
accountNo
teamAuthVO
viewType
isExpire
isOwner
```

修复注意：

- 登录后必须先切换团队上下文，否则每日考勤可能查到错误团队或空数据。
- 切团队是有状态接口。文档勘探只验证了切换到当前在线团队的幂等调用，避免改变用户真实上下文。
- 后续代码中应把“选中团队 + 切换成功 + 保存上下文”封装成一个原子流程。

### 每日考勤 V2

```text
GET https://api.hikiot.com/api-attendance/v1/statistics/v2/individual/single/daily?date=yyyy-MM-dd&ID=myStatic
```

成功响应：

```text
HTTP 200
code: 0
data: object
```

`data` 主要字段：

```text
avatarUrl
personNo
personName
departmentNo
jobNumber
orgName
attendanceName
dailyDetail
```

`dailyDetail` 主要字段：

```text
date
dailyStatus
shiftId
shiftName
shiftDetails
```

工作日有打卡时，`shiftDetails[0]` 常见字段：

```text
order
clockIn
inClocked
clockInTime
onStandardTime
onStandardTimeType
clockInTimeType
clockInStatusType
clockInStatusDesc
remoteClockInInfo
clockOff
offStandardTime
offStandardTimeType
clockOffTime
offClocked
clockOffTimeType
clockOffStatusType
clockOffStatusDesc
remoteClockOffInfo
```

`remoteClockInInfo` / `remoteClockOffInfo` 常见字段：

```text
wayOfClock
address
photo
```

边界样本：

- 休息日样本：`shiftId = -1`，`shiftName` 存在，`shiftDetails` 仍可能有 1 条，但没有 `clockInTime/clockOffTime/remoteClockInInfo/remoteClockOffInfo`。
- 当天只打上班卡样本：有 `clockInTime` 和 `remoteClockInInfo`，但没有 `clockOffTime` 和 `remoteClockOffInfo`。
- 已完整打卡样本：上下班时间和上下班照片信息都可能存在。

修复注意：

- Parser 必须对 `shiftDetails[0]` 字段缺失保持 null-safe。
- 不能把“存在 `shiftDetails`”等同于“有打卡”。
- 判断休息日可参考 `shiftId == -1` 或 `shiftName` 包含休息语义。
- V2 已经通过 token 和团队上下文识别用户，`personNo` 不需要放在 query 里。
- 当前代码已改为读取全部 `shiftDetails`，并会在发现 00:00 至跨天提醒截止时间之间的打卡时透传 `hasCrossDayPunch/crossDayPunchTime`，用于提醒用户手动调整工时。
- 因每日 V2 没有跨日期归属字段，APP 已关闭“跨天时间点前自动视为昨天”的逻辑；跨天场景只做提醒，不做自动日期归属。

### 旧每日考勤

```text
GET https://api.hikiot.com/api-attendance/v1/statistics/individual/single/daily?date=yyyy-MM-dd&personNo=<personNo>&ID=myStatic
```

成功响应结构与 V2 类似，但样本中没有 `remoteClockInInfo/remoteClockOffInfo` 照片字段。

修复注意：

- 旧接口需要 `personNo`，V2 不需要。
- 提醒服务当前仍硬编码旧接口，应迁移到 V2，避免前台和后台提醒数据口径不一致。
- 旧接口可作为临时兼容备用，但不应成为主要数据源。

### 月度考勤简表

```text
GET https://api.hikiot.com/api-attendance/v1/statistics/myAttendance?month=yyyy-MM&ID=myStatic
```

成功响应：

```text
HTTP 200
code: 0
data: array
```

`data[]` 样本字段：

```text
date
onDuty
shiftName
simpleStatus
```

修复注意：

- 该接口返回的是月度简表，不含完整上下班时间、工时、照片等前台统计所需字段。
- 当前代码的 `getMonthlyAttendance()` 没有使用这个接口，而是串行请求整月每日 V2 再聚合。逻辑能补字段，但性能差，且异常被吞。
- 推荐策略：月度简表用于快速判断日期范围和班次状态；完整工时明细按需或增量调用每日 V2。

### 请假记录

```text
GET https://api.hikiot.com/api-attendance/leaveRecord/getTodayRecords?date=yyyy-MM-dd
```

样本响应：

```text
HTTP 200
code: 0
data: []
```

修复注意：

- 当前样本为空数组，尚未确认非空时的字段结构。
- 后续需要用真实请假日补一份脱敏夹具，避免把“工作日无打卡”简单推断成请假。

## 错误与 token 失效

已验证：

```text
无效 token 请求 account/detail -> HTTP 401
无效 token 请求每日 V2 -> HTTP 401
```

代码要求：

- API 层必须区分 HTTP 状态码、业务 `code`、网络异常和 JSON 解析异常。
- 不要把所有失败都返回 `null/false`。
- `TokenExpiredService` 应同时识别 HTTP 401/403 和业务 `code = 999999`。

建议定义统一结果：

```dart
sealed class ApiResult<T> {
  const ApiResult();
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

class ApiFailure<T> extends ApiResult<T> {
  final int? httpStatus;
  final int? businessCode;
  final String message;
  final bool tokenExpired;
  const ApiFailure({
    this.httpStatus,
    this.businessCode,
    required this.message,
    this.tokenExpired = false,
  });
}
```

## 当前代码对接风险

1. 每日页和月度页的团队初始化存在竞态。每日页依赖 `teamNo/personNo`，但这些值由月度页初始化后写入。
2. 每日页部分保存/恢复路径把 `personNo` 当作 `teamNo` 使用，会把手动标记写入错误命名空间。
3. 后台提醒使用旧每日接口，前台使用 V2，字段和数据口径会分裂。
4. 每日 V2 的休息日和当天未完整打卡样本会缺字段，Parser 和 UI 都必须容忍。
5. 月度统计逐日串行请求每日 V2，整月刷新性能差，失败原因不可见。
6. 旧探索脚本里曾出现明文 token 写死的问题，后续脚本必须改用环境变量。

## 修复前建议落地的抽象

### TeamContext

```dart
class TeamContext {
  final String teamNo;
  final String personNo;
  final String? teamName;
  final bool isCurrentOnlineTeam;
}
```

用途：

- 统一管理当前团队上下文。
- 每日、月度、提醒服务都只读取同一个上下文来源。
- 所有本地缓存 key 都由 `teamNo` 派生。

### AttendanceDayDto

```dart
class AttendanceDayDto {
  final String date;
  final int? dailyStatus;
  final int? shiftId;
  final String? shiftName;
  final List<ShiftDetailDto> shifts;
}
```

用途：

- 保留 API 原始语义，不直接混入 UI 类型如“请假/加班日”。
- Parser 单独负责从 DTO 转领域对象。

### AttendanceDay

```dart
class AttendanceDay {
  final String date;
  final String? checkIn;
  final String? checkOut;
  final double hours;
  final bool hasCheckIn;
  final bool hasCheckOut;
  final bool isNativeRestDay;
  final bool isLate;
  final bool isEarlyLeave;
  final String? checkInPhotoUrl;
  final String? checkOutPhotoUrl;
}
```

用途：

- 每日页、月度页、提醒服务都消费同一个领域模型。
- 智能标记逻辑不要直接读 API Map。

## 建议补齐的测试夹具

所有夹具必须脱敏，禁止保存 token、姓名、手机号、团队名、团队编号、人员编号、照片真实 URL。

建议最少准备：

1. 工作日完整上下班打卡：有 `clockInTime/clockOffTime` 和双照片字段。
2. 当天只打上班卡：只有 `clockInTime`，没有 `clockOffTime`。
3. 休息日无打卡：`shiftId = -1`，缺少打卡时间字段。
4. 休息日有打卡：用于验证自动识别加班日。
5. 工作日无打卡但非请假：避免误判请假。
6. 请假接口非空样本：确认字段后再合并请假逻辑。
7. HTTP 401 样本：验证 token 失效流程。
8. 多团队账号样本：验证 `teamNo/personNo` 命名空间隔离。

## 后续待确认

- `dailyStatus` 枚举含义。
- `simpleStatus` 枚举含义。
- `clockInStatusType` / `clockOffStatusType` 完整枚举。
- 非空请假记录字段结构。
- 真实跨天打卡样本中 `shiftDetails` 的排列方式、凌晨打卡会归入哪一个自然日。
- `remoteClockInInfo.photo` 是否长期有效，以及是否需要鉴权下载。

## 本次未执行的操作

- 未调用 logout。
- 未切换到其他团队。
- 未保存 token。
- 未保存任何个人、团队或照片真实值。
