import 'package:flutter/foundation.dart';

enum MotionPreference { system, full, reduced }

/// 本机动效选择；保存成功后才通知页面，不改变操作系统的辅助功能设置。
class MotionSettings extends ChangeNotifier {
  MotionSettings({required this.read, required this.write});

  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  MotionPreference preference = MotionPreference.system;
  bool saving = false;
  String? error;
  bool _disposed = false;
  int _generation = 0;

  bool reduceMotion(bool systemReduced) => switch (preference) {
    MotionPreference.system => systemReduced,
    MotionPreference.full => false,
    MotionPreference.reduced => true,
  };

  Future<void> load() async {
    final generation = ++_generation;
    try {
      final value = await read();
      if (_disposed || generation != _generation) return;
      preference = MotionPreference.values.firstWhere(
        (item) => item.name == value,
        orElse: () => MotionPreference.system,
      );
      error = null;
    } catch (exception, stack) {
      debugPrint('读取动效偏好失败：$exception\n$stack');
      if (_disposed || generation != _generation) return;
      error = '无法读取页面动效设置，当前跟随系统';
    }
    notifyListeners();
  }

  Future<void> select(MotionPreference value) async {
    if (saving || preference == value) return;
    _generation++;
    saving = true;
    error = null;
    notifyListeners();
    try {
      await write(value.name);
      if (_disposed) return;
      preference = value;
    } catch (exception, stack) {
      debugPrint('保存动效偏好失败：$exception\n$stack');
      if (_disposed) return;
      error = '页面动效设置未保存，请重试';
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
