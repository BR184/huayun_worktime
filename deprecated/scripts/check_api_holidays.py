"""
分析海康互联API中的节假日/班次字段
"""
import requests
import json
from datetime import datetime, timedelta

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

def analyze_holiday_fields(data, date_str):
    print(f"\n[日期] {date_str}")
    
    # 查找可能与节假日/班次相关的字段
    relevant_keywords = ['duty', 'shift', 'rest', 'holiday', 'work', 'status', 'type', 'name']
    
    def find_fields(obj, path=""):
        if isinstance(obj, dict):
            for k, v in obj.items():
                new_path = f"{path}.{k}" if path else k
                if any(word in k.lower() for word in relevant_keywords):
                    print(f"  - {new_path}: {v}")
                find_fields(v, new_path)
        elif isinstance(obj, list):
            for i, item in enumerate(obj):
                find_fields(item, f"{path}[{i}]")

    find_fields(data)

def test_range(start_date_str, end_date_str):
    start_date = datetime.strptime(start_date_str, "%Y-%m-%d")
    end_date = datetime.strptime(end_date_str, "%Y-%m-%d")
    
    current_date = start_date
    while current_date <= end_date:
        date_str = current_date.strftime("%Y-%m-%d")
        url = f"https://api.hikiot.com/api-attendance/v1/statistics/v2/individual/single/daily?date={date_str}&ID=myStatic"
        
        try:
            response = requests.get(url, headers=HEADERS)
            data = response.json()
            if data['code'] == 0:
                analyze_holiday_fields(data['data'], date_str)
            else:
                print(f"[ERROR] {date_str} API返回错误: {data['msg']}")
        except Exception as e:
            print(f"[ERROR] {date_str} 请求失败: {e}")
            
        current_date += timedelta(days=1)

if __name__ == "__main__":
    # 测试 2026-01-01 (元旦) 到 2026-01-10 (今天)
    print("开始分析 2026-01-01 至 2026-01-10 的 API 字段...")
    test_range("2026-01-01", "2026-01-10")
