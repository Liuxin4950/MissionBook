import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../application/settings/motion_settings.dart';

MotionSettings createMotionSettings({File? preferencesFile}) {
  Future<File> file() async =>
      preferencesFile ??
      File('${(await getApplicationSupportDirectory()).path}/page_motion.txt');
  return MotionSettings(
    read: () async {
      final saved = await file();
      return await saved.exists() ? saved.readAsString() : null;
    },
    write: (value) async {
      final saved = await file();
      await saved.parent.create(recursive: true);
      final temporary = File('${saved.path}.tmp');
      await temporary.writeAsString(value, flush: true);
      await temporary.rename(saved.path);
    },
  );
}
