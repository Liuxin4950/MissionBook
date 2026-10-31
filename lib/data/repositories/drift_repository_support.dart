import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../../domain/entities/evidence.dart';
import '../local/app_database.dart';

/// 数据层共用的有界 SQL、写锁和幂等回执；不决定业务阶段或对象归属。
class DriftRepositorySupport {
  DriftRepositorySupport(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;

  /// 本项目有界 SQL 的绑定参数只接受 int、String 和 null。
  /// 时间、枚举和布尔值由调用者转换为 UTC 毫秒、稳定文本和 SQLite 的 0/1；
  /// 若新增小数等查询，使用 Drift 的显式 Variable 类型，不在这里隐式转换。
  Future<List<Map<String, Object?>>> rows(
    String sql, [
    List<Object?> args = const [],
  ]) async =>
      (await db
              .customSelect(
                sql,
                variables: args
                    .map<Variable>(
                      (v) => switch (v) {
                        int n => Variable.withInt(n),
                        String text => Variable.withString(text),
                        null => const Variable<String>(null),
                        _ => throw ArgumentError('无效查询参数'),
                      },
                    )
                    .toList(),
              )
              .get())
          .map((r) => r.data)
          .toList();

  Future<void> lock() => db.customStatement(
    'UPDATE analysis_jobs SET source_version=source_version WHERE 0',
  );

  Future<void> command(
    String? operationId,
    String kind,
    String entityId,
    Map<String, Object?> input,
    Map<String, Object?> result,
    Future<void> Function() write,
  ) async {
    if (operationId == null) {
      await write();
      return;
    }
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(input)))
        .toString();
    await db.transaction(() async {
      await lock();
      final saved = await (db.select(
        db.operationReceipts,
      )..where((t) => t.id.equals(operationId))).getSingleOrNull();
      if (saved != null) {
        if (saved.kind != kind ||
            saved.fingerprint != fingerprint ||
            saved.entityId != entityId) {
          throw const EvidenceConflict('操作编号已用于不同请求');
        }
        return;
      }
      await write();
      await db
          .into(db.operationReceipts)
          .insert(
            OperationReceiptsCompanion.insert(
              id: operationId,
              kind: kind,
              fingerprint: fingerprint,
              entityId: entityId,
              resultJson: jsonEncode(result),
              createdAt: clock().millisecondsSinceEpoch,
            ),
          );
    });
  }

  static Map<String, Object?> page(
    List<Map<String, Object?>> items,
    int total,
    int offset,
  ) => {
    'items': items,
    'total': total,
    'offset': offset,
    'nextOffset': offset + items.length < total ? offset + items.length : null,
    'truncated': offset + items.length < total,
  };
}
