import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/theme.dart';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import '../utils/login_token_extractor.dart';
import '../utils/login_webview_policy.dart';
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
  double progress = 0;
  bool isLoading = true;
  bool _cookiesCleared = false;
  bool _isSavingToken = false;

  @override
  void initState() {
    super.initState();
    if (widget.forceLogout) {
      _clearCookiesFirst();
    } else {
      _cookiesCleared = true;
    }
  }

  /// 强制登出时先清理 Cookie；失败也不能阻塞进入登录页。
  Future<void> _clearCookiesFirst() async {
    var cleanupFailed = false;
    try {
      await SessionService.clearHikiotCookies();
    } catch (e) {
      // Cookie 清理失败不阻塞进入登录页，给出明确但不阻塞的提示
      cleanupFailed = true;
      debugPrint('强制登出清理 Cookie 失败: $e');
    }
    if (mounted) {
      setState(() {
        _cookiesCleared = true;
      });
      if (cleanupFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('清理登录状态失败，若登录异常请手动清除浏览器数据'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
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

              // 导航设置：拦截外链跳转，Hikiot 域名内正常加载
              useShouldOverrideUrlLoading: true,

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
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url;
              // Hikiot 域名内（登录、验证、跳转）留在 WebView 加载
              if (url != null && LoginWebviewPolicy.shouldLoadInWebView(url)) {
                return NavigationActionPolicy.ALLOW;
              }
              // 外链（忘记密码/帮助/第三方登录等）交给系统浏览器，避免带离登录流程
              await _handleExternalUrl(url);
              return NavigationActionPolicy.CANCEL;
            },
            onCreateWindow: (controller, createWindowAction) async {
              // 接管 target=_blank / window.open 弹窗：
              // 内部 URL 用当前 WebView 加载，外链走系统浏览器
              final url = createWindowAction.request.url;
              if (url != null && LoginWebviewPolicy.shouldLoadInWebView(url)) {
                await controller.loadUrl(urlRequest: URLRequest(url: url));
                return true;
              }
              await _handleExternalUrl(url);
              return true;
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

              // 注入CSS和JavaScript来优化移动端显示（脚本见 LoginWebviewPolicy）
              await controller.evaluateJavascript(
                source: LoginWebviewPolicy.buildViewportFixScript(),
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

  /// 处理外链：用系统浏览器打开并给出明确提示。
  ///
  /// url 为 null 或打不开时仅记录日志，不抛异常阻断页面。
  Future<void> _handleExternalUrl(Uri? url) async {
    if (url == null) return;
    debugPrint('登录页外链转系统浏览器: $url');
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('外链打开失败: $url');
      }
    } catch (e) {
      debugPrint('外链打开异常: $e');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已跳转到外部浏览器打开，请返回后继续登录'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _tryExtractToken(InAppWebViewController controller) async {
    try {
      // 注入JavaScript返回完整Cookie字符串，在Dart侧解析，
      // 使提取/规范化逻辑可单测（见 LoginTokenExtractor / LoginWebviewPolicy）
      final rawCookie = await controller.evaluateJavascript(
        source: LoginWebviewPolicy.buildCookieReadScript(),
      );
      final token = LoginTokenExtractor.normalizeExtractedToken(
        LoginTokenExtractor.extractWwwTokenFromCookieString(
          rawCookie?.toString() ?? '',
        ),
      );

      if (token != null) {
        await _saveTokenAndNavigate(token);
      }
    } catch (e) {
      // 提取失败保持可恢复：页面仍可通过刷新/重登重试
      debugPrint('提取登录 token 失败: $e');
    }
  }

  Future<void> _saveTokenAndNavigate(String token) async {
    // 防止重复回调导致重复保存/重复导航
    if (_isSavingToken || !mounted) return;
    if (token.isEmpty) return;
    _isSavingToken = true;

    try {
      // 保存Token到本地
      // 不做 account/detail 预验证：会引入阻塞请求并改变现有启动流程；
      // 无效 token 会由主流程的 TokenExpiredService 失效处理兜底。
      await StorageService().saveToken(token);

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
            MaterialPageRoute(builder: (context) => MainScreen(token: token)),
          );
        }
      }
    } finally {
      _isSavingToken = false;
    }
  }
}
