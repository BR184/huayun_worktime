"""
海康互联 (HikIOT) 全量 API 统一探测与输出工具
基于移动端 V2 API 规范
"""
import requests
import json
import sys
import io
from datetime import datetime

# 解决控制台输出中文乱码问题
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# ================= 配置区 =================
# 请在此填入有效的 Token 和相关信息进行测试
TOKEN = "cc2347c3-07c3-4988-8175-0361bbf718ae"
PERSON_NO = "CY038665590"
TEAM_NO = ""  # 切换团队时使用，可选
DATE = datetime.now().strftime("%Y-%m-%d")
MONTH = datetime.now().strftime("%Y-%m")

# 安全开关：设置为 True 才会运行会导致 Token 变动或失效的 API (如登出、切换团队)
RUN_DANGEROUS_APIS = False 

# ================= 常量定义 =================
BASE_URL = "https://api.hikiot.com"

ENDPOINTS = {
    "账户详情": f"{BASE_URL}/api-saas/v1/account/detail",
    "切换团队": f"{BASE_URL}/api-link-saas/v3/team/change",
    "每日考勤(V2)": f"{BASE_URL}/api-attendance/v1/statistics/v2/individual/single/daily",
    "退出登录": f"{BASE_URL}/api-website/v1/logout",
    "月度考勤(备用)": f"{BASE_URL}/api-attendance/v1/statistics/myAttendance",
    "请假记录(备用)": f"{BASE_URL}/api-attendance/leaveRecord/getTodayRecords",
}

# 移动端标准请求头
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Linux; Android 12; wv) AppleWebKit/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "zh-CN,zh;q=0.9",
    "Content-Type": "application/json",
    "Authorization": f"Bearer {TOKEN}",
    "token": TOKEN,
    "www_token": TOKEN,
    "appNo": "__UNI__89A1A02",
    "terminal": "1",        # 1: 移动端 (关键)
    "versionCode": "1778",
    "Origin": "https://www.hikiot.com",
    "Referer": "https://www.hikiot.com/",
}

def print_section(title):
    print(f"\n{'='*25} {title} {'='*25}")

def call_api(name, method, url, params=None, json_data=None):
    print(f"正在调测: {name}")
    print(f"URL: {url}")
    try:
        if method == "GET":
            resp = requests.get(url, headers=HEADERS, params=params, timeout=10)
        else:
            resp = requests.post(url, headers=HEADERS, json=json_data, timeout=10)
        
        print(f"状态码: {resp.status_code}")
        try:
            data = resp.json()
            # 格式化输出
            print(json.dumps(data, ensure_ascii=False, indent=2))
            return data
        except:
            print(f"响应内容 (非JSON): {resp.text[:200]}")
    except Exception as e:
        print(f"请求失败: {e}")
    return None

def main():
    print_section("海康互联 API 探测工具")
    print(f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Token: {TOKEN[:8]}...{TOKEN[-8:] if len(TOKEN)>16 else ''}")
    
    # 1. 账户详情
    account_data = call_api("账户详情", "GET", ENDPOINTS["账户详情"])
    
    # 2. 每日考勤 (V2)
    # V2 移动端 API 关键参数：date, ID=myStatic
    params_daily = {"date": DATE, "ID": "myStatic"}
    call_api("每日考勤(V2)", "GET", ENDPOINTS["每日考勤(V2)"], params=params_daily)
    
    # 3. 月度考勤 (备用)
    params_monthly = {"month": MONTH, "ID": "myStatic"}
    call_api("月度考勤(备用)", "GET", ENDPOINTS["月度考勤(备用)"], params=params_monthly)
    
    # 4. 请假记录 (备用)
    params_leave = {"date": DATE}
    call_api("请假记录(备用)", "GET", ENDPOINTS["请假记录(备用)"], params=params_leave)

    # 5. 萤石云照片下载示例
    print_section("萤石云照片下载示例")
    print("说明: 照片下载通常直接 GET URL，无需 complex headers。")
    print("示例逻辑:")
    print("""
    resp = requests.get(photo_url)
    if resp.status_code == 200:
        with open('photo.jpg', 'wb') as f:
            f.write(resp.content)
    """)

    # 6. 危险区域 (默认跳过)
    if RUN_DANGEROUS_APIS:
        if TEAM_NO:
            print_section("切换团队测试")
            call_api("切换团队", "POST", ENDPOINTS["切换团队"], json_data={"teamNo": TEAM_NO, "terminal": 2})
        
        print_section("退出登录测试")
        call_api("退出登录", "POST", ENDPOINTS["退出登录"])
    else:
        print_section("安全提示")
        print("已跳过『切换团队』和『退出登录』以保护当前 Session。")
        print("如需测试，请将脚本上方的 RUN_DANGEROUS_APIS 设置为 True。")

    print_section("调试完毕")

if __name__ == "__main__":
    main()
