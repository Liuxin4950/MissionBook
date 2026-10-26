import 'package:flutter/services.dart';

/// Android AlarmManager 的窄桥接：系统只保存下一次唤醒，不保存任务阶段。
class PlannedAlarmBridge {
  static const channel = MethodChannel('mission_book/plans');

  int? _token;
  Future<void> beginSync() async {
    _token = await channel.invokeMethod<int>('beginSync');
  }

  Future<void> schedule(DateTime? next) => channel.invokeMethod<void>(
    'schedule',
    {'at': next?.millisecondsSinceEpoch, 'token': _token},
  );

  void listenForCommits(void Function() onCommitted) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'factsChanged') onCommitted();
    });
  }

  void dispose() => channel.setMethodCallHandler(null);
}
