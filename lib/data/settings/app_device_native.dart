import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:path_provider/path_provider.dart';
import '../../application/settings/app_device.dart';

AppDevice createAppDevice() => NativeAppDevice();

class NativeAppDevice implements AppDevice {
  NativeAppDevice({File? profileFile}) : _profileOverride = profileFile;
  final File? _profileOverride;
  static const _channel = MethodChannel('mission_book/device');

  // 使用独立偏好文件，避免与后台提醒进程同时写 reminders.json。
  Future<File> _profileFile() async {
    if (_profileOverride != null) return _profileOverride;
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/local_profile.json');
  }

  @override
  Future<LocalProfile> readProfile() async {
    final file = await _profileFile();
    if (!await file.exists()) return const LocalProfile();
    return LocalProfile.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> saveProfile(LocalProfile profile) async {
    final cleaned = profile.cleaned();
    final file = await _profileFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(cleaned.toJson()), flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<DeviceCapabilities> capabilities() async {
    final platform = Platform.isAndroid
        ? DevicePlatform.android
        : Platform.isWindows
        ? DevicePlatform.windows
        : Platform.isIOS
        ? DevicePlatform.ios
        : Platform.isMacOS
        ? DevicePlatform.macos
        : Platform.isLinux
        ? DevicePlatform.linux
        : DevicePlatform.other;
    if (!Platform.isAndroid && !Platform.isWindows) {
      return DeviceCapabilities(version: '当前平台无法读取版本', platform: platform);
    }
    final value = (await _channel.invokeMapMethod<String, dynamic>(
      'capabilities',
    ))!;
    return DeviceCapabilities(
      version: value['version'] as String,
      notifications: value['notifications'] as bool?,
      exactAlarms: value['exactAlarms'] as bool?,
      android: Platform.isAndroid,
      platform: platform,
      executionNotifications: value['executionNotifications'] as bool?,
      islandSupported: value['islandSupported'] as bool?,
      focusPermission: value['focusPermission'] as bool?,
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
