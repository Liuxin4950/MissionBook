import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/settings/motion_settings.dart';
import 'package:mission_book/data/settings/motion_settings_store_native.dart';
import 'package:mission_book/application/backup/backup_service.dart';
import 'package:mission_book/data/backup/local_resources_base.dart';
import 'package:mission_book/data/backup/local_resources_io.dart';

void main() {
  for (final style in PageMotionStyle.values) {
    test('${style.name} 风格保存后重新载入保留选择', () async {
      String? saved;
      final settings = MotionSettings(
        read: () async => saved,
        write: (value) async => saved = value,
      );
      addTearDown(settings.dispose);
      await settings.selectPageStyle(style);
      final reopened = MotionSettings(
        read: () async => saved,
        write: (_) async {},
      );
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.pageStyle, style);
    });
  }

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
    await first.selectPageStyle(PageMotionStyle.slide);
    final reopened = createMotionSettings(preferencesFile: file);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.preference, MotionPreference.full);
    expect(reopened.pageStyle, PageMotionStyle.slide);
    expect(reopened.reduceMotion(true), isFalse);
    await reopened.select(MotionPreference.reduced);
    expect(reopened.reduceMotion(false), isTrue);
  });

  test('旧版枚举保存值保留强度，未知风格回退平台', () async {
    String? saved = 'reduced';
    final settings = MotionSettings(
      read: () async => saved,
      write: (value) async => saved = value,
    );
    addTearDown(settings.dispose);
    await settings.load();
    expect(settings.preference, MotionPreference.reduced);
    expect(settings.pageStyle, PageMotionStyle.platform);
    saved = '{"preference":"full","pageStyle":"future"}';
    await settings.load();
    expect(settings.preference, MotionPreference.full);
    expect(settings.pageStyle, PageMotionStyle.platform);
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

  test('分页偏好不进入本机偏好备份，恢复时保留当前设备值', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mission-motion-backup-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final motionFile = File('${directory.path}/page_motion.txt');
    await motionFile.writeAsString(
      jsonEncode({
        'preference': 'reduced',
        'pageStyle': 'slide',
        'openSubpagesInPane': false,
      }),
    );
    final resources = IoLocalResourceStore(directory: () async => directory);

    final backup = await resources.collect({BackupResource.localPreferences});
    final sections =
        jsonDecode(utf8.decode(backup[localResourcesEntry]!))
            as Map<String, dynamic>;
    final exportedMotion = jsonDecode(sections['motion'] as String) as Map;
    expect(exportedMotion.containsKey('openSubpagesInPane'), isFalse);

    final incoming = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'motion': jsonEncode({
            'preference': 'full',
            'pageStyle': 'fade',
            'openSubpagesInPane': true,
          }),
        }),
      ),
    );
    await resources.apply({localResourcesEntry: incoming});
    final restored = jsonDecode(await motionFile.readAsString()) as Map;
    expect(restored['preference'], 'full');
    expect(restored['pageStyle'], 'fade');
    expect(restored['openSubpagesInPane'], isFalse);
  });
}
