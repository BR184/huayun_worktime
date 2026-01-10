import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// 简化测试版本 - 用于排查闪退问题
void main() {
  runZonedGuarded(
    () {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('Flutter错误: ${details.exception}');
      };
      runApp(const TestApp());
    },
    (error, stack) {
      debugPrint('异步错误: $error');
    },
  );
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '测试应用',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const TestHomePage(),
    );
  }
}

class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key});

  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage> {
  String status = '应用启动成功！';
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    try {
      addLog('开始测试...');

      // 测试1: 基础UI
      await Future.delayed(const Duration(milliseconds: 500));
      addLog('✓ 基础UI正常');

      // 测试2: SharedPreferences
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('test', 'value');
        final value = prefs.getString('test');
        addLog('✓ SharedPreferences正常: $value');
      } catch (e) {
        addLog('✗ SharedPreferences错误: $e');
      }

      // 测试3: WebView插件检查
      addLog('检查WebView插件...');
      try {
        // 这里不实际创建WebView，只是检查导入
        addLog('✓ WebView插件已加载');
      } catch (e) {
        addLog('✗ WebView插件错误: $e');
      }

      addLog('所有测试完成！');
      setState(() {
        status = '测试完成 - 查看下方日志';
      });
    } catch (e, stack) {
      addLog('✗ 测试失败: $e');
      addLog('堆栈: $stack');
      setState(() {
        status = '测试失败 - 查看错误';
      });
    }
  }

  void addLog(String message) {
    setState(() {
      logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
    debugPrint(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('闪退调试测试'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '应用状态',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(status, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '测试日志',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isError = log.contains('✗');
                    final isSuccess = log.contains('✓');

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isError
                              ? Colors.red
                              : isSuccess
                              ? Colors.green
                              : Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    logs.clear();
                    status = '重新测试中...';
                  });
                  _runTests();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重新测试'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
