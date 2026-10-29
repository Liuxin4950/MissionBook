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
