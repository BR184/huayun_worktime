""" 
测试萤石云图片URL获取流程 
"""
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import requests
import json

# 这是你之前抓包里出现的URL，我们会用它来测试
# 如果失效了，可能需要重新抓包或者重新运行 test_mobile_api.py 获取新的
TEST_URL = "https://open.ys7.com/api/lapp/mq/downloadurl?appKey=3068808d4fcd42239e77afd4a874171d&fileKey=ISAPI_FILES/GB2229332_2_604938/20260110074947980-GB2229332-5$encrypt=2,2026-01-10T07:52:49,2d18c27ef8172fe532acf98254f69a8c"

HEADERS = {
    # 模拟抓包中的请求头
    'User-Agent': 'Mozilla/5.0 (Linux; Android 12; V2366GA Build/V417IR; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/101.0.4951.61 Safari/537.36 uni-app Html5Plus/1.0 (Immersed/0.6666667)',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    'X-Requested-With': 'com.hikvision.sentinels',
    'Sec-Fetch-Site': 'cross-site',
    'Sec-Fetch-Mode': 'no-cors',
    'Sec-Fetch-Dest': 'image',
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7'
}

def test_ys7_api():
    print(f"Testing URL: {TEST_URL}")
    try:
        # 1. 尝试不带 Header 直接请求 (模拟 Dart http.get)
        print("\n--- Attempt 1: No Headers ---")
        resp1 = requests.get(TEST_URL)
        print(f"Status: {resp1.status_code}")
        if resp1.status_code == 200:
            print(f"Content-Type: {resp1.headers.get('Content-Type')}")
            print(f"Content Length: {len(resp1.content)} bytes")
            print(f"Body start: {resp1.content[:20]}")
        else:
            print(f"Body: {resp1.text[:200]}")
            
    except Exception as e:
        print(f"Attempt 1 Error: {e}")

    try:
        # 2. 尝试带 Header 请求
        print("\n--- Attempt 2: With Headers ---")
        resp2 = requests.get(TEST_URL, headers=HEADERS)
        print(f"Status: {resp2.status_code}")
        print(f"Body: {resp2.text[:500]}")
        
        if resp2.status_code == 200:
            try:
                data = resp2.json()
                print("\nJSON Parsed:")
                print(json.dumps(data, indent=2, ensure_ascii=False))
            except:
                print("\nResponse is NOT JSON")
    except Exception as e:
        print(f"Attempt 2 Error: {e}")

if __name__ == "__main__":
    test_ys7_api()
