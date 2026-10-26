import 'dart:js_interop';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../../application/settings/app_device.dart';

AppDevice createAppDevice() => WebAppDevice();

class WebAppDevice implements AppDevice {
  @override
  Future<LocalProfile> readProfile() async {
    final saved = web.window.localStorage.getItem('mission_book.local_profile');
    if (saved == null) return const LocalProfile();
    return LocalProfile.fromJson(jsonDecode(saved) as Map<String, dynamic>);
  }

  @override
  Future<void> saveProfile(LocalProfile profile) async {
    web.window.localStorage.setItem(
      'mission_book.local_profile',
      jsonEncode(profile.cleaned().toJson()),
    );
  }

  @override
  Future<DeviceCapabilities> capabilities() async =>
      const DeviceCapabilities(version: '浏览器预览版');
  @override
  Future<void> openSettings({required bool exactAlarms}) async =>
      throw UnsupportedError('请在浏览器网站设置中管理权限');
  @override
  Future<String?> saveBackup(Uint8List bytes, String fileName) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/zip'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    // 浏览器下载异步消费 Blob，延迟回收；只确认交接，不确认实际保存。
    Future<void>.delayed(
      const Duration(minutes: 1),
      () => web.URL.revokeObjectURL(url),
    );
    return '已交给浏览器下载，请在下载列表确认保存结果';
  }
}
