import 'package:mission_book/domain/entities/record_draft.dart';
import 'package:mission_book/domain/entities/analysis_scope.dart';
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
import 'package:mission_book/data/local/analysis_triggers.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';

class _Preferences implements AnalysisPreferencesStore {
  Set<AnalysisScope> scopes = {};
  bool failLoad = false;
  @override
  Future<Set<AnalysisScope>> load() async {
    if (failLoad) throw StateError('测试读取失败');
    return Set.of(scopes);
  }

  @override
  Future<void> save(Set<AnalysisScope> value) async => scopes = Set.of(value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('自动总结默认兼容开启，逐层选项和全部关闭可持久重开', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const settings = SecureAnalysisPreferences();
    expect(await settings.load(), summaryScopes);
    await settings.save({AnalysisScope.mission, AnalysisScope.goal});
    expect(await const SecureAnalysisPreferences().load(), {
      AnalysisScope.mission,
      AnalysisScope.goal,
    });
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
    records = RecordService(
      DriftRecordRepository(db),
      missions,
      missions.attachments,
    );
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
    const RecordDraft(
      id: 'record',
      type: ContentType.text,
      source: ContentSource.user,
      content: '今天完成了阅读',
    ),
  );

  test('原始记录不排独立总结，旧记录队列保留但不可领取', () async {
    await db.customStatement('''
      CREATE TRIGGER analysis_records_insert AFTER INSERT ON records
      BEGIN INSERT INTO analysis_jobs(scope,target_id,status)
        VALUES('record',NEW.id,'pending'); END
    ''');
    await installAnalysisTriggers(db);
    await seed();
    await service.drain();
    expect(prompts, isEmpty);
    expect((await db.select(db.records).get()).single.content, '今天完成了阅读');
    expect(await db.select(db.analysisJobs).get(), isEmpty);
    await db.customStatement(
      "INSERT INTO analysis_jobs(scope,target_id,status) VALUES('record','old-record-summary','pending')",
    );
    await store.recover();
    final legacyJobs = await db
        .customSelect(
          "SELECT target_id FROM analysis_jobs WHERE scope='record'",
        )
        .get();
    expect(legacyJobs.single.data['target_id'], 'old-record-summary');
    expect(await store.claim(), isNull);
    expect(summaryScopes, {
      AnalysisScope.mission,
      AnalysisScope.node,
      AnalysisScope.goal,
    });
  });

  test('偏好读取失败不采用开启默认值发起模型请求，读取恢复后可以重试', () async {
    preferences.failLoad = true;
    final goal = goals.prepareCreation(title: '阅读目标');
    await goals.create(goal);
    await service.drain();
    expect(prompts, isEmpty);
    expect(service.preferencesError, isNotNull);
    expect(service.automaticScopes, summaryScopes);
    preferences.failLoad = false;
    preferences.scopes = {AnalysisScope.goal};
    await service.drain();
    expect(prompts, hasLength(1));
    expect(service.preferencesError, isNull);
  });
}
