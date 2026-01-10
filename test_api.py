"""
海康互联考勤API测试脚本
测试工作日和节假日的API返回格式差异
"""
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import requests
import json
from datetime import datetime, timedelta

# 配置信息（从curl命令中提取）
BASE_URL = "https://api.hikiot.com/api-attendance/v1/statistics/individual/single/daily"
TOKEN = "cc2347c3-07c3-4988-8175-0361bbf718ae"
PERSON_NO = "CY038665590"

HEADERS = {
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8,ja;q=0.7",
    "Authorization": f"Bearer {TOKEN}",
    "Connection": "keep-alive",
    "Origin": "https://www.hikiot.com",
    "Referer": "https://www.hikiot.com/",
    "STN-PhoneType": "Windows 10",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36",
    "appNo": "__UNI__89A1A02",
    "authPerm": "undefined",
    "deviceid": "uPm7WE1zM0J4q1or",
    "devicename": "Chrome 143.0",
    "terminal": "2",
}


def fetch_daily_attendance(date_str: str) -> dict:
    """获取指定日期的考勤数据"""
    url = f"{BASE_URL}?date={date_str}&personNo={PERSON_NO}&ID=myStatic"
    response = requests.get(url, headers=HEADERS)
    return response.json()


def analyze_response(data: dict, date_str: str, expected_type: str):
    """分析API响应结构"""
    print(f"\n{'='*60}")
    print(f"[DATE] {date_str} ({expected_type})")
    print(f"{'='*60}")
    
    if data.get("code") != 0:
        print(f"[ERROR] API Error: code={data.get('code')}, msg={data.get('msg')}")
        return
    
    daily_data = data.get("data", {})
    daily_detail = daily_data.get("dailyDetail", {})
    
    print(f"\n[RESPONSE] Full response (data field):")
    print(json.dumps(daily_data, ensure_ascii=False, indent=2))
    
    print(f"\n[ANALYSIS] Key fields:")
    
    # 检查 shiftDetails（工作日）
    shift_details = daily_detail.get("shiftDetails")
    print(f"  - shiftDetails: {shift_details}")
    if shift_details and len(shift_details) > 0:
        first_shift = shift_details[0]
        print(f"    * clockInTime: {first_shift.get('clockInTime')}")
        print(f"    * clockOffTime: {first_shift.get('clockOffTime')}")
        print(f"    * clockInStatusType: {first_shift.get('clockInStatusType')}")
        print(f"    * clockOffStatusType: {first_shift.get('clockOffStatusType')}")
    
    # 检查 restClockTime（节假日/加班日）
    rest_clock_time = daily_detail.get("restClockTime")
    print(f"  - restClockTime: {rest_clock_time}")
    if rest_clock_time and len(rest_clock_time) > 0:
        print(f"    * First: {rest_clock_time[0]}")
        if len(rest_clock_time) > 1:
            print(f"    * Last: {rest_clock_time[-1]}")
    
    # 检查其他可能的字段
    print(f"\n[KEYS] dailyDetail all keys:")
    for key in daily_detail.keys():
        value = daily_detail[key]
        if isinstance(value, (list, dict)):
            print(f"  - {key}: {type(value).__name__}, len={len(value) if value else 0}")
        else:
            print(f"  - {key}: {value}")


def main():
    print("=" * 60)
    print("[TEST] Hikiot Attendance API Test")
    print(f"[TIME] {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    # 测试日期列表
    test_dates = [
        ("2026-01-10", "Today-Holiday(1 punch)"),
        ("2026-01-09", "Yesterday-Leave"),
        ("2026-01-08", "DayBefore-Normal"),
    ]
    
    for date_str, expected_type in test_dates:
        try:
            data = fetch_daily_attendance(date_str)
            analyze_response(data, date_str, expected_type)
        except Exception as e:
            print(f"\n[ERROR] Failed to get {date_str}: {e}")
    
    print(f"\n{'='*60}")
    print("[DONE] Test completed")
    print("=" * 60)


if __name__ == "__main__":
    main()
