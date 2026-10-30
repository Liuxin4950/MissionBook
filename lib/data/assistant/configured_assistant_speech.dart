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

/// 每次录音读取设置：默认使用本地 SenseVoice；配置了录音转写时改走用户的服务。
class ConfiguredAssistantSpeech implements AssistantSpeech, WarmUpSpeech {
  ConfiguredAssistantSpeech(this.settings, {LocalSpeechBackend? localBackend})
    : _local = localBackend ?? createLocalSpeechBackend();

  final AssistantSettingsStore settings;
  final LocalSpeechBackend _local;
  AssistantSpeech? _current;
  int _generation = 0;

  @override
  Future<void> warmUp() async {
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
    final generation = ++_generation;
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
    await _current?.cancel();
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
  final text = data is Map ? data['text'] : null;
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
