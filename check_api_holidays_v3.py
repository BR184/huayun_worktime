"""
分析海康互联API中的节假日/班次字段 - 完整数据对比版
"""
import requests
import json
from datetime import datetime
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

def analyze_date(date_str):
    url = f"https://api.hikiot.com/api-attendance/v1/statistics/v2/individual/single/daily?date={date_str}&ID=myStatic"
    try:
        response = requests.get(url, headers=HEADERS)
        data = response.json()
        if data['code'] == 0:
            print(f"\n{'='*20} {date_str} {'='*20}")
            # 打印整个 data['data'] 结构
            print(json.dumps(data['data'], ensure_ascii=False, indent=2))
        else:
            print(f"{date_str} | 错误: {data.get('msg')}")
    except Exception as e:
        print(f"{date_str} | 异常: {e}")

if __name__ == "__main__":
    # 对比 元旦(休息) 和 周一(工作日)
    analyze_date("2026-01-01") # 节假日/休息
    analyze_date("2026-01-05") # 工作日
