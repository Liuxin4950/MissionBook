import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/settings/app_device.dart';
import 'package:mission_book/data/settings/app_device_native.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('mission-profile-');
    file = File('${directory.path}/local_profile.json');
  });
  tearDown(() => directory.delete(recursive: true));

  test('本机资料独立保存，重新创建读取器仍能读到；空称呼不覆盖已有资料', () async {
    final device = NativeAppDevice(profileFile: file);
    expect((await device.readProfile()).name, '本机使用者');
    await device.saveProfile(
      const LocalProfile(name: '  小林  ', bio: '  每天进步一点  '),
    );
    final reloaded = await NativeAppDevice(profileFile: file).readProfile();
    expect(reloaded.name, '小林');
    expect(reloaded.bio, '每天进步一点');
    await expectLater(
      device.saveProfile(const LocalProfile(name: ' ')),
      throwsArgumentError,
    );
    expect((await device.readProfile()).name, '小林');
  });

  test('损坏资料明确失败，不静默覆盖；写入失败保留已有文件', () async {
    await file.writeAsString('损坏内容');
    final device = NativeAppDevice(profileFile: file);
    await expectLater(device.readProfile(), throwsFormatException);
    expect(await file.readAsString(), '损坏内容');
    await device.saveProfile(const LocalProfile(name: '原资料'));
    await Directory('${file.path}.tmp').create();
    await expectLater(
      device.saveProfile(const LocalProfile(name: '新资料')),
      throwsA(isA<FileSystemException>()),
    );
    expect((await device.readProfile()).name, '原资料');
  });
}
