import 'package:drift/native.dart';
import '../local/app_database.dart';

Future<AppDatabase> openBackupValidationDatabase() async =>
    AppDatabase(executor: NativeDatabase.memory());
