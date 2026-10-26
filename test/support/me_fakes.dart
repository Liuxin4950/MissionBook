import 'dart:typed_data';
import 'package:mission_book/application/backup/backup_service.dart';
import 'package:mission_book/application/settings/app_device.dart';

class TestBackup implements BackupExporter {
  @override
  Future<Uint8List> create() async => Uint8List(0);
}

class TestAppDevice implements AppDevice {
  LocalProfile profile = const LocalProfile();
  @override
  Future<LocalProfile> readProfile() async => profile;
  @override
  Future<void> saveProfile(LocalProfile value) async {
    profile = value.cleaned();
  }

  @override
  Future<DeviceCapabilities> capabilities() async => const DeviceCapabilities(
    version: '0.2.2 (4)',
    notifications: false,
    exactAlarms: true,
    android: true,
  );
  @override
  Future<void> openSettings({required bool exactAlarms}) async {}
  @override
  Future<String?> saveBackup(Uint8List bytes, String fileName) async => null;
}
