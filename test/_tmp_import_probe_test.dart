import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_package_import_service.dart';
import 'package:mission_book/data/goal_import/goal_import_database.dart';
import 'package:mission_book/domain/entities/goal_package_import.dart';
import 'package:mission_book/domain/repositories/goal_package_repository.dart';

class _NoopRepository implements GoalPackageRepository {
  @override
  Future<String?> duplicateContent(String schema, String hash) async => null;
  @override
  Future<GoalImportResult> importPackage(
    GoalImportStage stage,
    GoalImportPreview preview,
    GoalImportOptions options,
    GoalImportCancellation cancellation,
  ) async => throw UnimplementedError();
  @override
  Future<GoalImportResult?> receipt(
    String schema,
    String packageId,
    String hash,
  ) async => null;
  @override
  Future<void> review(
    GoalImportStage stage,
    GoalImportPreview preview,
    GoalImportOptions options,
  ) async => throw UnimplementedError();
}

// 临时诊断：用真实导入文件走一遍 prepare，确认是解析问题还是环境问题。
void main() {
  test('prepare real package', () async {
    final bytes = File(
      r'C:\Users\Liuxin\Downloads\MissionBook-2026秋季课表.json',
    ).readAsBytesSync();
    print('PROBE bytes=${bytes.length}');

    final stage = GoalImportDatabase(executor: NativeDatabase.memory());
    final service = GoalPackageImportService(
      stage: stage,
      repository: _NoopRepository(),
    );
    try {
      final source = GoalImportSource(
        name: 'MissionBook-2026秋季课表.json',
        length: bytes.length,
        openRead: () async* {
          yield bytes;
        },
      );
      final preview = await service.prepare(source);
      print(
        'PROBE OK job=${preview.jobId} '
        'nodes=${preview.nodeCount} missions=${preview.missionCount}',
      );
    } catch (error, stack) {
      print('PROBE FAIL type=${error.runtimeType}');
      print('PROBE FAIL msg=$error');
      print('PROBE FAIL stack=${stack.toString().split('\n').take(6).join(' | ')}');
    } finally {
      await service.dispose();
    }
  });
}
