import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_metrics.dart';
import '../../core/theme/colors.dart';
import '../../data/settings/today_widget_appearance.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_section_header.dart';
import '../widgets/app_segmented_control.dart';
import 'today_widget_preview.dart';

/// 「设置 → 界面 → 桌面小组件」的原位编辑器。
///
/// 编辑器挂在设置页的列表项内，不新增必经路由。读取、保存、重绘和预览
/// 都只走 `mission_book/today_widget` 外观方法；改动只形成草稿，保存才写一次。
class TodayWidgetAppearanceEditor extends StatefulWidget {
  const TodayWidgetAppearanceEditor({super.key, required this.onClose});

  /// 收起编辑器。是否丢弃未保存修改由本组件先确认。
  final VoidCallback onClose;

  @override
  State<TodayWidgetAppearanceEditor> createState() =>
      TodayWidgetAppearanceEditorState();
}

class TodayWidgetAppearanceEditorState
    extends State<TodayWidgetAppearanceEditor>
    with AutomaticKeepAliveClientMixin {
  static const _previewDebounceDelay = Duration(milliseconds: 120);
  static const _twoColumnMinWidth = 800.0;

  TodayWidgetAppearance? _saved;
  TodayWidgetAppearance? _draft;
  TodayWidgetAppearance? _defaults;
  TodayWidgetAppearanceSource? _source;
  bool _recovered = false;
  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  bool _closing = false;
  String? _saveError;
  String? _saveNote;
  bool _widgetsWarning = false;
  bool _redrawing = false;
  TodayWidgetPreview? _preview;
  bool _previewLoading = false;
  String? _previewError;
  TodayWidgetSizeClass _previewSize = TodayWidgetSizeClass.medium;
  TodayWidgetTheme _previewTheme = TodayWidgetTheme.light;
  Timer? _previewDebounce;
  int _previewGeneration = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_load(initial: true));
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }

  bool get _dirty => _saved != null && _draft != _saved;

  bool get _canEdit => !_saving && !_loading && _draft != null;

  String get _statusText {
    if (_saving) return '保存中…';
    if (_dirty) return '有未保存的修改';
    return _saveNote ?? '已是最新';
  }

  Future<void> _load({bool initial = false}) async {
    if (!initial) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final result = await TodayWidgetAppearance.load();
      if (!mounted) return;
      setState(() {
        _defaults = result.defaults;
        _saved = result.appearance;
        _draft = result.appearance;
        _source = result.source;
        _recovered = result.recovered;
        _loading = false;
        _loadError = null;
        _saveError = null;
        _saveNote = null;
        _widgetsWarning = false;
        _preview = null;
        _previewError = null;
      });
      _schedulePreview(immediate: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '暂时无法读取小组件外观，请重试。';
      });
    }
  }

  /// 用当前草稿生成下一版，避免连续点按 +/− 时用到旧 build 捕获的值。
  void _apply(
    TodayWidgetAppearance Function(TodayWidgetAppearance current) change,
  ) {
    final current = _draft;
    if (!_canEdit || current == null) return;
    setState(() {
      _draft = change(current);
      _saveError = null;
      _saveNote = null;
    });
    _schedulePreview();
  }

  void _resetToDefaults() {
    if (!_canEdit) return;
    setState(() {
      _draft = _defaults ?? TodayWidgetAppearance.defaults;
      _saveError = null;
      _saveNote = null;
    });
    _schedulePreview(immediate: true);
  }

  Future<void> _save() async {
    final draft = _draft;
    if (_saving || _loading || draft == null || !_dirty) return;
    setState(() {
      _saving = true;
      _saveError = null;
      _saveNote = null;
    });
    try {
      final result = await draft.save();
      if (!mounted) return;
      setState(() {
        // 保存回执才是新基准；重绘失败不能把编辑器拉回旧值。
        _saved = result.appearance;
        _draft = result.appearance;
        _saving = false;
        _saveNote = switch (result.widgets) {
          TodayWidgetWidgetsState.noInstances => '已保存，尚未添加桌面小组件',
          _ => '已保存',
        };
        _widgetsWarning = switch (result.widgets) {
          TodayWidgetWidgetsState.partialFailure ||
          TodayWidgetWidgetsState.failed => true,
          _ => false,
        };
      });
      _schedulePreview(immediate: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = _describeSaveError(error);
      });
    }
  }

  Future<void> _redraw() async {
    if (_redrawing || _saving) return;
    setState(() {
      _redrawing = true;
      _saveError = null;
    });
    try {
      final state = await TodayWidgetAppearance.redrawWidgets();
      if (!mounted) return;
      setState(() {
        _redrawing = false;
        _widgetsWarning = switch (state) {
          TodayWidgetWidgetsState.partialFailure ||
          TodayWidgetWidgetsState.failed => true,
          _ => false,
        };
        _saveNote = switch (state) {
          TodayWidgetWidgetsState.noInstances => '尚未添加桌面小组件',
          TodayWidgetWidgetsState.requested => '已请求桌面更新',
          _ => _saveNote,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _redrawing = false;
        _saveError = '重新绘制失败，请稍后重试。';
      });
    }
  }

  String _describeSaveError(Object error) {
    if (error is PlatformException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return '保存失败：$message 草稿已保留。';
      }
    }
    return '保存失败，草稿已保留，请重试。';
  }

  void _schedulePreview({bool immediate = false}) {
    if (_draft == null) return;
    _previewDebounce?.cancel();
    final generation = ++_previewGeneration;
    if (immediate) {
      unawaited(_fetchPreview(generation));
      return;
    }
    // 拖动数值时合并请求；后一次改动让旧回执因代次不符而丢弃。
    _previewDebounce = Timer(
      _previewDebounceDelay,
      () => unawaited(_fetchPreview(generation)),
    );
  }

  Future<void> _fetchPreview(int generation) async {
    if (!mounted) return;
    final draft = _draft;
    if (draft == null) return;
    final sizeClass = _previewSize;
    final theme = _previewTheme;
    setState(() {
      _previewLoading = _preview == null;
      _previewError = null;
    });
    try {
      final preview = await TodayWidgetAppearance.preview(
        appearance: draft,
        sizeClass: sizeClass,
        theme: theme,
      );
      if (!mounted || generation != _previewGeneration) return;
      setState(() {
        _preview = preview;
        _previewLoading = false;
        _previewError = null;
      });
    } catch (_) {
      if (!mounted || generation != _previewGeneration) return;
      setState(() {
        _previewLoading = false;
        _previewError = '暂时无法生成预览，请重试。';
      });
    }
  }

  void _changePreviewSize(TodayWidgetSizeClass value) {
    if (_previewSize == value) return;
    setState(() => _previewSize = value);
    _schedulePreview(immediate: true);
  }

  void _changePreviewTheme(TodayWidgetTheme value) {
    if (_previewTheme == value) return;
    setState(() => _previewTheme = value);
    _schedulePreview(immediate: true);
  }

  Future<bool> _confirmDiscard() async {
    if (_closing) return false;
    _closing = true;
    try {
      return await AppConfirmDialog.show(
        context: context,
        title: '放弃小组件外观修改？',
        message: '尚未保存的样式、字号、间距和显示内容将被丢弃。',
        cancelText: '继续编辑',
        confirmText: '放弃修改',
      );
    } finally {
      _closing = false;
    }
  }

  /// 详情右栏换页等离开守卫使用：false 表示用户选择继续编辑。
  Future<bool> confirmLeave() async {
    if (_saving || _closing) return false;
    if (!_dirty) return true;
    return _confirmDiscard();
  }

  /// 设置页行再次点按与编辑器关闭按钮共用此入口。
  Future<void> requestClose() async {
    if (!await confirmLeave()) return;
    if (mounted) widget.onClose();
  }

  Future<void> _handlePageBack() async {
    if (_saving || _closing) return;
    if (!_dirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (await _confirmDiscard() && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final draft = _draft;
    return PopScope<void>(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handlePageBack());
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.spaceXl,
          0,
          AppMetrics.spaceXl,
          AppMetrics.spaceLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: AppSectionHeader('外观设置', subtle: true)),
                IconButton(
                  key: const Key('today-widget-close'),
                  tooltip: '收起小组件设置',
                  onPressed: _saving ? null : () => unawaited(requestClose()),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              '只影响这台安卓设备的桌面，已添加的小组件无需重新添加。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppMetrics.spaceMd),
            if (_loadError case final error?) ...[
              _loadErrorView(error),
            ] else if (draft == null) ...[
              const LinearProgressIndicator(
                key: Key('today-widget-loading'),
                semanticsLabel: '正在读取小组件外观',
              ),
            ] else ...[
              if (_loadNotice() case final notice?) ...[
                _Notice(text: notice),
                const SizedBox(height: AppMetrics.spaceMd),
              ],
              _editorBody(context, draft),
            ],
          ],
        ),
      ),
    );
  }

  Widget _loadErrorView(String error) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            error,
            key: const Key('today-widget-load-error'),
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('today-widget-retry'),
            onPressed: _load,
            child: const Text('重试'),
          ),
        ),
      ],
    );
  }

  String? _loadNotice() {
    final notices = <String>[
      if (_source == TodayWidgetAppearanceSource.migrated) '已从旧版颜色和文字大小迁移。',
      if (_recovered) '小组件设置曾损坏，已恢复为默认外观。',
    ];
    return notices.isEmpty ? null : notices.join(' ');
  }

  Widget _editorBody(BuildContext context, TodayWidgetAppearance draft) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = (MediaQuery.textScalerOf(context).scale(100) / 100)
            .clamp(1.0, 1.3);
        final twoColumn =
            constraints.maxWidth >= _twoColumnMinWidth &&
            constraints.maxWidth >= _twoColumnMinWidth * textScale;
        final preview = _previewPane();
        final form = _settingsForm(context, draft);
        if (!twoColumn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionHeader('预览', subtle: true),
              const SizedBox(height: AppMetrics.spaceSm),
              preview,
              const SizedBox(height: AppMetrics.spaceXl),
              form,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionHeader('预览', subtle: true),
                  const SizedBox(height: AppMetrics.spaceSm),
                  preview,
                ],
              ),
            ),
            const SizedBox(width: AppMetrics.spaceLg),
            Expanded(flex: 6, child: form),
          ],
        );
      },
    );
  }

  Widget _previewPane() => TodayWidgetPreviewPane(
    preview: _preview,
    sizeClass: _previewSize,
    exampleTheme: _previewTheme,
    loading: _previewLoading && _preview == null,
    error: _previewError,
    onSizeClassChanged: _changePreviewSize,
    onExampleThemeChanged: _changePreviewTheme,
    onRetry: () => _schedulePreview(immediate: true),
  );

  Widget _settingsForm(BuildContext context, TodayWidgetAppearance draft) {
    return IgnorePointer(
      ignoring: _saving,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _saving ? .6 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader('样式与颜色', subtle: true),
            const SizedBox(height: AppMetrics.spaceSm),
            _fieldLabel('风格预设'),
            Text(
              '预设会一次调整版式、颜色、字号和间距；应用后仍可继续细调。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppMetrics.spaceSm),
            _presetPicker(context, draft),
            const SizedBox(height: AppMetrics.spaceMd),
            _fieldLabel('版式'),
            AppSegmentedControl<TodayWidgetStyle>(
              options: const {
                TodayWidgetStyle.paper: '纸页清单',
                TodayWidgetStyle.indexCard: '课程卡片',
                TodayWidgetStyle.timeline: '任务时间轴',
                TodayWidgetStyle.minimal: '极简',
              },
              selected: draft.style,
              onSelected: (value) =>
                  _apply((current) => current.copyWith(style: value)),
              optionKey: (value) =>
                  ValueKey('today-widget-style-${value.name}'),
            ),
            const SizedBox(height: AppMetrics.spaceMd),
            _fieldLabel('色彩'),
            AppSegmentedControl<TodayWidgetTheme>(
              options: const {
                TodayWidgetTheme.system: '跟随系统',
                TodayWidgetTheme.light: '浅色',
                TodayWidgetTheme.dark: '深色',
              },
              selected: draft.theme,
              onSelected: (value) =>
                  _apply((current) => current.copyWith(theme: value)),
              optionKey: (value) =>
                  ValueKey('today-widget-theme-${value.name}'),
            ),
            const SizedBox(height: AppMetrics.spaceMd),
            _fieldLabel('外框圆角'),
            AppSegmentedControl<int>(
              options: {
                for (final value in TodayWidgetAppearanceLimits.radiusOptions)
                  value: '$value dp',
              },
              selected: draft.radiusDp,
              onSelected: (value) =>
                  _apply((current) => current.copyWith(radiusDp: value)),
              optionKey: (value) => ValueKey('today-widget-radius-$value'),
            ),
            const SizedBox(height: AppMetrics.spaceXl),
            const AppSectionHeader('字号', subtle: true),
            const SizedBox(height: AppMetrics.spaceXs),
            _numberRow(
              label: '卡片标题',
              keyPrefix: 'headerSp',
              value: draft.headerSp,
              min: TodayWidgetAppearanceLimits.headerSpMin,
              max: TodayWidgetAppearanceLimits.headerSpMax,
              unit: 'sp',
            ),
            _numberRow(
              label: '任务名',
              keyPrefix: 'taskSp',
              value: draft.taskSp,
              min: TodayWidgetAppearanceLimits.taskSpMin,
              max: TodayWidgetAppearanceLimits.taskSpMax,
              unit: 'sp',
            ),
            _numberRow(
              label: '日期、时间与状态',
              keyPrefix: 'metaSp',
              value: draft.metaSp,
              min: TodayWidgetAppearanceLimits.metaSpMin,
              max: TodayWidgetAppearanceLimits.metaSpMax,
              unit: 'sp',
            ),
            const SizedBox(height: AppMetrics.spaceXl),
            const AppSectionHeader('间距', subtle: true),
            const SizedBox(height: AppMetrics.spaceXs),
            _numberRow(
              label: '外侧左右',
              keyPrefix: 'horizontalPaddingDp',
              value: draft.horizontalPaddingDp,
              min: TodayWidgetAppearanceLimits.horizontalPaddingDpMin,
              max: TodayWidgetAppearanceLimits.horizontalPaddingDpMax,
              unit: 'dp',
            ),
            _numberRow(
              label: '外侧上下',
              keyPrefix: 'verticalPaddingDp',
              value: draft.verticalPaddingDp,
              min: TodayWidgetAppearanceLimits.verticalPaddingDpMin,
              max: TodayWidgetAppearanceLimits.verticalPaddingDpMax,
              unit: 'dp',
            ),
            _numberRow(
              label: '行内上下',
              keyPrefix: 'rowPaddingDp',
              value: draft.rowPaddingDp,
              min: TodayWidgetAppearanceLimits.rowPaddingDpMin,
              max: TodayWidgetAppearanceLimits.rowPaddingDpMax,
              unit: 'dp',
            ),
            _numberRow(
              label: '行间隔',
              keyPrefix: 'rowGapDp',
              value: draft.rowGapDp,
              min: TodayWidgetAppearanceLimits.rowGapDpMin,
              max: TodayWidgetAppearanceLimits.rowGapDpMax,
              unit: 'dp',
            ),
            const SizedBox(height: AppMetrics.spaceXl),
            const AppSectionHeader('显示内容', subtle: true),
            const SizedBox(height: AppMetrics.spaceXs),
            _switchRow(
              switchKey: const Key('today-widget-showDetails'),
              title: '显示详细信息',
              subtitle: '关闭后只显示任务名；下面的时间与阶段设置会保留。',
              value: draft.showDetails,
              onChanged: (value) =>
                  _apply((current) => current.copyWith(showDetails: value)),
            ),
            _fieldLabel('时间显示'),
            AppSegmentedControl<TodayWidgetTimeMode>(
              options: const {
                TodayWidgetTimeMode.none: '不显示',
                TodayWidgetTimeMode.start: '开始时间',
                TodayWidgetTimeMode.range: '开始–结束',
              },
              selected: draft.timeMode,
              onSelected: (value) =>
                  _apply((current) => current.copyWith(timeMode: value)),
              optionKey: (value) => ValueKey('today-widget-time-${value.name}'),
            ),
            _switchRow(
              switchKey: const Key('today-widget-showStatus'),
              title: '显示阶段状态',
              value: draft.showStatus,
              onChanged: (value) =>
                  _apply((current) => current.copyWith(showStatus: value)),
            ),
            _switchRow(
              switchKey: const Key('today-widget-showDate'),
              title: '显示日期',
              value: draft.showDate,
              onChanged: (value) =>
                  _apply((current) => current.copyWith(showDate: value)),
            ),
            _switchRow(
              switchKey: const Key('today-widget-showMore'),
              title: '显示「另有 N 项」',
              subtitle: '只隐藏数量；标题和空态仍可打开今天。',
              value: draft.showMore,
              onChanged: (value) =>
                  _apply((current) => current.copyWith(showMore: value)),
            ),
            const SizedBox(height: AppMetrics.spaceMd),
            _fieldLabel('中、大号最多显示'),
            AppSegmentedControl<int>(
              options: {
                for (
                  var value = TodayWidgetAppearanceLimits.rowLimitMin;
                  value <= TodayWidgetAppearanceLimits.rowLimitMax;
                  value++
                )
                  value: '$value 项',
              },
              selected: draft.rowLimit,
              onSelected: (value) =>
                  _apply((current) => current.copyWith(rowLimit: value)),
              optionKey: (value) => ValueKey('today-widget-row-limit-$value'),
            ),
            const SizedBox(height: AppMetrics.spaceXl),
            _saveFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _presetPicker(BuildContext context, TodayWidgetAppearance draft) {
    final selected = draft.matchingPreset;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth >= 620 ? 188.0 : 160.0;
        return Wrap(
          spacing: AppMetrics.spaceSm,
          runSpacing: AppMetrics.spaceSm,
          children: [
            for (final preset in TodayWidgetPreset.values)
              _presetTile(
                context,
                preset,
                selected: selected == preset,
                width: tileWidth,
              ),
          ],
        );
      },
    );
  }

  Widget _presetTile(
    BuildContext context,
    TodayWidgetPreset preset, {
    required bool selected,
    required double width,
  }) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: '${preset.label}预设，${preset.description}',
      child: InkWell(
        key: ValueKey('today-widget-preset-${preset.name}'),
        borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
        onTap: _canEdit
            ? () => _apply((current) => preset.applyTo(current))
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: width,
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.all(AppMetrics.spaceSm),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: .08)
                : theme.colorScheme.surface,
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_presetIcon(preset), color: theme.colorScheme.primary),
              const SizedBox(width: AppMetrics.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preset.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _presetIcon(TodayWidgetPreset preset) => switch (preset) {
    TodayWidgetPreset.balanced => Icons.auto_awesome_outlined,
    TodayWidgetPreset.courseCards => Icons.view_agenda_outlined,
    TodayWidgetPreset.timeline => Icons.timeline_outlined,
    TodayWidgetPreset.compact => Icons.density_small,
    TodayWidgetPreset.darkForest => Icons.dark_mode_outlined,
  };

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(
      top: AppMetrics.spaceXs,
      bottom: AppMetrics.spaceXs,
    ),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
    ),
  );

  void _adjustNumber(String keyPrefix, int delta) {
    _apply((current) {
      final next = (_numberValue(current, keyPrefix) + delta)
          .clamp(_numberMin(keyPrefix), _numberMax(keyPrefix))
          .toInt();
      return _writeNumber(current, keyPrefix, next);
    });
  }

  void _setNumber(String keyPrefix, int value) {
    _apply(
      (current) => _writeNumber(
        current,
        keyPrefix,
        value.clamp(_numberMin(keyPrefix), _numberMax(keyPrefix)).toInt(),
      ),
    );
  }

  static int _numberValue(TodayWidgetAppearance appearance, String key) =>
      switch (key) {
        'headerSp' => appearance.headerSp,
        'taskSp' => appearance.taskSp,
        'metaSp' => appearance.metaSp,
        'horizontalPaddingDp' => appearance.horizontalPaddingDp,
        'verticalPaddingDp' => appearance.verticalPaddingDp,
        'rowPaddingDp' => appearance.rowPaddingDp,
        'rowGapDp' => appearance.rowGapDp,
        _ => throw ArgumentError.value(key, 'key', '未知的小组件数值'),
      };

  static int _numberMin(String key) => switch (key) {
    'headerSp' => TodayWidgetAppearanceLimits.headerSpMin,
    'taskSp' => TodayWidgetAppearanceLimits.taskSpMin,
    'metaSp' => TodayWidgetAppearanceLimits.metaSpMin,
    'horizontalPaddingDp' => TodayWidgetAppearanceLimits.horizontalPaddingDpMin,
    'verticalPaddingDp' => TodayWidgetAppearanceLimits.verticalPaddingDpMin,
    'rowPaddingDp' => TodayWidgetAppearanceLimits.rowPaddingDpMin,
    'rowGapDp' => TodayWidgetAppearanceLimits.rowGapDpMin,
    _ => throw ArgumentError.value(key, 'key', '未知的小组件数值'),
  };

  static int _numberMax(String key) => switch (key) {
    'headerSp' => TodayWidgetAppearanceLimits.headerSpMax,
    'taskSp' => TodayWidgetAppearanceLimits.taskSpMax,
    'metaSp' => TodayWidgetAppearanceLimits.metaSpMax,
    'horizontalPaddingDp' => TodayWidgetAppearanceLimits.horizontalPaddingDpMax,
    'verticalPaddingDp' => TodayWidgetAppearanceLimits.verticalPaddingDpMax,
    'rowPaddingDp' => TodayWidgetAppearanceLimits.rowPaddingDpMax,
    'rowGapDp' => TodayWidgetAppearanceLimits.rowGapDpMax,
    _ => throw ArgumentError.value(key, 'key', '未知的小组件数值'),
  };

  static TodayWidgetAppearance _writeNumber(
    TodayWidgetAppearance appearance,
    String key,
    int value,
  ) => switch (key) {
    'headerSp' => appearance.copyWith(headerSp: value),
    'taskSp' => appearance.copyWith(taskSp: value),
    'metaSp' => appearance.copyWith(metaSp: value),
    'horizontalPaddingDp' => appearance.copyWith(horizontalPaddingDp: value),
    'verticalPaddingDp' => appearance.copyWith(verticalPaddingDp: value),
    'rowPaddingDp' => appearance.copyWith(rowPaddingDp: value),
    'rowGapDp' => appearance.copyWith(rowGapDp: value),
    _ => throw ArgumentError.value(key, 'key', '未知的小组件数值'),
  };

  Widget _numberRow({
    required String label,
    required String keyPrefix,
    required int value,
    required int min,
    required int max,
    required String unit,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            IconButton(
              key: ValueKey('today-widget-$keyPrefix-minus'),
              tooltip: '减少$label',
              onPressed: _canEdit && value > min
                  ? () => _adjustNumber(keyPrefix, -1)
                  : null,
              icon: const Icon(Icons.remove, size: AppMetrics.iconMd),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '$value$unit',
                key: ValueKey('today-widget-$keyPrefix-value'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: ValueKey('today-widget-$keyPrefix-plus'),
              tooltip: '增加$label',
              onPressed: _canEdit && value < max
                  ? () => _adjustNumber(keyPrefix, 1)
                  : null,
              icon: const Icon(Icons.add_rounded, size: AppMetrics.iconMd),
            ),
          ],
        ),
        Semantics(
          label: label,
          child: Slider(
            key: ValueKey('today-widget-$keyPrefix-slider'),
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value$unit',
            semanticFormatterCallback: (next) => '${next.round()}$unit',
            onChanged: _canEdit
                ? (next) => _setNumber(keyPrefix, next.round())
                : null,
          ),
        ),
      ],
    );
  }

  Widget _switchRow({
    required Key switchKey,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppMetrics.touchTargetMin),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              key: switchKey,
              value: value,
              onChanged: _canEdit ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveFooter(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saveError case final error?) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              key: const Key('today-widget-save-error'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
          const SizedBox(height: AppMetrics.spaceSm),
        ],
        if (_widgetsWarning) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  '已保存，桌面暂未更新',
                  key: const Key('today-widget-widgets-warning'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
              TextButton(
                key: const Key('today-widget-redraw'),
                onPressed: _redrawing || _saving ? null : _redraw,
                child: Text(_redrawing ? '正在重绘…' : '重新绘制'),
              ),
            ],
          ),
          const SizedBox(height: AppMetrics.spaceSm),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('today-widget-reset'),
                onPressed: _canEdit ? _resetToDefaults : null,
                child: const Text('恢复默认'),
              ),
            ),
            const SizedBox(width: AppMetrics.spaceMd),
            Expanded(
              child: FilledButton(
                key: const Key('today-widget-save'),
                onPressed: _canEdit && _dirty ? _save : null,
                child: Text(_saving ? '保存中…' : '保存'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppMetrics.spaceSm),
        Semantics(
          liveRegion: true,
          child: Text(
            _statusText,
            key: const Key('today-widget-status'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _saveError != null
                  ? AppColors.error
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppMetrics.spaceSm),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
        ),
        child: Text(
          text,
          key: const Key('today-widget-load-notice'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.warning),
        ),
      ),
    );
  }
}
