import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/theme.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  /// 是否强制登出（清除 cookies 后再加载登录页）
  final bool forceLogout;

  const LoginScreen({super.key, this.forceLogout = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  InAppWebViewController? webViewController;
  String? extractedToken;
  double progress = 0;
  bool isLoading = true;
  bool _cookiesCleared = false;

  @override
  void initState() {
    super.initState();
    if (widget.forceLogout) {
      _clearCookiesFirst();
    } else {
      _cookiesCleared = true;
    }
  }

  Future<void> _clearCookiesFirst() async {
    final cookieManager = CookieManager.instance();
    await cookieManager.deleteAllCookies();
    await cookieManager.deleteCookies(url: WebUri('https://www.hikiot.com'));
    await cookieManager.deleteCookies(url: WebUri('https://hikiot.com'));
    await cookieManager.deleteCookies(url: WebUri('https://api.hikiot.com'));
    if (mounted) {
      setState(() {
        _cookiesCleared = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果需要强制登出但 cookies 还没清除完，先显示加载
    if (widget.forceLogout && !_cookiesCleared) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('正在退出...'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录海康互联'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: '返回登录页',
            onPressed: () {
              webViewController?.loadUrl(
                urlRequest: URLRequest(
                  url: WebUri('https://www.hikiot.com/portal/login'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              webViewController?.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('https://www.hikiot.com/portal/login'),
            ),
            initialSettings: InAppWebViewSettings(
              // 基础设置
              javaScriptEnabled: true,
              javaScriptCanOpenWindowsAutomatically: true,

              // 视口和缩放设置（关键修复）
              supportZoom: true,
              builtInZoomControls: false,
              displayZoomControls: false,
              useWideViewPort: true, // 使用宽视口
              loadWithOverviewMode: true, // 加载时自适应屏幕
              initialScale: 80, // 初始缩放80%，确保内容能完全显示
              // 媒体播放
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,

              // 导航设置
              useShouldOverrideUrlLoading: false,

              // 缓存和存储
              cacheEnabled: true,
              clearCache: false,
              thirdPartyCookiesEnabled: true,

              // 用户代理（模拟真实移动浏览器）
              userAgent:
                  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',

              // 其他优化
              useHybridComposition: true,
              disableVerticalScroll: false,
              disableHorizontalScroll: false,

              // 文本缩放
              minimumFontSize: 1,

              // 自动适配
              layoutAlgorithm: LayoutAlgorithm.NORMAL,
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;

              // 添加控制台日志监听，方便调试
              debugPrint('WebView已创建');
            },
            onLoadStart: (controller, url) {
              setState(() {
                isLoading = true;
              });
              debugPrint('开始加载: ${url?.toString()}');
            },
            onLoadStop: (controller, url) async {
              setState(() {
                isLoading = false;
              });
              debugPrint('加载完成: ${url?.toString()}');

              // 注入CSS和JavaScript来优化移动端显示
              await controller.evaluateJavascript(
                source: '''
                (function() {
                  // 确保viewport meta标签正确，设置初始缩放
                  var viewport = document.querySelector('meta[name=viewport]');
                  if (viewport) {
                    viewport.setAttribute('content', 'width=device-width, initial-scale=0.8, maximum-scale=5.0, user-scalable=yes');
                  } else {
                    var meta = document.createElement('meta');
                    meta.name = 'viewport';
                    meta.content = 'width=device-width, initial-scale=0.8, maximum-scale=5.0, user-scalable=yes';
                    document.getElementsByTagName('head')[0].appendChild(meta);
                  }
                  
                  // 添加CSS修复样式，确保内容不超出屏幕
                  var style = document.createElement('style');
                  style.textContent = `
                    * { 
                      box-sizing: border-box !important; 
                    }
                    html, body { 
                      margin: 0 !important; 
                      padding: 0 !important; 
                      overflow-x: hidden !important;
                      width: 100% !important;
                      max-width: 100vw !important;
                    }
                    body > * {
                      max-width: 100% !important;
                    }
                    .container, [class*="container"] { 
                      max-width: 100% !important;
                      padding-left: 10px !important;
                      padding-right: 10px !important;
                    }
                  `;
                  document.head.appendChild(style);
                  
                  // 延迟100ms后重新调整
                  setTimeout(function() {
                    window.scrollTo(0, 0);
                    // 尝试让页面重新布局
                    document.body.style.width = '100%';
                  }, 100);
                })();
              ''',
              );

              // 检查是否是登录后的页面
              if (url != null && !url.toString().contains('/login')) {
                // 可能已经登录，尝试提取Token
                await _tryExtractToken(controller);
              }
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                this.progress = progress / 100;
              });
            },
            onConsoleMessage: (controller, consoleMessage) {
              // 输出网页控制台日志，帮助调试
              debugPrint('控制台: ${consoleMessage.message}');
            },
            onReceivedError: (controller, request, error) {
              debugPrint('加载错误: ${error.description}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('加载错误: ${error.description}'),
                  backgroundColor: AppColors.error,
                ),
              );
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

  Future<void> _tryExtractToken(InAppWebViewController controller) async {
    try {
      // 注入JavaScript提取Cookie中的Token
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

      if (result != null &&
          result.toString().isNotEmpty &&
          result.toString() != 'null') {
        setState(() {
          extractedToken = result.toString();
        });
        await _saveTokenAndNavigate();
      }
    } catch (e) {
      print('提取Token失败: $e');
    }
  }

  Future<void> _saveTokenAndNavigate() async {
    if (extractedToken != null && mounted) {
      // 保存Token到本地
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('hikiot_token', extractedToken!);

      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('登录成功！'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );

        // 延迟一下再跳转，让用户看到提示
        await Future.delayed(const Duration(seconds: 1));

        // 跳转到统计页面
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(token: extractedToken!),
            ),
          );
        }
      }
    }
  }
}
