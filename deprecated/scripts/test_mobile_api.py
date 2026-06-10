"""
测试海康互联移动端API - 查找照片字段
"""
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import requests
import json

# 移动端Token (用户抓包提供)
TOKEN = "133af996-bc83-437b-b01d-55b09ff4d442"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Linux; Android 12; V2366GA Build/V417IR; wv) AppleWebKit/537.36",
    "Accept-Encoding": "gzip",
    "Authorization": f"Bearer {TOKEN}",
    "UNI-Request-Source": "1",
    "appNo": "__UNI__89A1A02",
    "terminal": "1",  # 移动端用 1
    "deviceid": "A31DF1F162B340FFE720C7C20FFFAF9442183850",
    "versionCode": "1778",
}


def test_api(name: str, url: str):
    """测试API并打印结果"""
    print(f"\n{'='*70}")
    print(f"[API] {name}")
    print(f"[URL] {url}")
    print(f"{'='*70}")

    try:
        response = requests.get(url, headers=HEADERS)
        data = response.json()
        print(json.dumps(data, ensure_ascii=False, indent=2))

        # 搜索照片相关字段
        def find_photo_fields(obj, path=""):
            results = []
            if isinstance(obj, dict):
                for k, v in obj.items():
                    new_path = f"{path}.{k}" if path else k
                    if any(word in k.lower() for word in ['photo', 'image', 'url', 'pic', 'img', 'file', 'key']):
                        results.append((new_path, v))
                    results.extend(find_photo_fields(v, new_path))
            elif isinstance(obj, list):
                for i, item in enumerate(obj):
                    results.extend(find_photo_fields(item, f"{path}[{i}]"))
            return results

        photo_fields = find_photo_fields(data)
        if photo_fields:
            print("\n[PHOTO/FILE RELATED FIELDS FOUND]:")
            for path, value in photo_fields:
                print(f"  * {path}: {value}")

    except Exception as e:
        print(f"[ERROR] {e}")


if __name__ == "__main__":
    # 测试 v2 版本的每日考勤API (最可能包含照片)
    test_api(
        "V2 Daily Attendance (Mobile)",
        "https://api.hikiot.com/api-attendance/v1/statistics/v2/individual/single/daily?date=2026-01-10&ID=myStatic"
    )

    # 测试请假记录
    test_api(
        "Today Leave Records",
        "https://api.hikiot.com/api-attendance/leaveRecord/getTodayRecords?date=2026-01-10"
    )

    # 测试月度统计
    test_api(
        "Monthly Attendance",
        "https://api.hikiot.com/api-attendance/v1/statistics/myAttendance?month=2026-01&ID=myStatic"
    )
