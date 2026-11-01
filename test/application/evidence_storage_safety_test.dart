import 'package:mission_book/application/attachments/attachment_coordinator.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/domain/entities/record_draft.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/attachments/attachment_file_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/attachments/attachment_native.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/evidence.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';

class _Picker implements ImageAttachmentPicker {
  _Picker(this.bytes);
  final Uint8List bytes;
  @override
  Future<SelectedAttachment?> pick() async => SelectedAttachment(
    fileName: '结果.png',
    byteLength: bytes.length,
    readBytes: () async => bytes,
  );
}

/// 停在“文件已检查、数据库尚未提交”的真实业务边界，重现清理与提交交错。
class _DelayedRepository extends DriftMissionRepository {
  _DelayedRepository(super.database)
    : super(clock: () => DateTime.utc(2030, 1, 1));
  final entered = Completer<void>();
  final release = Completer<void>();
  bool fail = false;
  @override
  Future<EvidenceSubmissionResult> submitEvidence(
    EvidenceSubmission command,
  ) async {
    entered.complete();
    await release.future;
    if (fail) throw StateError('测试写入失败');
    return super.submitEvidence(command);
  }
}

/// 固定记录文件校验后、数据库提交前的并发边界。
class _DelayedRecordRepository extends DriftRecordRepository {
  _DelayedRecordRepository(super.db);
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> saveRecord(
    RecordDraft draft, {
    String? goalId,
    String? nodeId,
    String? missionId,
  }) async {
    entered.complete();
    await release.future;
    await super.saveRecord(
      draft,
      goalId: goalId,
      nodeId: nodeId,
      missionId: missionId,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List png;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff244d3d), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(2, 2);
    png = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
  });

  late Directory directory;
  late AppDatabase database;
  late _DelayedRepository repository;
  late NativeAttachmentStore store;
  late MissionService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'mission_evidence_commit_',
    );
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = _DelayedRepository(database);
    store = NativeAttachmentStore(applicationDirectory: () async => directory);
    service = MissionService(
      repository,
      attachments: AttachmentCoordinator(
        files: AttachmentFileService(store: store, picker: _Picker(png)),
        referencedKeys: repository.referencedAttachmentKeys,
      ),
    );
  });
  tearDown(() async {
    await service.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<(EvidenceDraft, EvidenceSubmission)> prepare() async {
    await service.create(
      title: '事务结果',
      scheduledDate: '2030-01-01',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
      verificationPolicy: VerificationPolicy.optionalEvidence,
    );
    final id = (await repository.findScheduledOn(
      '2030-01-01',
    )).single.mission.id;
    var detail = (await repository.findDetail(id))!;
    await service.execute(
      service.prepareExecution(detail: detail, type: ExecutionEventType.start),
    );
    detail = (await repository.findDetail(id))!;
    await service.execute(
      service.prepareExecution(
        detail: detail,
        type: ExecutionEventType.end,
        report: UserReportedResult.completed,
        submitOptionalEvidence: true,
      ),
    );
    detail = (await repository.findDetail(id))!;
    final draft = (await service.pickEvidenceImage(id))!;
    return (
      draft,
      service.prepareEvidenceSubmission(detail: detail, items: [draft]),
    );
  }

  test('并发初始化失败后复用同一次重试，避免重复清理', () async {
    final firstQuery = Completer<Set<String>>();
    final retryQuery = Completer<Set<String>>();
    var calls = 0;
    final coordinator = AttachmentCoordinator(
      files: AttachmentFileService(store: store, picker: _Picker(png)),
      referencedKeys: () {
        calls++;
        return calls == 1 ? firstQuery.future : retryQuery.future;
      },
    );
    late Future<void> retry;
    final first = coordinator.initialize().then<void>(
      (_) => fail('首次初始化应失败'),
      onError: (Object _) {
        retry = coordinator.initialize();
      },
    );
    final second = coordinator.initialize().then<void>(
      (_) => fail('首次初始化应失败'),
      onError: (Object _) {},
    );
    firstQuery.completeError(StateError('读取引用失败'));
    await Future.wait([first, second]);
    final third = coordinator.initialize();
    retryQuery.complete({});
    await Future.wait([retry, third]);
    expect(calls, 2);
  });

  test('删除图片来源再清理草稿，材料快照仍持有真实文件', () async {
    final (draft, command) = await prepare();
    final records = RecordService(
      DriftRecordRepository(database),
      service,
      service.attachments,
    );
    await records.save(RecordDraft.fromContent(draft));
    await records.useAsMaterial(draft.id, command.missionId);
    await records.delete(draft.id);
    await service.discardEvidenceDrafts([draft]);
    expect(await store.read(draft.attachmentStorageKey!), png);
    expect(
      (await repository.findDetail(
        command.missionId,
      ))!.evidence.single.attachmentStorageKey,
      draft.attachmentStorageKey,
    );
  });

  test('记录提交与任务材料草稿清理交错时，记录图片仍然可读', () async {
    final delayed = _DelayedRecordRepository(database);
    final records = RecordService(delayed, service, service.attachments);
    final draft = (await records.pickImage('independent-record'))!;
    final saving = records.save(draft);
    await delayed.entered.future;
    final cleaning = service.discardEvidenceDrafts([
      EvidenceDraft.fromContent(draft),
    ]);
    delayed.release.complete();
    await saving;
    await cleaning;
    expect(await store.read(draft.attachmentStorageKey!), orderedEquals(png));
    expect(
      (await records.readDraft(draft.id)).attachmentStorageKey,
      draft.attachmentStorageKey,
    );
  });

  test('记录与任务使用不同附件协调器时明确拒绝', () {
    final other = AttachmentCoordinator(
      referencedKeys: repository.referencedAttachmentKeys,
    );
    expect(
      () => RecordService(DriftRecordRepository(database), service, other),
      throwsArgumentError,
    );
  });

  test('保存和草稿清理交错时，正式材料仍保有完整图片', () async {
    final (draft, command) = await prepare();
    final saving = service.submitEvidence(command);
    await repository.entered.future;
    final cleaning = service.discardEvidenceDrafts([draft]);
    repository.release.complete();
    await saving;
    await cleaning;
    final detail = (await repository.findDetail(command.missionId))!;
    expect(detail.phase, MissionPhase.closed);
    expect(detail.evidence, hasLength(1));
    expect(await store.read(draft.attachmentStorageKey!), orderedEquals(png));
  });

  test('保存失败后仍能清理未提交副本，不遗留阻塞后续操作的队列', () async {
    final (draft, command) = await prepare();
    repository.fail = true;
    final saving = service.submitEvidence(command);
    final failed = expectLater(saving, throwsStateError);
    await repository.entered.future;
    final cleaning = service.discardEvidenceDrafts([draft]);
    repository.release.complete();
    await failed;
    await cleaning;
    expect(await store.listKeys(), isEmpty);
    final detail = (await repository.findDetail(command.missionId))!;
    expect(detail.phase, MissionPhase.evidencePending);
    expect(detail.evidence, isEmpty);
  });

  test('相机确认生成私有草稿副本，放弃时只删除未引用照片', () async {
    final capturedAt = DateTime.utc(2030, 1, 1, 8);
    final draft = await service.prepareEvidenceCameraImage(
      'camera-mission',
      png,
      capturedAt: capturedAt,
    );
    expect(draft.type, ContentType.image);
    expect(draft.source, ContentSource.camera);
    expect(draft.capturedAt, capturedAt);
    expect(await store.read(draft.attachmentStorageKey!), orderedEquals(png));
    await service.discardEvidenceDrafts([draft]);
    expect(await store.listKeys(), isEmpty);
  });
}
