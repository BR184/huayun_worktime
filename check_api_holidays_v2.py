"""
分析海康互联API中的节假日/班次字段 - 修正版
"""
import requests
import json
from datetime import datetime, timedelta
import sys
import io

# 强制使用 UTF-8 输出
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

TOKEN = "133af996-bc83-437b-b01d-55b09ff4d442"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Linux; Android 12; V2366GA Build/V417IR; wv) AppleWebKit/537.36",
    "Accept-Encoding": "gzip",
    "Authorization": f"Bearer {TOKEN}",
    "UNI-Request-Source": "1",
    "appNo": "__UNI__89A1A02",
    "terminal": "1",
    "deviceid": "A31DF1F162B340FFE720C7C20FFFAF9442183850",
    "versionCode": "1778",
}

def check_date(date_str):
    url = f"https://api.hikiot.com/api-attendance/v1/statistics/v2/individual/single/daily?date={date_str}&ID=myStatic"
    try:
        response = requests.get(url, headers=HEADERS)
        data = response.json()
        if data['code'] == 0:
            result = data['data']
            daily_detail = result.get('dailyDetail', {})
            
            # 提取关键字段
            duty_status = daily_detail.get('dutyStatus', 'N/A')
            duty_status_desc = daily_detail.get('dutyStatusDesc', 'N/A')
            
            shift_details = daily_detail.get('shiftDetails', [])
            shift_name = "N/A"
            duty_type = "N/A"
            if shift_details:
                shift_name = shift_details[0].get('shiftName', 'N/A')
                duty_type = shift_details[0].get('dutyType', 'N/A')
            
            # 打印摘要
            print(f"{date_str} | dutyStatus: {duty_status} ({duty_status_desc}) | shiftName: {shift_name} | dutyType: {duty_type}")
            
            # 如果是元旦，打印完整 dailyDetail 结构以便深入分析
            if date_str == "2026-01-01":
                print("\n[2026-01-01 详细数据结构]:")
                print(json.dumps(daily_detail, ensure_ascii=False, indent=2))
                
        else:
            print(f"{date_str} | 错误: {data.get('msg')}")
    except Exception as e:
        print(f"{date_str} | 异常: {e}")

if __name__ == "__main__":
    print("日期       | 状态字段分析")
    print("-" * 80)
    
    # 测试 2026-01-01 (元旦，法定假日)
    # 测试 2026-01-04 (周日，休息日)
    # 测试 2026-01-05 (周一，工作日)
    # 测试 2026-01-10 (今日)
    dates = ["2026-01-01", "2026-01-02", "2026-01-03", "2026-01-04", "2026-01-05", "2026-01-10"]
    for d in dates:
        check_date(d)
