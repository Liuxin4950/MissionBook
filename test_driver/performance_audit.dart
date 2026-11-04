import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('build/performance_audit/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
  responseDataCallback: (data) async {
    // 截图单独保存，不把像素字节混入帧时间结果。
    final samples = {...?data}..remove('screenshots');
    final file = File('build/performance_audit/device_profile.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(samples),
    );
  },
);
