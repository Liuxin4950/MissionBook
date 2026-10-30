import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:uuid/uuid.dart';

import '../../domain/entities/goal_package_import.dart';
import '../../domain/repositories/goal_package_repository.dart';
import '../../domain/rules/goal_package_rules.dart';
import 'goal_package_parser.dart';

/// 组织流读、暂存、完整校验和预览；只有确认提交才调用正式业务仓储。
class GoalPackageImportService {
  GoalPackageImportService({
    required this.stage,
    required this.repository,
    this.onCommitted,
  }) {
    tzdata.initializeTimeZones();
  }
  final GoalImportStage stage;
  final GoalPackageRepository repository;
  final void Function()? onCommitted;
  final _uuid = const Uuid();
  GoalImportResult? lastResult;
  bool _busy = false;
  bool get busy => _busy;

  Future<GoalImportPreview> prepare(
    GoalImportSource source, {
    GoalImportCancellation? cancellation,
    void Function(String)? onProgress,
  }) async {
    if (_busy) throw StateError('正在处理另一份导入');
    if (source.length != null && source.length! > source.maxBytes) {
      throw const GoalImportException('LIMIT_BYTES', '/', '文件超过导入大小限制');
    }
    _busy = true;
    final cancel = cancellation ?? GoalImportCancellation();
    final jobId = _uuid.v4();
    final goalId = _uuid.v4();
    try {
      await stage.begin(jobId, goalId);
      final pending = <GoalImportEntry>[];
      String rawKey(Map<String, Object?> raw, String path) {
        final key = raw['key'];
        if (key is! String || key.trim().isEmpty) {
          GoalPackageRules.fail('INVALID_KEY', path, '需要非空的 key');
        }
        return key.trim();
      }

      final parser = GoalPackageParser(
        onNode: (raw, index, parent, order) => pending.add(
          GoalImportEntry(
            kind: 'NODE',
            sourceIndex: index,
            parentIndex: parent,
            orderIndex: order,
            raw: raw,
            id: _uuid.v4(),
            key: rawKey(raw, '/nodes/$index/key'),
          ),
        ),
        onMission: (raw, index) => pending.add(
          GoalImportEntry(
            kind: 'MISSION',
            sourceIndex: index,
            raw: raw,
            id: _uuid.v4(),
            scheduleId: _uuid.v4(),
            planId: _uuid.v4(),
            key: rawKey(raw, '/missions/$index/key'),
          ),
        ),
      );
      var bytesRead = 0;
      Stream<List<int>> chunks() async* {
        await for (final bytes in source.openRead()) {
          cancel.check();
          bytesRead += bytes.length;
          if (bytesRead > source.maxBytes ||
              bytesRead > GoalImportLimits.fileBytes) {
            throw const GoalImportException('LIMIT_BYTES', '/', '输入超过大小限制');
          }
          for (var offset = 0; offset < bytes.length; offset += 65536) {
            cancel.check();
            yield bytes.sublist(
              offset,
              (offset + 65536).clamp(0, bytes.length),
            );
          }
        }
      }

      Future<void> flush() async {
        while (pending.isNotEmpty) {
          cancel.check();
          final count = pending.length.clamp(1, 100);
          final entries = pending.sublist(0, count);
          pending.removeRange(0, count);
          try {
            await stage.append(jobId, entries);
          } catch (error) {
            if (error.toString().contains('UNIQUE constraint')) {
              throw const GoalImportException(
                'DUPLICATE_KEY',
                '/',
                '节点或任务 key 重复',
              );
            }
            rethrow;
          }
        }
      }

      var first = true;
      await for (final text in utf8.decoder.bind(chunks())) {
        cancel.check();
        if (first && text.isNotEmpty) {
          first = false;
          if (text.codeUnitAt(0) == 0xfeff) {
            throw const GoalImportException('BOM', '/', '请保存为 UTF-8 无 BOM 文件');
          }
        }
        parser.add(text);
        await flush();
        onProgress?.call('已读取 $bytesRead 字节，正在校验');
        // 原生/Web 每块让出执行权；SQLite 暂存由独立数据库执行。
        await Future<void>.delayed(Duration.zero);
      }
      final root = parser.finish();
      await flush();
      final outline = GoalPackageRules.validateRoot(root);
      if (outline && bytesRead > GoalImportLimits.pasteBytes) {
        throw const GoalImportException('LIMIT_BYTES', '/', '仅大纲协议仍限 2 MiB');
      }
      await stage.setRoot(jobId, root);
      final nodeIds = <String, String>{};
      final refs = <_NodeRef>[];
      var offset = 0;
      while (true) {
        cancel.check();
        final page = await stage.entries(
          jobId,
          'NODE',
          offset: offset,
          limit: 100,
        );
        if (page.isEmpty) break;
        for (final entry in page) {
          final key = GoalPackageRules.validateNode(entry, outline: outline);
          if (nodeIds.containsKey(key)) {
            GoalPackageRules.fail('DUPLICATE_NODE_KEY', '/nodes', '节点 key 重复');
          }
          nodeIds[key] = entry.id;
          refs.add(
            _NodeRef(entry.sourceIndex, entry.parentIndex, entry.orderIndex),
          );
        }
        offset += page.length;
      }
      final hash = await _hash(jobId, root, refs, false, cancel);
      final contentHash = await _hash(jobId, root, refs, true, cancel);
      final packageId = outline ? jobId : root['packageId']! as String;
      final existing = await repository.receipt(
        root['schema']! as String,
        packageId,
        hash,
      );
      var total = 0;
      var fixed = 0;
      var required = 0;
      var optional = 0;
      offset = 0;
      while (!outline) {
        cancel.check();
        final page = await stage.entries(
          jobId,
          'MISSION',
          offset: offset,
          limit: 100,
        );
        if (page.isEmpty) break;
        final resolved = <GoalImportEntry>[];
        for (final entry in page) {
          final values = GoalPackageRules.resolveMission(
            entry,
            GoalPackageRules.object(root['defaults'], '/defaults'),
            nodeIds,
          );
          final record = GoalImportEntry(
            kind: entry.kind,
            sourceIndex: entry.sourceIndex,
            key: entry.key,
            id: entry.id,
            scheduleId: entry.scheduleId,
            planId: entry.planId,
            raw: entry.raw,
            resolved: values,
          );
          try {
            GoalPackageRules.creation(
              record,
              goalId,
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            );
          } on ArgumentError catch (error) {
            throw GoalImportException(
              'INVALID_MISSION',
              '/missions/$offset',
              error.message.toString(),
            );
          }
          resolved.add(record);
          total += values['plannedDurationMinutes']! as int;
          if (values['timePolicy'] == 'FIXED') fixed++;
          if (values['verificationPolicy'] == 'REQUIRED_EVIDENCE') required++;
          if (values['verificationPolicy'] == 'OPTIONAL_EVIDENCE') optional++;
        }
        await stage.resolveBatch(jobId, resolved);
        offset += page.length;
        onProgress?.call('已校验 $offset 个任务');
      }
      final duplicate = await repository.duplicateContent(
        root['schema']! as String,
        contentHash,
      );
      final summary = <String, Object?>{
        'payloadHash': hash,
        'contentHash': contentHash,
        'nodeCount': parser.nodeCount,
        'missionCount': parser.missionCount,
        'totalMinutes': total,
        'fixedCount': fixed,
        'requiredCount': required,
        'optionalCount': optional,
        'existingGoalId': existing?.goalId,
        'duplicateGoalId': duplicate,
      };
      await stage.seal(jobId, summary);
      return _preview(jobId, goalId, root, summary);
    } catch (_) {
      try {
        await stage.discard(jobId);
      } catch (_) {
        /* 未取得的作业不清理。 */
      }
      rethrow;
    } finally {
      _busy = false;
    }
  }

  Future<GoalImportPreview?> recover() async {
    final job = await stage.pending();
    if (job == null || job['state'] != 'READY') return null;
    return _preview(
      job['jobId']! as String,
      job['goalId']! as String,
      (job['root']! as Map).cast<String, Object?>(),
      (job['summary']! as Map).cast<String, Object?>(),
    );
  }

  Future<void> discard({String? expectedJobId}) async {
    if (_busy) throw StateError('请先等待当前操作结束');
    final job = await stage.pending();
    if (job != null && expectedJobId != null && job['jobId'] != expectedJobId) {
      throw const GoalImportException('JOB_CHANGED', '/', '已有另一份导入草稿，请重新打开');
    }
    if (job != null) await stage.discard(job['jobId']! as String);
  }

  Future<void> review(GoalImportPreview preview, GoalImportOptions options) =>
      repository.review(stage, preview, options);

  Future<GoalImportResult> commit(
    GoalImportPreview preview,
    GoalImportOptions options, {
    GoalImportCancellation? cancellation,
  }) async {
    if (_busy) throw StateError('正在处理导入');
    _busy = true;
    try {
      final result = await repository.importPackage(
        stage,
        preview,
        options,
        cancellation ?? GoalImportCancellation(),
      );
      lastResult = result;
      // 事实已提交，通知/清理异常不能把成功变成重新创建。
      try {
        onCommitted?.call();
      } catch (_) {
        /* 启动/刷新仍会对账。 */
      }
      try {
        await stage.discard(preview.jobId);
      } catch (_) {
        /* 回执仍可确认成功。 */
      }
      return result;
    } finally {
      _busy = false;
    }
  }

  Future<List<GoalImportEntry>> page(
    GoalImportPreview preview,
    String kind,
    int offset,
  ) => stage.entries(
    preview.jobId,
    kind,
    offset: offset,
    limit: GoalImportLimits.pageSize,
  );

  Future<void> dispose() => stage.close();

  /// 只保留节点标题与父路径，长说明仍从暂存分页读取。
  Future<Map<String, String>> nodePaths(GoalImportPreview preview) async {
    final byIndex = <int, String>{};
    final byKey = <String, String>{};
    var offset = 0;
    while (true) {
      final rows = await stage.entries(
        preview.jobId,
        'NODE',
        offset: offset,
        limit: 100,
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        final parent = byIndex[row.parentIndex];
        final title = (row.raw['title']! as String).trim();
        final path = parent == null ? title : '$parent › $title';
        byIndex[row.sourceIndex] = path;
        byKey[row.key] = path;
      }
      offset += rows.length;
    }
    return byKey;
  }

  static GoalImportPreview _preview(
    String id,
    String goalId,
    Map<String, Object?> root,
    Map<String, Object?> s,
  ) => GoalImportPreview(
    jobId: id,
    goalId: goalId,
    root: root,
    payloadHash: s['payloadHash']! as String,
    contentHash: s['contentHash']! as String,
    nodeCount: s['nodeCount']! as int,
    missionCount: s['missionCount']! as int,
    totalMinutes: s['totalMinutes']! as int,
    fixedCount: s['fixedCount']! as int,
    requiredCount: s['requiredCount']! as int,
    optionalCount: s['optionalCount']! as int,
    existingGoalId: s['existingGoalId'] as String?,
    duplicateGoalId: s['duplicateGoalId'] as String?,
  );

  Future<String> _hash(
    String jobId,
    Map<String, Object?> root,
    List<_NodeRef> nodes,
    bool excludeId,
    GoalImportCancellation cancellation,
  ) async {
    final output = _DigestSink();
    final sink = sha256.startChunkedConversion(output);
    void write(String value) => sink.add(utf8.encode(value));
    Future<void> node(_NodeRef ref) async {
      cancellation.check();
      final row = (await stage.entries(
        jobId,
        'NODE',
        offset: ref.index,
        limit: 1,
      )).single;
      final fields = row.raw.keys.toList()..sort();
      write('{');
      for (var i = 0; i < fields.length; i++) {
        if (i > 0) write(',');
        final field = fields[i];
        write('${jsonEncode(field)}:');
        if (field == 'children') {
          write('[');
          final children =
              nodes.where((item) => item.parent == ref.index).toList()
                ..sort((a, b) => a.order.compareTo(b.order));
          for (var c = 0; c < children.length; c++) {
            if (c > 0) write(',');
            await node(children[c]);
          }
          write(']');
        } else {
          write(canonicalJson(row.raw[field]));
        }
      }
      write('}');
    }

    write('{');
    final fields =
        root.keys.where((key) => !excludeId || key != 'packageId').toList()
          ..sort();
    for (var i = 0; i < fields.length; i++) {
      if (i > 0) write(',');
      final field = fields[i];
      write('${jsonEncode(field)}:');
      if (field == 'nodes') {
        write('[');
        final roots = nodes.where((item) => item.parent == null).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        for (var n = 0; n < roots.length; n++) {
          if (n > 0) write(',');
          await node(roots[n]);
        }
        write(']');
      } else if (field == 'missions') {
        write('[');
        var offset = 0;
        while (true) {
          cancellation.check();
          final page = await stage.entries(
            jobId,
            'MISSION',
            offset: offset,
            limit: 100,
          );
          if (page.isEmpty) break;
          for (final entry in page) {
            if (offset > 0) write(',');
            write(canonicalJson(entry.raw));
            offset++;
          }
        }
        write(']');
      } else {
        write(canonicalJson(root[field]));
      }
    }
    write('}');
    sink.close();
    return output.value!.toString();
  }

  /// 协议只含受限整数；字段名为固定 ASCII。保留数组顺序和原始字符串。
  static String canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${canonicalJson(value[key])}').join(',')}}';
    }
    if (value is List) return '[${value.map(canonicalJson).join(',')}]';
    return jsonEncode(value);
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

class _NodeRef {
  const _NodeRef(this.index, this.parent, this.order);
  final int index;
  final int? parent;
  final int order;
}
