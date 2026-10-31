/// 一次已提交写操作的幂等回执。
///
/// [kind] 与 [fingerprint] 识别同一业务请求，[resultJson] 保存可重放的结果；
/// 回执和业务事实在同一事务内提交，响应丢失后先按稳定调用身份核对。
class OperationReceiptInfo {
  const OperationReceiptInfo({
    required this.id,
    required this.kind,
    required this.fingerprint,
    required this.entityId,
    required this.resultJson,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String fingerprint;
  final String entityId;
  final String resultJson;
  final DateTime createdAt;
}
