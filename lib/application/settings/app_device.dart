import 'dart:typed_data';

/// 系统能力只描述查询结果，不把权限获准等同于提醒服务已经接通。
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.version,
    this.notifications,
    this.exactAlarms,
    this.android = false,
  });
  final String version;
  final bool? notifications;
  final bool? exactAlarms;
  final bool android;
}

abstract interface class AppDevice {
  Future<DeviceCapabilities> capabilities();
  Future<void> openSettings({required bool exactAlarms});
  // null 表示用户取消；浏览器返回下载交接说明，不声称文件已经保存。
  Future<String?> saveBackup(Uint8List bytes, String fileName);

}
