import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mission_book/application/assistant/assistant_settings.dart';
import 'package:mission_book/data/assistant/assistant_voice_ticket.dart';
import 'package:mission_book/data/assistant/configured_assistant_speech.dart';
import 'package:mission_book/data/speech/local_speech_backend.dart';

import '../../support/assistant_fakes.dart';

class FakeLocalSpeechBackend implements LocalSpeechBackend {
  FakeLocalSpeechBackend({
    this.supported = true,
    this.hasModelResult = false,
    this.prepareResult = false,
  });

  @override
  bool supported;
  bool hasModelResult;
  bool prepareResult;
  int hasModelCalls = 0;
  int prepareCalls = 0;
  int transcribeCalls = 0;
  String text = '明天复习布局';
  Object? transcribeError;

  @override
  String? lastError;

  @override
  Future<bool> hasModel() async {
    hasModelCalls++;
    return hasModelResult;
  }

  @override
  Future<bool> prepare() async {
    prepareCalls++;
    return prepareResult;
  }

  @override
  Future<String> transcribe(Uint8List pcm16) async {
    transcribeCalls++;
    final failure = transcribeError;
    if (failure != null) throw failure;
    return text;
  }

  @override
  Future<void> dispose() async {}
}

const remoteSettings = AssistantSpeechSettings(
  useTranscription: true,
  endpoint: 'https://speech.example.invalid/v1/audio/transcriptions',
  model: 'speech-test',
);

void main() {
  late MemoryAssistantSettingsStore settings;
  final pcm = Uint8List(3200);

  setUp(() {
    settings = MemoryAssistantSettingsStore();
  });

  ConfiguredAssistantSpeech configured(
    FakeLocalSpeechBackend backend, {
    http.Client Function()? clientFactory,
  }) => ConfiguredAssistantSpeech(
    settings,
    localBackend: backend,
    clientFactory: clientFactory,
  );

  ClientFunctionCounter counter() => ClientFunctionCounter();

  test('离线缺模型返回 offlineModelMissing，不准备、不识别、不联网', () async {
    final backend = FakeLocalSpeechBackend(hasModelResult: false);
    final clients = counter();
    final speech = configured(backend, clientFactory: clients.newClient);
    final preflight = await speech.preflight();

    expect(preflight.ready, isFalse);
    expect(preflight.mode, AssistantVoiceMode.offline);
    expect(preflight.failure?.code, 'offlineModelMissing');
    expect(
      preflight.failure?.message,
      AssistantVoiceMessages.offlineModelMissing,
    );
    expect(backend.hasModelCalls, 1);
    expect(backend.prepareCalls, 0);
    expect(backend.transcribeCalls, 0);
    expect(clients.created, 0);
  });

  test(
    '模型摘要校验失败映射 offlineModelInvalid，worker 失败映射 offlineModelInitFailed',
    () async {
      final broken = FakeLocalSpeechBackend(hasModelResult: false);
      broken.lastError = '离线语音模型完整性校验失败';
      final invalid = await configured(broken).preflight();
      expect(invalid.failure?.code, 'offlineModelInvalid');
      expect(
        invalid.failure?.message,
        AssistantVoiceMessages.offlineModelInvalid,
      );

      final crashed = FakeLocalSpeechBackend(
        hasModelResult: true,
        prepareResult: false,
      );
      crashed.lastError = '离线语音模型准备失败：worker 启动失败';
      final failed = await configured(crashed).preflight();
      expect(failed.failure?.code, 'offlineModelInitFailed');
      expect(
        failed.failure?.message,
        AssistantVoiceMessages.offlineModelInitFailed,
      );
      expect(crashed.prepareCalls, 1);
      expect(crashed.transcribeCalls, 0);
    },
  );

  test('离线预检成功后固定本地后端，改设置也不切远程', () async {
    final backend = FakeLocalSpeechBackend(
      hasModelResult: true,
      prepareResult: true,
    );
    final clients = counter();
    final speech = configured(backend, clientFactory: clients.newClient);
    final preflight = await speech.preflight();
    expect(preflight.ready, isTrue);
    expect(preflight.mode, AssistantVoiceMode.offline);

    // 本轮开始后把已保存设置改成远程；本轮仍必须使用预检时固定的离线后端。
    settings.speech = remoteSettings;
    settings.transcriptionCredential = 'remote-key';
    final text = await preflight.prepared!.transcribe(pcm);
    expect(text, '明天复习布局');
    expect(backend.transcribeCalls, 1);
    expect(clients.created, 0);
  });

  test('离线准备成功但未配置远程时，preflight 也不读取凭据', () async {
    final backend = FakeLocalSpeechBackend(
      hasModelResult: true,
      prepareResult: true,
    );
    settings.transcriptionCredential = null;
    final preflight = await configured(backend).preflight();
    expect(preflight.mode, AssistantVoiceMode.offline);
    expect(preflight.ready, isTrue);
  });

  test(
    '离线识别失败映射 noSpeech / offlineModelInitFailed / transcribeTimeout',
    () async {
      Future<AssistantVoiceFailure> prepareFailure(Object error) async {
        final backend = FakeLocalSpeechBackend(
          hasModelResult: true,
          prepareResult: true,
        )..transcribeError = error;
        final speech = configured(backend);
        final preflight = await speech.preflight();
        expect(preflight.ready, isTrue);
        try {
          await preflight.prepared!.transcribe(pcm);
          fail('预期识别失败');
        } on AssistantVoiceFailure catch (failure) {
          return failure;
        }
      }

      final silent = FakeLocalSpeechBackend(
        hasModelResult: true,
        prepareResult: true,
      )..text = '。';
      final speech = configured(silent);
      final offline = await speech.preflight();
      await expectLater(
        offline.prepared!.transcribe(pcm),
        throwsA(
          isA<AssistantVoiceFailure>().having(
            (failure) => failure.code,
            'code',
            'noSpeech',
          ),
        ),
      );

      expect(
        (await prepareFailure(const FormatException('模型未就绪'))).code,
        'offlineModelInitFailed',
      );
      expect(
        (await prepareFailure(TimeoutException('识别超时'))).code,
        'transcribeTimeout',
      );
    },
  );

  test('空音频在进入后端前返回 emptyAudio', () async {
    final backend = FakeLocalSpeechBackend(
      hasModelResult: true,
      prepareResult: true,
    );
    final speech = configured(backend);
    final preflight = await speech.preflight();
    await expectLater(
      preflight.prepared!.transcribe(Uint8List(2)),
      throwsA(
        isA<AssistantVoiceFailure>()
            .having((failure) => failure.code, 'code', 'emptyAudio')
            .having(
              (failure) => failure.message,
              'message',
              AssistantVoiceMessages.emptyAudio,
            ),
      ),
    );
    expect(backend.transcribeCalls, 0);
  });

  test('远程缺 endpoint/model 或独立凭据返回 remoteConfigMissing', () async {
    for (final speech in [
      const AssistantSpeechSettings(useTranscription: true),
      const AssistantSpeechSettings(
        useTranscription: true,
        endpoint: 'https://speech.example.invalid/v1',
      ),
    ]) {
      settings.speech = speech;
      settings.transcriptionCredential = null;
      final preflight = await configured(FakeLocalSpeechBackend()).preflight();
      expect(preflight.ready, isFalse);
      expect(preflight.mode, AssistantVoiceMode.remote);
      expect(preflight.failure?.code, 'remoteConfigMissing');
      expect(
        preflight.failure?.message,
        AssistantVoiceMessages.remoteConfigMissing,
      );
    }

    settings.speech = remoteSettings;
    settings.transcriptionCredential = null;
    final missingKey = await configured(FakeLocalSpeechBackend()).preflight();
    expect(missingKey.failure?.code, 'remoteConfigMissing');
  });

  test('非法 endpoint 返回 remoteConfigInvalid', () async {
    for (final endpoint in [
      'http://speech.example.invalid/v1',
      'https://user:secret@speech.example.invalid/v1',
      'https://speech.example.invalid/v1?token=secret',
    ]) {
      settings.speech = AssistantSpeechSettings(
        useTranscription: true,
        endpoint: endpoint,
        model: 'speech-test',
      );
      settings.transcriptionCredential = 'remote-key';
      final preflight = await configured(FakeLocalSpeechBackend()).preflight();
      expect(preflight.failure?.code, 'remoteConfigInvalid');
      expect(
        preflight.failure?.message,
        AssistantVoiceMessages.remoteConfigInvalid,
      );
    }
  });

  test('远程预检不上传音频；voice 轮内用固定服务配置发送一次', () async {
    settings.speech = remoteSettings;
    settings.transcriptionCredential = 'remote-key';
    final requests = <http.Request>[];
    final clients = counter();
    final speech = configured(
      FakeLocalSpeechBackend(),
      clientFactory: () => MockClient((request) async {
        requests.add(request);
        expect(request.url, Uri.parse(remoteSettings.endpoint));
        expect(request.headers['Authorization'], 'Bearer remote-key');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        expect(latin1.decode(request.bodyBytes), contains('speech-test'));
        return http.Response(
          jsonEncode({'text': '远程转写'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final preflight = await speech.preflight();
    expect(preflight.ready, isTrue);
    expect(preflight.mode, AssistantVoiceMode.remote);
    expect(requests, isEmpty);
    expect(clients.created, 0);

    // 开始后修改设置不影响本轮固定路由。
    settings.speech = const AssistantSpeechSettings();
    settings.transcriptionCredential = null;
    final text = await preflight.prepared!.transcribe(pcm);
    expect(text, '远程转写');
    expect(requests, hasLength(1));
  });

  test(
    '远程失败映射 remoteAuthFailed / remoteRequestFailed / noSpeech，不静默切本地',
    () async {
      Future<AssistantVoiceFailure> remoteFailure(
        http.Response response,
      ) async {
        settings.speech = remoteSettings;
        settings.transcriptionCredential = 'remote-key';
        final backend = FakeLocalSpeechBackend(
          hasModelResult: true,
          prepareResult: true,
        );
        final speech = configured(
          backend,
          clientFactory: () => MockClient((request) async => response),
        );
        final preflight = await speech.preflight();
        expect(preflight.ready, isTrue);
        try {
          await preflight.prepared!.transcribe(pcm);
          fail('预期远程识别失败');
        } on AssistantVoiceFailure catch (failure) {
          expect(backend.transcribeCalls, 0);
          return failure;
        }
      }

      final unauthorized = await remoteFailure(http.Response('no', 401));
      expect(unauthorized.code, 'remoteAuthFailed');
      expect(unauthorized.message, AssistantVoiceMessages.remoteAuthFailed);

      final serverError = await remoteFailure(http.Response('no', 500));
      expect(serverError.code, 'remoteRequestFailed');

      final emptyBody = await remoteFailure(
        http.Response(
          jsonEncode({'text': '   '}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      expect(emptyBody.code, 'noSpeech');
    },
  );

  test('取消远程识别返回 cancelled，迟到响应不产生文字', () async {
    settings.speech = remoteSettings;
    settings.transcriptionCredential = 'remote-key';
    final gate = Completer<void>();
    final speech = configured(
      FakeLocalSpeechBackend(),
      clientFactory: () => MockClient((request) async {
        await gate.future;
        return http.Response(
          jsonEncode({'text': '迟到文字'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final preflight = await speech.preflight();
    final pending = preflight.prepared!.transcribe(pcm);
    await pumpEventQueue();
    await preflight.prepared!.cancel();
    gate.complete();
    await expectLater(
      pending,
      throwsA(
        isA<AssistantVoiceFailure>().having(
          (failure) => failure.code,
          'code',
          'cancelled',
        ),
      ),
    );
  });

  test('transcribePcm 保留既有长度校验与离线识别行为', () async {
    final backend = FakeLocalSpeechBackend(
      hasModelResult: true,
      prepareResult: true,
    )..text = '保留原有入口';
    final speech = configured(backend);
    expect(await speech.transcribePcm(pcm), '保留原有入口');
    await expectLater(
      speech.transcribePcm(Uint8List(2)),
      throwsFormatException,
    );
    expect(backend.transcribeCalls, 1);
  });
}

/// 测试用客户端计数；离线预检不得创建任何 HTTP 客户端。
class ClientFunctionCounter {
  int created = 0;

  http.Client newClient() {
    created++;
    return MockClient((request) async => throw StateError('离线预检不应联网'));
  }
}
