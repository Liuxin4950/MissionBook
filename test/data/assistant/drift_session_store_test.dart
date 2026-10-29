import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/local/app_database.dart';

void main() {
  late AppDatabase database;
  late DriftSessionStore store;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    store = DriftSessionStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('会话日志按序保存，关闭后重开并分页读取', () async {
    final handle = await store.create('session-a');
    await handle.append('session_created', {
      'id': 'session-a',
      'title': '今天安排',
    });
    await handle.append('message_added', {'value': 1});
    await handle.append('message_added', {'value': 2});
    expect(handle.recordCount, 3);
    await handle.close();

    final reopened = await store.open('session-a');
    final page = await reopened.readRecords(start: 1, limit: 1);
    expect(page, hasLength(1));
    expect(page.single.sequence, 1);
    expect(page.single.data['value'], 1);
    expect(await store.listSessionIds(), ['session-a']);
    expect((await store.listConversations()).single.title, '今天安排');
    await reopened.close();
  });

  test('初始记录原子导入且序号必须连续', () async {
    final records = [
      SessionRecord(
        sequence: 0,
        timestamp: DateTime.utc(2026, 10, 29),
        type: 'session_created',
        data: const {'id': 'imported', 'title': '导入会话'},
      ),
      SessionRecord(
        sequence: 1,
        timestamp: DateTime.utc(2026, 10, 29, 0, 1),
        type: 'message_added',
        data: const {'value': true},
      ),
    ];
    final handle = await store.create('imported', initialRecords: records);
    expect(handle.recordCount, 2);
    expect((await handle.readRecords()).last.data['value'], isTrue);
    await handle.close();

    await expectLater(
      store.create(
        'broken',
        initialRecords: [
          SessionRecord(
            sequence: 2,
            timestamp: DateTime.utc(2026),
            type: 'session_created',
            data: const {},
          ),
        ],
      ),
      throwsFormatException,
    );
  });

  test('写租约阻止第二写入者，关闭后释放', () async {
    final first = await store.create('shared');
    await expectLater(store.open('shared'), throwsStateError);
    await first.close();
    final second = await store.open('shared');
    await second.close();
  });

  test('过期租约可接管，旧写入者不能继续追加', () async {
    var now = DateTime.utc(2026, 10, 29, 12);
    final leasedStore = DriftSessionStore(
      database,
      clock: () => now,
      writerLease: const Duration(seconds: 3),
    );
    final first = await leasedStore.create('lease');
    now = now.add(const Duration(seconds: 4));
    final second = await leasedStore.open('lease');
    await expectLater(
      first.append('message_added', const {}),
      throwsStateError,
    );
    await second.close();
    await first.close();
  });

  test('关联引用可重建，活跃会话不能删除', () async {
    final handle = await store.create('referenced');
    await store.attachReference('referenced', missionId: 'mission-1');
    expect((await store.listConversations()).single.missionId, 'mission-1');
    await expectLater(store.delete('referenced'), throwsStateError);
    await handle.close();
    await store.delete('referenced');
    expect(await store.listSessionIds(), isEmpty);
  });
}
