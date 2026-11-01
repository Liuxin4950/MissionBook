import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('页面使用统一的字号、圆角和常用操作图标', () {
    final violations = <String>[];
    final rules = <String, RegExp>{
      '字号使用文字角色': RegExp(r'fontSize\s*:\s*\d'),
      '圆角使用设计令牌': RegExp(r'BorderRadius\.circular\(\s*\d'),
      '常用操作使用统一图标': RegExp(
        r'Icons\.(?:add|close|search|file_upload_outlined|play_arrow)\b',
      ),
    };
    for (final entity in Directory(
      'lib/presentation',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final rule in rules.entries) {
        if (rule.value.hasMatch(source)) {
          violations.add('${entity.path}: ${rule.key}');
        }
      }
    }
    expect(violations, isEmpty);
  });
}
