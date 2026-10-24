import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../../../core/theme/colors.dart';

/// 列表只展示有界缩略图；原有字节供独立查看层使用，不另存缩略文件或修改原图。
class EvidenceImagePreview extends StatelessWidget {
  const EvidenceImagePreview({
    super.key,
    required this.bytes,
    required this.name,
    this.height = 148,
  });

  final Uint8List bytes;
  final String name;
  final double height;

  ImageProvider get _provider => ResizeImage(
    MemoryImage(bytes),
    width: 1600,
    height: 1600,
    policy: ResizeImagePolicy.fit,
  );

  void _open(BuildContext context) {
    // 图片本身就是入口。查看层不依赖所在材料区域的 PopScope，关闭不会丢弃草稿。
    showDialog<void>(
      context: context,
      // 背景铺满整屏，内容自己避让安全区；否则状态栏和底部会露出灰色遮罩。
      useSafeArea: false,
      builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: AppColors.background,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarDividerColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Dialog.fullscreen(
          key: const Key('evidence-image-viewer'),
          backgroundColor: AppColors.background,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭图片',
                        color: AppColors.textPrimary,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 8,
                    child: Center(
                      child: Image(
                        image: _provider,
                        fit: BoxFit.contain,
                        semanticLabel: name,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '双指缩放 · 拖动查看',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '放大图片：$name',
    child: Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: _provider,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.open_in_full_rounded, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
