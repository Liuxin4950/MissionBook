import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'speech_model_store_base.dart';

SpeechModelStore createSpeechModelStore() => IoSpeechModelStore();

/// 流式下载到私有目录，校验成功后才发布模型；不会自动联网。
class IoSpeechModelStore implements SpeechModelStore {
  IoSpeechModelStore({
    Future<Directory> Function()? directory,
    http.Client Function()? clientFactory,
    this.files = senseVoiceFiles,
    bool? supported,
  }) : _directory = directory ?? _defaultDirectory,
       _clientFactory = clientFactory ?? http.Client.new,
       supported = supported ?? Platform.isAndroid;

  final Future<Directory> Function() _directory;
  final http.Client Function() _clientFactory;
  final List<SpeechModelFile> files;
  @override
  final bool supported;
  Future<SpeechModelPaths>? _download;
  http.Client? _client;
  bool _cancelled = false;

  @override
  int get downloadBytes => files.fold(0, (sum, file) => sum + file.bytes);

  static Future<Directory> _defaultDirectory() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/speech/sensevoice');
  }

  @override
  Future<SpeechModelPaths?> findInstalled() async {
    if (!supported) return null;
    final directory = await _directory();
    final signature = await _signature(directory.path, files);
    if (signature == null) return null;
    final marker = File('${directory.path}/.verified');
    if (!await marker.exists() || await marker.readAsString() != signature) {
      // 兼容旧版本已部署的模型；大文件校验放到后台 isolate。
      final path = directory.path;
      final manifest = files;
      if (!await _verifyOffThread(path, manifest)) return null;
      await marker.writeAsString(signature, flush: true);
    }
    return SpeechModelPaths(
      directory: directory.path,
      model: '${directory.path}/model.int8.onnx',
      tokens: '${directory.path}/tokens.txt',
    );
  }

  @override
  Future<SpeechModelPaths> ensureInstalled() async {
    final existing = await findInstalled();
    if (existing != null) return existing;
    throw const FormatException('尚未下载离线语音模型，请到助手设置 → 语音输入中选择下载，或改用文字。');
  }

  @override
  Future<SpeechModelPaths> download({
    required void Function(int received, int total) onProgress,
  }) {
    if (!supported) {
      return Future.error(UnsupportedError('当前仅 Android 支持离线语音。'));
    }
    return _download ??= _downloadFiles(onProgress).whenComplete(() {
      _download = null;
    });
  }

  @override
  void cancelDownload() {
    _cancelled = true;
    _client?.close();
  }

  void _checkCancelled() {
    if (_cancelled) throw const SpeechModelDownloadCancelled();
  }

  Future<SpeechModelPaths> _downloadFiles(
    void Function(int, int) progress,
  ) async {
    _cancelled = false;
    final directory = await _directory();
    http.Client? client;
    var timedOut = false;
    Timer? deadline;
    try {
      final installed = await findInstalled();
      _checkCancelled();
      if (installed != null) return installed;
      await directory.create(recursive: true);
      client = _clientFactory();
      _client = client;
      deadline = Timer(const Duration(minutes: 20), () {
        timedOut = true;
        client?.close();
      });
      var received = 0;
      progress(0, downloadBytes);
      for (final file in files) {
        _checkCancelled();
        final response = await client
            .send(http.Request('GET', Uri.parse(file.url)))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw FormatException('模型下载失败（HTTP ${response.statusCode}），请稍后重试。');
        }
        if (response.contentLength != null &&
            response.contentLength != file.bytes) {
          throw const FormatException('模型文件长度不匹配，已停止下载。');
        }
        final partial = File('${directory.path}/${file.name}.part');
        var count = 0;
        final output = await partial.open(mode: FileMode.write);
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 30),
          )) {
            _checkCancelled();
            if (timedOut) throw TimeoutException('模型下载超时');
            count += chunk.length;
            if (count > file.bytes) {
              throw const FormatException('模型文件超出预期大小，已停止下载。');
            }
            await output.writeFrom(chunk);
            received += chunk.length;
            progress(received, downloadBytes);
          }
        } finally {
          await output.close();
        }
        _checkCancelled();
        if (count != file.bytes) throw const FormatException('模型下载不完整，请重试。');
        final path = partial.path;
        final digest = await _digestOffThread(path);
        _checkCancelled();
        if (digest != file.sha256) {
          throw const FormatException('模型完整性校验失败，请重新下载。');
        }
      }
      _checkCancelled();
      // 两个文件都通过校验才生效；从不把 .part 交给识别引擎。
      for (final file in files) {
        await File(
          '${directory.path}/${file.name}.part',
        ).rename('${directory.path}/${file.name}');
      }
      final signature = await _signature(directory.path, files);
      await File(
        '${directory.path}/.verified',
      ).writeAsString(signature!, flush: true);
      return (await findInstalled())!;
    } catch (_) {
      if (_cancelled) throw const SpeechModelDownloadCancelled();
      if (timedOut) throw TimeoutException('模型下载超时，请重试。');
      rethrow;
    } finally {
      deadline?.cancel();
      client?.close();
      _client = null;
      for (final file in files) {
        final partial = File('${directory.path}/${file.name}.part');
        if (await partial.exists()) await partial.delete();
      }
    }
  }
}

Future<String> _digest(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();

// 独立函数避免闭包顺带捕获下载方法中的 Client、订阅等不可跨 isolate 对象。
Future<String> _digestOffThread(String path) =>
    Isolate.run(() => _digest(path));

Future<bool> _verifyOffThread(String path, List<SpeechModelFile> files) =>
    Isolate.run(() => _verifyFiles(path, files));

Future<bool> _verifyFiles(String directory, List<SpeechModelFile> files) async {
  for (final file in files) {
    if (await _digest('$directory/${file.name}') != file.sha256) return false;
  }
  return true;
}

Future<String?> _signature(
  String directory,
  List<SpeechModelFile> files,
) async {
  final values = <String>[];
  for (final file in files) {
    final stat = await File('$directory/${file.name}').stat();
    if (stat.type != FileSystemEntityType.file || stat.size != file.bytes) {
      return null;
    }
    values.add(
      '${file.sha256}:${stat.size}:${stat.modified.microsecondsSinceEpoch}',
    );
  }
  return values.join('\n');
}
