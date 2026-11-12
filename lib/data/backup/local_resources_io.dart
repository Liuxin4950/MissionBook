import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../application/backup/backup_service.dart';
import '../speech/speech_model_store.dart';
import 'local_resources_base.dart';

LocalResourceStore createLocalResourceStore() => IoLocalResourceStore();

/// 助手设置来自设备安全存储，资料/动效/提醒是应用支持目录下的独立偏好文件。
class IoLocalResourceStore implements LocalResourceStore {
  IoLocalResourceStore({
    Future<Directory> Function()? directory,
    FlutterSecureStorage? storage,
    SpeechModelStore? speech,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           ),
       _speech = speech ?? createSpeechModelStore();

  final Future<Directory> Function() _directory;
  final FlutterSecureStorage _storage;
  final SpeechModelStore _speech;

  static const _preferenceFiles = {
    'localProfile': 'local_profile.json',
    'motion': 'page_motion.txt',
    'reminders': 'reminders.json',
  };

  @override
  Future<Map<String, Uint8List>> collect(Set<BackupResource> resources) async {
    final files = <String, Uint8List>{};
    final sections = <String, Object?>{};
    if (resources.contains(BackupResource.assistantSettings)) {
      sections['assistantSettings'] = await _storage.readAll();
    }
    if (resources.contains(BackupResource.localPreferences)) {
      for (final entry in _preferenceFiles.entries) {
        sections[entry.key] = await _readText(entry.value);
      }
    }
    if (sections.isNotEmpty) {
      files[localResourcesEntry] = Uint8List.fromList(
        utf8.encode(jsonEncode(sections)),
      );
    }
    if (resources.contains(BackupResource.speechModel)) {
      final installed = await _speech.findInstalled();
      if (installed != null) {
        for (final file in senseVoiceFiles) {
          files['$speechEntryPrefix${file.name}'] = await File(
            '${installed.directory}/${file.name}',
          ).readAsBytes();
        }
      }
    }
    return files;
  }

  @override
  Future<void> apply(Map<String, Uint8List> files) async {
    final raw = files[localResourcesEntry];
    if (raw != null) {
      final decoded = jsonDecode(utf8.decode(raw));
      if (decoded is! Map) throw const FormatException('本机资源清单无效');
      final settings = decoded['assistantSettings'];
      if (settings != null) {
        if (settings is! Map) throw const FormatException('助手设置内容无效');
        final entries = <String, String>{};
        for (final entry in settings.entries) {
          final value = entry.value;
          if (entry.key is! String || value is! String) {
            throw const FormatException('助手设置内容无效');
          }
          entries[entry.key as String] = value;
        }
        // 整份替换：备份里没有的键一并清除，避免残留旧凭据被继续解析。
        for (final key in (await _storage.readAll()).keys) {
          if (!entries.containsKey(key)) await _storage.delete(key: key);
        }
        for (final entry in entries.entries) {
          await _storage.write(key: entry.key, value: entry.value);
        }
      }
      for (final entry in _preferenceFiles.entries) {
        final value = decoded[entry.key];
        if (value == null) continue;
        if (value is! String) throw const FormatException('本机偏好内容无效');
        await _writeText(entry.value, value);
      }
    }
    final model = files.entries
        .where((entry) => entry.key.startsWith(speechEntryPrefix))
        .toList();
    if (model.isEmpty) return;
    final target = Directory(
      '${(await _directory()).path}/speech/sensevoice',
    );
    await target.create(recursive: true);
    for (final entry in model) {
      final name = entry.key.substring(speechEntryPrefix.length);
      // 只接受固定清单内的文件名，备份不能借模型条目写到目录之外。
      if (!senseVoiceFiles.any((file) => file.name == name)) {
        throw FormatException('备份包含未知的语音模型文件：$name');
      }
      await File('${target.path}/$name').writeAsBytes(entry.value, flush: true);
    }
    // 不写 .verified：下次 findInstalled 会按真实字节重新校验 sha256。
  }

  @override
  Future<int> installedSpeechBytes() async {
    if (!_speech.supported) return 0;
    return await _speech.findInstalled() == null
        ? 0
        : senseVoiceFiles.fold<int>(0, (sum, file) => sum + file.bytes);
  }

  Future<String?> _readText(String name) async {
    final file = File('${(await _directory()).path}/$name');
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> _writeText(String name, String value) async {
    final file = File('${(await _directory()).path}/$name');
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(value, flush: true);
    await temporary.rename(file.path);
  }
}