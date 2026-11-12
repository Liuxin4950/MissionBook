import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/backup/backup_service.dart';
import 'local_resources_base.dart';

LocalResourceStore createLocalResourceStore() => WebLocalResourceStore();

/// 浏览器没有应用支持目录，只有助手设置可以带走；资料、动效、提醒与模型不适用。
class WebLocalResourceStore implements LocalResourceStore {
  WebLocalResourceStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, Uint8List>> collect(Set<BackupResource> resources) async {
    if (!resources.contains(BackupResource.assistantSettings)) return {};
    final settings = await _storage.readAll();
    if (settings.isEmpty) return {};
    return {
      localResourcesEntry: Uint8List.fromList(
        utf8.encode(jsonEncode({'assistantSettings': settings})),
      ),
    };
  }

  @override
  Future<void> apply(Map<String, Uint8List> files) async {
    final raw = files[localResourcesEntry];
    if (raw == null) return;
    final decoded = jsonDecode(utf8.decode(raw));
    if (decoded is! Map) throw const FormatException('本机资源清单无效');
    final settings = decoded['assistantSettings'];
    if (settings == null) return;
    if (settings is! Map) throw const FormatException('助手设置内容无效');
    final entries = <String, String>{};
    for (final entry in settings.entries) {
      final value = entry.value;
      if (entry.key is! String || value is! String) {
        throw const FormatException('助手设置内容无效');
      }
      entries[entry.key as String] = value;
    }
    for (final key in (await _storage.readAll()).keys) {
      if (!entries.containsKey(key)) await _storage.delete(key: key);
    }
    for (final entry in entries.entries) {
      await _storage.write(key: entry.key, value: entry.value);
    }
  }

  @override
  Future<int> installedSpeechBytes() async => 0;
}