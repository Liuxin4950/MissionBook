import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/settings/motion_settings.dart';
import 'package:mission_book/data/settings/motion_settings_store_native.dart';

void main() {
  test('首次跟随系统，保存后重新装载保留本机选择', () async {
    final directory = await Directory.systemTemp.createTemp('mission-motion-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/motion.txt');
    final first = createMotionSettings(preferencesFile: file);
    addTearDown(first.dispose);
    await first.load();
    expect(first.preference, MotionPreference.system);
    expect(first.reduceMotion(true), isTrue);
    expect(first.reduceMotion(false), isFalse);
    await first.select(MotionPreference.full);
    final reopened = createMotionSettings(preferencesFile: file);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.preference, MotionPreference.full);
    expect(reopened.reduceMotion(true), isFalse);
    await reopened.select(MotionPreference.reduced);
    expect(reopened.reduceMotion(false), isTrue);
  });

  test('保存失败不显示为已生效，能够重试，迟到读取不能覆盖新选择', () async {
    final reading = Completer<String?>();
    var fail = true;
    final settings = MotionSettings(
      read: () => reading.future,
      write: (_) async {
        if (fail) throw const FileSystemException('模拟磁盘错误');
      },
    );
    addTearDown(settings.dispose);
    final loading = settings.load();
    await settings.select(MotionPreference.full);
    expect(settings.preference, MotionPreference.system);
    expect(settings.error, isNotNull);
    fail = false;
    await settings.select(MotionPreference.full);
    reading.complete('reduced');
    await loading;
    expect(settings.preference, MotionPreference.full);
    expect(settings.error, isNull);
  });
}
