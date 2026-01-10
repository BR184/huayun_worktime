import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class PhotoPreviewScreen extends StatefulWidget {
  final String photoUrl;
  final String heroTag;

  const PhotoPreviewScreen({
    super.key,
    required this.photoUrl,
    required this.heroTag,
  });

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  bool _isSaving = false;

  Future<void> _saveImage() async {
    setState(() => _isSaving = true); // 放在try外面确保状态更新

    try {
      // 1. 请求权限 (Gal处理)
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final access = await Gal.requestAccess();
        if (!access) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要相册权限才能保存图片')),
            );
          }
          return;
        }
      }

      // 2. 下载图片到临时文件
      final response = await http.get(Uri.parse(widget.photoUrl));
      if (response.statusCode != 200) {
        throw Exception('图片下载失败: ${response.statusCode}');
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = 'worktime_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      // 3. 保存到相册
      await Gal.putImage(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      }
      
      // 清理临时文件
      if (await file.exists()) {
        await file.delete();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存出错: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download),
            onPressed: _isSaving ? null : _saveImage,
            tooltip: '保存图片',
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: widget.heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              widget.photoUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                '加载失败，无法查看大图',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
