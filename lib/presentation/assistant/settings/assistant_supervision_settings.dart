import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/errors/user_error_message.dart';
import '../../widgets/app_section_card.dart';

/// 管理本机的应用使用授权和运行状态，不配置模型。
class AssistantSupervisionSettings extends StatefulWidget {
  const AssistantSupervisionSettings({super.key});

  @override
  State<AssistantSupervisionSettings> createState() =>
      _AssistantSupervisionSettingsState();
}

class _AssistantSupervisionSettingsState
    extends State<AssistantSupervisionSettings>
    with WidgetsBindingObserver {
  static const _device = MethodChannel('mission_book/device');
  Map<String, Object?>? _state;
  String? _error;
  bool _busy = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_read());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_read());
  }

  Future<void> _read() async {
    final revision = ++_revision;
    try {
      final state = await _device.invokeMapMethod<String, Object?>(
        'observationStatus',
      );
      if (mounted && revision == _revision) setState(() => _state = state);
    } catch (error) {
      if (mounted && revision == _revision && _state == null) {
        setState(() => _error = userErrorMessage(error, fallback: '无法读取授权状态'));
      }
    }
  }

  Future<void> _apply({
    bool? enabled,
    bool? paused,
    bool authorize = false,
  }) async {
    if (_busy) return;
    _revision++;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (enabled != null || paused != null) {
        final state = await _device
            .invokeMapMethod<String, Object?>('configureObservation', {
              if (enabled != null) 'enabled': enabled,
              if (paused != null) 'paused': paused,
            });
        if (mounted) setState(() => _state = state);
      }
      if (mounted && authorize && _state?['granted'] != true) {
        await _device.invokeMethod<void>('requestUsageAccess');
      }
    } catch (error) {
      if (mounted)
        setState(() => _error = userErrorMessage(error, fallback: '应用感知设置未生效'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        unawaited(_read());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _state?['enabled'] == true;
    final granted = _state?['granted'] == true;
    final paused = _state?['paused'] == true;
    final ready = !_busy && _state != null;
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.query_stats_rounded),
            title: const Text('应用使用情况'),
            subtitle: const Text('悬浮聊天会向当前模型提供 App 名称和估算停留时间。'),
            value: enabled,
            onChanged: ready
                ? (value) => _apply(enabled: value, authorize: value)
                : null,
          ),
          if (enabled)
            TextButton.icon(
              icon: Icon(
                !granted
                    ? Icons.lock_open
                    : paused
                    ? Icons.play_arrow
                    : Icons.pause,
              ),
              label: Text(
                !granted
                    ? '授权应用使用情况'
                    : paused
                    ? '恢复应用感知'
                    : '暂停应用感知',
              ),
              onPressed: ready
                  ? () => _apply(
                      authorize: !granted,
                      paused: granted ? !paused : null,
                    )
                  : null,
            ),
          if (_error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
