"""
测试API中的照片字段
"""
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import requests
import json
from datetime import datetime

BASE_URL = "https://api.hikiot.com/api-attendance/v1/statistics/individual/single/daily"
TOKEN = "cc2347c3-07c3-4988-8175-0361bbf718ae"
PERSON_NO = "CY038665590"

HEADERS = {
    "Accept": "application/json, text/plain, */*",
    "Authorization": f"Bearer {TOKEN}",
    "Origin": "https://www.hikiot.com",
    "Referer": "https://www.hikiot.com/",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "terminal": "2",
}

def fetch_and_find_photo_fields(date_str: str):
    """获取数据并查找所有包含photo/image/url的字段"""
    url = f"{BASE_URL}?date={date_str}&personNo={PERSON_NO}&ID=myStatic"
    response = requests.get(url, headers=HEADERS)
    data = response.json()

    print(f"\n{'='*60}")
    print(f"[DATE] {date_str}")
    print(f"{'='*60}")

    if data.get("code") != 0:
        print(f"[ERROR] code={data.get('code')}, msg={data.get('msg')}")
        return

    # 打印完整JSON以便分析
    print("\n[FULL JSON]:")
    print(json.dumps(data, ensure_ascii=False, indent=2))

    # 递归查找photo相关字段
    def find_photo_fields(obj, path=""):
        results = []
        if isinstance(obj, dict):
            for k, v in obj.items():
                new_path = f"{path}.{k}" if path else k
                if any(word in k.lower() for word in ['photo', 'image', 'url', 'pic', 'img']):
                    results.append((new_path, v))
                results.extend(find_photo_fields(v, new_path))
        elif isinstance(obj, list):
            for i, item in enumerate(obj):
                results.extend(find_photo_fields(item, f"{path}[{i}]"))
        return results

    photo_fields = find_photo_fields(data)

    print("\n[PHOTO RELATED FIELDS]:")
    if photo_fields:
        for path, value in photo_fields:
            print(f"  - {path}: {value}")
    else:
        print("  No photo fields found!")

if __name__ == "__main__":
    # 测试有打卡记录的日期
    fetch_and_find_photo_fields("2026-01-10")  # 今天
    fetch_and_find_photo_fields("2026-01-08")  # 前天工作日
