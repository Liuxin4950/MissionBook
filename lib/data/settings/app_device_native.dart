import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:path_provider/path_provider.dart';
import '../../application/settings/app_device.dart';

AppDevice createAppDevice() => NativeAppDevice();

class NativeAppDevice implements AppDevice {
  static const _channel = MethodChannel('mission_book/device');

  @override
  Future<DeviceCapabilities> capabilities() async {
    if (!Platform.isAndroid && !Platform.isWindows) {
      return const DeviceCapabilities(version: '当前平台无法读取版本');
    }
    final value = (await _channel.invokeMapMethod<String, dynamic>(
      'capabilities',
    ))!;
    return DeviceCapabilities(
      version: value['version'] as String,
      notifications: value['notifications'] as bool?,
      exactAlarms: value['exactAlarms'] as bool?,
      android: Platform.isAndroid,
    );
  }

  @override
  Future<void> openSettings({required bool exactAlarms}) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>(
        exactAlarms ? 'exactAlarmSettings' : 'notificationSettings',
      );
    } else if (Platform.isWindows) {
      final result = await Process.run('explorer.exe', [
        'ms-settings:notifications',
      ]);
      if (result.exitCode != 0) throw StateError('无法打开系统通知设置');
    } else {
      throw UnsupportedError('请在系统设置中管理通知权限');
    }
  }

  @override
  Future<String?> saveBackup(Uint8List bytes, String fileName) async {
    if (Platform.isAndroid) {
      final root = await getTemporaryDirectory();
      final directory = await root.createTemp('mission-book-backup-');
      final file = File('${directory.path}/$fileName');
      try {
        await file.writeAsBytes(bytes, flush: true);
        return await _channel.invokeMethod<String>('saveBackup', {
          'path': file.path,
          'name': fileName,
        });
      } finally {
        await directory.delete(recursive: true);
      }
    }
    final location = await FileSelectorPlatform.instance.getSaveLocation(
      options: SaveDialogOptions(suggestedName: fileName),
      acceptedTypeGroups: [
        const XTypeGroup(label: 'ZIP 备份', extensions: ['zip']),
      ],
    );
    if (location == null) return null;
    await XFile.fromData(
      bytes,
      mimeType: 'application/zip',
      name: fileName,
    ).saveTo(location.path);
    return '已保存到 ${location.path}';
  }
}
