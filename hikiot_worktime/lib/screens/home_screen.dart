import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? token;
  double progress = 0;
  bool isLoading = true;

  // Streamlit服务器地址 - 根据实际情况修改
  // 如果在本地测试，使用 http://10.0.2.2:8501 (Android模拟器)
  // 如果部署到服务器，使用实际的服务器地址
  String streamlitUrl = 'http://localhost:8501';

  InAppWebViewController? webViewController;

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
        title: const Text('海康工时统计'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              webViewController?.reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettingsDialog();
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: token == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('加载中...'),
                ],
              ),
            )
          : Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri('$streamlitUrl?token=$token'),
                  ),
                  initialSettings: InAppWebViewSettings(
                    // 基础设置
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,

                    // 触摸和交互
                    supportZoom: true,
                    builtInZoomControls: true,
                    displayZoomControls: false,

                    // 媒体播放
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,

                    // 导航设置
                    useShouldOverrideUrlLoading: false,

                    // 缓存和存储
                    cacheEnabled: true,
                    thirdPartyCookiesEnabled: true,

                    // 优化
                    useHybridComposition: true,
                  ),
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      isLoading = true;
                    });
                  },
                  onLoadStop: (controller, url) {
                    setState(() {
                      isLoading = false;
                    });
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      this.progress = progress / 100;
                    });
                  },
                  onReceivedError: (controller, request, error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('加载错误: ${error.description}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    print('Console: ${consoleMessage.message}');
                  },
                ),
                if (isLoading)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          '加载中... ${(progress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  void _showSettingsDialog() {
    final TextEditingController urlController = TextEditingController(
      text: streamlitUrl,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Streamlit服务器地址',
                hintText: 'http://your-server.com:8501',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '提示：\n- 本地测试用: http://10.0.2.2:8501\n- 实际服务器: 填写真实地址',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                streamlitUrl = urlController.text.trim();
              });

              // 保存设置
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setString('streamlit_url', streamlitUrl);

              Navigator.pop(context);

              // 重新加载页面
              webViewController?.loadUrl(
                urlRequest: URLRequest(
                  url: WebUri('$streamlitUrl?token=$token'),
                ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    // 显示确认对话框
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('hikiot_token');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }
}
