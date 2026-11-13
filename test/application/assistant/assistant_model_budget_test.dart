import 'dart:async';
import 'dart:typed_data';

import 'package:agent_core/agent_core.dart';
import 'package:agent_core/src/sessions/session_state.dart' show SessionState;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/attachments/attachment_coordinator.dart';
import 'package:mission_book/application/attachments/attachment_file_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';

import '../../support/assistant_fakes.dart';

class _Model implements AgentModel {
  _Model(this.respond);

  final FutureOr<ModelResponse> Function(ModelRequest) respond;
  final requests = <ModelRequest>[];

  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) {
    requests.add(request);
    return Future.sync(() => respond(request));
  }
}

class _Settings extends MemoryAssistantSettingsStore {
  @override
  Future<String?> resolveCredential(String credentialKey) async {
    fail('Scripted models must not resolve credentials');
  }
}

class _Images implements AttachmentStore, ImageAttachmentPicker {
  int reads = 0;

  @override
  Future<Uint8List> read(String storageKey) async {
    reads++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> delete(String storageKey) async {}
  @override
  Future<Set<String>> listKeys() async => {};
  @override
  Future<SelectedAttachment?> pick() async => null;
  @override
  Future<void> writeNew(String storageKey, Uint8List bytes) async {}
}

ModelProfile _profile({
  String id = 'deepseek-chat',
  int output = 2048,
  int window = 64000,
  bool images = true,
}) => ModelProfile(
  id: id,
  provider: 'test',
  model: 'test-model',
  endpoint: Uri.parse('https://example.invalid/chat/completions'),
  protocol: ModelProtocol.chatCompletions,
  credentialKey: 'TEST_MODEL_CREDENTIAL',
  contextWindowTokens: window,
  maxOutputTokens: output,
  supportsImages: images,
  retry: RetryPolicy(maxRetries: 0),
);

ModelResponse _response(
  ModelStopReason reason, {
  String text = '{"actions":[]}',
  bool toolCall = false,
}) => ModelResponse(
  message: AssistantMessage(
    content: [
      TextBlock(text: text),
      if (toolCall)
        ToolCallBlock(
          id: 'unexpected',
          name: 'unexpectedTool',
          input: const {},
        ),
    ],
    provider: 'test',
    model: 'test-model',
  ),
  stopReason: reason,
);

Matcher _modelError(String code) =>
    isA<ModelException>().having((error) => error.code, 'code', code);

void main() {
  late AppDatabase db;
  late DriftSessionStore sessions;
  late MissionService missions;
  late GoalService goals;
  late _Settings settings;
  late _Images images;
  AssistantController? assistant;
  final now = DateTime.utc(2030, 1, 1);

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    sessions = DriftSessionStore(db);
    settings = _Settings();
    images = _Images();
    final repository = DriftMissionRepository(db, clock: () => now);
    missions = MissionService(
      repository,
      attachments: AttachmentCoordinator(
        files: AttachmentFileService(store: images, picker: images),
        referencedKeys: repository.referencedAttachmentKeys,
      ),
      clock: () => now,
    );
    goals = GoalService(DriftGoalRepository(db));
    assistant = null;
  });

  tearDown(() async {
    await assistant?.close();
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<AssistantController> create(
    _Model model, {
    ModelProfile? profile,
    List<ModelProfile> extraProfiles = const [],
    String? summary,
    Map<String, AgentModel> extraModels = const {},
    int headroom = 512,
  }) async {
    final result = AssistantController(
      sessionStore: sessions,
      settingsStore: settings,
      missions: missions,
      goals: goals,
      unifiedReader: DriftUnifiedReader(db),
      clock: () => now,
      configuration: AgentConfiguration(
        profiles: [profile ?? _profile(), ...extraProfiles],
        defaultModelProfile: 'deepseek-chat',
        summaryModelProfile: summary,
        context: ContextPolicy(headroomTokens: headroom),
      ),
      modelOverrides: {'deepseek-chat': model, ...extraModels},
    );
    assistant = result;
    await result.initialize();
    expect(result.initialized, isTrue, reason: result.errorMessage);
    return result;
  }

  Future<SessionState> sessionState(AssistantController ai) async {
    final handle = await sessions.open(ai.currentSessionId!, readOnly: true);
    try {
      return SessionState.fromRecords(await handle.readRecords());
    } finally {
      await handle.close();
    }
  }

  test(
    'distinct summary survives initial selection and later model switches',
    () async {
      final main = _Model((_) => textResponse('main'));
      final selected = _Model((_) => textResponse('selected'));
      final summary = _Model((_) => textResponse('summary'));
      settings.profileId = 'other';
      final ai = await create(
        main,
        extraProfiles: [
          _profile(id: 'other'),
          _profile(id: 'summary'),
        ],
        extraModels: {'other': selected, 'summary': summary},
        summary: 'summary',
      );

      await ai.send('create session');
      expect(selected.requests, hasLength(1));
      expect((await sessionState(ai)).summaryProfileId, 'summary');
      await ai.selectModelProfile('deepseek-chat');
      final state = await sessionState(ai);
      expect(state.modelProfileId, 'deepseek-chat');
      expect(state.summaryProfileId, 'summary');
      expect(await ai.analyze('source'), 'summary');
      expect(main.requests, isEmpty);
      expect(summary.requests, hasLength(1));
    },
  );

  test('default summary follows the selected main model', () async {
    final main = _Model((_) => textResponse('main'));
    final selected = _Model((_) => textResponse('selected'));
    settings.profileId = 'other';
    final ai = await create(
      main,
      extraProfiles: [_profile(id: 'other')],
      extraModels: {'other': selected},
    );

    await ai.send('create session');
    expect((await sessionState(ai)).summaryProfileId, 'other');
    expect(await ai.analyze('source'), 'selected');
    await ai.selectModelProfile('deepseek-chat');
    expect((await sessionState(ai)).summaryProfileId, 'deepseek-chat');
    expect(await ai.analyze('source'), 'main');
  });

  test(
    'removed custom summary falls back to the selected main model',
    () async {
      final model = _Model((_) => textResponse('main'));
      final ai = await create(
        model,
        extraProfiles: [_profile(id: 'custom')],
        summary: 'custom',
      );

      expect(await ai.analyze('source'), 'main');
      await ai.send('create session');
      expect((await sessionState(ai)).summaryProfileId, 'deepseek-chat');
    },
  );

  test(
    'on-demand images use main while text uses the distinct summary',
    () async {
      final started = Completer<void>();
      final completion = Completer<ModelResponse>();
      final main = _Model((request) {
        if (request.purpose == ModelRequestPurpose.conversation) {
          started.complete();
          return completion.future;
        }
        return textResponse('image observation');
      });
      final summary = _Model((_) => textResponse('text analysis'));
      final ai = await create(
        main,
        extraProfiles: [_profile(id: 'summary', output: 32, images: false)],
        extraModels: {'summary': summary},
        summary: 'summary',
      );
      final sending = ai.send('inspect image');
      await started.future;
      try {
        expect(
          await ai.analyzeOnDemand(
            'image source',
            imageKey: 'attachments/source/photo.png',
            mime: 'image/png',
          ),
          'image observation',
        );
        expect(await ai.analyzeOnDemand('text source'), 'text analysis');
        final imageRequest = main.requests.last;
        expect(imageRequest.maxOutputTokens, 2000);
        expect(
          imageRequest.messages.single.content
              .whereType<ImageBlock>()
              .single
              .url,
          'data:image/png;base64,AQID',
        );
        expect(summary.requests.single.maxOutputTokens, 32);
        expect(summary.requests.single.tools, isEmpty);
        expect(images.reads, 1);
      } finally {
        completion.complete(textResponse('done'));
        await sending;
      }
    },
  );

  for (final cap in [16, 2000, 4096]) {
    test('analysis clamps output for a profile cap of $cap', () async {
      final model = _Model((_) => textResponse('analysis'));
      final ai = await create(model, profile: _profile(output: cap));

      expect(await ai.analyze('source', json: true), 'analysis');
      final request = model.requests.single;
      expect(request.maxOutputTokens, cap > 2000 ? 2000 : cap);
      expect(request.jsonOutput, isTrue);
      expect(request.purpose, ModelRequestPurpose.summary);
      expect(request.tools, isEmpty);
      expect(request.messages.single.text, 'source');
      expect(ai.transcript, isEmpty);
      expect(await sessions.listSessionIds(), isEmpty);
    });
  }

  test(
    'analysis remains isolated from existing conversation and memory context',
    () async {
      final model = _Model((_) => textResponse('analysis'));
      final ai = await create(model);
      await ai.send('private history marker');
      final transcript = ai.transcript;
      final recordCount = (await sessionState(ai)).transcript.length;

      expect(await ai.analyze('only this source'), 'analysis');
      final request = model.requests.last;
      expect(request.messages, hasLength(1));
      expect(request.messages.single, isA<UserMessage>());
      expect(request.messages.single.text, 'only this source');
      expect(request.systemPrompt, isNot(contains('private history marker')));
      expect(request.tools, isEmpty);
      expect(ai.transcript, transcript);
      expect((await sessionState(ai)).transcript, hasLength(recordCount));
      expect(ai.lastMemoryInjection, isEmpty);
    },
  );

  test(
    'oversized source fails with a stable error and zero model requests',
    () async {
      final model = _Model((_) => textResponse('must not run'));
      final ai = await create(
        model,
        profile: _profile(window: 1024, output: 64),
      );
      final source = 'private-source-marker ' * 2000;

      await expectLater(
        ai.analyze(source, json: true),
        throwsA(
          isA<ModelException>()
              .having((error) => error.code, 'code', 'context_too_large')
              .having(
                (error) => error.toString(),
                'safe error',
                isNot(contains('private-source-marker')),
              ),
        ),
      );
      expect(model.requests, isEmpty);
      expect(await sessions.listSessionIds(), isEmpty);
    },
  );

  test(
    'output and headroom reserves cannot consume the input window',
    () async {
      final model = _Model((_) => textResponse('must not run'));
      final ai = await create(
        model,
        profile: _profile(window: 2500, output: 2048),
      );

      await expectLater(
        ai.analyze('source'),
        throwsA(_modelError('context_too_large')),
      );
      expect(model.requests, isEmpty);
    },
  );

  test(
    'image tokens are counted after loading the actual image content',
    () async {
      final model = _Model((_) => textResponse('text fits'));
      final ai = await create(
        model,
        profile: _profile(window: 4096, output: 128),
      );
      expect(await ai.analyze('source'), 'text fits');
      model.requests.clear();

      await expectLater(
        ai.analyze('source', imageKey: 'attachments/private/photo.png'),
        throwsA(_modelError('context_too_large')),
      );
      expect(images.reads, 1);
      expect(model.requests, isEmpty);
      expect(await sessions.listSessionIds(), isEmpty);
    },
  );

  final invalidResults = <String, ModelResponse>{
    'truncated JSON': _response(
      ModelStopReason.maxTokens,
      text: '{"actions":[',
    ),
    'truncated valid JSON': _response(ModelStopReason.maxTokens),
    'refused': _response(ModelStopReason.refused),
    'tool stop reason': _response(ModelStopReason.toolUse),
    'tool call despite completed stop': _response(
      ModelStopReason.completed,
      toolCall: true,
    ),
    'empty text': _response(ModelStopReason.completed, text: '  \n'),
  };
  for (final result in invalidResults.entries) {
    test('analysis rejects ${result.key}', () async {
      final model = _Model((_) => result.value);
      final ai = await create(model);

      await expectLater(
        ai.analyze('source', json: true),
        throwsA(_modelError('analysis_failed')),
      );
      expect(model.requests, hasLength(1));
      expect(ai.transcript, isEmpty);
    });

    test('connection rejects ${result.key}', () async {
      final model = _Model((_) => result.value);
      final ai = await create(model);

      await expectLater(
        ai.testConnection(),
        throwsA(_modelError('connection_test_failed')),
      );
      expect(model.requests, hasLength(1));
      expect(await sessions.listSessionIds(), isEmpty);
    });
  }

  for (final reason in [ModelStopReason.maxTokens, ModelStopReason.completed]) {
    test('reflection queue respects actual completion: ${reason.name}', () async {
      // Even syntactically valid JSON must not publish after a max-token stop.
      final model = _Model((_) => _response(reason));
      final ai = await create(model);
      final service = AnalysisService(
        store: DriftAnalysisStore(db),
        model: ai.analyze,
        mainBusy: () => ai.isRunning,
      );
      try {
        await db.customStatement(
          "INSERT INTO analysis_jobs(scope,target_id,status) VALUES('reflection','global','pending')",
        );
        await service.drain();
        final job = await db.select(db.analysisJobs).getSingle();
        if (reason == ModelStopReason.completed) {
          expect(job.status, 'pending');
          expect(job.sourceVersion, 2);
          expect(job.attempts, 0);
          expect(job.error, isNull);
        } else {
          expect(job.status, 'failed');
          expect(job.sourceVersion, 1);
          expect(job.attempts, 1);
          expect(job.error, isNot(contains('{"actions"')));
        }
        expect(model.requests, hasLength(1));
        expect(model.requests.single.jsonOutput, isTrue);
        expect(await sessions.listSessionIds(), isEmpty);
      } finally {
        await service.dispose();
      }
    });
  }

  for (final cap in [16, 128]) {
    test(
      'connection clamps 64 by profile cap $cap and returns completion',
      () async {
        final model = _Model((_) => textResponse('  连接正常  '));
        final ai = await create(model, profile: _profile(output: cap));

        expect(await ai.testConnection(), '连接正常');
        expect(model.requests.single.maxOutputTokens, cap < 64 ? cap : 64);
        expect(model.requests.single.tools, isEmpty);
        expect(await sessions.listSessionIds(), isEmpty);
      },
    );
  }
}
