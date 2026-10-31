import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_preferences.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/data/analysis/analysis_preferences_store.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/domain/entities/evidence.dart';

class _Preferences implements AnalysisPreferencesStore {
  Set<String> scopes = {};
  bool failLoad = false;
  @override
  Future<Set<String>> load() async {
    if (failLoad) throw StateError('测试读取失败');
    return Set.of(scopes);
  }

  @override
  Future<void> save(Set<String> value) async => scopes = Set.of(value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('自动总结默认兼容开启，逐层选项和全部关闭可持久重开', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const settings = SecureAnalysisPreferences();
    expect(await settings.load(), summaryScopes);
    await settings.save({'mission', 'goal'});
    expect(await const SecureAnalysisPreferences().load(), {'mission', 'goal'});
    await settings.save({});
    expect(await const SecureAnalysisPreferences().load(), isEmpty);
  });

  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late RecordService records;
  late DriftAnalysisStore store;
  late _Preferences preferences;
  late AnalysisService service;
  late List<String> prompts;
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(db));
    goals = GoalService(DriftGoalRepository(db));
    records = RecordService(DriftRecordRepository(db), missions);
    store = DriftAnalysisStore(db);
    preferences = _Preferences();
    prompts = [];
    service = AnalysisService(
      store: store,
      preferencesStore: preferences,
      mainBusy: () => false,
      model: (prompt, {imageKey, mime, json = false}) async {
        prompts.add(prompt);
        return '可核对的总结';
      },
    );
  });
  tearDown(() async {
    await service.dispose();
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<void> seed() => records.save(
    const EvidenceDraft(
      id: 'record',
      type: EvidenceType.text,
      source: EvidenceSource.user,
      content: '今天完成了阅读',
    ),
  );

  test('关闭自动总结后事实和待办保留，不调用模型；手动一次仍可生成', () async {
    await seed();
    await service.drain();
    expect(prompts, isEmpty);
    expect((await db.select(db.records).get()).single.content, '今天完成了阅读');
    expect((await db.select(db.analysisJobs).get()).single.status, 'pending');
    await store.retry('record', 'record');
    await service.drain();
    expect(prompts, hasLength(1));
    expect(
      (await records.repository.analysis('record', 'record'))['content'],
      '可核对的总结',
    );
    expect(service.automaticScopes, isEmpty);
  });

  test('手动记录总结不会绕过节点和目标的关闭开关，重新开启继续待办', () async {
    final goal = goals.prepareCreation(title: '阅读目标');
    await goals.create(goal);
    final node = goals.prepareNodeCreation(goalId: goal.id, title: '第一阶段');
    await goals.createNode(node);
    await records.save(
      const EvidenceDraft(
        id: 'record',
        type: EvidenceType.text,
        source: EvidenceSource.user,
        content: '阶段笔记',
      ),
      goalId: goal.id,
      nodeId: node.id,
    );
    await store.retry('record', 'record');
    await service.drain();
    expect(prompts, hasLength(1));
    expect((await db.select(db.analysisVersions).get()).map((e) => e.scope), [
      'record',
    ]);
    await service.saveAutomaticScopes({'node', 'goal'});
    await service.drain();
    expect(
      (await db.select(db.analysisVersions).get()).map((e) => e.scope),
      containsAll(['record', 'node', 'goal']),
    );
  });

  test('手动请求在运行中退出后可恢复，不依赖页面内存标记', () async {
    await seed();
    await store.retry('record', 'record');
    final claimed = (await store.claim(automaticScopes: {}))!;
    expect(claimed.manual, isTrue);
    await store.recover();
    final recovered = (await store.claim(automaticScopes: {}))!;
    expect(recovered.manual, isTrue);
    expect(recovered.version, claimed.version);
    expect(await store.publish(recovered, '恢复后的总结', [], 0), isTrue);
  });

  test('偏好读取失败不采用开启默认值发起模型请求，读取恢复后可以重试', () async {
    preferences.failLoad = true;
    await seed();
    await service.drain();
    expect(prompts, isEmpty);
    preferences.failLoad = false;
    preferences.scopes = {'record'};
    await service.drain();
    expect(prompts, hasLength(1));
  });

  test('手动请求来源变更时拒绝旧结果，关闭的自动总结不会继续调用', () async {
    await seed();
    await store.retry('record', 'record');
    final claimed = (await store.claim(automaticScopes: {}))!;
    await records.updateContent('record', '今天完成了阅读', '新增了阅读笔记');
    expect(await store.publish(claimed, '过期总结', [], 0), isFalse);
    await service.drain();
    expect(prompts, isEmpty);
    expect(await db.select(db.analysisVersions).get(), isEmpty);
  });
}
