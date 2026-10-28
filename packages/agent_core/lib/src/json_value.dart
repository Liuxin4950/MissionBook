/// 复制并冻结 JSON 对象，防止外部在授权后偷偷改动工具参数。
Map<String, Object?> freezeJsonObject(Map<String, Object?> value) {
  return _freeze(value) as Map<String, Object?>;
}

Object? _freeze(Object? value) {
  if (value == null || value is String || value is bool) return value;
  if (value is num && value.isFinite) return value;
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_freeze));
  }
  if (value is Map<String, Object?>) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, item) => MapEntry(key, _freeze(item))),
    );
  }
  throw ArgumentError('工具参数和 Schema 必须只包含 JSON 值');
}
