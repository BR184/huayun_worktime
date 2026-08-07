// THESIS: 把启动与主界面塑造成精密工时仪表，拒绝装饰性渐变和低密度大卡片。
// OWN-WORLD: 冷白画布、白色仪表面、深色文字、钴蓝操作与青柚/莓红语义状态，使用细边和克制双影。
// STORY: 用户先看到可信的工具身份，随后直接进入每日核对、月度复盘或设置任务。
// FIRST VIEWPORT: 品牌标记居中，状态信息紧随其下；不播放无意义的循环展示动画。
// FORM: Android Material 3 Operate 模式，以高密度仪表布局承载公司工时口径。

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/theme.dart';
import 'screens/disclaimer_dialog.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/storage_service.dart';
import 'utils/date_helper.dart';
import 'utils/haptic_utils.dart';
import 'utils/work_time_calculator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android WebView 调试只在非 release 构建启用。
  if (Platform.isAndroid && !kReleaseMode) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  await WorkTimeCalculator.initialize();
  await DateHelper.initialize();
  await HapticUtils.init();

  runZonedGuarded(
    () {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('Flutter错误: ${details.exception}');
        debugPrint('堆栈: ${details.stack}');
      };
      runApp(const MyApp());
    },
    (error, stack) {
      debugPrint('异步错误: $error');
      debugPrint('堆栈: $stack');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '华云工时查询工具',
      theme: AppTheme.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      locale: const Locale('zh', 'CN'),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    final curve = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = curve;
    _scaleAnimation = Tween<double>(begin: 0.97, end: 1).animate(curve);
    _entranceController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      DisclaimerDialog.showIfNeeded(context, _checkLoginStatus);
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final token = await StorageService().loadToken();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            token != null ? MainScreen(token: token) : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(scale: _scaleAnimation, child: const SplashView()),
    );
  }
}

/// 可独立渲染的启动视图，便于做尺寸和视觉回归检查。
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'HUAYUN · WORKTIME',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppStyles.shadowMd,
                      ),
                      child: Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSunken,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            size: 32,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '华云工时查询工具',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '清晰核对每一天',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text(
                          '正在确认登录状态',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'v2.3.1',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
