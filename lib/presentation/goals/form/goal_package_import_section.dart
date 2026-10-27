import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../application/goals/goal_service.dart';
import '../../../application/goals/goal_package_import_service.dart';
import '../../../domain/entities/goal_package_import.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_text_field.dart';

/// 原导入区域内完成文件读取、分页预览和确认，支持恢复本机封存草稿。
class GoalPackageImportSection extends StatefulWidget {
  const GoalPackageImportSection({
    super.key,
    required this.goals,
    required this.onImported,
    this.onDraftChanged,
  });
  final GoalService goals;
  final ValueChanged<String> onImported;
  final VoidCallback? onDraftChanged;
  @override
  State<GoalPackageImportSection> createState() =>
      GoalPackageImportSectionState();
}

class GoalPackageImportSectionState extends State<GoalPackageImportSection> {
  final _input = TextEditingController();
  final _previousOffsets = <int>[];
  GoalImportPreview? _preview;
  GoalImportCancellation? _cancellation;
  Future<List<GoalImportEntry>>? _page;
  Map<String, String> _paths = {};
  String? _knownJobId;
  String? _error;
  String? _reviewError;
  String? _sourceName;
  String _progress = '';
  String _kind = 'MISSION';
  int _offset = 0;
  int _reviewGeneration = 0;
  bool _busy = false;
  bool _restoring = true;
  bool _reviewing = false;
  bool _unknown = false;
  bool _saved = false;
  bool _keepPast = false;
  bool _allowDue = false;
  bool _allowOverlaps = false;
  bool _settingInput = false;
  GoalPackageImportService get _service => widget.goals.packages!;
  GoalImportOptions get _options => GoalImportOptions(
    keepPastSchedules: _keepPast,
    allowDueAutoStart: _allowDue,
    allowOverlaps: _allowOverlaps,
  );

  @override
  void initState() {
    super.initState();
    _input.addListener(_changed);
    unawaited(_recover());
  }

  Future<void> _recover() async {
    try {
      final pending = await _service.stage.pending();
      final preview = await _service.recover();
      if (!mounted) return;
      _knownJobId = pending?['jobId'] as String?;
      if (preview != null) {
        await _showPreview(preview);
      } else if (pending != null) {
        setState(() => _error = '上次文件读取或校验未完成。请丢弃未完成草稿后重新选择文件。');
      }
    } catch (error) {
      if (mounted) setState(() => _error = '无法恢复导入草稿：$error');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _changed() {
    if (_settingInput || _busy || _unknown) return;
    setState(() {
      _preview = null;
      _page = null;
      _saved = false;
      _sourceName = null;
      _error = null;
      _reviewError = null;
      _reviewGeneration++;
    });
    widget.onDraftChanged?.call();
  }

  Future<bool> prepareToCollapse() async {
    if (_busy || _restoring) return false;
    if (_saved || _input.text.isEmpty && _knownJobId == null) return true;
    final keep = _preview != null || _unknown;
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: '离开目标导入？',
      message: keep
          ? '本机已保留这次预览，下次可继续确认。保存结果不明时仍使用同一次导入核对。'
          : '尚未校验的输入会丢失，已保存的目标和任务不受影响。',
      cancelText: '继续查看',
      confirmText: keep ? '保留预览并离开' : '放弃输入',
    );
    if (confirmed && !keep && _knownJobId != null) {
      await _service.discard(expectedJobId: _knownJobId);
    }
    return confirmed;
  }

  Future<void> _discard() async {
    if (_busy) return;
    try {
      await _service.discard(expectedJobId: _knownJobId);
      if (!mounted) return;
      setState(() {
        _knownJobId = null;
        _preview = null;
        _page = null;
        _unknown = false;
        _error = null;
        _reviewError = null;
        _reviewGeneration++;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _pick() async {
    if (_busy || _unknown || _restoring) return;
    _cancellation = GoalImportCancellation();
    setState(() {
      _busy = true;
      _error = null;
      _progress = '选择 JSON 文件';
    });
    try {
      // 先触发选择器，保留 Web 用户点击的激活时机；系统取消保留原预览。
      final source = await widget.goals.pickImportSource();
      if (!mounted || source == null) return;
      _cancellation!.check();
      _settingInput = true;
      _input.clear();
      _settingInput = false;
      await _prepare(source);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _validate() async {
    if (_busy || _unknown || _restoring) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _prepare(GoalImportSource.text(_input.text));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepare(GoalImportSource source) async {
    if (_knownJobId != null) {
      await _service.discard(expectedJobId: _knownJobId);
      _knownJobId = null;
    }
    _cancellation = GoalImportCancellation();
    setState(() {
      _preview = null;
      _page = null;
      _sourceName = source.name;
      _saved = false;
    });
    widget.onDraftChanged?.call();
    final preview = await _service.prepare(
      source,
      cancellation: _cancellation,
      onProgress: (message) {
        if (mounted) setState(() => _progress = message);
      },
    );
    if (!mounted) return;
    setState(() => _knownJobId = preview.jobId);
    await _showPreview(preview);
  }

  Future<void> _showPreview(GoalImportPreview preview) async {
    final paths = await _service.nodePaths(preview);
    if (!mounted) return;
    setState(() {
      _knownJobId = preview.jobId;
      _preview = preview;
      _paths = paths;
      _kind = preview.missionCount == 0 ? 'NODE' : 'MISSION';
      _offset = 0;
      _previousOffsets.clear();
      _page = _service.page(preview, _kind, 0);
      _error = null;
    });
    await _review();
  }

  Future<void> _review() async {
    final preview = _preview;
    if (preview == null) return;
    final generation = ++_reviewGeneration;
    setState(() {
      _reviewing = true;
      _reviewError = null;
    });
    String? failure;
    try {
      await _service.review(preview, _options);
    } catch (error) {
      failure = error.toString();
    }
    if (!mounted || generation != _reviewGeneration) return;
    setState(() {
      _reviewing = false;
      _reviewError = failure;
    });
  }

  Future<void> _commit() async {
    final preview = _preview;
    if (_busy || preview == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = '正在保存整包，全部成功后生效';
    });
    _cancellation = GoalImportCancellation();
    try {
      final result = await _service.commit(
        preview,
        _options,
        cancellation: _cancellation,
      );
      if (!mounted) return;
      setState(() {
        _saved = true;
        _unknown = false;
      });
      widget.onImported(result.goalId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _unknown =
            error is! GoalImportException &&
            error is! GoalImportCancelled &&
            error is! ArgumentError;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _turnPage(int offset, {bool previous = false}) {
    final preview = _preview!;
    setState(() {
      if (!previous) _previousOffsets.add(_offset);
      _offset = offset;
      _page = _service.page(preview, _kind, offset);
    });
  }

  String _time(Object? instant, Object? zone) {
    if (instant == null) return '';
    final local = tz.TZDateTime.from(
      DateTime.parse(instant as String),
      tz.getLocation(zone as String),
    );
    return local.toString().split('.').first;
  }

  Widget _entry(GoalImportEntry entry) {
    final raw = entry.raw;
    final values = entry.resolved;
    if (entry.kind == 'NODE') {
      return ListTile(
        title: Text((raw['title']! as String).trim()),
        subtitle: Text(
          [
            _paths[entry.key] ?? entry.key,
            if (raw['description'] != null) raw['description']! as String,
          ].join('\n'),
        ),
      );
    }
    final value = values!;
    final path = raw['nodeKey'] == null
        ? '直接属于目标'
        : _paths[raw['nodeKey']] ?? raw['nodeKey'];
    final at = value['fixedStartAt'];
    final deadline = value['evidenceDeadlineAt'];
    return ExpansionTile(
      key: ValueKey(entry.id),
      title: Text(value['title']! as String),
      subtitle: Text(
        '$path\n${at == null ? value['scheduledDate']! as String : _time(at, value['timeZone'])} · ${value['timePolicy'] == 'FIXED' ? '固定' : '自选'} · ${value['plannedDurationMinutes']} 分钟 · ${value['timeZone']! as String}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('具体目标：${value['objective']! as String}'),
        if (value['description'] != null)
          Text('说明：${value['description']! as String}'),
        if (value['why'] != null) Text('为什么：${value['why']! as String}'),
        for (final (index, step) in (value['steps']! as List).indexed)
          Text('${index + 1}. ${step as String}'),
        if (value['notes'] != null) Text('备注：${value['notes']! as String}'),
        Text(
          '材料要求：${switch (value['verificationPolicy']) {
            'REQUIRED_EVIDENCE' => '必须提交',
            'OPTIONAL_EVIDENCE' => '可选提交',
            _ => '仅自报',
          }}',
        ),
        if (value['verificationCriteria'] != null)
          Text('验收方向：${value['verificationCriteria']! as String}'),
        if (deadline != null)
          Text(
            '材料截止：${_time(deadline, value['timeZone'])}（${value['timeZone']! as String}）\nUTC：$deadline',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('导入目标与计划', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('支持原大纲和完整目标包。文件最多 32 MiB、10000 个任务；小段 JSON 可粘贴。'),
        const SizedBox(height: 12),
        AppTextField(
          key: const Key('goal-import-input'),
          label: 'JSON 内容',
          hint: '粘贴 JSON，或选择文件',
          controller: _input,
          readOnly: _busy || _unknown || _restoring,
          minLines: 3,
          maxLines: 6,
          inputFormatters: [
            TextInputFormatter.withFunction((old, next) {
              if (next.text.length > GoalImportLimits.pasteBytes ||
                  next.text.length > GoalImportLimits.pasteBytes ~/ 4 &&
                      utf8.encode(next.text).length >
                          GoalImportLimits.pasteBytes) {
                setState(() => _error = '粘贴超过 2 MiB，请选择文件；原输入已保留');
                return old;
              }
              return next;
            }),
          ],
        ),
        if (_sourceName != null) Text('来源：$_sourceName'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('goal-import-file'),
              onPressed: _busy || _unknown || _restoring ? null : _pick,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('选择 JSON 文件'),
            ),
            TextButton.icon(
              key: const Key('goal-import-preview'),
              onPressed: _busy || _unknown || _restoring ? null : _validate,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('校验并预览'),
            ),
            if (_knownJobId != null && !_unknown)
              TextButton(
                onPressed: _busy ? null : _discard,
                child: const Text('丢弃导入草稿'),
              ),
          ],
        ),
        if (_busy || _restoring) ...[
          const LinearProgressIndicator(),
          Semantics(
            liveRegion: true,
            child: Text(_restoring ? '检查本机导入草稿' : _progress),
          ),
          if (_busy && _cancellation != null)
            TextButton(
              onPressed: () => _cancellation!.cancel(),
              child: const Text('取消本次操作'),
            ),
        ],
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              key: const Key('goal-import-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (preview != null) ...[
          const Divider(height: 28),
          Text(preview.title, style: Theme.of(context).textTheme.titleMedium),
          if (preview.goal['description'] != null)
            Text(preview.goal['description']! as String),
          if (preview.goal['why'] != null)
            Text('为什么：${preview.goal['why']! as String}'),
          Text(
            '完整大纲 · ${preview.nodeCount} 个节点；${preview.missionCount} 个任务，共 ${preview.totalMinutes} 分钟',
          ),
          Text(
            '固定 ${preview.fixedCount} · 自选 ${preview.missionCount - preview.fixedCount} · 强制材料 ${preview.requiredCount} · 可选材料 ${preview.optionalCount}',
          ),
          if (preview.existingGoalId != null)
            const Text('此包已导入，确认会返回原目标，不重复创建。'),
          if (preview.duplicateGoalId != null && preview.existingGoalId == null)
            const Text('相同计划内容曾以其他包编号导入，本次确认将创建独立副本。'),
          if (preview.missionCount > 0) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('保留已过期计划（不补执行历史）'),
              value: _keepPast,
              onChanged: _busy || _unknown
                  ? null
                  : (value) {
                      setState(() => _keepPast = value!);
                      unawaited(_review());
                    },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('允许当前时段的固定任务导入后自动开始'),
              value: _allowDue,
              onChanged: _busy || _unknown
                  ? null
                  : (value) {
                      setState(() => _allowDue = value!);
                      unawaited(_review());
                    },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('允许固定计划重叠（同时仅一个任务运行）'),
              value: _allowOverlaps,
              onChanged: _busy || _unknown
                  ? null
                  : (value) {
                      setState(() => _allowOverlaps = value!);
                      unawaited(_review());
                    },
            ),
          ],
          if (_reviewError != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _reviewError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('任务'),
                selected: _kind == 'MISSION',
                onSelected: _busy || preview.missionCount == 0
                    ? null
                    : (_) => setState(() {
                        _kind = 'MISSION';
                        _offset = 0;
                        _previousOffsets.clear();
                        _page = _service.page(preview, _kind, 0);
                      }),
              ),
              ChoiceChip(
                label: const Text('节点'),
                selected: _kind == 'NODE',
                onSelected: _busy
                    ? null
                    : (_) => setState(() {
                        _kind = 'NODE';
                        _offset = 0;
                        _previousOffsets.clear();
                        _page = _service.page(preview, _kind, 0);
                      }),
              ),
            ],
          ),
          FutureBuilder<List<GoalImportEntry>>(
            key: ValueKey(preview.jobId + _kind + _offset.toString()),
            future: _page,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('无法读取预览：${snapshot.error}');
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final entries = snapshot.data!;
              final count = _kind == 'MISSION'
                  ? preview.missionCount
                  : preview.nodeCount;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in entries) _entry(entry),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _busy || _previousOffsets.isEmpty
                            ? null
                            : () {
                                final offset = _previousOffsets.removeLast();
                                _turnPage(offset, previous: true);
                              },
                        child: const Text('上一页'),
                      ),
                      Text(
                        '第 ${_offset + (entries.isEmpty ? 0 : 1)}–${_offset + entries.length} / $count',
                      ),
                      TextButton(
                        onPressed: _busy || _offset + entries.length >= count
                            ? null
                            : () => _turnPage(_offset + entries.length),
                        child: const Text('下一页'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('goal-import-confirm'),
            onPressed:
                _busy ||
                    _saved ||
                    _reviewing ||
                    !_unknown && _reviewError != null
                ? null
                : _commit,
            icon: const Icon(Icons.check),
            label: Text(
              _saved
                  ? '已导入目标'
                  : _unknown
                  ? '重试并确认原导入结果'
                  : preview.existingGoalId != null
                  ? '确认原导入结果'
                  : '确认创建目标与全部任务',
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    _input.dispose();
    super.dispose();
  }
}
