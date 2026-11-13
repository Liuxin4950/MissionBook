import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../application/attachments/attachment_file_service.dart';
import '../../application/backup/backup_service.dart';
import '../speech/speech_model_store_base.dart';
import 'local_resources_base.dart';

/// 勾选离线语音模型时包内会多出约 228 MiB 原件，上限按此放宽；
/// 展开总量仍有硬上限，解压炸弹不会无界增长。
const maxBackupBytes = 768 * 1024 * 1024;
const maxExpandedBackupBytes = 1024 * 1024 * 1024;

const backupFormatVersion = 2;
const backupDatabaseEntry = 'database.json';

/// 读取本应用的 ZIP；行数据只接受 JSON 基本类型，从不执行任何 SQL 或 DDL。
Map<String, Object?> decodeBackupArchive(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > maxBackupBytes) {
    throw const FormatException('请选择非空且不超过 768 MiB 的 MissionBook ZIP 备份');
  }
  // 先只读中央目录，不解压任何条目：archive 对 UNIX 符号链接条目会立即 readBytes。
  final directory = ZipDirectory();
  try {
    directory.read(InputMemoryStream(bytes));
  } on RangeError {
    throw const FormatException('备份 ZIP 目录被截断');
  }
  if (directory.fileHeaders.length > 20000) {
    throw const FormatException('备份文件数量过多');
  }
  final names = <String>{};
  for (final header in directory.fileHeaders) {
    if (!names.add(header.filename)) throw const FormatException('备份包含重复文件');
    final name = header.filename;
    if (name.endsWith('/') || name.endsWith('\\')) {
      throw const FormatException('备份不能包含目录或链接');
    }
    if (header.versionMadeBy >> 8 == 3 &&
        (header.externalFileAttributes >> 16) & 0xf000 == 0xa000) {
      throw const FormatException('备份不能包含目录或链接');
    }
  }
  final archive = ZipDecoder().decodeBytes(bytes);
  var expanded = 0;
  final files = <String, Uint8List>{};
  for (final file in archive) {
    final name = file.name;
    if (!file.isFile || file.symbolicLink != null) {
      throw const FormatException('备份不能包含目录或链接');
    }
    final isSpeech = name.startsWith(speechEntryPrefix);
    if (!{
          'manifest.json',
          backupDatabaseEntry,
          'assistant-conversations.json',
          'README.txt',
          localResourcesEntry,
        }.contains(name) &&
        !isSpeech) {
      validateAttachmentKey(name);
    }
    if (isSpeech &&
        !senseVoiceFiles.any(
          (model) => model.name == name.substring(speechEntryPrefix.length),
        )) {
      throw const FormatException('备份包含未知的语音模型文件');
    }
    expanded += file.size;
    final limit = name.startsWith('attachments/')
        ? AttachmentFileService.maxBytes
        : isSpeech
        ? 512 * 1024 * 1024
        : name == 'manifest.json' || name == localResourcesEntry
        ? 4 * 1024 * 1024
        : 128 * 1024 * 1024;
    if (file.size < 0 ||
        file.size > limit ||
        expanded > maxExpandedBackupBytes) {
      throw const FormatException('备份展开后超过允许大小');
    }
    final content = file.content;
    if (content.length != file.size || getCrc32(content) != file.crc32) {
      throw const FormatException('备份文件损坏，请重新导出');
    }
    if (name == 'manifest.json' ||
        name == backupDatabaseEntry ||
        name == localResourcesEntry ||
        isSpeech ||
        name.startsWith('attachments/')) {
      files[name] = content;
    }
  }
  final manifestBytes = files['manifest.json'];
  final databaseBytes = files[backupDatabaseEntry];
  if (manifestBytes == null || databaseBytes == null) {
    throw const FormatException('缺少备份清单或数据库');
  }
  final manifest = jsonDecode(utf8.decode(manifestBytes));
  if (manifest is! Map ||
      manifest['format'] != 'mission-book-backup' ||
      manifest['formatVersion'] != backupFormatVersion ||
      manifest['databaseFormat'] != 'json') {
    throw const FormatException('不是支持的 MissionBook 完整备份');
  }
  final exportedAt = DateTime.tryParse(
    manifest['exportedAt']?.toString() ?? '',
  );
  final version = manifest['databaseVersion'];
  final fingerprint = manifest['schemaFingerprint'];
  if (exportedAt == null ||
      version is! int ||
      fingerprint is! String ||
      fingerprint.isEmpty ||
      manifest['attachments'] is! List) {
    throw const FormatException('备份清单不完整');
  }
  final attachments = <String, Uint8List>{};
  for (final name in manifest['attachments'] as List) {
    if (name is! String || attachments.containsKey(name)) {
      throw const FormatException('附件清单无效');
    }
    validateAttachmentKey(name);
    final content = files[name];
    if (content == null || content.isEmpty) {
      throw const FormatException('备份缺少清单中的附件');
    }
    attachments[name] = content;
  }
  if (files.keys.where((name) => name.startsWith('attachments/')).length !=
      attachments.length) {
    throw const FormatException('附件文件与清单不一致');
  }
  final database = jsonDecode(utf8.decode(databaseBytes));
  if (database is! Map ||
      database['schemaVersion'] != version ||
      database['tables'] is! Map) {
    throw const FormatException('备份数据库内容无效');
  }
  final tables = <String, List<Map<String, Object?>>>{};
  for (final entry in (database['tables'] as Map).entries) {
    final name = entry.key;
    final rows = entry.value;
    if (name is! String || rows is! List) {
      throw const FormatException('备份表数据无效');
    }
    final parsed = <Map<String, Object?>>[];
    for (final row in rows) {
      if (row is! Map) throw const FormatException('备份行数据无效');
      final values = <String, Object?>{};
      for (final field in row.entries) {
        if (field.key is! String ||
            !(field.value == null ||
                field.value is num ||
                field.value is String)) {
          throw const FormatException('备份行包含不支持的列或值');
        }
        values[field.key as String] = field.value;
      }
      parsed.add(values);
    }
    tables[name] = parsed;
  }
  final resourceFiles = <String, Uint8List>{
    for (final entry in files.entries)
      if (entry.key == localResourcesEntry ||
          entry.key.startsWith(speechEntryPrefix))
        entry.key: entry.value,
  };
  final Object? localSections = resourceFiles.containsKey(localResourcesEntry)
      ? jsonDecode(utf8.decode(resourceFiles[localResourcesEntry]!))
      : null;
  if (localSections != null && localSections is! Map) {
    throw const FormatException('本机资源清单无效');
  }
  final kinds = <BackupResource>[
    if (localSections is Map && localSections.containsKey('assistantSettings'))
      BackupResource.assistantSettings,
    if (localSections is Map &&
        (localSections.containsKey('localProfile') ||
            localSections.containsKey('motion') ||
            localSections.containsKey('reminders')))
      BackupResource.localPreferences,
    if (resourceFiles.keys.any((name) => name.startsWith(speechEntryPrefix)))
      BackupResource.speechModel,
  ];
  final declaredResources = manifest['resources'];
  if (declaredResources is! List ||
      !declaredResources.every((value) => value is String) ||
      declaredResources.toSet().length != declaredResources.length ||
      declaredResources.toSet().length != kinds.length ||
      !kinds.every((kind) => declaredResources.contains(kind.name))) {
    throw const FormatException('备份清单中的本机资源与文件内容不一致');
  }
  return {
    'version': version,
    'schemaFingerprint': fingerprint,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'tables': tables,
    'attachments': attachments,
    'resources': resourceFiles,
    'resourceKinds': kinds,
  };
}
