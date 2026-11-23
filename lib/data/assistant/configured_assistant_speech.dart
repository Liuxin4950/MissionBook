import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:record/record.dart';

import '../../application/assistant/assistant_settings.dart';
import '../../application/assistant/assistant_speech.dart';
import '../speech/local_speech_backend.dart';
import 'assistant_voice_ticket.dart';

/// 每次录音读取设置：默认使用本地 SenseVoice；配置了录音转写时改走用户的服务。
class ConfiguredAssistantSpeech
    implements
        AssistantSpeech,
        WarmUpSpeech,
        DisposableAssistantSpeech,
        AssistantVoiceSpeech {
  ConfiguredAssistantSpeech(
    this.settings, {
    LocalSpeechBackend? localBackend,
    http.Client Function()? clientFactory,
  }) : _local = localBackend ?? createLocalSpeechBackend(),
       _clientFactory = clientFactory ?? http.Client.new;

  final AssistantSettingsStore settings;
  final LocalSpeechBackend _local;
  final http.Client Function() _clientFactory;
  final _preparedVoices = <_PreparedAssistantVoice>{};
  AssistantSpeech? _current;
  int _generation = 0;
  bool _disposed = false;
  http.Client? _externalClient;

  /// 悬浮录音前的预检/准备：离线只检查并加载已安装的 SenseVoice，远程只校验
  /// 已保存配置与独立凭据。不下载模型、不上传音频、不申请麦克风，也不返回凭据。
  @override
  Future<VoicePreflight> preflight() async {
    if (_disposed) {
      return const VoicePreflight.failed(
        mode: AssistantVoiceMode.offline,
        failure: AssistantVoiceFailure(
          'offlineModelInitFailed',
          AssistantVoiceMessages.offlineModelInitFailed,
        ),
      );
    }
    final AssistantSettings saved;
    try {
      saved = await settings.load();
    } catch (_) {
      return const VoicePreflight.failed(
        mode: AssistantVoiceMode.offline,
        failure: AssistantVoiceFailure(
          'workspaceUnavailable',
          AssistantVoiceMessages.workspaceUnavailable,
        ),
      );
    }
    if (saved.speech.useTranscription) return _remotePreflight(saved.speech);
    return _offlinePreflight();
  }

  Future<VoicePreflight> _offlinePreflight() async {
    if (!_local.supported) {
      return const VoicePreflight.failed(
        mode: AssistantVoiceMode.offline,
        failure: AssistantVoiceFailure(
          'offlineModelMissing',
          AssistantVoiceMessages.offlineModelMissing,
        ),
      );
    }
    bool hasModel;
    try {
      hasModel = await _local.hasModel();
    } catch (_) {
      hasModel = false;
    }
    if (!hasModel) {
      return VoicePreflight.failed(
        mode: AssistantVoiceMode.offline,
        failure: _missingOfflineModel(_local.lastError),
      );
    }
    var prepared = false;
    try {
      prepared = await _local.prepare();
    } catch (_) {
      prepared = false;
    }
    if (!prepared) {
      return VoicePreflight.failed(
        mode: AssistantVoiceMode.offline,
        failure: _brokenOfflineModel(_local.lastError),
      );
    }
    final route = _PreparedAssistantVoice.offline(_local);
    _track(route);
    return VoicePreflight.ready(
      mode: AssistantVoiceMode.offline,
      prepared: route,
    );
  }

  Future<VoicePreflight> _remotePreflight(AssistantSpeechSettings route) async {
    final endpoint = route.endpoint.trim();
    final model = route.model.trim();
    if (endpoint.isEmpty || model.isEmpty) {
      return const VoicePreflight.failed(
        mode: AssistantVoiceMode.remote,
        failure: AssistantVoiceFailure(
          'remoteConfigMissing',
          AssistantVoiceMessages.remoteConfigMissing,
        ),
      );
    }
    try {
      route.validate();
    } on ArgumentError {
      return const VoicePreflight.failed(
        mode: AssistantVoiceMode.remote,
        failure: AssistantVoiceFailure(
          'remoteConfigInvalid',
          AssistantVoiceMessages.remoteConfigInvalid,
        ),
      );
    }
    String? credential;
    try {
      credential = await settings.resolveCredential(
        'MISSIONBOOK_TRANSCRIPTION_API_KEY',
      );
    } catch (_) {
      credential = null;
    }
    final key = credential?.trim() ?? '';
    if (key.isEmpty) {
      return const VoicePreflight.failed(
        mode: AssistantVoiceMode.remote,
        failure: AssistantVoiceFailure(
          'remoteConfigMissing',
          AssistantVoiceMessages.remoteConfigMissing,
        ),
      );
    }
    final prepared = _PreparedAssistantVoice.remote(_clientFactory, route, key);
    _track(prepared);
    return VoicePreflight.ready(
      mode: AssistantVoiceMode.remote,
      prepared: prepared,
    );
  }

  void _track(_PreparedAssistantVoice voice) {
    _preparedVoices.add(voice);
    voice._owner = this;
  }

  /// 后端只能通过 lastError 附加细节；没有可识别原因时按缺模型处理，
  /// 让用户走可下载/重新下载的明确路径。
  static AssistantVoiceFailure _missingOfflineModel(String? lastError) {
    final reason = lastError ?? '';
    if (_looksBroken(reason)) {
      return const AssistantVoiceFailure(
        'offlineModelInvalid',
        AssistantVoiceMessages.offlineModelInvalid,
      );
    }
    return const AssistantVoiceFailure(
      'offlineModelMissing',
      AssistantVoiceMessages.offlineModelMissing,
    );
  }

  static AssistantVoiceFailure _brokenOfflineModel(String? lastError) {
    final reason = lastError ?? '';
    if (_looksMissing(reason)) {
      return const AssistantVoiceFailure(
        'offlineModelMissing',
        AssistantVoiceMessages.offlineModelMissing,
      );
    }
    if (_looksBroken(reason)) {
      return const AssistantVoiceFailure(
        'offlineModelInvalid',
        AssistantVoiceMessages.offlineModelInvalid,
      );
    }
    return const AssistantVoiceFailure(
      'offlineModelInitFailed',
      AssistantVoiceMessages.offlineModelInitFailed,
    );
  }

  static bool _looksBroken(String reason) =>
      reason.contains('校验') ||
      reason.contains('完整性') ||
      reason.contains('损坏') ||
      reason.toLowerCase().contains('sha');

  static bool _looksMissing(String reason) =>
      reason.contains('尚未下载') ||
      reason.contains('未安装') ||
      reason.contains('不存在') ||
      reason.contains('not found') ||
      reason.contains('no such file');

  /// 由 Android 可见录音窗口提供 PCM，使用同一本地或远程转写配置。
  Future<String> transcribePcm(Uint8List pcm) async {
    if (_disposed) throw StateError('语音服务已关闭');
    if (pcm.length < 3200 || pcm.length > 960000 || pcm.length.isOdd) {
      throw const FormatException('录音为空或超出长度限制');
    }
    final generation = ++_generation;
    await _current?.cancel();
    _externalClient?.close();
    final saved = await settings.load();
    if (generation != _generation) return '';
    Future<String> recognize() async {
      if (saved.speech.useTranscription) {
        final key = await settings.resolveCredential(
          'MISSIONBOOK_TRANSCRIPTION_API_KEY',
        );
        if (generation != _generation) return '';
        final client = http.Client();
        _externalClient = client;
        try {
          return await transcribeAudio(
            client,
            saved.speech,
            key,
            pcmToWav(pcm),
          );
        } finally {
          client.close();
          if (identical(_externalClient, client)) _externalClient = null;
        }
      }
      if (!_local.supported || !await _local.hasModel()) {
        throw const FormatException('语音模型未就绪，请先配置或使用文字');
      }
      if (!await _local.prepare()) throw const FormatException('语音模型未能加载');
      if (generation != _generation) return '';
      return _local.transcribe(pcm);
    }

    final result = (await recognize().timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        if (generation == _generation) {
          _externalClient?.close();
          _externalClient = null;
        }
        throw const FormatException('语音转写超时');
      },
    )).trim();
    if (generation != _generation) return '';
    if (!hasRecognizedSpeech(result)) throw const FormatException('没有识别到清晰语音');
    return result;
  }

  @override
  Future<void> warmUp() async {
    if (_disposed) throw StateError('语音服务已关闭');
    if ((await settings.load()).speech.useTranscription) return;
    if (!_local.supported || !await _local.hasModel()) return;
    await _local.prepare();
  }

  @override
  Future<bool> start({
    required void Function(String) onText,
    required VoidCallback onDone,
    VoidCallback? onProcessing,
    required void Function(String) onError,
  }) async {
    if (_disposed) throw StateError('语音服务已关闭');
    final generation = ++_generation;
    _externalClient?.close();
    _externalClient = null;
    await _current?.cancel();
    final saved = await settings.load();
    if (generation != _generation) return false;
    if (saved.speech.useTranscription) {
      saved.speech.validate();
      final key = await settings.resolveCredential(
        'MISSIONBOOK_TRANSCRIPTION_API_KEY',
      );
      if (generation != _generation) return false;
      final client = http.Client();
      _current = RecordedAssistantSpeech(
        transcribe: (pcm) =>
            transcribeAudio(client, saved.speech, key, pcmToWav(pcm)),
        limit: const Duration(seconds: 50),
        transcribeTimeout: const Duration(seconds: 30),
        genericError: '录音转写连接失败，请检查服务地址、浏览器跨域许可及网络。',
        onCancel: () async => client.close(),
        onDispose: () async => client.close(),
      );
    } else {
      if (!_local.supported) {
        onError(_local.lastError ?? '当前平台不支持离线语音。');
        return false;
      }
      if (!await _local.hasModel()) {
        if (generation == _generation) {
          onError('尚未下载离线语音模型，请到助手设置 → 语音输入中选择下载，或改用文字。');
        }
        return false;
      }
      if (generation != _generation) return false;
      // 只加载已安装的模型，与录音并行进行；不自动下载。
      final prepared = _local.prepare();
      _current = RecordedAssistantSpeech(
        transcribe: (pcm) async {
          if (!await prepared) {
            throw FormatException(_local.lastError ?? '离线语音模型未就绪，请稍后重试。');
          }
          return _local.transcribe(pcm);
        },
        limit: const Duration(seconds: 30),
        transcribeTimeout: const Duration(seconds: 60),
        genericError: '离线语音识别失败，请重试或改用文字。',
      );
    }
    return _current!.start(
      onText: onText,
      onDone: onDone,
      onProcessing: onProcessing,
      onError: onError,
    );
  }

  @override
  Future<void> stop() async => _current?.stop();

  @override
  Future<void> cancel() async {
    ++_generation;
    _externalClient?.close();
    _externalClient = null;
    await _current?.cancel();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _externalClient?.close();
    _externalClient = null;
    final current = _current;
    _current = null;
    try {
      await current?.cancel();
    } finally {
      // 悬浮录音的远程请求可能仍在等待；关闭时一并取消，避免留下孤立连接。
      for (final voice in _preparedVoices.toList()) {
        await voice.cancel();
      }
      _preparedVoices.clear();
      await _local.dispose();
    }
  }
}

/// 悬浮录音一轮的后端副本：离线路线不再重新读取设置，远程路线固定
/// 本轮 endpoint/model/凭据，并且拥有独立的 HTTP 客户端用于取消。
class _PreparedAssistantVoice implements PreparedAssistantVoice {
  _PreparedAssistantVoice._({
    required this.mode,
    LocalSpeechBackend? local,
    http.Client Function()? clientFactory,
    AssistantSpeechSettings? settings,
    String? credential,
  }) : _local = local,
       _clientFactory = clientFactory,
       _settings = settings,
       _credential = credential;

  factory _PreparedAssistantVoice.offline(LocalSpeechBackend local) =>
      _PreparedAssistantVoice._(mode: AssistantVoiceMode.offline, local: local);

  factory _PreparedAssistantVoice.remote(
    http.Client Function() clientFactory,
    AssistantSpeechSettings settings,
    String credential,
  ) => _PreparedAssistantVoice._(
    mode: AssistantVoiceMode.remote,
    clientFactory: clientFactory,
    settings: settings,
    credential: credential,
  );

  static const _cancelled = AssistantVoiceFailure(
    'cancelled',
    AssistantVoiceMessages.cancelled,
  );
  static const _emptyAudio = AssistantVoiceFailure(
    'emptyAudio',
    AssistantVoiceMessages.emptyAudio,
  );
  static const _timeout = AssistantVoiceFailure(
    'transcribeTimeout',
    AssistantVoiceMessages.transcribeTimeout,
  );
  static const _noSpeech = AssistantVoiceFailure(
    'noSpeech',
    AssistantVoiceMessages.noSpeech,
  );
  static const _offlineInitFailed = AssistantVoiceFailure(
    'offlineModelInitFailed',
    AssistantVoiceMessages.offlineModelInitFailed,
  );
  static const _remoteFailed = AssistantVoiceFailure(
    'remoteRequestFailed',
    AssistantVoiceMessages.remoteRequestFailed,
  );
  static const _failed = AssistantVoiceFailure(
    'failed',
    AssistantVoiceMessages.failed,
  );

  @override
  final AssistantVoiceMode mode;

  final LocalSpeechBackend? _local;
  final http.Client Function()? _clientFactory;
  final AssistantSpeechSettings? _settings;
  final String? _credential;
  ConfiguredAssistantSpeech? _owner;
  http.Client? _client;
  bool _cancelledRequest = false;
  bool _detached = false;

  @override
  Future<String> transcribe(Uint8List pcm16) async {
    if (_cancelledRequest) throw _cancelled;
    if (!isValidVoicePcm(pcm16)) throw _emptyAudio;
    try {
      final text = _local == null
          ? await _transcribeRemote(pcm16)
          : await _transcribeOffline(pcm16);
      if (_cancelledRequest) throw _cancelled;
      final trimmed = text.trim();
      if (!hasRecognizedSpeech(trimmed)) throw _noSpeech;
      return trimmed;
    } finally {
      _detach();
    }
  }

  Future<String> _transcribeOffline(Uint8List pcm16) async {
    try {
      return await _local!
          .transcribe(pcm16)
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw _timeout;
    } on FormatException {
      // 预检后模型又被删除或 worker 重建失败：不能静默转远程。
      throw _offlineInitFailed;
    } catch (_) {
      throw _failed;
    }
  }

  Future<String> _transcribeRemote(Uint8List pcm16) async {
    final client = _clientFactory!();
    _client = client;
    try {
      return await transcribeAudio(
        client,
        _settings!,
        _credential,
        pcmToWav(pcm16),
      ).timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw _timeout;
    } on http.ClientException {
      throw _cancelledRequest ? _cancelled : _remoteFailed;
    } on FormatException catch (error) {
      if (_cancelledRequest) throw _cancelled;
      throw _remoteFailure(error.message);
    } catch (_) {
      throw _cancelledRequest ? _cancelled : _remoteFailed;
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  static AssistantVoiceFailure _remoteFailure(String message) {
    if (message.contains('401') ||
        message.contains('403') ||
        message.contains('拒绝访问')) {
      return const AssistantVoiceFailure(
        'remoteAuthFailed',
        AssistantVoiceMessages.remoteAuthFailed,
      );
    }
    if (message.contains('没有返回文字')) {
      return _noSpeech;
    }
    if (message.contains('过大') || message.contains('过长')) {
      return _failed;
    }
    if (message.contains('转写服务')) {
      return AssistantVoiceFailure('remoteRequestFailed', message);
    }
    return _remoteFailed;
  }

  @override
  Future<void> cancel() async {
    if (_cancelledRequest) return;
    _cancelledRequest = true;
    final client = _client;
    _client = null;
    client?.close();
    _detach();
  }

  void _detach() {
    if (_detached) return;
    _detached = true;
    _owner?._preparedVoices.remove(this);
    _owner = null;
  }
}

typedef SpeechTranscriber = Future<String> Function(Uint8List pcm16);

/// 噪声常被识别成单个句号或空白；这类结果不能当作用户说出的文字。
bool hasRecognizedSpeech(String text) => text
    .replaceAll(RegExp(r'[\s，。！？、；：,.!?;:“”‘’（）()【】\[\]…—-]'), '')
    .isNotEmpty;

/// 最多 [limit] 秒单声道录音，停止后交给 [transcribe]；不自动发起聊天。
class RecordedAssistantSpeech implements AssistantSpeech {
  RecordedAssistantSpeech({
    required SpeechTranscriber transcribe,
    this.limit = const Duration(seconds: 50),
    this.transcribeTimeout = const Duration(seconds: 30),
    this.genericError = '语音识别失败，请重试或改用文字。',
    AudioRecorder? recorder,
    Future<void> Function()? onCancel,
    Future<void> Function()? onDispose,
  }) : _transcribe = transcribe,
       _recorder = recorder ?? AudioRecorder(),
       _onCancel = onCancel,
       _onDispose = onDispose;

  final SpeechTranscriber _transcribe;
  final Duration limit;
  final Duration transcribeTimeout;
  final String genericError;
  final AudioRecorder _recorder;
  final Future<void> Function()? _onCancel;
  final Future<void> Function()? _onDispose;
  final _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  Timer? _limit;
  void Function(String)? _onText;
  void Function(String)? _onError;
  VoidCallback? _onDone;
  VoidCallback? _onProcessing;
  bool _cancelled = false;
  bool _stopping = false;
  bool _disposed = false;

  @override
  Future<bool> start({
    required void Function(String) onText,
    required VoidCallback onDone,
    VoidCallback? onProcessing,
    required void Function(String) onError,
  }) async {
    _onText = onText;
    _onDone = onDone;
    _onProcessing = onProcessing;
    _onError = onError;
    try {
      if (!await _recorder.hasPermission()) {
        onError('麦克风未获授权，请在浏览器站点设置或系统设置中允许麦克风。');
        await _dispose();
        return false;
      }
      if (_cancelled) {
        await _dispose();
        return false;
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      if (_cancelled) {
        await _recorder.cancel();
        await _dispose();
        return false;
      }
      _subscription = stream.listen(
        (bytes) {
          if (_cancelled || _disposed) return;
          if (_pcm.length + bytes.length <= 16000 * 2 * limit.inSeconds) {
            _pcm.add(bytes);
          } else {
            unawaited(stop());
          }
        },
        onError: (Object error) {
          if (_cancelled) return;
          _onError?.call('录音中断，请检查麦克风后重试。');
          unawaited(cancel());
        },
      );
      _limit = Timer(limit, () => unawaited(stop()));
      return true;
    } catch (_) {
      if (!_cancelled) onError('无法启动麦克风录音，请检查麦克风权限或设备是否被占用。');
      await _dispose();
      return false;
    }
  }

  @override
  Future<void> stop() async {
    if (_cancelled || _stopping || _disposed) return;
    _stopping = true;
    _limit?.cancel();
    _onProcessing?.call();
    try {
      await _recorder.stop();
      await _subscription?.cancel();
      if (_cancelled) return;
      final pcm = _pcm.takeBytes();
      if (pcm.length < 3200) throw const FormatException('录音太短，请说完一句话后结束录音');
      final text = (await _transcribe(pcm).timeout(transcribeTimeout)).trim();
      if (!_cancelled) {
        if (!hasRecognizedSpeech(text)) {
          _onError?.call('没有识别到清晰语音，请重试或改用文字。');
        } else {
          _onText?.call(text);
        }
      }
    } on TimeoutException {
      if (!_cancelled) _onError?.call('语音识别超时，请重试或改用文字。');
    } catch (error) {
      if (!_cancelled) {
        _onError?.call(error is FormatException ? error.message : genericError);
      }
    } finally {
      await _dispose();
      if (!_cancelled) _onDone?.call();
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    _limit?.cancel();
    try {
      await _onCancel?.call();
      if (!_disposed) await _recorder.cancel();
    } finally {
      await _dispose();
    }
  }

  Future<void> _dispose() async {
    if (_disposed) return;
    _disposed = true;
    _limit?.cancel();
    await _subscription?.cancel();
    _pcm.clear();
    await _onDispose?.call();
    await _recorder.dispose();
  }
}

/// OpenAI 兼容的 multipart 转写协议；不依赖聊天供应商支持音频。
Future<String> transcribeAudio(
  http.Client client,
  AssistantSpeechSettings settings,
  String? credential,
  Uint8List wav,
) async {
  settings.validate();
  final request = http.MultipartRequest('POST', Uri.parse(settings.endpoint))
    ..followRedirects = false
    ..fields.addAll({
      'model': settings.model,
      'language': 'zh',
      'response_format': 'json',
    })
    ..files.add(
      http.MultipartFile.fromBytes(
        'file',
        wav,
        filename: 'speech.wav',
        contentType: MediaType('audio', 'wav'),
      ),
    );
  if (credential != null && credential.isNotEmpty) {
    request.headers['Authorization'] = 'Bearer $credential';
  }
  final response = await client.send(request);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw FormatException(
      response.statusCode == 401 || response.statusCode == 403
          ? '转写服务拒绝访问，请检查独立转写 API Key（HTTP ${response.statusCode}）'
          : '转写服务返回 HTTP ${response.statusCode}，请核对地址、模型或服务额度',
    );
  }
  final buffer = BytesBuilder(copy: false);
  await for (final bytes in response.stream) {
    if (buffer.length + bytes.length > 128 * 1024) {
      throw const FormatException('转写返回内容过大');
    }
    buffer.add(bytes);
  }
  final data = jsonDecode(utf8.decode(buffer.takeBytes()));
  final text = data is Map<String, dynamic> ? data['text'] : null;
  if (text is! String || text.trim().isEmpty) {
    throw const FormatException('转写服务没有返回文字，请检查录音后重试');
  }
  if (text.length > 32000) throw const FormatException('转写文字过长');
  return text.trim();
}

Uint8List pcmToWav(Uint8List pcm) {
  final result = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(result);
  void tag(int offset, String value) =>
      result.setRange(offset, offset + value.length, value.codeUnits);
  tag(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, 16000, Endian.little);
  header.setUint32(28, 32000, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  result.setRange(44, result.length, pcm);
  return result;
}
