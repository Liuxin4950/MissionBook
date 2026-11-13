import '../../application/memory/memory_settings.dart';
import '../local/app_database.dart';

class DriftMemorySettingsStore implements MemorySettingsStore {
  const DriftMemorySettingsStore(this.db);
  final AppDatabase db;

  static const extractionKey = 'memory.extraction.enabled';

  @override
  Future<bool> extractionEnabled() async {
    final row = await (db.select(
      db.appSettings,
    )..where((t) => t.key.equals(extractionKey))).getSingleOrNull();
    return row?.value != '0';
  }

  @override
  Future<void> saveExtractionEnabled(bool enabled) => db
      .into(db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          key: extractionKey,
          value: enabled ? '1' : '0',
          updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      );
}
