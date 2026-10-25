import 'dart:convert';

/// 提醒/通知种类（规格《数据落地与平台》§7.1–7.2，不增不减）。
///
/// 材料截止不发系统通知（到点只做事实补算），每日回顾等无规格依据的不做。
enum ReminderKind {
  /// 开始提醒：FIXED 未开始任务到计划时刻，按钮「开始 / 延后 15 分钟」。
  startReminder,

  /// 执行通知（执行中）：标题 + Focus 摘要 +「停止」。
  executionRunning,

  /// 执行通知（暂停中）：标题 + Focus 摘要 +「继续」。
  executionPaused,
}

/// 系统提醒的投影内容：由任务事实与提醒偏好生成，只读，不写回业务表。
///
/// payload 带 Mission ID、所依据的排期版本/执行 sequence，以及各动作的
/// 稳定候选事件 id（§7.2）：重复回调共用同一身份按领域规则幂等，
/// 旧 sequence 的延迟按钮会被拒绝并提示刷新。
class ReminderRequest {
  const ReminderRequest({
    required this.idempotencyKey,
    required this.notificationId,
    required this.missionId,
    required this.scheduleRevisionId,
    required this.kind,
    required this.title,
    required this.body,
    required this.expectedSequence,
    required this.candidateEventIds,
    this.scheduledFor,
  });

  /// 幂等键 `mission-<id>-<kind>-<scheduleRevisionId>`：改期换键，杜绝旧延后沿用。
  final String idempotencyKey;

  /// 稳定的通知 id（由 ReminderStore 分配并持久化，重排=同 id 覆盖）。
  final int notificationId;

  final String missionId;
  final String scheduleRevisionId;
  final ReminderKind kind;

  /// 通知标题与正文：由阶段与事件投影，文案不进业务表。
  final String title;
  final String body;

  /// 生成本提醒时任务的执行序号；动作执行前校验，旧按钮只提示刷新。
  final int expectedSequence;

  /// 各动作的稳定候选事件 id（动作名 → 事件 id），重试复用。
  final Map<String, String> candidateEventIds;

  /// 计划触发时刻（UTC）；空表示立即显示（补发/执行通知）。
  final DateTime? scheduledFor;

  String toPayload() => jsonEncode({
    'missionId': missionId,
    'scheduleRevisionId': scheduleRevisionId,
    'kind': kind.name,
    'expectedSequence': expectedSequence,
    'candidateEventIds': candidateEventIds,
    'idempotencyKey': idempotencyKey,
    'notificationId': notificationId,
  });

  static ReminderRequest? fromPayload(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final kind = ReminderKind.values.asNameMap()[json['kind']];
      if (kind == null) return null;
      return ReminderRequest(
        idempotencyKey: json['idempotencyKey'] as String,
        notificationId: json['notificationId'] as int,
        missionId: json['missionId'] as String,
        scheduleRevisionId: json['scheduleRevisionId'] as String,
        kind: kind,
        title: '',
        body: '',
        expectedSequence: json['expectedSequence'] as int,
        candidateEventIds: {
          for (final entry
              in (json['candidateEventIds'] as Map<String, dynamic>).entries)
            entry.key: entry.value as String,
        },
      );
    } on Object {
      // 设置损坏按“无 payload”处理，调用方提示可能丢失偏好（§7.1）。
      return null;
    }
  }
}
