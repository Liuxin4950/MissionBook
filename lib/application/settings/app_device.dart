import 'dart:typed_data';
import 'local_profile.dart';
export 'local_profile.dart';

enum DevicePlatform { android, windows, ios, macos, linux, web, other }

/// 系统能力只描述查询结果，不把权限获准等同于提醒服务已经接通。
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.version,
    this.notifications,
    this.exactAlarms,
    required this.platform,
    this.executionNotifications,
    this.islandSupported,
    this.focusPermission,
    this.focusConfigured,
  });
  final String version;
  final bool? notifications;
  final bool? exactAlarms;
  final DevicePlatform platform;
  final bool? executionNotifications;
  final bool? islandSupported;
  final bool? focusPermission;
  final bool? focusConfigured;
}

abstract interface class AppDevice {
  Future<LocalProfile> readProfile();
  Future<void> saveProfile(LocalProfile profile);
  Future<DeviceCapabilities> capabilities();
  Future<void> openSettings({required bool exactAlarms});
  // null 表示用户取消；浏览器返回下载交接说明，不声称文件已经保存。
  Future<String?> saveBackup(Uint8List bytes, String fileName);
}
