import 'package:flutter/material.dart';

/// 内容分区共用的白色表面；不承担加载或业务状态。
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.paperBackground = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool paperBackground; // 仅引导和摘要区使用纸纹，正文表单保持白底。

  static const paperTexture = DecorationImage(
    image: ResizeImage(
      AssetImage('assets/illustrations/paper-leaf-background.png'),
      width: 1024,
    ),
    fit: BoxFit.cover,
    alignment: Alignment.centerRight,
    opacity: .2, // 浅纸纹上仍保持次级正文的对比度。
  );
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(image: paperBackground ? paperTexture : null),
      child: Padding(padding: padding, child: child),
    ),
  );
}
