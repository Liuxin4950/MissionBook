import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

import '../local/app_database.dart';

Future<AppDatabase> openBackupValidationDatabase() async {
  final sqlite = await WasmSqlite3.loadFromUrl(
    Uri.base.resolve('sqlite3.wasm'),
  );
  sqlite.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
  return AppDatabase(executor: WasmDatabase.inMemory(sqlite));
}
