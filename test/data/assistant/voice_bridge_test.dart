import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/assistant/assistant_speech.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/assistant_voice_ticket.dart';
import 'package:mission_book/data/assistant/assistant_workspace_bridge.dart';
import 'package:mission_book/data/assistant/configured_assistant_speech.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/speech/local_speech_backend.dart';

import '../../support/assistant_fakes.dart';

class FakeLocalSpeechBackend implements LocalSpeechBackend {
  bool hasModelResult = true;
  bool prepareResult = true;
  int transcribeCalls = 0;
  String text = '明天复习布局';
  Completer<String>? gate;
  String? failureMessage;

  @override
  bool get supported => true;
  @override
  String? get lastError => failureMessage;
  @override
  Future<bool> hasModel() async => hasModelResult;
  @override
  Future<bool> prepare() async => prepareResult;
  @override
  Future<String> transcribe(Uint8List pcm16) async {
    transcribeCalls++;
    final waiting = gate;
    if (waiting != null) return waiting.future;
    return text;
  }

  @override
  Future<void> dispose() async {}
}

class FakeDesktopSpeech implements AssistantSpeech {
  int starts = 0;
  int stops = 0;
  int cancels = 0;
  String text = '桌面语音';
  String? error;

  @override
  Future<bool> start({
    required void Function(String) onText,
    required VoidCallback onDone,
    VoidCallback? onProcessing,
    required void Function(String) onError,
  }) async {
    starts++;
    onText(text);
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late MissionService missions;
  late GoalService goals;
  late MemoryAssistantSettingsStore settings;
  late AssistantController assistant;
  late FakeLocalSpeechBackend backend;
  late ConfiguredAssistantSpeech speech;
  var clientCreations = 0;
  AssistantWorkspaceBridge? bridge;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(
      DriftMissionRepository(database),
      clock: () => DateTime.utc(2026, 11, 23, 1),
    );
    goals = GoalService(DriftGoalRepository(database));
    settings = MemoryAssistantSettingsStore();
    assistant = AssistantController(
      sessionStore: DriftSessionStore(database),
      settingsStore: settings,
      missions: missions,
      goals: goals,
      unifiedReader: DriftUnifiedReader(database),
    );
    backend = FakeLocalSpeechBackend();
    clientCreations = 0;
    speech = ConfiguredAssistantSpeech(
      settings,
      localBackend: backend,
      clientFactory: () {
        clientCreations++;
        throw StateError('测试中不应创建真实 HTTP 客户端');
      },
    );
  });

  tearDown(() async {
    bridge?.detach();
    bridge = null;
    await assistant.close();
    await missions.dispose();
    await goals.dispose();
    await database.close();
  });

  Future<Object?> dispatch(
    String method,
    Map<String, Object?> args, {
    int? generation,
  }) async {
    final message = const StandardMethodCodec().encodeMethodCall(
      MethodCall(method, {
        'generation': generation ?? bridge!.generation,
        ...args,
      }),
    );
    ByteData? reply;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          AssistantWorkspaceBridge.channel.name,
          message,
          (data) => reply = data,
        );
    return reply == null
        ? null
        : const StandardMethodCodec().decodeEnvelope(reply!);
  }

  Future<Map<String, Object?>> dispatchMap(
    String method,
    Map<String, Object?> args, {
    int? generation,
  }) async {
    final result = await dispatch(method, args, generation: generation);
    return (result as Map).cast<String, Object?>();
  }

  final pcm = Uint8List(3200);

  test('beginVoice/voice 通过通道写入绑定草稿，重复提交与取消幂等', () async {
    bridge = AssistantWorkspaceBridge(assistant, speech: speech)..install();
    final draftKey = assistant.draftKey;

    final ready = await dispatchMap('beginVoice', {'ticket': 'voice-1'});
    expect(ready, {
      'ready': true,
      'mode': 'offline',
      'draftKey': draftKey,
      'label': '离线语音',
    });

    final busy = await dispatchMap('beginVoice', {'ticket': 'voice-2'});
    expect(busy['errorCode'], 'busy');

    assistant.saveDraft(null, '已有草稿');
    final accepted = await dispatch('voice', {'ticket': 'voice-1', 'pcm': pcm});
    expect(accepted, {'accepted': true, 'draftKey': draftKey});
    expect(assistant.draft, '已有草稿\n明天复习布局');
    expect(backend.transcribeCalls, 1);

    final duplicate = await dispatchMap('voice', {
      'ticket': 'voice-1',
      'pcm': pcm,
    });
    expect(duplicate['errorCode'], 'ticketInvalid');
    expect(assistant.draft, '已有草稿\n明天复习布局');

    expect(await dispatch('cancelVoice', {'ticket': 'voice-1'}), isNull);
    expect(await dispatch('cancelVoice', {'ticket': 'voice-1'}), isNull);
  });

  test('远程模式 beginVoice 只预检配置，不创建客户端也不上传音频', () async {
    settings.speech = const AssistantSpeechSettings(
      useTranscription: true,
      endpoint: 'https://speech.example.invalid/v1/audio/transcriptions',
      model: 'speech-test',
    );
    settings.transcriptionCredential = 'remote-key';
    bridge = AssistantWorkspaceBridge(assistant, speech: speech)..install();

    final ready = await dispatchMap('beginVoice', {'ticket': 'remote-1'});
    expect(ready['ready'], true);
    expect(ready['mode'], 'remote');
    expect(ready['label'], '录音转写服务');
    expect(clientCreations, 0);
    expect(backend.transcribeCalls, 0);

    await dispatch('cancelVoice', {'ticket': 'remote-1'});
  });

  test('工作区 detach 后的迟到转写不写入任何草稿', () async {
    bridge = AssistantWorkspaceBridge(assistant, speech: speech)..install();
    backend.gate = Completer<String>();
    final ready = await dispatchMap('beginVoice', {'ticket': 'voice-late'});
    expect(ready['ready'], true);

    final pending = dispatchMap('voice', {'ticket': 'voice-late', 'pcm': pcm});
    await pumpEventQueue();
    bridge!.detach();
    backend.gate!.complete('迟到文字');

    final late = await pending;
    expect(late['accepted'], false);
    expect(late['errorCode'], 'cancelled');
    expect(assistant.draft, isEmpty);
  });

  test('缺模型时 beginVoice 返回 offlineModelMissing，原生无需异常处理', () async {
    backend.hasModelResult = false;
    bridge = AssistantWorkspaceBridge(assistant, speech: speech)..install();
    final ready = await dispatchMap('beginVoice', {'ticket': 'voice-missing'});
    expect(ready['ready'], false);
    expect(ready['errorCode'], 'offlineModelMissing');
    expect(ready['message'], AssistantVoiceMessages.offlineModelMissing);
    expect(backend.transcribeCalls, 0);
    expect(clientCreations, 0);
  });

  test('工作区代次不符时语音方法返回结构化失败而不是 PlatformException', () async {
    bridge = AssistantWorkspaceBridge(assistant, speech: speech)..install();
    final stale = bridge!.generation - 1;

    final begin = await dispatch('beginVoice', {
      'ticket': 'stale',
    }, generation: stale);
    expect((begin! as Map)['ready'], false);
    expect((begin as Map)['errorCode'], 'workspaceUnavailable');

    final voiceResult = await dispatch('voice', {
      'ticket': 'stale',
      'pcm': pcm,
    }, generation: stale);
    expect((voiceResult! as Map)['accepted'], false);
    expect((voiceResult as Map)['errorCode'], 'workspaceUnavailable');

    final cancel = await dispatch('cancelVoice', {
      'ticket': 'stale',
    }, generation: stale);
    expect(cancel, isNull);
  });

  test('桌面桥接的 voiceStart/voiceFinish 不受新语音票据影响', () async {
    final desktop = FakeDesktopSpeech();
    final desktopVoice = AssistantVoiceController(desktop);
    bridge = AssistantWorkspaceBridge(assistant, desktopVoice: desktopVoice)
      ..install();

    final unavailable = await dispatchMap('beginVoice', {'ticket': 'desktop'});
    expect(unavailable['ready'], false);
    expect(unavailable['errorCode'], 'workspaceUnavailable');

    final started = await dispatchMap('voiceStart', {
      'key': assistant.draftKey,
    });
    expect(started['generation'], bridge!.generation);
    expect(desktop.starts, 1);

    final finished = await dispatch('voiceFinish', {'key': assistant.draftKey});
    expect(finished, isA<Map<Object?, Object?>>());
    expect((finished! as Map)['text'], '桌面语音');
    expect((finished as Map)['error'], isNull);
    expect(desktop.stops, 1);
    expect(assistant.draft, isEmpty);
  });
}
