import 'package:web/web.dart' as web;

import '../../application/settings/motion_settings.dart';

MotionSettings createMotionSettings() => MotionSettings(
  read: () async => web.window.localStorage.getItem('mission_book.page_motion'),
  write: (value) async =>
      web.window.localStorage.setItem('mission_book.page_motion', value),
);
