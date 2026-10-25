import '../entities/evidence.dart';
import '../entities/mission.dart';
import '../entities/mission_schedule_revision.dart';

/// 只检查材料本身；任务是否待补、是否超时仍由取得写权限后的事务决定。
void validateEvidenceDraft(EvidenceDraft item, String missionId) {
  if (item.id.trim().isEmpty) throw ArgumentError('材料编号不能为空');
  if (item.capturedAt != null && !item.capturedAt!.isUtc) {
    throw ArgumentError('材料产生时刻必须使用 UTC');
  }
  switch (item.type) {
    case EvidenceType.text:
    case EvidenceType.code:
    case EvidenceType.manualRecord:
      if (item.source != EvidenceSource.user ||
          (item.content?.trim().isEmpty ?? true)) {
        throw ArgumentError('请填写材料内容');
      }
      if (item.attachmentStorageKey != null ||
          item.attachmentFileName != null ||
          item.attachmentMimeType != null) {
        throw ArgumentError('文字、代码和手动记录不能包含附件引用');
      }
    case EvidenceType.image:
    case EvidenceType.file:
      final key = item.attachmentStorageKey;
      // 只允许本任务自己的平铺附件键。UUID 由准备入口提供，不允许盘符或 ../。
      if ((item.source != EvidenceSource.fileSystem &&
              !(item.type == EvidenceType.image &&
                  item.source == EvidenceSource.camera)) ||
          key == null ||
          !key.startsWith('attachments/$missionId/') ||
          key.split('/').length != 3 ||
          key.contains('..') ||
          key.contains('\\') ||
          key.contains(':') ||
          key.endsWith('/') ||
          (item.attachmentFileName?.trim().isEmpty ?? true)) {
        throw ArgumentError('附件引用无效，请重新选择文件');
      }
  }
}

/// 可选材料允许轻量记录；只有强制材料需要事先说清验收方向与期限。
void validateEvidenceRequirement({
  required VerificationPolicy policy,
  required String? criteria,
  required MissionScheduleRevision schedule,
}) {
  if (policy == VerificationPolicy.requiredEvidence) {
    if (criteria == null || criteria.trim().isEmpty) {
      throw ArgumentError('请填写必须提交什么材料');
    }
    final deadline = schedule.evidenceDeadlineAt;
    if (deadline == null || !deadline.isUtc) {
      throw ArgumentError('强制材料必须设置有效截止时间');
    }
    if (schedule.fixedStartAt != null &&
        !deadline.isAfter(schedule.fixedStartAt!)) {
      throw ArgumentError('材料截止必须晚于任务开始时刻');
    }
  } else if (schedule.evidenceDeadlineAt != null) {
    throw ArgumentError('只有强制材料任务设置材料截止时间');
  }
}
