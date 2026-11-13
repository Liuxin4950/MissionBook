import 'package:agent_core/agent_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/assistant/assistant_prompt.dart';
import 'package:mission_book/application/assistant/assistant_settings.dart';
import 'package:mission_book/application/assistant/context_tools.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/memory/memory_usage_recorder.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/application/web/web_service.dart';
import 'package:mission_book/domain/repositories/memory_repository.dart';

class _Unused
    implements
        RecordService,
        MissionService,
        AnalysisStore,
        WebService,
        MemoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('不应调用 ${invocation.memberName}');
}

class _Memory extends MemoryService {
  _Memory() : super(_Unused());
  final writes = <Map<String, Object?>>[];
  bool? lastUserEdited;
  bool? lastCorrection;
  final usage = <({List<String> ids, bool injected})>[];

  @override
  Future<Map<String, Object?>> save(
    Map<String, Object?> entry, {
    bool userEdited = false,
    bool explicitCorrection = false,
    String? operationId,
  }) async {
    writes.add(entry);
    lastUserEdited = userEdited;
    lastCorrection = explicitCorrection;
    return {'saved': true};
  }

  @override
  Future<Map<String, Object?>> select({
    required String sessionId,
    required String selectionId,
    String? goalId,
    String? search,
    int offset = 0,
    int limit = 20,
    bool fullContent = false,
    String? layer,
  }) async => {
    'items': [
      {'id': 'memory'},
      {'id': 'memory'},
    ],
  };

  @override
  Future<void> recordUsage({
    required List<String> ids,
    required bool injected,
  }) async => usage.add((ids: ids, injected: injected));
}

void main() {
  late _Memory memory;
  late MemoryUsageRecorder usage;
  late List<AgentTool> tools;
  const original = '我习惯早上跑步。\n每次先热身。';
  const version = <String, Object?>{
    'id': 'existing',
    'content': '晚上跑步',
    'layer': 'semantic',
    'certainty': 'stated',
    'source_ref': 'old-source',
  };
  setUp(() {
    memory = _Memory();
    usage = MemoryUsageRecorder(memory);
    final unused = _Unused();
    tools = contextTools(
      records: unused,
      missions: unused,
      memory: memory,
      analysis: unused,
      web: unused,
      analyze: (prompt, {imageKey, mime, json = true}) async => '',
      userStatement: () => original,
      usageRecorder: usage,
      snapshot: (_) => {'memoryVersion': version},
    );
  });
  ToolContext context(String callId) => ToolContext(
    callId: callId,
    sessionId: 'session',
    cancellation: CancellationToken(),
  );
  AgentTool tool(String name) =>
      tools.singleWhere((t) => t.definition.name == name);

  for (final certainty in ['stated', 'inferred', 'unverified']) {
    for (final basis in <String?>[
      null,
      '',
      '   ',
      '之前说过的原话',
      '我习惯早上跑步。每次先热身。',
      ' 我习惯早上跑步。 ',
    ]) {
      test('$certainty拒绝非当前逐字basis ${basis ?? "missing"}，不写服务', () async {
        final input = <String, Object?>{
          'content': '偏好晨跑',
          'layer': 'semantic',
          'certainty': certainty,
          'basis': ?basis,
        };
        if (basis == null) {
          expect(tool('saveMemory').validateInput(input), isNotNull);
        }
        await expectLater(
          tool('saveMemory').execute(input, context('invalid')),
          throwsA(
            isA<ToolRejected>().having(
              (e) => e.code,
              'code',
              'memory_basis_invalid',
            ),
          ),
        );
        expect(memory.writes, isEmpty);
      });
    }
    test('$certainty有当前逐字basis可保存并保留来源', () async {
      final input = <String, Object?>{
        'content': '偏好晨跑',
        'layer': 'semantic',
        'certainty': certainty,
        'basis': original,
      };
      expect(tool('saveMemory').validateInput(input), isNull);
      await tool('saveMemory').execute(input, context('save'));
      expect(memory.writes.single['certainty'], certainty);
      expect(memory.writes.single['sourceKind'], 'assistant');
      expect(memory.writes.single['sourceRef'], 'conversation:session:save');
      expect(memory.lastUserEdited, false);
      expect(memory.lastCorrection, false);
    });
  }

  test('AI明确更正传快照和explicitCorrection，不冒充用户手动编辑', () async {
    await tool('saveMemory').execute({
      'id': 'existing',
      'content': '早上跑步',
      'layer': 'semantic',
      'certainty': 'stated',
      'basis': '我习惯早上跑步。',
    }, context('correct'));
    expect(memory.lastUserEdited, false);
    expect(memory.lastCorrection, true);
    expect(memory.writes.single['expectedVersion'], version);
    expect(memory.writes.single['sourceRef'], 'conversation:session:correct');
  });

  test('inferred不能更正已有条目，即使有合法basis', () async {
    await expectLater(
      tool('saveMemory').execute({
        'id': 'existing',
        'content': '早上跑步',
        'layer': 'semantic',
        'certainty': 'inferred',
        'basis': original,
      }, context('correct')),
      throwsA(isA<ToolRejected>()),
    );
    expect(memory.writes, isEmpty);
  });

  test('schema、工具描述和prompt统一要求所有certainty有basis，支持五层', () {
    final save = tool('saveMemory').definition;
    expect(save.inputSchema['required'] as List, contains('basis'));
    final properties = save.inputSchema['properties'] as Map;
    expect(
      (properties['layer'] as Map)['description'],
      contains('episodic=有跨会话价值'),
    );
    expect(save.description, contains('stated、inferred、unverified'));
    expect((properties['certainty'] as Map)['description'], contains('所有值'));
    expect(
      buildAssistantSystemPrompt(const AssistantPersona()),
      contains('包括 inferred'),
    );
  });

  test('getMemory实际使用共享recorder，召回去重并与注入独立', () async {
    await tool('getMemory').execute({}, context('get-1'));
    await tool('getMemory').execute({}, context('get-2'));
    usage.record(['memory'], injected: true);
    await usage.drain();
    expect(memory.usage.map((call) => [call.ids, call.injected]), [
      [
        ['memory'],
        false,
      ],
      [
        ['memory'],
        true,
      ],
    ]);
  });
}
