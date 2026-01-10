# 移动端开发指南

## 🎯 架构方案

### 方案选择：Flutter + WebView混合

**为什么选择Flutter？**
- ✅ 一套代码，同时支持Android和iOS
- ✅ 原生性能，流畅体验
- ✅ 热重载，开发效率高
- ✅ WebView插件成熟，方便嵌入Streamlit

---

## 🚀 快速开始

### 1. 安装Flutter SDK

```bash
# 下载Flutter
# https://flutter.dev/docs/get-started/install

# 验证安装
flutter doctor
```

### 2. 创建Flutter项目

```bash
# 在项目根目录创建mobile文件夹
cd auto_worktime
mkdir mobile
cd mobile

# 创建Flutter项目
flutter create hikiot_worktime

# 进入项目
cd hikiot_worktime
```

### 3. 添加依赖

编辑 `pubspec.yaml`：
```yaml
dependencies:
  flutter:
    sdk: flutter
  webview_flutter: ^4.4.2           # WebView组件
  flutter_inappwebview: ^6.0.0      # 增强的WebView
  shared_preferences: ^2.2.2        # 本地存储
  http: ^1.1.2                      # HTTP请求
  provider: ^6.1.1                  # 状态管理
```

安装依赖：
```bash
flutter pub get
```

---

## 📱 核心功能实现

### 1. WebView登录页面

```dart
// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  InAppWebViewController? webViewController;
  String? extractedToken;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('登录海康互联'),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: Uri.parse('https://www.hikiot.com'),
        ),
        onWebViewCreated: (controller) {
          webViewController = controller;
          
          // 监听URL变化
          controller.addJavaScriptHandler(
            handlerName: 'extractToken',
            callback: (args) {
              // 处理提取的Token
              setState(() {
                extractedToken = args[0];
              });
              _saveTokenAndNavigate();
            },
          );
        },
        onLoadStop: (controller, url) async {
          // 页面加载完成，尝试提取Token
          await _tryExtractToken(controller);
        },
      ),
    );
  }

  Future<void> _tryExtractToken(InAppWebViewController controller) async {
    // 注入JavaScript提取Cookie
    String js = '''
      (function() {
        var cookies = document.cookie.split(';');
        var token = null;
        for (var i = 0; i < cookies.length; i++) {
          var cookie = cookies[i].trim();
          if (cookie.startsWith('www_token=')) {
            token = cookie.substring('www_token='.length);
            break;
          }
        }
        return token;
      })();
    ''';
    
    var result = await controller.evaluateJavascript(source: js);
    
    if (result != null && result.toString().isNotEmpty) {
      setState(() {
        extractedToken = result.toString();
      });
      _saveTokenAndNavigate();
    }
  }

  void _saveTokenAndNavigate() async {
    if (extractedToken != null) {
      // 保存Token到本地
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('hikiot_token', extractedToken!);
      
      // 跳转到主页
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }
}
```

### 2. Streamlit内嵌页面

```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? token;
  String streamlitUrl = 'http://your-server.com'; // 改为实际服务器地址

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('hikiot_token');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('工时统计'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: token == null
          ? Center(child: CircularProgressIndicator())
          : InAppWebView(
              initialUrlRequest: URLRequest(
                url: Uri.parse('$streamlitUrl/?token=$token'),
              ),
            ),
    );
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('hikiot_token');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }
}
```

### 3. 主入口

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '海康工时统计',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('hikiot_token');
    
    // 延迟1秒显示启动画面
    await Future.delayed(Duration(seconds: 1));
    
    // 根据Token判断跳转
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => token != null ? HomeScreen() : LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              '工时统计系统',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
```

---

## 📦 打包发布

### Android

```bash
# 生成签名密钥
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# 配置签名（编辑 android/key.properties）
storePassword=your_password
keyPassword=your_password
keyAlias=upload
storeFile=/path/to/upload-keystore.jks

# 打包APK
flutter build apk --release

# 打包AAB（Google Play）
flutter build appbundle --release
```

### iOS

```bash
# 需要Mac电脑和Apple Developer账号

# 打开Xcode
open ios/Runner.xcworkspace

# 配置签名和证书

# 打包
flutter build ios --release
```

---

## 🔄 部署方案

### 方案1：本地Streamlit + 远程连接

```dart
// 应用内运行Streamlit服务（需要Chaquopy插件）
// 适合完全离线使用
```

### 方案2：远程Streamlit服务器

```dart
// 推荐：部署Streamlit到云服务器
// APP通过WebView连接服务器
String streamlitUrl = 'https://your-app.streamlit.app';
```

### 方案3：混合模式

- 在线时连接服务器
- 离线时使用本地缓存数据

---

## 🎨 UI优化

### 1. 适配移动端样式

在Streamlit中添加移动端检测：
```python
# app/main.py
st.set_page_config(
    page_title="工时统计",
    page_icon="📊",
    layout="wide",  # 桌面用wide，移动端用centered
    initial_sidebar_state="auto"
)

# 检测移动端
is_mobile = st.session_state.get('is_mobile', False)
```

### 2. 响应式布局

```python
# 根据屏幕宽度调整列数
if is_mobile:
    cols = st.columns(2)
else:
    cols = st.columns(4)
```

---

## 🐛 常见问题

### Q: WebView无法加载？
A: 检查网络权限和CORS配置

### Q: Token提取失败？
A: 确认Cookie名称是否为`www_token`

### Q: iOS审核被拒？
A: 提供隐私政策和数据使用说明

---

## 📈 下一步

1. 完成Flutter项目初始化
2. 实现WebView登录功能
3. 集成Streamlit页面
4. 测试Token提取
5. 打包发布

---

**移动端开发即将完成！** 🚀
