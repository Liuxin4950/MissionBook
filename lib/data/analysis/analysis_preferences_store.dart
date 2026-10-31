import '../../domain/entities/analysis_scope.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../application/analysis/analysis_preferences.dart';

/// 本机自动总结选项沿用现有设置存储，不增加业务表或队列。
class SecureAnalysisPreferences implements AnalysisPreferencesStore {
  const SecureAnalysisPreferences({
    this.storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  });
  final FlutterSecureStorage storage;
  static const key = 'assistant_analysis_automatic_scopes';
  @override
  Future<Set<AnalysisScope>> load() async {
    final value = await storage.read(key: key);
    if (value == null) return {...summaryScopes};
    final decoded = jsonDecode(value);
    if (decoded is! List) throw const FormatException('自动总结设置无效');
    return decoded
        .cast<String>()
        .map(AnalysisScope.parse)
        .where(summaryScopes.contains)
        .toSet();
  }

  @override
  Future<void> save(Set<AnalysisScope> scopes) => storage.write(
    key: key,
    value: jsonEncode(
      scopes.where(summaryScopes.contains).map((scope) => scope.name).toList()
        ..sort(),
    ),
  );
}
