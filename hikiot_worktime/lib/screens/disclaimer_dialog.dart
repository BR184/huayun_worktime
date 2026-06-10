import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class DisclaimerDialog extends StatelessWidget {
  final VoidCallback onConfirmed;
  const DisclaimerDialog({super.key, required this.onConfirmed});

  static Future<void> showIfNeeded(
    BuildContext context,
    VoidCallback onConfirmed,
  ) async {
    final storage = StorageService();
    final shown = await storage.loadDisclaimerAccepted();
    if (!context.mounted) return;

    if (!shown) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DisclaimerDialog(onConfirmed: onConfirmed),
      );
    } else {
      onConfirmed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('免责声明'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('本软件由AI辅助编写，仅供参考。'),
            SizedBox(height: 8),
            Text('使用本软件产生的任何后果由用户自行承担。'),
            SizedBox(height: 8),
            Text('工时数据仅离线本地保存，未上传至任何服务器。'),
            SizedBox(height: 8),
            Text('请妥善保管您的数据，避免丢失。'),
            SizedBox(height: 8),
            Text('如有疑问请联系开发者。'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await StorageService().saveDisclaimerAccepted(true);
            if (!context.mounted) return;

            Navigator.of(context).pop();
            onConfirmed();
          },
          child: const Text('我已知晓并同意'),
        ),
      ],
    );
  }
}
