import 'dart:async';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_ownership.dart';
import '../../domain/entities/mission_creation.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/execution_plan.dart';
import '../../domain/repositories/mission_repository.dart';
import '../../domain/repositories/mission_query_repository.dart';
import '../../domain/entities/goal_node.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/rules/goal_node_record_rules.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/execution_command.dart';
import '../../domain/entities/historical_completion.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/entities/evidence.dart';
import '../../domain/entities/operation_receipt.dart';
import '../../domain/entities/mission_plan.dart';
import '../../domain/repositories/mission_plan_repository.dart';
import '../../domain/repositories/mission_makeup_repository.dart';
import '../../domain/rules/evidence_rules.dart';
import '../../domain/rules/mission_creation_rules.dart';
import '../../domain/rules/scheduled_execution_rules.dart';
import '../evidence/evidence_image_service.dart';

/// 任务的应用业务入口：组织创建、查询、编辑、取消和执行。
///
/// App 只创建一个 MissionService，页面通过方法名选择要做的事。
/// 本类负责输入检查与业务对象组织；SQL、行转换和事务保存仍由仓储完成。
class MissionService {
  // 调用者传入仓储对象，保存到下面的 repository 属性。
  // clock 提供业务时刻（创建时间、编辑时间）；测试注入可控时钟固定时间断言。
  MissionService(
    this.repository, {
    EvidenceImageService? images,
    DateTime Function() clock = DateTime.now,
  }) : _images = images,
       _clock = clock {
    // 创建共享服务时准备时区资料，多个业务方法共用。
    tzdata.initializeTimeZones();
  }

  // 只依赖仓储接口；这里不需要知道 Companion 或数据库表。
  final MissionRepository repository;
  final EvidenceImageService? _images;
  // 所有“现在几点”都从这里取，不再散落 DateTime.now()，时钟回拨测试才可控。
  final DateTime Function() _clock;
  // 页面按同一业务时钟判断计划边界，测试和仓储不再使用不同的“现在”。
  DateTime get currentTime => _clock();
  Future<void>? _imageInitialization;
  final _preparedImageKeys = <String>{}; // 当前会话准备的副本，删除草稿不能删正式引用。
  Future<void>? _attachmentCommitQueue;

  /// 文件系统不能加入 SQLite 事务；同一业务服务把“检查文件→提交引用”和
  /// “重读引用→删除草稿副本”串行执行，避免检查后图片被另一个入口删掉。
  Future<T> _withAttachmentCommit<T>(Future<T> Function() operation) {
    final previous = _attachmentCommitQueue;
    // 空闲时在本次调用的异步上下文直接开始，不在服务构造时创建待完成 Future。
    final result = previous == null
        ? Future<T>.sync(operation)
        : previous.then<T>((_) => operation());
    late final Future<void> tail;
    void release() {
      if (identical(_attachmentCommitQueue, tail)) {
        _attachmentCommitQueue = null;
      }
    }

    // 本次错误仍传给调用者；队列本身恢复为成功，后面的重试/清理不会永久阻塞。
    tail = result.then<void>(
      (_) => release(),
      onError: (Object _, StackTrace _) => release(),
    );
    _attachmentCommitQueue = tail;
    return result;
  }

  EvidenceImageService get _imageService =>
      _images ?? (throw StateError('当前环境未配置图片存储，请重新打开应用'));

  // 创建一个编号生成器，后面用 v4() 生成唯一编号。
  final Uuid uuid = const Uuid();
  // 服务持有发送端；broadcast 允许今天页、详情页等同时登记监听。
  // void 表示通知没有业务数据：只说“请重读”，不把 RUNNING 等阶段放进通知。
  final _changes = StreamController<void>.broadcast();
  // 仅用于合并同一次提交引起的重复刷新，不是任务阶段、事件序号或数据库版本。
  // 先增加再通知，页面便能识别“本次查询已经在这次提交之后发起”。
  int _changeRevision = 0;
  int get changeRevision => _changeRevision;
  // 页面拿到接收端后调用 changes.listen(回调)，登记收到通知时要做的事。
  Stream<void> get changes => _changes.stream;
  Future<void> dispose() => _changes.close();

  /// 记录和任务材料共用附件提交锁，清理不会删除尚在提交的记录附件。
  Future<void> commitRecordAttachment(
    EvidenceDraft draft,
    Future<void> Function() save,
  ) => _withAttachmentCommit(() async {
    final key = draft.attachmentStorageKey;
    if (key != null) await _imageService.read(key);
    await save();
    _preparedImageKeys.remove(key);
    _notify();
  });

  // notify 意为“通知”；这是我们自己定义的方法，_ 表示仅本 Dart 库内部使用。
  // 调用者必须先等仓储成功返回。add 会让已监听页面的回调随后收到一次信号。
  void _notify() {
    if (!_changes.isClosed) {
      _changeRevision++;
      _changes.add(null); // void 通知用 null 触发，不代表任务数据为空。
    }
  }

  /// 用页面读到的详情固定本次动作身份与旧序号；这里只准备意图，不写数据库。
  /// 同一次操作失败后复用返回的命令，不能重新生成编号后盲目再发一次。
  ExecutionCommand prepareExecution({
    required MissionDetail detail,
    required ExecutionEventType type,
    int? minutes,
    String? reason,
    UserReportedResult? report,
    String? userReasonCategory,
    String? userReasonText,
    bool? submitOptionalEvidence,
    String? commandId,
  }) {
    return ExecutionCommand(
      // 通知动作带固定候选事件 id：同一动作的重复回调共用同一身份，
      // 重试按领域规则幂等；前台按钮不传时照旧每次生成新身份。
      id: commandId ?? uuid.v4(),
      missionId: detail.mission.id,
      expectedSequence: detail.lastSequence,
      type: type,
      // 开始时带上页面读到的排期编号，让事务确认用户看到的计划没有被改过。
      // 之后的动作沿用已保存 START 绑定的计划，不重新选择排期。
      scheduleRevisionId: type == ExecutionEventType.start
          ? detail.schedule.id
          : null,
      grantedDurationMinutes: minutes,
      reason: reason,
      userReportedResult: report,
      userReasonCategory: userReasonCategory,
      userReasonText: userReasonText,
      submitOptionalEvidence: submitOptionalEvidence,
    );
  }

  /// 等仓储事务提交后再通知页面重读；真正的事件时刻、序号由写事务确定。
  Future<ExecutionEvent> execute(ExecutionCommand command) async {
    // await 等待仓储的整个事务；抛异常时会直接离开，不执行下面的通知。
    final stopped = await repository.reconcileScheduledEnds();
    if (stopped.isNotEmpty) _notify();
    final event = await repository.execute(command);
    _notify();
    return event;
  }

  Future<void> startMakeup(
    MissionDetail original,
    String commandId, {
    DateTime? evidenceDeadlineAt,
  }) async {
    final store = repository;
    if (store is! MissionMakeupRepository) {
      throw UnsupportedError('当前仓储不支持现在补做');
    }
    await (store as MissionMakeupRepository).startMakeup(
      original,
      commandId,
      evidenceDeadlineAt: evidenceDeadlineAt,
    );
    _notify();
  }

  Future<OperationReceiptInfo> completeHistory(
    HistoricalCompletion request,
  ) async {
    final Object source = repository;
    if (source is! HistoricalCompletionRepository) {
      throw StateError('当前存储不支持历史补记');
    }
    final receipt = await source.completeHistory(request);
    _notify();
    return receipt;
  }

  Future<List<MissionDetail>> findActive() => repository.findActive();
  Future<List<MissionGoalChoices>> findGoalChoices() =>
      repository.findGoalChoices();
  Future<MissionOwnershipInfo?> findOwnershipInfo(MissionOwnership ownership) =>
      repository.findOwnershipInfo(ownership);
  Future<List<MissionDetail>> findForGoal(String goalId) async {
    await reconcileEvidenceDeadlines();
    return repository.findForGoal(goalId);
  }

  /// Agent 快照只读取事实，不触发截止补算或其他维护写入。
  Future<List<MissionDetail>> findForGoalSnapshot(String goalId) =>
      repository.findForGoal(goalId);

  Future<List<MissionDetail>> findFinishedSnapshot() =>
      repository.findFinished();

  Future<OperationReceiptInfo?> findOperationReceipt(String operationId) {
    final Object source = repository;
    if (source is MissionQueryRepository) {
      return source.findOperationReceipt(operationId);
    }
    return Future.value(null);
  }

  Future<List<MissionDetail>> findFinished() async {
    await reconcileEvidenceDeadlines();
    return repository.findFinished();
  }

  Future<List<MissionDetail>> findCancelled() => repository.findCancelled();

  /// 自动执行也从本服务进入仓储；提交后通知各页面重读。
  Future<List<String>> reconcileScheduledMissions() async {
    final changed = await repository.reconcileScheduledMissions();
    if (changed.isNotEmpty) _notify();
    return changed;
  }

  /// Android 后台引擎已提交事实后，让当前界面重新查询数据库。
  void refreshAfterExternalCommit() => _notify();

  /// “全部任务”复用详情事实及截止补算，不建立第二套阶段判断。
  Future<List<MissionDetail>> findAllDetails() async {
    await reconcileEvidenceDeadlines();
    return repository.findAllDetails();
  }

  Future<PlannedMissionSnapshot> findPlannedSnapshot() async {
    final Object source = repository;
    if (source is MissionQueryRepository) return source.findPlannedSnapshot();
    final all = await findAllDetails();
    return PlannedMissionSnapshot(
      hasRunning: all.any((detail) => detail.phase == MissionPhase.running),
      nextEndAt:
          (all
                  .map(
                    (detail) =>
                        scheduledExecutionEnd(detail.schedule, detail.events),
                  )
                  .whereType<DateTime>()
                  .toList()
                ..sort())
              .firstOrNull,
      candidates: [
        for (final detail in all)
          if (detail.phase == MissionPhase.notStarted &&
              detail.schedule.fixedStartAt != null)
            PlannedMissionPoint(
              start: detail.schedule.fixedStartAt!,
              end: detail.schedule.fixedStartAt!.add(
                Duration(minutes: detail.schedule.plannedDurationMinutes),
              ),
            ),
      ],
    );
  }

  Future<List<MissionDetail>> findReminderCandidates() async {
    final Object source = repository;
    if (source is MissionQueryRepository) {
      return source.findReminderCandidates();
    }
    return findAllDetails();
  }

  Future<({int total, int completed})> findGoalCoverage(
    String goalId,
    List<GoalNode> nodes,
  ) async {
    final Object source = repository;
    if (source is MissionQueryRepository) {
      return goalNodeCoverageFromIds(
        nodes,
        await source.findCompletedGoalNodeIds(goalId),
      );
    }
    return goalNodeCoverage(nodes, await findForGoal(goalId));
  }

  /// 查询前/恢复前台补算，不在纯阶段函数或 Focus 重绘中写事实。
  Future<int> reconcileEvidenceDeadlines() async {
    final count = await repository.reconcileEvidenceDeadlines();
    if (count > 0) _notify();
    return count;
  }

  Future<List<MissionDetail>> findPendingEvidence() async {
    await reconcileEvidenceDeadlines();
    return repository.findPendingEvidence();
  }

  EvidenceDraft createTextEvidence(
    String content, {
    EvidenceType type = EvidenceType.text,
    String? supersedesEvidenceId,
  }) {
    if (type != EvidenceType.text &&
        type != EvidenceType.code &&
        type != EvidenceType.manualRecord) {
      throw ArgumentError('该入口只创建文字、代码或手动记录');
    }
    return EvidenceDraft(
      id: uuid.v4(),
      type: type,
      source: EvidenceSource.user,
      content: content,
      supersedesEvidenceId: supersedesEvidenceId,
    );
  }

  Future<void> _initializeImages() async {
    try {
      // 缓存正在进行的恢复工作；并发点击也会等它完成，之后才允许创建新草稿。
      await (_imageInitialization ??= () async {
        final referenced = await repository.referencedAttachmentKeys();
        await _imageService.removeUnreferenced(referenced);
      }());
    } catch (_) {
      _imageInitialization = null; // 首次失败允许用户重试，不永久缓存失败 Future。
      rethrow;
    }
  }

  /// 编辑区显示时提前准备，系统选择按钮就绪后可直接保留浏览器用户激活。
  Future<void> initializeEvidenceImages() => _initializeImages();

  Future<EvidenceDraft?> pickEvidenceImage(
    String missionId, {
    String? supersedesEvidenceId,
  }) async {
    await _initializeImages();
    final prepared = await _imageService.pickAndPrepare(missionId);
    if (prepared == null) return null;
    _preparedImageKeys.add(prepared.storageKey);
    return EvidenceDraft(
      id: uuid.v4(),
      type: EvidenceType.image,
      source: EvidenceSource.fileSystem,
      attachmentStorageKey: prepared.storageKey,
      attachmentFileName: prepared.fileName,
      attachmentMimeType: prepared.mimeType,
      supersedesEvidenceId: supersedesEvidenceId,
    );
  }

  Future<EvidenceDraft?> pickEvidenceFile(
    String missionId, {
    String? supersedesEvidenceId,
  }) async {
    await _initializeImages();
    final prepared = await _imageService.pickFileAndPrepare(missionId);
    if (prepared == null) return null;
    _preparedImageKeys.add(prepared.storageKey);
    return EvidenceDraft(
      id: uuid.v4(),
      type: EvidenceType.file,
      source: EvidenceSource.fileSystem,
      attachmentStorageKey: prepared.storageKey,
      attachmentFileName: prepared.fileName,
      attachmentMimeType: prepared.mimeType,
      supersedesEvidenceId: supersedesEvidenceId,
    );
  }

  Future<EvidenceDraft> prepareEvidenceCameraImage(
    String missionId,
    Uint8List bytes, {
    required DateTime capturedAt,
  }) async {
    await _initializeImages();
    final prepared = await _imageService.prepareCapturedImage(missionId, bytes);
    _preparedImageKeys.add(prepared.storageKey);
    return EvidenceDraft(
      id: uuid.v4(),
      type: EvidenceType.image,
      source: EvidenceSource.camera,
      attachmentStorageKey: prepared.storageKey,
      attachmentFileName: prepared.fileName,
      attachmentMimeType: prepared.mimeType,
      capturedAt: capturedAt.toUtc(),
    );
  }

  Future<Uint8List> readEvidenceImage(String storageKey) =>
      _imageService.read(storageKey);

  Future<void> discardEvidenceDrafts(List<EvidenceDraft> items) =>
      _withAttachmentCommit(() async {
        final referenced = await repository.referencedAttachmentKeys();
        for (final item in items) {
          final key = item.attachmentStorageKey;
          if (key != null &&
              _preparedImageKeys.contains(key) &&
              !referenced.contains(key)) {
            await _imageService.delete(key);
            _preparedImageKeys.remove(key);
          }
        }
      });

  EvidenceSubmission prepareEvidenceSubmission({
    required MissionDetail detail,
    required List<EvidenceDraft> items,
  }) {
    if (items.isEmpty) throw ArgumentError('请至少添加一份有效材料');
    for (final item in items) {
      validateEvidenceDraft(item, detail.mission.id);
      if (item.supersedesEvidenceId != null) {
        throw ArgumentError('首次提交不能修正已有材料');
      }
    }
    return EvidenceSubmission(
      id: uuid.v4(),
      missionId: detail.mission.id,
      items: items,
    );
  }

  Future<EvidenceSubmissionResult> submitEvidence(
    EvidenceSubmission submission,
  ) => _withAttachmentCommit(() async {
    // 文件校验在事务前完成，SQLite 不等待系统选择器或复制文件。
    // 已保存批次重试交给仓储认原身份，缺失附件由材料阅读明确提示。
    final current = await repository.findDetail(submission.missionId);
    final alreadySaved =
        current?.evidence.any((item) => item.submissionId == submission.id) ??
        false;
    if (!alreadySaved) {
      for (final item in submission.items) {
        validateEvidenceDraft(item, submission.missionId);
        if (item.attachmentStorageKey != null) {
          await _imageService.read(item.attachmentStorageKey!);
        }
      }
    }
    final result = await repository.submitEvidence(submission);
    if (result == EvidenceSubmissionResult.submitted) {
      for (final item in submission.items) {
        _preparedImageKeys.remove(item.attachmentStorageKey);
      }
    }
    _notify();
    return result;
  });

  EvidenceCorrection prepareEvidenceCorrection({
    required MissionDetail detail,
    required Evidence original,
    required EvidenceDraft draft,
  }) {
    if (!detail.effectiveEvidence.any((item) => item.id == original.id) ||
        draft.supersedesEvidenceId != original.id ||
        draft.type != original.type) {
      throw const EvidenceConflict('只能修正当前有效的同类材料');
    }
    validateEvidenceDraft(draft, detail.mission.id);
    return EvidenceCorrection(missionId: detail.mission.id, item: draft);
  }

  Future<Evidence> correctEvidence(EvidenceCorrection correction) =>
      _withAttachmentCommit(() async {
        final current = await repository.findDetail(correction.missionId);
        final saved =
            current?.evidence.any((item) => item.id == correction.item.id) ??
            false;
        if (!saved) {
          validateEvidenceDraft(correction.item, correction.missionId);
          final key = correction.item.attachmentStorageKey;
          if (key != null) await _imageService.read(key);
        }
        final result = await repository.correctEvidence(correction);
        _preparedImageKeys.remove(correction.item.attachmentStorageKey);
        _notify();
        return result;
      });

  Future<void> skipOptionalEvidence(String missionId) async {
    await repository.skipOptionalEvidence(missionId);
    _notify();
  }

  /// 开始前编辑任务、材料要求和排期；原快照用于事务内的冲突检查。
  /// 页面只提供可编辑值，任务身份和已经发生的执行事实不能修改。
  /// 旧入口省略 verificationPolicy 时保留原材料配置；新表单传完整配置，空说明表示清空。
  Future<void> edit({
    required MissionDetail original,
    required String title,
    required String objective,
    required String scheduledDate,
    required int plannedDurationMinutes,
    required TimePolicy timePolicy,
    ExecutionPlanContent? content,
    DateTime? fixedStartAt,
    VerificationPolicy? verificationPolicy,
    String? verificationCriteria,
    MissionOwnership? ownership,
    String? description,
    String? why,
    bool updateContext = false,
    DateTime? evidenceDeadlineAt,
    String? operationId,
  }) async {
    final cleanTitle = title.trim();
    final cleanObjective = objective.trim();
    if (original.mission.id.trim().isEmpty || cleanTitle.isEmpty) {
      throw ArgumentError('任务编号和任务名称不能为空');
    }
    if (cleanObjective.isEmpty) {
      throw ArgumentError('具体目标不能为空');
    }
    _validateSchedule(
      scheduledDate: scheduledDate,
      timeZone: original.schedule.timeZone,
      plannedDurationMinutes: plannedDurationMinutes,
      timePolicy: timePolicy,
      fixedStartAt: fixedStartAt,
    );
    // 这里构造提案，不代表已经增加版本；仓储比较最新事实后才决定是否追加。
    final proposedSchedule = MissionScheduleRevision(
      id: uuid.v4(),
      missionId: original.mission.id,
      revisionNumber: original.schedule.revisionNumber + 1,
      scheduledDate: scheduledDate,
      timeZone: original.schedule.timeZone,
      plannedDurationMinutes: plannedDurationMinutes,
      timePolicy: timePolicy,
      fixedStartAt: fixedStartAt?.toUtc(),
      evidenceDeadlineAt: verificationPolicy == null
          ? original.schedule.evidenceDeadlineAt
          : evidenceDeadlineAt?.toUtc(),
      // 编辑时刻取服务注入时钟；执行事件时刻由仓储时钟在事务内提供。
      changedAt: _clock().toUtc(),
    );
    validateMissionSchedule(proposedSchedule);
    if (content != null) {
      validateExecutionPlanContent(content.steps, content.notes);
    }
    await repository.edit(
      original: original,
      title: cleanTitle,
      objective: cleanObjective,
      schedule: proposedSchedule,
      content: content,
      verificationPolicy: verificationPolicy,
      verificationCriteria: _clean(verificationCriteria),
      ownership: ownership,
      description: _clean(description),
      why: _clean(why),
      updateContext: updateContext,
      operationId: operationId,
    );
    _notify();
  }

  // 创建和编辑共用输入规则；时区与固定时刻在同一个入口校验。
  void _validateSchedule({
    required String scheduledDate,
    required String timeZone,
    required int plannedDurationMinutes,
    required TimePolicy timePolicy,
    required DateTime? fixedStartAt,
  }) {
    if (plannedDurationMinutes <= 0) {
      throw ArgumentError('计划时长必须大于 0 分钟');
    }
    validateScheduledDate(scheduledDate);
    final tz.Location location;
    try {
      location = tz.getLocation(timeZone);
    } on tz.LocationNotFoundException {
      throw ArgumentError('时区名称无效');
    }
    if (timePolicy == TimePolicy.fixed) {
      if (fixedStartAt == null) {
        throw ArgumentError('固定时间任务必须填写开始时刻');
      }
      final localStart = tz.TZDateTime.from(fixedStartAt, location);
      final parts = scheduledDate.split('-');
      if (localStart.year != int.parse(parts[0]) ||
          localStart.month != int.parse(parts[1]) ||
          localStart.day != int.parse(parts[2])) {
        throw ArgumentError('固定开始时刻必须属于所选计划日期');
      }
    } else if (fixedStartAt != null) {
      throw ArgumentError('自选时间任务不能包含固定开始时刻');
    }
  }

  /// 详情页传入当前任务编号；等待仓储事务完成，页面才能显示取消结果。
  Future<void> cancel({required String missionId, String? operationId}) async {
    if (missionId.trim().isEmpty) {
      throw ArgumentError('任务编号不能为空');
    }
    // 不使用页面之前读到的状态判断是否已取消；由仓储重读最新事实。
    await repository.cancel(missionId, operationId: operationId);
    _notify();
  }

  /// 一次创建入口；未提供归属时创建独立任务，关联目标和节点均为可选项。
  ///
  /// fixedStartAt 表达绝对时刻，保存前统一转 UTC；固定策略必须提供，
  /// 且在 timeZone 内属于 scheduledDate，自选策略则必须为空。
  /// 输入无效时以 ArgumentError 结束 Future，且不调用仓储。
  /// 仓储保存失败时继续向调用者传递异常；成功完成才表示三表事务已提交。
  Future<void> create({
    required String title,
    required String scheduledDate, // 例如 '2026-10-20'
    required String timeZone, // 例如 'Asia/Shanghai'
    required int plannedDurationMinutes,
    TimePolicy timePolicy = TimePolicy.flexible,
    DateTime? fixedStartAt,
    MissionDetail? retrySource,
    String? objective,
    List<String>? steps,
    String? notes,
    VerificationPolicy verificationPolicy = VerificationPolicy.selfReport,
    String? verificationCriteria,
    DateTime? evidenceDeadlineAt,
    MissionOwnership ownership = const MissionOwnership(),
    String? description,
    String? why,
  }) async {
    final request = prepareCreation(
      title: title,
      scheduledDate: scheduledDate,
      timeZone: timeZone,
      plannedDurationMinutes: plannedDurationMinutes,
      timePolicy: timePolicy,
      fixedStartAt: fixedStartAt,
      retrySource: retrySource,
      objective: objective,
      steps: steps,
      notes: notes,
      verificationPolicy: verificationPolicy,
      verificationCriteria: verificationCriteria,
      evidenceDeadlineAt: evidenceDeadlineAt,
      ownership: ownership,
      description: description,
      why: why,
    );
    await createPrepared(request);
  }

  /// 把表单值准备成一整份固定请求，交回表单保留；这里还没有写数据库。
  MissionCreation prepareCreation({
    required String title,
    required String scheduledDate,
    required String timeZone,
    required int plannedDurationMinutes,
    TimePolicy timePolicy = TimePolicy.flexible,
    DateTime? fixedStartAt,
    MissionDetail? retrySource,
    String? objective,
    List<String>? steps,
    String? notes,
    VerificationPolicy verificationPolicy = VerificationPolicy.selfReport,
    String? verificationCriteria,
    DateTime? evidenceDeadlineAt,
    MissionOwnership ownership = const MissionOwnership(),
    String? description,
    String? why,
    String? requestId,
  }) {
    ownership.validate(); // 检查编号组合；目标是否有效由保存事务重新读取后判断。
    // trim 去掉标题首尾空白；全是空格也算没填写。
    final cleanTitle = title.trim();
    final cleanObjective = (objective ?? cleanTitle).trim();

    if (cleanTitle.isEmpty) {
      throw ArgumentError('任务标题不能为空');
    }
    if (cleanObjective.isEmpty) throw ArgumentError('具体目标不能为空');

    _validateSchedule(
      scheduledDate: scheduledDate,
      timeZone: timeZone,
      plannedDurationMinutes: plannedDurationMinutes,
      timePolicy: timePolicy,
      fixedStartAt: fixedStartAt,
    );

    // 外部固定请求用确定性编号核对未知结果；普通表单仍使用随机 UUID。
    final missionId = requestId == null
        ? uuid.v4()
        : uuid.v5(Namespace.url.value, '$requestId:mission');
    final scheduleId = requestId == null
        ? uuid.v4()
        : uuid.v5(Namespace.url.value, '$requestId:schedule');
    final planId = requestId == null
        ? uuid.v4()
        : uuid.v5(Namespace.url.value, '$requestId:plan');
    // 同一次创建只取一次 now，让三个对象的创建时间一致；统一到毫秒精度。
    final now = DateTime.fromMillisecondsSinceEpoch(
      _clock().toUtc().millisecondsSinceEpoch,
      isUtc: true,
    );

    final mission = Mission(
      id: missionId,
      title: cleanTitle,
      description: _clean(description ?? retrySource?.mission.description),
      why: _clean(why ?? retrySource?.mission.why),
      goalId: ownership.goalId,
      goalNodeId: ownership.goalNodeId,
      sourceMissionId: retrySource?.mission.id,
      relationType: retrySource == null ? null : MissionRelationType.retry,
      verificationPolicy: verificationPolicy,
      createdAt: now,
      updatedAt: now,
    );

    final schedule = MissionScheduleRevision(
      id: scheduleId, // 固定请求可核对，普通创建保持随机编号。
      missionId: missionId, // 但所属任务编号与上面相同。
      revisionNumber: 1,
      scheduledDate: scheduledDate,
      timeZone: timeZone,
      timePolicy: timePolicy,
      fixedStartAt: fixedStartAt?.toUtc(),
      evidenceDeadlineAt: evidenceDeadlineAt?.toUtc(),
      plannedDurationMinutes: plannedDurationMinutes,
      changedAt: now,
    );

    final plan = ExecutionPlan(
      id: planId, // 同一创建请求的任务、排期和方案身份保持稳定。
      missionId: missionId,
      objective: cleanObjective, // 普通创建默认标题；再次尝试允许调整具体目标。
      steps: (steps ?? retrySource?.executionPlan.steps ?? const [])
          .map((step) => step.trim())
          .toList(),
      verificationCriteria: _clean(verificationCriteria),
      notes: _clean(notes ?? retrySource?.executionPlan.notes),
      createdAt: now,
      updatedAt: now,
    );

    // 三个业务对象准备完毕，先检查材料配置，再把完整请求交回表单保留。
    validateEvidenceRequirement(
      policy: verificationPolicy,
      criteria: plan.verificationCriteria,
      schedule: schedule,
    );
    final request = MissionCreation(
      mission: mission,
      schedule: schedule,
      plan: plan,
    );
    validateMissionCreation(request);
    return request;
  }

  /// 使用表单保留的请求保存；重复提交同一请求由仓储识别，成功后通知页面重读。
  Future<void> createPrepared(MissionCreation request) async {
    validateMissionCreation(request);
    await repository.create(
      mission: request.mission,
      initialSchedule: request.schedule,
      executionPlan: request.plan,
    );
    _notify();
  }

  /// 计划卡传入完整提案，只检查排期；最终保存仍会在事务内重新检查。
  Future<List<MissionPlanConflict>> checkPlan(MissionPlan plan) {
    _validatePlan(plan);
    final source = repository;
    if (source is! MissionPlanRepository) {
      throw StateError('当前任务存储不支持整份计划保存');
    }
    return (source as MissionPlanRepository).checkPlan(plan);
  }

  /// 一次提交只发一次页面刷新；事务失败时不产生部分任务或排期版本。
  Future<OperationReceiptInfo> applyPlan(MissionPlan plan) async {
    final source = repository;
    if (source is! MissionPlanRepository) {
      throw StateError('当前任务存储不支持整份计划保存');
    }
    _validatePlan(plan);
    final receipt = await (source as MissionPlanRepository).applyPlan(plan);
    _notify();
    return receipt;
  }

  void _validatePlan(MissionPlan plan) {
    for (final item in plan.items) {
      validateMissionSchedule(item.schedule);
      if (item.creation != null) validateMissionCreation(item.creation!);
      final original = item.original;
      if (original != null) {
        validateEvidenceRequirement(
          policy: original.mission.verificationPolicy,
          criteria: original.executionPlan.verificationCriteria,
          schedule: item.schedule,
        );
      }
    }
  }

  /// 检查 YYYY-MM-DD 日历日期，返回按仓储约定排序的查询结果。
  ///
  /// 无效输入以 ArgumentError 结束 Future，仓储错误继续向上传递。
  /// 今天页的 _loadMissions 提供所选日期，并等待此 Future 后显示结果。
  Future<List<ScheduledMission>> findScheduledOn({
    required String scheduledDate,
  }) async {
    validateScheduledDate(scheduledDate);
    // 这里只约束输入；读表和存储类型转换由真实仓储负责。
    await reconcileEvidenceDeadlines();
    final missions = await repository.findScheduledOn(scheduledDate);
    return missions;
  }

  Future<List<ScheduledMission>> findScheduledSnapshotOn({
    required String scheduledDate,
  }) {
    validateScheduledDate(scheduledDate);
    return repository.findScheduledOn(scheduledDate);
  }

  /// 按编号读取任务详情；不存在返回 null，读取或转换失败通过 Future 传出错误。
  ///
  /// missionId 来自用户点击的那条任务，不用标题或列表位置代替唯一编号。
  Future<MissionDetail?> findDetail({required String missionId}) async {
    if (missionId.trim().isEmpty) {
      throw ArgumentError('任务编号不能为空');
    }

    // 先通过业务入口补记必要的材料超时事实，再读取完整快照；阶段 getter 本身不写库。
    await reconcileEvidenceDeadlines();
    final detail = await repository.findDetail(missionId);
    if (detail != null) {
      // 页面需要按此时区换算时刻。无效时区在 Future 中报错，走页面的重试状态，
      // 避免等到 Widget 排版时才抛错，导致整个详情区域无法构建。
      tz.getLocation(detail.schedule.timeZone);
    }
    return detail;
  }

  Future<MissionDetail?> findDetailSnapshot({required String missionId}) {
    if (missionId.trim().isEmpty) {
      throw ArgumentError('任务编号不能为空');
    }
    return repository.findDetail(missionId);
  }

  String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
