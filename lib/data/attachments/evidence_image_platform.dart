// 编译时选择平台文件，浏览器不会导入 dart:io，原生也不会导入浏览器 API。
export 'evidence_image_native.dart'
    if (dart.library.js_interop) 'evidence_image_web.dart';
