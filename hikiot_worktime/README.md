# 海康工时统计移动端应用# hikiot_worktime



这是基于Flutter开发的海康互联工时统计系统移动端应用。A new Flutter project.



## 📱 功能特点## Getting Started



- ✅ 自动登录海康互联（WebView）This project is a starting point for a Flutter application.

- ✅ 提取并保存登录Token

- ✅ 嵌入Streamlit工时统计页面A few resources to get you started if this is your first Flutter project:

- ✅ 支持退出登录

- ✅ 可配置服务器地址- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)

- ✅ 启动画面- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)



## 🚀 使用说明For help getting started with Flutter development, view the

[online documentation](https://docs.flutter.dev/), which offers tutorials,

### 首次使用samples, guidance on mobile development, and a full API reference.


1. 安装APK到Android设备
2. 打开应用，会自动跳转到海康互联登录页面
3. 输入账号密码登录
4. 登录成功后，Token会自动保存，下次启动无需重新登录
5. 主页面会加载Streamlit工时统计系统

### 配置Streamlit服务器地址

1. 在主页面点击右上角"设置"图标
2. 输入Streamlit服务器地址：
   - 本地测试：`http://10.0.2.2:8501` （Android模拟器）
   - 真实服务器：`http://your-server.com:8501`
3. 点击"保存"，页面会自动重新加载

### 退出登录

点击主页面右上角的"退出"图标，确认后会清除Token并返回登录页面。

## 🛠️ 开发说明

### 项目结构

```
lib/
├── main.dart              # 主入口和启动画面
└── screens/
    ├── login_screen.dart  # 登录页面（WebView）
    └── home_screen.dart   # 主页面（Streamlit）
```

### 依赖包

- `flutter_inappwebview`: WebView组件
- `shared_preferences`: 本地存储
- `http`: HTTP请求
- `provider`: 状态管理
- `url_launcher`: URL启动器

## 📦 打包说明

### 准备工作

1. 确保Flutter环境正常：
```bash
flutter doctor
```

2. 如果提示Android工具链问题，在Android Studio中：
   - 打开 SDK Manager
   - 安装 "Android SDK Command-line Tools (latest)"
   - 运行 `flutter doctor --android-licenses` 接受许可

### 打包APK

```bash
# 进入项目目录
cd d:\tool\auto_worktime\mobile\hikiot_worktime

# 打包debug版本（测试用）
C:\Flutter\flutter\bin\flutter.bat build apk --debug

# 打包release版本（正式发布）
C:\Flutter\flutter\bin\flutter.bat build apk --release

# 生成的APK路径：
# build/app/outputs/flutter-apk/app-release.apk
```

### 配置签名（可选，用于正式发布）

1. 生成密钥：
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. 创建 `android/key.properties`：
```properties
storePassword=your_password
keyPassword=your_password
keyAlias=upload
storeFile=D:/path/to/upload-keystore.jks
```

3. 更新 `android/app/build.gradle.kts` 配置签名

## 🔧 常见问题

### Q: 无法加载Streamlit页面？
A: 
1. 检查网络连接
2. 确认Streamlit服务器地址正确
3. 确保服务器允许跨域访问
4. 检查Android的网络权限（已在AndroidManifest.xml中配置）

### Q: Token提取失败？
A: 
1. 确认海康互联的Cookie名称是否为 `www_token`
2. 检查WebView的JavaScript是否启用
3. 查看控制台日志

### Q: 应用闪退？
A: 
1. 检查Android版本（需要API 21+，即Android 5.0+）
2. 查看错误日志：`flutter logs`

## 📝 后续优化建议

- [ ] 添加指纹/面容识别
- [ ] 支持离线模式
- [ ] 添加推送通知
- [ ] 优化WebView性能
- [ ] 添加深色模式
- [ ] 支持多语言

## 📄 许可证

内部使用项目
