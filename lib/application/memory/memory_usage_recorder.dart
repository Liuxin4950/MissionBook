import 'dart:async';

import 'package:flutter/foundation.dart';

import 'memory_service.dart';

/// 注入与召回计数：节流后 best-effort 写入，失败只记录调试信息，不阻断发送。
class MemoryUsageRecorder {
  MemoryUsageRecorder(
    this.memory, {
    this.throttle = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final MemoryService memory;
  final Duration throttle;
  final DateTime Function() _clock;
  final _recent = <String, DateTime>{};
  final _pending = <Future<void>>{};

  /// 资源关闭前等待已提交的统计；发送路径不等待此方法。
  Future<void> drain() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }

  void record(List<String> ids, {required bool injected}) {
    final now = _clock();
    _recent.removeWhere((_, last) => now.difference(last) >= throttle);
    final fresh = <String>[];
    for (final id in ids.toSet()) {
      final key = '$id:${injected ? 'i' : 'r'}';
      final last = _recent[key];
      if (last != null && now.difference(last) < throttle) continue;
      _recent[key] = now;
      fresh.add(id);
    }
    if (fresh.isEmpty) return;
    // 延后调用也隔离同步异常，统计不占用发送的同步调用栈。
    late final Future<void> pending;
    pending = Future<void>(() async {
      try {
        await memory.recordUsage(ids: fresh, injected: injected);
      } catch (_) {
        debugPrint('记忆使用计数失败，已跳过本次统计');
      }
    }).whenComplete(() => _pending.remove(pending));
    _pending.add(pending);
  }
}
