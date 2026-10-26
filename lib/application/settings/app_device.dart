import 'dart:typed_data';
import 'local_profile.dart';
export 'local_profile.dart';

/// 系统能力只描述查询结果，不把权限获准等同于提醒服务已经接通。
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.version,
    this.notifications,
    this.exactAlarms,
    this.android = false,
    this.executionNotifications,
    this.islandSupported,
    this.focusPermission,
  });
  final String version;
  final bool? notifications;
  final bool? exactAlarms;
  final bool android;
  final bool? executionNotifications;
  final bool? islandSupported;
  final bool? focusPermission;
}

abstract interface class AppDevice {
  Future<LocalProfile> readProfile();
  Future<void> saveProfile(LocalProfile profile);
  Future<DeviceCapabilities> capabilities();
  Future<void> openSettings({required bool exactAlarms});
  // null 表示用户取消；浏览器返回下载交接说明，不声称文件已经保存。
  Future<String?> saveBackup(Uint8List bytes, String fileName);
}
