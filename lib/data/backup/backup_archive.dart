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

/// 读取本应用已有 ZIP；只把受限 INSERT 字面量解析为值，从不执行备份 SQL。
Map<String, Object?> decodeBackupArchive(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > maxBackupBytes) {
    throw const FormatException('请选择非空且不超过 768 MiB 的 MissionBook ZIP 备份');
  }
  // 先只读中央目录，不解压任何条目：archive 对 UNIX 符号链接条目会立即 readBytes，
  // 等 decodeBytes 返回再检查就已经来不及，声明大小防护会被链接条目绕过。
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
    // UNIX 创建者版本 3，且高 16 位的文件类型为 S_IFLNK。
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
      'database.sql',
      'assistant-conversations.json',
      'README.txt',
      localResourcesEntry,
    }.contains(name) &&
        !isSpeech) {
      validateAttachmentKey(name);
    }
    // 模型条目只认固定清单内的文件名，不能借前缀写入其他位置。
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
    // 可阅读日志和说明不参与恢复，避免把重复副本传回工作区。
    if (name == 'manifest.json' ||
        name == 'database.sql' ||
        name == localResourcesEntry ||
        isSpeech ||
        name.startsWith('attachments/')) {
      files[name] = content;
    }
  }
  final manifestBytes = files['manifest.json'];
  final sql = files['database.sql'];
  if (manifestBytes == null || sql == null) {
    throw const FormatException('缺少备份清单或数据库');
  }
  final decoded = jsonDecode(utf8.decode(manifestBytes));
  if (decoded is! Map ||
      decoded['format'] != 'mission-book-backup' ||
      decoded['formatVersion'] != 1 ||
      decoded['databaseFormat'] != 'sqlite-sql') {
    throw const FormatException('不是支持的 MissionBook 完整备份');
  }
  final exportedAt = DateTime.tryParse(decoded['exportedAt']?.toString() ?? '');
  if (exportedAt == null || decoded['attachments'] is! List) {
    throw const FormatException('备份清单不完整');
  }
  final attachments = <String, Uint8List>{};
  for (final name in decoded['attachments'] as List) {
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
  final sqlText = utf8.decode(sql);
  final versions = RegExp(
    r'^PRAGMA user_version=(\d+);$',
    multiLine: true,
  ).allMatches(sqlText).toList();
  if (versions.length != 1 ||
      int.parse(versions.single[1]!) != decoded['databaseVersion']) {
    throw const FormatException('数据库版本标记与备份清单不一致');
  }
  final resourceFiles = <String, Uint8List>{
    for (final entry in files.entries)
      if (entry.key == localResourcesEntry ||
          entry.key.startsWith(speechEntryPrefix))
        entry.key: entry.value,
  };
  // 类别按包内真实内容判定，不采信清单自述；旧备份没有这些条目时自然为空。
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
  return {
    'version': decoded['databaseVersion'],
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'tables': parseBackupSql(sqlText),
    'attachments': attachments,
    'resources': resourceFiles,
    'resourceKinds': kinds,
  };
}

Map<String, List<Map<String, Object?>>> parseBackupSql(String sql) {
  final tables = <String, List<Map<String, Object?>>>{};
  var begun = false, committed = false, foreignKeysOn = false;
  for (final statement in _statements(sql)) {
    final text = statement.trim();
    if (text == 'PRAGMA foreign_keys=OFF') continue;
    if (text == 'BEGIN TRANSACTION' && !begun) {
      begun = true;
      continue;
    }
    if (text == 'COMMIT' && begun && !committed) {
      committed = true;
      continue;
    }
    if (text == 'PRAGMA foreign_keys=ON' && committed) {
      foreignKeysOn = true;
      continue;
    }
    if (RegExp(r'^PRAGMA user_version=\d+$').hasMatch(text) && !committed) {
      continue;
    }
    if (!begun || committed) throw const FormatException('备份 SQL 结构无效');
    final table = RegExp(
      r'^CREATE TABLE "([a-z_]+)"\s*\(',
      caseSensitive: false,
    ).firstMatch(text);
    if (table != null) {
      if (tables.containsKey(table[1])) throw const FormatException('备份表定义重复');
      tables[table[1]!] = [];
      continue;
    }
    // 索引和触发器是导出的说明；恢复时只使用当前应用自身的结构。
    if (RegExp(
      r'^CREATE (?:UNIQUE )?INDEX\b|^CREATE TRIGGER\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      continue;
    }
    final insert = RegExp(
      r'^INSERT INTO "([a-z_]+)" \(([^)]+)\) VALUES \((.*)\)$',
      dotAll: true,
    ).firstMatch(text);
    if (insert == null || !tables.containsKey(insert[1])) {
      throw const FormatException('备份包含不支持的 SQL');
    }
    final columns = insert[2]!.split(',');
    final values = insert[3]!.split(',');
    if (columns.length != values.length ||
        columns.toSet().length != columns.length) {
      throw const FormatException('备份数据列不完整');
    }
    final row = <String, Object?>{};
    for (var i = 0; i < columns.length; i++) {
      final column = RegExp(r'^"([a-z_][a-z_0-9]*)"$').firstMatch(columns[i]);
      if (column == null) throw const FormatException('备份数据列无效');
      row[column[1]!] = _literal(values[i]);
    }
    tables[insert[1]]!.add(row);
  }
  if (!begun || !committed || !foreignKeysOn) {
    throw const FormatException('备份数据库未完整写入');
  }
  return tables;
}

Object? _literal(String value) {
  if (value == 'NULL') return null;
  if (RegExp(r'^-?\d+$').hasMatch(value)) return int.parse(value);
  if (RegExp(r'^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$').hasMatch(value)) {
    return double.parse(value);
  }
  final text = RegExp(r"^CAST\(X'([0-9a-fA-F]*)' AS TEXT\)$").firstMatch(value);
  final blob = RegExp(r"^X'([0-9a-fA-F]*)'$").firstMatch(value);
  final hex = (text ?? blob)?[1];
  if (hex == null || hex.length.isOdd) {
    throw const FormatException('备份包含不支持的数据字面量');
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return text == null ? bytes : utf8.decode(bytes);
}

/// 只按 SQL 引号和触发器 BEGIN/CASE/END 划分，触发器正文不会被当作数据行。
Iterable<String> _statements(String source) sync* {
  var start = 0, depth = 0;
  String? quote;
  var trigger = false;
  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    if (quote != null) {
      if (ch == quote) {
        if (i + 1 < source.length && source[i + 1] == quote) {
          i++;
        } else {
          quote = null;
        }
      }
      continue;
    }
    if (ch == "'" || ch == '"') {
      quote = ch;
      continue;
    }
    if (_isWordStart(source.codeUnitAt(i))) {
      final wordStart = i;
      while (i + 1 < source.length &&
          (_isWordStart(source.codeUnitAt(i + 1)) ||
              (source.codeUnitAt(i + 1) >= 48 &&
                  source.codeUnitAt(i + 1) <= 57))) {
        i++;
      }
      final word = source.substring(wordStart, i + 1).toUpperCase();
      if (word == 'TRIGGER' &&
          source.substring(start, wordStart).trim().toUpperCase() == 'CREATE') {
        trigger = true;
      }
      if (trigger && (word == 'BEGIN' || word == 'CASE')) depth++;
      if (trigger && word == 'END') depth--;
    }
    if (ch == ';' && depth == 0) {
      yield source.substring(start, i);
      start = i + 1;
      trigger = false;
    }
  }
  if (quote != null ||
      depth != 0 ||
      source.substring(start).trim().isNotEmpty) {
    throw const FormatException('备份 SQL 被截断');
  }
}

bool _isWordStart(int code) =>
    code == 95 || (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
