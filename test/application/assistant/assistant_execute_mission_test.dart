import 'dart:convert';
import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_tools.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_command.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';

class _LostResponseRepository extends DriftMissionRepository {
  _LostResponseRepository(super.database, {required super.clock});
  bool loseResponse = false;
  @override
  Future<ExecutionEvent> execute(ExecutionCommand command) async {
    final result = await super.execute(command);
    if (loseResponse) throw StateError('模拟提交成功后响应丢失');
    return result;
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 11, 2);
  late AppDatabase db;
  late _LostResponseRepository repository;
  late MissionService missions;
  late GoalService goals;
  late AssistantTools tools;
  late String id;
  var statement = '今天这节任务我做完了';
  final prepared = <String, PreparedToolCall>{};
  setUp(() async {
    prepared.clear();
    statement = '今天这节任务我做完了';
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = _LostResponseRepository(db, clock: () => now);
    missions = MissionService(repository, clock: () => now);
    goals = GoalService(DriftGoalRepository(db));
    tools = AssistantTools(
      unifiedReader: DriftUnifiedReader(db),
      missions: missions,
      goals: goals,
      resolveCall: (callId) => prepared[callId]!,
      userStatement: () => statement,
      clock: () => now,
    );
    final request = missions.prepareCreation(
      title: '工具执行任务',
      scheduledDate: '2026-11-11',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    await missions.createPrepared(request);
    id = request.mission.id;
  });
  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });
  Future<ToolOutput> run(
    String callId,
    String type, {
    String? report,
    int? minutes,
    String? basis,
  }) async {
    final input = <String, Object?>{
      'missionId': id,
      'type': type,
      'report': ?report,
      'minutes': ?minutes,
      'basis': basis,
    };
    prepared.putIfAbsent(callId, () => throw StateError('not prepared'));
    return tools.tools
        .singleWhere((t) => t.definition.name == 'executeMission')
        .execute(
          input,
          ToolContext(
            callId: callId,
            sessionId: 'test',
            cancellation: CancellationToken(),
          ),
        );
  }

  Future<void> prepare(
    String callId,
    String type, {
    String? report,
    int? minutes,
    String? basis,
  }) async {
    prepared[callId] = await tools.prepare('executeMission', {
      'missionId': id,
      'type': type,
      'report': ?report,
      'minutes': ?minutes,
      'basis': basis,
    });
  }

  test('执行工具 Schema 固定要求 basis；非 END 显式传 null', () {
    final schema = tools.tools
        .singleWhere((tool) => tool.definition.name == 'executeMission')
        .definition
        .inputSchema;
    expect(schema['required'] as List, contains('basis'));
    expect(
      tools.validate('executeMission', {
        'missionId': id,
        'type': 'START',
        'basis': null,
      }),
      isNull,
    );
    expect(
      tools.validate('executeMission', {
        'missionId': id,
        'type': 'END',
        'report': 'COMPLETED',
      }),
      isNotNull,
    );
  });

  test('END 缺少用户报告时明确拒绝且零写入', () async {
    prepared['end'] = PreparedToolCall(
      {'missionId': id, 'type': 'END'},
      snapshot: {'detail': (await missions.findDetail(missionId: id))!},
    );
    await expectLater(
      run('end', 'END'),
      throwsA(
        isA<ToolRejected>().having((e) => e.code, 'code', 'report_required'),
      ),
    );
    expect(await db.select(db.executionEvents).get(), isEmpty);
    expect(await db.select(db.operationReceipts).get(), isEmpty);
  });
  test('工具 START PAUSE RESUME EXTEND END 走真实事务并返回真实事件', () async {
    for (final type in ['START', 'PAUSE', 'RESUME', 'EXTEND', 'END']) {
      await prepare(
        type,
        type,
        report: type == 'END' ? 'COMPLETED' : null,
        minutes: type == 'EXTEND' ? 5 : null,
        basis: type == 'END' ? statement : null,
      );
      final output = await run(
        type,
        type,
        report: type == 'END' ? 'COMPLETED' : null,
        minutes: type == 'EXTEND' ? 5 : null,
        basis: type == 'END' ? statement : null,
      );
      expect(output.isError, isFalse);
      expect((jsonDecode(output.text) as Map)['event']['id'], 'test:$type');
    }
    final saved = (await missions.findDetail(missionId: id))!;
    expect(saved.events, hasLength(5));
    expect(saved.events.last.userReportedResult, UserReportedResult.completed);
    expect(saved.events.last.reason, statement);
    expect(saved.phase, MissionPhase.closed);
  });
  test('END 缺少 basis 或依据不是用户原话时拒绝且零写入', () async {
    await prepare('start', 'START');
    await run('start', 'START');
    // 直接固定提案，模拟绕过早期检查后执行器仍须拒绝。
    prepared['no-basis'] = PreparedToolCall(
      {'missionId': id, 'type': 'END', 'report': 'COMPLETED'},
      snapshot: {'detail': (await missions.findDetail(missionId: id))!},
    );
    await expectLater(
      run('no-basis', 'END', report: 'COMPLETED'),
      throwsA(
        isA<ToolRejected>().having((e) => e.code, 'code', 'basis_required'),
      ),
    );
    await expectLater(
      tools.prepare('executeMission', {
        'missionId': id,
        'type': 'END',
        'report': 'COMPLETED',
        'basis': '模型自己编的完成说法',
      }),
      throwsA(
        isA<ToolRejected>().having(
          (e) => e.code,
          'code',
          'user_basis_required',
        ),
      ),
    );
    prepared['fake'] = PreparedToolCall(
      {
        'missionId': id,
        'type': 'END',
        'report': 'COMPLETED',
        'basis': '模型自己编的完成说法',
      },
      snapshot: {'detail': (await missions.findDetail(missionId: id))!},
    );
    await expectLater(
      run('fake', 'END', report: 'COMPLETED', basis: '模型自己编的完成说法'),
      throwsA(
        isA<ToolRejected>().having(
          (e) => e.code,
          'code',
          'user_basis_required',
        ),
      ),
    );
    final saved = (await missions.findDetail(missionId: id))!;
    expect(saved.events.map((e) => e.type), [ExecutionEventType.start]);
  });
  test('非 END 动作携带 basis 被拒绝；END 重试按原依据幂等确认', () async {
    await expectLater(
      tools.prepare('executeMission', {
        'missionId': id,
        'type': 'START',
        'basis': statement,
      }),
      throwsA(
        isA<ToolRejected>().having(
          (e) => e.code,
          'code',
          'user_basis_required',
        ),
      ),
    );
    await prepare('start', 'START');
    await run('start', 'START');
    await prepare('end', 'END', report: 'COMPLETED', basis: statement);
    repository.loseResponse = true;
    final first = await run(
      'end',
      'END',
      report: 'COMPLETED',
      basis: statement,
    );
    repository.loseResponse = false;
    final second = await run(
      'end',
      'END',
      report: 'COMPLETED',
      basis: statement,
    );
    expect(jsonDecode(first.text)['event'], jsonDecode(second.text)['event']);
    final saved = (await missions.findDetail(missionId: id))!;
    expect(saved.events, hasLength(2));
    expect(saved.events.last.reason, statement);
  });
  test('提交后丢失响应按固定事件编号找回，重试返回同一事件', () async {
    await prepare('start', 'START');
    repository.loseResponse = true;
    final first = await run('start', 'START');
    final second = await run('start', 'START');
    expect(jsonDecode(first.text)['event'], jsonDecode(second.text)['event']);
    expect((await missions.findDetail(missionId: id))!.events, hasLength(1));
  });
  test('预览后任务已变化，工具映射拒绝且不追加第二条事件', () async {
    await prepare('stale', 'START');
    final original = (await missions.findDetail(missionId: id))!;
    await missions.execute(
      missions.prepareExecution(
        detail: original,
        type: ExecutionEventType.start,
        commandId: 'other-start',
      ),
    );
    await expectLater(
      run('stale', 'START'),
      throwsA(
        isA<ToolRejected>().having((e) => e.code, 'code', 'execution_rejected'),
      ),
    );
    expect(
      (await missions.findDetail(missionId: id))!.events.single.id,
      'other-start',
    );
  });
}
