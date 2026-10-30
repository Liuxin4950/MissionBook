import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:drift/drift.dart';
import '../../application/web/web_service.dart';
import '../assistant/assistant_settings_store.dart';
import '../local/app_database.dart';

class SecureWebSettings implements WebSettingsStore {
  const SecureWebSettings();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  @override
  Future<String?> key() => const SecureAssistantSettingsStore()
      .resolveCredential('MISSIONBOOK_TAVILY_API_KEY');
  @override
  Future<int> limit() async =>
      (int.tryParse(
                await _storage.read(key: 'assistant_search_monthly_limit') ??
                    '1000',
              ) ??
              1000)
          .clamp(0, 1000);
  @override
  Future<void> save(String? key, int limit) async {
    if (limit < 0 || limit > 1000) throw ArgumentError('本地月度上限为0～1000');
    if (key != null) {
      await const SecureAssistantSettingsStore().saveCredential(
        'MISSIONBOOK_TAVILY_API_KEY',
        key,
      );
    }
    await _storage.write(
      key: 'assistant_search_monthly_limit',
      value: '$limit',
    );
  }
}

class DriftSearchQuota implements SearchQuotaStore {
  DriftSearchQuota(this.db);
  final AppDatabase db;
  @override
  Future<bool> reserve(String month, int limit) => db.transaction(() async {
    await db.customStatement(
      'INSERT OR IGNORE INTO search_usage(month,credits) VALUES(?,0)',
      [month],
    );
    final changed = await db.customUpdate(
      'UPDATE search_usage SET credits=credits+1 WHERE month=? AND credits<?',
      variables: [Variable.withString(month), Variable.withInt(limit)],
    );
    return changed == 1;
  });
  @override
  Future<int> used(String month) async =>
      (await (db.select(
        db.searchUsage,
      )..where((t) => t.month.equals(month))).getSingleOrNull())?.credits ??
      0;
  @override
  Future<void> exhaust(String month, int limit) async {
    await db.customStatement(
      'UPDATE search_usage SET credits=MAX(credits,?) WHERE month=?',
      [limit, month],
    );
  }
}
