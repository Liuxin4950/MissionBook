import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/notifications/reminder_store.dart';

void main() {
  late Directory tempDir;
  late File file;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('reminder_store_fix_test_');
    file = File('${tempDir.path}/reminders.json');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('新分配 id 保存后才返回；重启后不变且新 key 不撞号', () async {
    final store = ReminderStore(file);
    await store.load();
    final first = await store.notificationIdOf('mission-a-start');
    final second = await store.notificationIdOf('mission-b-start');
    expect(second, isNot(first));

    // 模拟重启：只凭文件恢复，已分配 id 必须原样返回。
    final reopened = ReminderStore(file);
    await reopened.load();
    expect(await reopened.notificationIdOf('mission-a-start'), first);
    expect(await reopened.notificationIdOf('mission-b-start'), second);
    final third = await reopened.notificationIdOf('mission-c-start');
    expect({first, second, third}, hasLength(3));
    expect(reopened.notificationIds['mission-a-start'], first);

    // 只读快照：调用方拿到后不能反向修改仓库状态。
    expect(() => reopened.notificationIds['other'] = 1, throwsUnsupportedError);

    final again = ReminderStore(file);
    await again.load();
    expect(await again.notificationIdOf('mission-c-start'), third);
    expect(again.notificationIds, {
      'mission-a-start': first,
      'mission-b-start': second,
      'mission-c-start': third,
    });
  });

  test('并发分配与偏好写入串行落盘，文件有效且重启后一致', () async {
    final store = ReminderStore(file);
    await store.load();
    final until = DateTime.utc(2026, 10, 25, 3, 15);

    final keyIds = List.generate(10, (i) => store.notificationIdOf('key-$i'));
    final sameKeyIds = List.generate(5, (_) => store.notificationIdOf('same'));
    await Future.wait<void>([
      store.register(missionId: 'm1', scheduleRevisionId: 'r1'),
      store.snooze(missionId: 'm1', scheduleRevisionId: 'r1', until: until),
      store.register(missionId: 'm2', scheduleRevisionId: 'r2'),
      ...keyIds.map((future) => future.then((_) {})),
      ...sameKeyIds.map((future) => future.then((_) {})),
    ]);

    final ids = store.notificationIds;
    expect(ids, hasLength(11));
    expect(ids.values.toSet(), hasLength(11), reason: '并发分配不能撞号');
    expect((await Future.wait(sameKeyIds)).toSet(), hasLength(1));

    // 队列排空后文件必须是完整 JSON，而不是最后一次写入的残片。
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(
      (raw['notificationIds'] as Map<String, dynamic>).cast<String, int>(),
      ids,
    );
    expect(raw['nextNotificationId'], 12);
    expect(
      (raw['preferences'] as Map<String, dynamic>).keys,
      containsAll(['m1', 'm2']),
    );

    final reopened = ReminderStore(file);
    await reopened.load();
    expect(reopened.notificationIds, ids);
    expect(reopened.preferenceOf('m1')!.snoozedUntil, until);
    expect(reopened.preferenceOf('m1')!.delivered, isFalse);
  });

  test('保存失败回滚内存并向调用方抛出；修复路径后重试成功', () async {
    // 父路径是普通文件，保存必然失败，用来模拟磁盘/权限异常。
    final blocker = File('${tempDir.path}/blocked');
    await blocker.writeAsString('not a directory');
    final blockedFile = File('${blocker.path}/reminders.json');
    final store = ReminderStore(blockedFile);
    await store.load();
    final until = DateTime.utc(2026, 10, 25, 4);

    await expectLater(
      store.notificationIdOf('key-a'),
      throwsA(isA<FileSystemException>()),
    );
    expect(store.notificationIds, isEmpty, reason: '失败分配必须回滚编号');
    await expectLater(
      store.snooze(missionId: 'm1', scheduleRevisionId: 'r1', until: until),
      throwsA(isA<FileSystemException>()),
    );
    expect(store.preferenceOf('m1'), isNull, reason: '失败偏好不能伪装成功');

    // 修复写入路径后重试：失败的那笔没有占用 id，后续仍可正常保存。
    await blocker.delete();
    expect(await store.notificationIdOf('key-a'), 1);
    await store.snooze(missionId: 'm1', scheduleRevisionId: 'r1', until: until);

    final reopened = ReminderStore(blockedFile);
    await reopened.load();
    expect(await reopened.notificationIdOf('key-a'), 1);
    expect(reopened.preferenceOf('m1')!.snoozedUntil, until);
  });
}
