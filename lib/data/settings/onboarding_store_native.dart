import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../application/settings/onboarding_store.dart';

OnboardingStore createOnboardingStore() => _NativeOnboardingStore();

class _NativeOnboardingStore implements OnboardingStore {
  Future<File> _file() async => File(
    '${(await getApplicationSupportDirectory()).path}/onboarding_v1.txt',
  );

  @override
  Future<bool> readCompleted() async {
    final file = await _file();
    if (!await file.exists()) return false;
    return (await file.readAsString()).trim() == 'completed';
  }

  @override
  Future<void> markCompleted() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString('completed\n', flush: true);
    await temporary.rename(file.path);
  }
}
