import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../application/goals/goal_service.dart';
import '../../../application/goals/goal_package_import_service.dart';
import '../../../domain/entities/goal_package_import.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_expansion.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_section_card.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_layout.dart';

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
  String? _reviewCode;
  bool _pasteOpen = false;
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
  final bool _keepPast = true;
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
      debugPrint('恢复导入草稿失败：$error');
      if (mounted) setState(() => _error = '暂时无法读取上次的导入草稿，请关闭后重试。');
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
      if (mounted) setState(() => _error = _errorText(error));
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
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _validate() async {
    if (_busy || _unknown || _restoring || _input.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _prepare(GoalImportSource.text(_input.text));
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
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
      _reviewCode = null;
    });
    String? failure;
    String? failureCode;
    try {
      await _service.review(preview, _options);
    } catch (error) {
      failure = _errorText(error);
      failureCode = error is GoalImportException ? error.code : null;
    }
    if (!mounted || generation != _reviewGeneration) return;
    setState(() {
      _reviewing = false;
      _reviewError = failure;
      _reviewCode = failureCode;
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
        _error = _errorText(error);
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (raw['title']! as String).trim(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              [
                _paths[entry.key] ?? entry.key,
                if (raw['description'] != null) raw['description']! as String,
              ].join('\n'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    final value = values!;
    final path = raw['nodeKey'] == null
        ? '直接属于目标'
        : _paths[raw['nodeKey']] ?? raw['nodeKey'];
    final at = value['fixedStartAt'];
    final deadline = value['evidenceDeadlineAt'];
    return AppExpansionTile(
      key: ValueKey(entry.id),
      title: Text(value['title']! as String),
      subtitle: Text(
        '${at == null ? value['scheduledDate']! as String : _time(at, value['timeZone'])} · ${value['plannedDurationMinutes']} 分钟',
      ),
      insetHeader: false,
      headerPadding: const EdgeInsets.symmetric(vertical: AppLayout.spaceSm),
      childrenPadding: const EdgeInsets.only(bottom: AppLayout.spaceLg),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$path'),
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

  static const _outlineExample = '''{
  "schema": "mission-book.goal-outline",
  "version": 1,
  "goal": {"title": "目标名称"},
  "nodes": [{"key": "stage-1", "title": "阶段名称", "children": []}]
}''';

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppLayout.spaceSm,
            runSpacing: AppLayout.spaceSm,
            children: [
              for (final (index, label) in ['选择内容', '检查预览', '确认导入'].indexed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.spaceMd,
                    vertical: AppLayout.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (_saved
                                ? 2
                                : preview != null
                                ? 1
                                : 0) ==
                            index
                        ? AppColors.primarySoft
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppLayout.radiusMd),
                  ),
                  child: Text(
                    '${index + 1}  $label',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color:
                          (_saved
                                  ? 2
                                  : preview != null
                                  ? 1
                                  : 0) ==
                              index
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppLayout.spaceXl),
          if (preview == null) ...[
            FilledButton.tonalIcon(
              key: const Key('goal-import-file'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppLayout.topBarHeight),
              ),
              onPressed: _busy || _unknown || _restoring ? null : _pick,
              icon: const Icon(
                Icons.upload_file_outlined,
                size: AppLayout.iconLg,
              ),
              label: const Text('选择课表或目标文件'),
            ),
            const SizedBox(height: AppLayout.spaceMd),
            Text(
              '支持 MissionBook 目标大纲或目标计划 JSON。文件读取后先预览，确认后才保存。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppLayout.spaceMd),
            AppExpansionTile(
              key: const Key('goal-import-paste-toggle'),
              title: const Text('粘贴 JSON'),
              onExpansionChanged: (value) => setState(() => _pasteOpen = value),
              childrenPadding: const EdgeInsets.only(top: AppLayout.spaceMd),
              children: [
                AppTextField(
                  key: const Key('goal-import-input'),
                  label: 'JSON 内容',
                  hint: '粘贴目标或课表 JSON',
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
                        setState(() => _error = '内容较大，请选择文件');
                        return old;
                      }
                      return next;
                    }),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceSm),
                FilledButton.icon(
                  key: const Key('goal-import-preview'),
                  onPressed:
                      _busy ||
                          _unknown ||
                          _restoring ||
                          _input.text.trim().isEmpty
                      ? null
                      : _validate,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('预览内容'),
                ),
              ],
            ),
            if (!_pasteOpen)
              Text(
                'JSON · 最多 32 MB',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(
                _sourceName ?? '已保存的导入草稿',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: _busy || _unknown ? null : _discard,
                child: const Text('更换'),
              ),
            ),
          ],
          if (preview == null)
            AppExpansionTile(
              key: const Key('goal-import-format-help'),
              title: const Text('查看支持的格式'),
              childrenPadding: const EdgeInsets.only(
                top: AppLayout.spaceMd,
                bottom: AppLayout.spaceLg,
              ),
              children: [
                const Text(
                  '普通文本、Excel 或任意 JSON 不能直接导入。下面是目标大纲的最小格式；课表请使用 MissionBook 课表导出文件。',
                ),
                const SizedBox(height: AppLayout.spaceMd),
                const SelectableText(_outlineExample),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: _outlineExample),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('格式示例已复制')));
                    }
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('复制格式示例'),
                ),
              ],
            ),
          if (_knownJobId != null && preview == null && !_unknown)
            TextButton(
              onPressed: _busy ? null : _discard,
              child: const Text('丢弃未完成草稿'),
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
            Padding(
              padding: const EdgeInsets.only(top: AppLayout.spaceLg),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(AppLayout.spaceLg),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(AppLayout.radiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '导入尚未完成',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: AppLayout.spaceSm),
                      Text(
                        _error!,
                        key: const Key('goal-import-error'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppLayout.spaceSm),
                      const Text('已有目标与任务不会因此改变。'),
                    ],
                  ),
                ),
              ),
            ),
          if (preview != null) ...[
            const Divider(height: 32),
            Text(preview.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppLayout.spaceXs),
            Text(
              '完整大纲 · ${preview.nodeCount} 个节点；${preview.missionCount} 个任务，共 ${preview.totalMinutes} 分钟',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppLayout.spaceMd),
            Wrap(
              spacing: AppLayout.spaceSm,
              runSpacing: AppLayout.spaceSm,
              children: [
                Chip(
                  avatar: const Icon(
                    Icons.calendar_month,
                    size: AppLayout.iconSm,
                  ),
                  label: Text('固定 ${preview.fixedCount}'),
                ),
                const Chip(
                  avatar: Icon(Icons.history, size: AppLayout.iconSm),
                  label: Text('保留历史计划'),
                ),
              ],
            ),
            if (preview.existingGoalId != null) ...[
              const SizedBox(height: AppLayout.spaceSm),
              const Text('此包已导入，确认会返回原目标，不重复创建。'),
            ],
            if (preview.duplicateGoalId != null &&
                preview.existingGoalId == null) ...[
              const SizedBox(height: AppLayout.spaceSm),
              const Text('相同计划内容曾以其他包编号导入，本次确认将创建独立副本。'),
            ],
            if (_reviewCode == 'DUE_AUTO_START' || _allowDue)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('按当前时段自动开始'),
                value: _allowDue,
                onChanged: _busy || _unknown
                    ? null
                    : (value) {
                        setState(() => _allowDue = value);
                        unawaited(_review());
                      },
              ),
            if (_reviewCode == 'SCHEDULE_CONFLICT' || _allowOverlaps)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('保留重叠课程'),
                value: _allowOverlaps,
                onChanged: _busy || _unknown
                    ? null
                    : (value) {
                        setState(() => _allowOverlaps = value);
                        unawaited(_review());
                      },
              ),
            if (_reviewError != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _reviewError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: AppLayout.spaceXl),
            FilledButton.icon(
              key: const Key('goal-import-confirm'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppLayout.actionMinHeight),
              ),
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
                    : '导入 ${preview.missionCount > 0 ? '${preview.missionCount} 个任务' : '${preview.nodeCount} 个节点'}',
              ),
            ),
            const SizedBox(height: AppLayout.spaceXl),
            Row(
              children: [
                Text('预览内容', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${_kind == 'MISSION' ? preview.missionCount : preview.nodeCount} 项',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppLayout.spaceSm),
            Wrap(
              spacing: AppLayout.spaceSm,
              runSpacing: AppLayout.spaceSm,
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
            const SizedBox(height: AppLayout.spaceSm),
            FutureBuilder<List<GoalImportEntry>>(
              key: ValueKey(preview.jobId + _kind + _offset.toString()),
              future: _page,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('无法读取导入预览，请重试。'),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _page = _service.page(preview, _kind, _offset);
                              }),
                        child: const Text('重试'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final entries = snapshot.data!;
                final count = _kind == 'MISSION'
                    ? preview.missionCount
                    : preview.nodeCount;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, entry) in entries.indexed) ...[
                      if (index > 0) const Divider(height: 1),
                      _entry(entry),
                    ],
                    const SizedBox(height: AppLayout.spaceSm),
                    Wrap(
                      spacing: AppLayout.spaceSm,
                      runSpacing: AppLayout.spaceXs,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
                          style: Theme.of(context).textTheme.bodySmall,
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
          ],
        ],
      ),
    );
  }

  String _errorText(Object error) {
    if (error is GoalImportException) {
      if (error.code == 'UNKNOWN_FIELD' &&
          error.path.toLowerCase() == '/schema') {
        return '格式标识的字段名应为小写“schema”。请按下方“查看支持的格式”检查大小写后重新预览。';
      }
      if (error.code == 'UNSUPPORTED_SCHEMA') {
        return '文件不是受支持的目标或课表格式。请使用 MissionBook 导出的 JSON，或按下方“查看支持的格式”整理内容。';
      }
      if (error.code == 'UNSUPPORTED_VERSION') {
        return '此文件的格式版本不受支持，请使用版本 1 的导入文件。';
      }
      if (error.code == 'INVALID_JSON') {
        return 'JSON 内容不完整或格式有误：${error.message}。请检查括号、引号与逗号后重新预览。';
      }

      final item = RegExp(r'^/(missions|nodes)/(\d+)').firstMatch(error.path);
      if (item != null) {
        return '第 ${int.parse(item.group(2)!) + 1} 个${item.group(1) == 'missions' ? '任务' : '节点'}：${error.message}';
      }
      return '${error.message}${error.path == "/" ? "" : "（位置：${error.path}）"}。请调整内容后重新预览。';
    }
    if (error is GoalImportCancelled) return '已取消，可重新选择文件';
    debugPrint('目标导入失败：$error');
    return '暂时无法完成操作，输入已保留。请重试；若保存结果尚未确认，请先核对原导入结果。';
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    _input.dispose();
    super.dispose();
  }
}
