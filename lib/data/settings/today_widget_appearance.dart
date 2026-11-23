import '../notifications/today_widget_bridge.dart';

/// 桌面小组件外观的线格式版本。原生与 Dart 都只接受这个版本。
const int todayWidgetAppearanceVersion = 2;

/// 契约里的字符串值。枚举成员名受 Dart 关键字限制，线格式统一取 [wire]。
abstract interface class TodayWidgetWireValue {
  String get wire;
}

/// 小组件版式。切换版式只改变绘制，不重置字号、间距和信息开关。
enum TodayWidgetStyle implements TodayWidgetWireValue {
  paper('paper'),
  indexCard('index'),
  minimal('minimal');

  const TodayWidgetStyle(this.wire);

  @override
  final String wire;
}

/// 小组件色彩，独立于应用自身的浅色主题。
enum TodayWidgetTheme implements TodayWidgetWireValue {
  system('system'),
  light('light'),
  dark('dark');

  const TodayWidgetTheme(this.wire);

  @override
  final String wire;
}

/// 时间信息的显示方式；`range` 放不下时由原生预览降级为开始时间，不改保存值。
enum TodayWidgetTimeMode implements TodayWidgetWireValue {
  none('none'),
  start('start'),
  range('range');

  const TodayWidgetTimeMode(this.wire);

  @override
  final String wire;
}

/// 设置页预览的尺寸类别；只影响预览，不改变设备上的偏好。
enum TodayWidgetSizeClass implements TodayWidgetWireValue {
  small('small'),
  medium('medium'),
  large('large');

  const TodayWidgetSizeClass(this.wire);

  @override
  final String wire;
}

/// `setAppearance`/`redrawWidgets` 对桌面实例的重绘回执。
enum TodayWidgetWidgetsState implements TodayWidgetWireValue {
  noInstances('noInstances'),
  requested('requested'),
  partialFailure('partialFailure'),
  failed('failed');

  const TodayWidgetWidgetsState(this.wire);

  @override
  final String wire;
}

/// `getAppearance` 声明本次外观的来源。
enum TodayWidgetAppearanceSource implements TodayWidgetWireValue {
  v2('v2'),
  migrated('migrated'),
  defaults('defaults');

  const TodayWidgetAppearanceSource(this.wire);

  @override
  final String wire;
}

/// 预览尺寸是取真实组件尺寸还是契约里的参考尺寸。
enum TodayWidgetSizeSource implements TodayWidgetWireValue {
  widget('widget'),
  reference('reference');

  const TodayWidgetSizeSource(this.wire);

  @override
  final String wire;
}

/// 预览的空态；`waiting` 是尚无当日快照，`empty` 是快照确实没有任务。
enum TodayWidgetPreviewEmpty implements TodayWidgetWireValue {
  none('none'),
  waiting('waiting'),
  empty('empty');

  const TodayWidgetPreviewEmpty(this.wire);

  @override
  final String wire;
}

/// 预览的溢出处理结果；`headerOnly` 表示空间不足时退化为题头入口。
enum TodayWidgetPreviewOverflow implements TodayWidgetWireValue {
  none('none'),
  tight('tight'),
  headerOnly('headerOnly');

  const TodayWidgetPreviewOverflow(this.wire);

  @override
  final String wire;
}

/// 预览的最终行版式：`wide` 为时间—任务—状态三槽，`stacked` 为上下布局。
enum TodayWidgetPreviewRowLayout implements TodayWidgetWireValue {
  wide('wide'),
  stacked('stacked');

  const TodayWidgetPreviewRowLayout(this.wire);

  @override
  final String wire;
}

/// 预览尾部显示的种类。
enum TodayWidgetPreviewFooterKind implements TodayWidgetWireValue {
  more('more'),
  headerCount('headerCount'),
  none('none');

  const TodayWidgetPreviewFooterKind(this.wire);

  @override
  final String wire;
}

/// 外观可调范围集中在这里，设置页直接引用，避免控件与原生取值域分叉。
abstract final class TodayWidgetAppearanceLimits {
  static const headerSpMin = 11;
  static const headerSpMax = 17;
  static const taskSpMin = 11;
  static const taskSpMax = 20;
  static const metaSpMin = 10;
  static const metaSpMax = 16;
  static const horizontalPaddingDpMin = 8;
  static const horizontalPaddingDpMax = 16;
  static const verticalPaddingDpMin = 4;
  static const verticalPaddingDpMax = 12;
  static const rowPaddingDpMin = 3;
  static const rowPaddingDpMax = 9;
  static const rowGapDpMin = 0;
  static const rowGapDpMax = 8;
  static const radiusOptions = <int>[8, 12, 16];
  static const rowLimitMin = 1;
  static const rowLimitMax = 5;

  /// 字号步长与间距步长；设置页的 Slider 和 − / + 都使用整数步进。
  static const stepSp = 1;
  static const stepDp = 1;
}

/// 一份设备级的小组件外观。原生负责默认值、持久化和最终回执；
/// 这里的实例是编辑草稿与预览输入，不直接读写原生文件。
class TodayWidgetAppearance {
  const TodayWidgetAppearance({
    this.version = currentVersion,
    required this.style,
    required this.theme,
    required this.headerSp,
    required this.taskSp,
    required this.metaSp,
    required this.horizontalPaddingDp,
    required this.verticalPaddingDp,
    required this.rowPaddingDp,
    required this.rowGapDp,
    required this.radiusDp,
    required this.showDetails,
    required this.timeMode,
    required this.showStatus,
    required this.showDate,
    required this.showMore,
    required this.rowLimit,
  });

  static const currentVersion = todayWidgetAppearanceVersion;

  /// 契约第 1 节的默认值；仅在没有读取到原生 `defaults` 时兜底。
  static const defaults = TodayWidgetAppearance(
    style: TodayWidgetStyle.paper,
    theme: TodayWidgetTheme.system,
    headerSp: 12,
    taskSp: 12,
    metaSp: 11,
    horizontalPaddingDp: 10,
    verticalPaddingDp: 6,
    rowPaddingDp: 4,
    rowGapDp: 4,
    radiusDp: 16,
    showDetails: true,
    timeMode: TodayWidgetTimeMode.range,
    showStatus: true,
    showDate: true,
    showMore: true,
    rowLimit: 5,
  );

  final int version;
  final TodayWidgetStyle style;
  final TodayWidgetTheme theme;
  final int headerSp;
  final int taskSp;
  final int metaSp;
  final int horizontalPaddingDp;
  final int verticalPaddingDp;
  final int rowPaddingDp;
  final int rowGapDp;
  final int radiusDp;
  final bool showDetails;
  final TodayWidgetTimeMode timeMode;
  final bool showStatus;
  final bool showDate;
  final bool showMore;
  final int rowLimit;

  /// 严格解析原生结构：版本必须为 2；未知枚举、非整数、越界都拒绝；
  /// 契约里的键缺失时用默认值补齐，未知的多余键忽略。
  factory TodayWidgetAppearance.fromMap(Map<Object?, Object?> map) {
    final version = _readInt(map, 'version');
    if (version != currentVersion) {
      throw FormatException('不支持的小组件外观版本：$version');
    }
    const fallback = defaults;
    return TodayWidgetAppearance(
      version: version,
      style: _readEnum(map, 'style', TodayWidgetStyle.values, fallback.style),
      theme: _readEnum(map, 'theme', TodayWidgetTheme.values, fallback.theme),
      headerSp: _readInt(
        map,
        'headerSp',
        fallback: fallback.headerSp,
        min: TodayWidgetAppearanceLimits.headerSpMin,
        max: TodayWidgetAppearanceLimits.headerSpMax,
      ),
      taskSp: _readInt(
        map,
        'taskSp',
        fallback: fallback.taskSp,
        min: TodayWidgetAppearanceLimits.taskSpMin,
        max: TodayWidgetAppearanceLimits.taskSpMax,
      ),
      metaSp: _readInt(
        map,
        'metaSp',
        fallback: fallback.metaSp,
        min: TodayWidgetAppearanceLimits.metaSpMin,
        max: TodayWidgetAppearanceLimits.metaSpMax,
      ),
      horizontalPaddingDp: _readInt(
        map,
        'horizontalPaddingDp',
        fallback: fallback.horizontalPaddingDp,
        min: TodayWidgetAppearanceLimits.horizontalPaddingDpMin,
        max: TodayWidgetAppearanceLimits.horizontalPaddingDpMax,
      ),
      verticalPaddingDp: _readInt(
        map,
        'verticalPaddingDp',
        fallback: fallback.verticalPaddingDp,
        min: TodayWidgetAppearanceLimits.verticalPaddingDpMin,
        max: TodayWidgetAppearanceLimits.verticalPaddingDpMax,
      ),
      rowPaddingDp: _readInt(
        map,
        'rowPaddingDp',
        fallback: fallback.rowPaddingDp,
        min: TodayWidgetAppearanceLimits.rowPaddingDpMin,
        max: TodayWidgetAppearanceLimits.rowPaddingDpMax,
      ),
      rowGapDp: _readInt(
        map,
        'rowGapDp',
        fallback: fallback.rowGapDp,
        min: TodayWidgetAppearanceLimits.rowGapDpMin,
        max: TodayWidgetAppearanceLimits.rowGapDpMax,
      ),
      radiusDp: _readInt(
        map,
        'radiusDp',
        fallback: fallback.radiusDp,
        allowed: TodayWidgetAppearanceLimits.radiusOptions,
      ),
      showDetails: _readBool(
        map,
        'showDetails',
        fallback: fallback.showDetails,
      ),
      timeMode: _readEnum(
        map,
        'timeMode',
        TodayWidgetTimeMode.values,
        fallback.timeMode,
      ),
      showStatus: _readBool(map, 'showStatus', fallback: fallback.showStatus),
      showDate: _readBool(map, 'showDate', fallback: fallback.showDate),
      showMore: _readBool(map, 'showMore', fallback: fallback.showMore),
      rowLimit: _readInt(
        map,
        'rowLimit',
        fallback: fallback.rowLimit,
        min: TodayWidgetAppearanceLimits.rowLimitMin,
        max: TodayWidgetAppearanceLimits.rowLimitMax,
      ),
    );
  }

  /// 提交给原生与保存回执的完整结构。
  Map<String, Object?> toMap() => <String, Object?>{
    'version': version,
    'style': style.wire,
    'theme': theme.wire,
    'headerSp': headerSp,
    'taskSp': taskSp,
    'metaSp': metaSp,
    'horizontalPaddingDp': horizontalPaddingDp,
    'verticalPaddingDp': verticalPaddingDp,
    'rowPaddingDp': rowPaddingDp,
    'rowGapDp': rowGapDp,
    'radiusDp': radiusDp,
    'showDetails': showDetails,
    'timeMode': timeMode.wire,
    'showStatus': showStatus,
    'showDate': showDate,
    'showMore': showMore,
    'rowLimit': rowLimit,
  };

  TodayWidgetAppearance copyWith({
    int? version,
    TodayWidgetStyle? style,
    TodayWidgetTheme? theme,
    int? headerSp,
    int? taskSp,
    int? metaSp,
    int? horizontalPaddingDp,
    int? verticalPaddingDp,
    int? rowPaddingDp,
    int? rowGapDp,
    int? radiusDp,
    bool? showDetails,
    TodayWidgetTimeMode? timeMode,
    bool? showStatus,
    bool? showDate,
    bool? showMore,
    int? rowLimit,
  }) => TodayWidgetAppearance(
    version: version ?? this.version,
    style: style ?? this.style,
    theme: theme ?? this.theme,
    headerSp: headerSp ?? this.headerSp,
    taskSp: taskSp ?? this.taskSp,
    metaSp: metaSp ?? this.metaSp,
    horizontalPaddingDp: horizontalPaddingDp ?? this.horizontalPaddingDp,
    verticalPaddingDp: verticalPaddingDp ?? this.verticalPaddingDp,
    rowPaddingDp: rowPaddingDp ?? this.rowPaddingDp,
    rowGapDp: rowGapDp ?? this.rowGapDp,
    radiusDp: radiusDp ?? this.radiusDp,
    showDetails: showDetails ?? this.showDetails,
    timeMode: timeMode ?? this.timeMode,
    showStatus: showStatus ?? this.showStatus,
    showDate: showDate ?? this.showDate,
    showMore: showMore ?? this.showMore,
    rowLimit: rowLimit ?? this.rowLimit,
  );

  /// 读取原生归一化外观、默认值、恢复标记和来源。
  /// 通道异常或响应结构不合法时抛错，由设置页显示重试，不能伪装成默认值。
  static Future<TodayWidgetAppearanceRead> load() async {
    final response = await TodayWidgetBridge.getAppearance();
    final version = _readInt(response, 'version');
    if (version != currentVersion) {
      throw FormatException('不支持的小组件外观版本：$version');
    }
    final appearance = TodayWidgetAppearance.fromMap(
      _readMap(response, 'appearance'),
    );
    final defaults = TodayWidgetAppearance.fromMap(
      _readMap(response, 'defaults'),
    );
    final source = _readRequiredEnum(
      response,
      'source',
      TodayWidgetAppearanceSource.values,
    );
    return TodayWidgetAppearanceRead(
      appearance: appearance,
      defaults: defaults,
      recovered: _readBool(response, 'recovered', fallback: false),
      source: source,
    );
  }

  /// 一次保存请求：原生先校验并原子保存，再用同一份快照重绘已有实例。
  Future<TodayWidgetAppearanceSaveResult> save() async {
    final response = await TodayWidgetBridge.setAppearance(toMap());
    return TodayWidgetAppearanceSaveResult(
      appearance: TodayWidgetAppearance.fromMap(
        _readMap(response, 'appearance'),
      ),
      widgets: _readEnum(
        response,
        'widgets',
        TodayWidgetWidgetsState.values,
        TodayWidgetWidgetsState.failed,
      ),
    );
  }

  /// 只用已保存外观和缓存快照重绘；不读取任务库，也不写偏好。
  static Future<TodayWidgetWidgetsState> redrawWidgets() async {
    final response = await TodayWidgetBridge.redrawWidgets();
    return _readEnum(
      response,
      'widgets',
      TodayWidgetWidgetsState.values,
      TodayWidgetWidgetsState.failed,
    );
  }

  /// 请求原生用同一份布局规划器给出预览计划；不写偏好、不查任务库。
  static Future<TodayWidgetPreview> preview({
    required TodayWidgetAppearance appearance,
    required TodayWidgetSizeClass sizeClass,
    required TodayWidgetTheme theme,
  }) async {
    final response = await TodayWidgetBridge.previewAppearance(
      appearance: appearance.toMap(),
      sizeClass: sizeClass.wire,
      theme: theme.wire,
    );
    return TodayWidgetPreview.fromMap(response);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodayWidgetAppearance &&
          version == other.version &&
          style == other.style &&
          theme == other.theme &&
          headerSp == other.headerSp &&
          taskSp == other.taskSp &&
          metaSp == other.metaSp &&
          horizontalPaddingDp == other.horizontalPaddingDp &&
          verticalPaddingDp == other.verticalPaddingDp &&
          rowPaddingDp == other.rowPaddingDp &&
          rowGapDp == other.rowGapDp &&
          radiusDp == other.radiusDp &&
          showDetails == other.showDetails &&
          timeMode == other.timeMode &&
          showStatus == other.showStatus &&
          showDate == other.showDate &&
          showMore == other.showMore &&
          rowLimit == other.rowLimit;

  @override
  int get hashCode => Object.hash(
    version,
    style,
    theme,
    headerSp,
    taskSp,
    metaSp,
    horizontalPaddingDp,
    verticalPaddingDp,
    rowPaddingDp,
    rowGapDp,
    radiusDp,
    showDetails,
    timeMode,
    showStatus,
    showDate,
    showMore,
    rowLimit,
  );
}

/// `getAppearance` 的完整回执。
class TodayWidgetAppearanceRead {
  const TodayWidgetAppearanceRead({
    required this.appearance,
    required this.defaults,
    required this.recovered,
    required this.source,
  });

  final TodayWidgetAppearance appearance;
  final TodayWidgetAppearance defaults;

  /// 存储损坏或迁移失败时原生已回退默认值；设置页必须可见提示。
  final bool recovered;
  final TodayWidgetAppearanceSource source;
}

/// `setAppearance` 的完整回执：保存结果与桌面重绘结果分开。
class TodayWidgetAppearanceSaveResult {
  const TodayWidgetAppearanceSaveResult({
    required this.appearance,
    required this.widgets,
  });

  final TodayWidgetAppearance appearance;
  final TodayWidgetWidgetsState widgets;
}

/// 契约 2.4 的预览计划。颜色为 ARGB int，度量单位与原生一致。
class TodayWidgetPreview {
  const TodayWidgetPreview({
    required this.version,
    required this.sizeClass,
    required this.sizeSource,
    required this.widthDp,
    required this.heightDp,
    required this.theme,
    required this.style,
    required this.colors,
    required this.metrics,
    required this.header,
    required this.rows,
    required this.footer,
    required this.empty,
    required this.overflow,
    required this.rowLayout,
    required this.spineVisible,
    required this.dividerVisible,
    required this.sample,
  });

  final int version;
  final TodayWidgetSizeClass sizeClass;
  final TodayWidgetSizeSource sizeSource;
  final int widthDp;
  final int heightDp;

  /// `system` 已由原生解析成 light/dark；这里只接受这两种。
  final TodayWidgetTheme theme;
  final TodayWidgetStyle style;
  final TodayWidgetPreviewColors colors;
  final TodayWidgetPreviewMetrics metrics;
  final TodayWidgetPreviewHeader header;
  final List<TodayWidgetPreviewRow> rows;
  final TodayWidgetPreviewFooter footer;
  final TodayWidgetPreviewEmpty empty;
  final TodayWidgetPreviewOverflow overflow;

  /// 规划器最终选定的行版式；Flutter 必须直接使用，不自行推断。
  final TodayWidgetPreviewRowLayout rowLayout;

  /// 行首书脊与行间分隔线；同样由规划器按样式和容量直接给出。
  final bool spineVisible;
  final bool dividerVisible;

  /// 契约要求预览数据固定为示例；设置页必须标出「示例数据」。
  final bool sample;

  factory TodayWidgetPreview.fromMap(Map<Object?, Object?> map) {
    final version = _readInt(map, 'version');
    if (version != TodayWidgetAppearance.currentVersion) {
      throw FormatException('不支持的小组件预览版本：$version');
    }
    final theme = _readRequiredEnum(map, 'theme', TodayWidgetTheme.values);
    if (theme == TodayWidgetTheme.system) {
      throw const FormatException('预览主题必须已解析为 light 或 dark');
    }
    final rawRows = map['rows'];
    if (rawRows is! List<Object?>) {
      throw FormatException('小组件预览 rows 无效：$rawRows');
    }
    return TodayWidgetPreview(
      version: version,
      sizeClass: _readRequiredEnum(
        map,
        'sizeClass',
        TodayWidgetSizeClass.values,
      ),
      sizeSource: _readRequiredEnum(
        map,
        'sizeSource',
        TodayWidgetSizeSource.values,
      ),
      widthDp: _readInt(map, 'widthDp', min: 1),
      heightDp: _readInt(map, 'heightDp', min: 1),
      theme: theme,
      style: _readRequiredEnum(map, 'style', TodayWidgetStyle.values),
      colors: TodayWidgetPreviewColors.fromMap(_readMap(map, 'colors')),
      metrics: TodayWidgetPreviewMetrics.fromMap(_readMap(map, 'metrics')),
      header: TodayWidgetPreviewHeader.fromMap(_readMap(map, 'header')),
      rows: List.unmodifiable([
        for (final row in rawRows)
          TodayWidgetPreviewRow.fromMap(_readMapValue(row, 'rows')),
      ]),
      footer: TodayWidgetPreviewFooter.fromMap(_readMap(map, 'footer')),
      empty: _readRequiredEnum(map, 'empty', TodayWidgetPreviewEmpty.values),
      overflow: _readRequiredEnum(
        map,
        'overflow',
        TodayWidgetPreviewOverflow.values,
      ),
      rowLayout: _readRequiredEnum(
        map,
        'rowLayout',
        TodayWidgetPreviewRowLayout.values,
      ),
      spineVisible: _readRequiredBool(map, 'spineVisible'),
      dividerVisible: _readRequiredBool(map, 'dividerVisible'),
      sample: _readBool(map, 'sample', fallback: true),
    );
  }
}

class TodayWidgetPreviewColors {
  const TodayWidgetPreviewColors({
    required this.surface,
    required this.content,
    required this.rowSurface,
    required this.spine,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
    required this.warn,
    required this.hairline,
  });

  final int surface;
  final int content;
  final int rowSurface;
  final int spine;
  final int primaryText;
  final int secondaryText;
  final int accent;
  final int warn;
  final int hairline;

  factory TodayWidgetPreviewColors.fromMap(Map<Object?, Object?> map) =>
      TodayWidgetPreviewColors(
        surface: _readInt(map, 'surface'),
        content: _readInt(map, 'content'),
        rowSurface: _readInt(map, 'rowSurface'),
        spine: _readInt(map, 'spine'),
        primaryText: _readInt(map, 'primaryText'),
        secondaryText: _readInt(map, 'secondaryText'),
        accent: _readInt(map, 'accent'),
        warn: _readInt(map, 'warn'),
        hairline: _readInt(map, 'hairline'),
      );
}

class TodayWidgetPreviewMetrics {
  const TodayWidgetPreviewMetrics({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.rowPadding,
    required this.rowGap,
    required this.radius,
    required this.headerSp,
    required this.taskSp,
    required this.metaSp,
    required this.headerHeight,
    required this.footerHeight,
    required this.rowHeight,
  });

  final int horizontalPadding;
  final int verticalPadding;
  final int rowPadding;
  final int rowGap;
  final int radius;
  final int headerSp;
  final int taskSp;
  final int metaSp;
  final int headerHeight;
  final int footerHeight;
  final int rowHeight;

  factory TodayWidgetPreviewMetrics.fromMap(Map<Object?, Object?> map) =>
      TodayWidgetPreviewMetrics(
        horizontalPadding: _readInt(map, 'horizontalPadding', min: 0),
        verticalPadding: _readInt(map, 'verticalPadding', min: 0),
        rowPadding: _readInt(map, 'rowPadding', min: 0),
        rowGap: _readInt(map, 'rowGap', min: 0),
        radius: _readInt(map, 'radius', min: 0),
        headerSp: _readInt(map, 'headerSp', min: 1),
        taskSp: _readInt(map, 'taskSp', min: 1),
        metaSp: _readInt(map, 'metaSp', min: 1),
        headerHeight: _readInt(map, 'headerHeight', min: 0),
        footerHeight: _readInt(map, 'footerHeight', min: 0),
        rowHeight: _readInt(map, 'rowHeight', min: 0),
      );
}

class TodayWidgetPreviewHeader {
  const TodayWidgetPreviewHeader({
    required this.visible,
    required this.left,
    required this.right,
    this.count,
  });

  final bool visible;
  final String left;
  final String right;
  final String? count;

  factory TodayWidgetPreviewHeader.fromMap(Map<Object?, Object?> map) =>
      TodayWidgetPreviewHeader(
        visible: _readBool(map, 'visible', fallback: false),
        left: _readString(map, 'left', fallback: ''),
        right: _readString(map, 'right', fallback: ''),
        count: _readNullableString(map, 'count'),
      );
}

class TodayWidgetPreviewRow {
  const TodayWidgetPreviewRow({
    required this.title,
    required this.showTime,
    required this.showStatus,
    required this.titleMaxLines,
    this.time,
    this.status,
    this.progress,
  });

  final String? time;
  final String title;
  final String? status;
  final bool showTime;
  final bool showStatus;
  final int titleMaxLines;

  /// 仅当前时段行有值；是计划进度文案，不是执行事实。
  final String? progress;

  factory TodayWidgetPreviewRow.fromMap(Map<Object?, Object?> map) =>
      TodayWidgetPreviewRow(
        time: _readNullableString(map, 'time'),
        title: _readString(map, 'title'),
        status: _readNullableString(map, 'status'),
        showTime: _readBool(map, 'showTime', fallback: false),
        showStatus: _readBool(map, 'showStatus', fallback: false),
        titleMaxLines: _readInt(map, 'titleMaxLines', min: 1, max: 2),
        progress: _readNullableString(map, 'progress'),
      );
}

class TodayWidgetPreviewFooter {
  const TodayWidgetPreviewFooter({
    required this.visible,
    required this.kind,
    this.text,
  });

  final bool visible;
  final TodayWidgetPreviewFooterKind kind;
  final String? text;

  factory TodayWidgetPreviewFooter.fromMap(Map<Object?, Object?> map) =>
      TodayWidgetPreviewFooter(
        visible: _readBool(map, 'visible', fallback: false),
        kind: _readEnum(
          map,
          'kind',
          TodayWidgetPreviewFooterKind.values,
          TodayWidgetPreviewFooterKind.none,
        ),
        text: _readNullableString(map, 'text'),
      );
}

/// 契约键缺失时用默认值补齐；出现非整数、未知枚举或越界直接拒绝。
int _readInt(
  Map<Object?, Object?> map,
  String key, {
  int? fallback,
  int? min,
  int? max,
  List<int>? allowed,
}) {
  if (!map.containsKey(key)) {
    if (fallback != null) return fallback;
    throw FormatException('小组件外观缺少 $key');
  }
  final value = map[key];
  if (value is! int) throw FormatException('小组件外观字段 $key 不是整数：$value');
  if (min != null && value < min) {
    throw FormatException('小组件外观字段 $key 小于 $min：$value');
  }
  if (max != null && value > max) {
    throw FormatException('小组件外观字段 $key 大于 $max：$value');
  }
  if (allowed != null && !allowed.contains(value)) {
    throw FormatException('小组件外观字段 $key 不在允许范围：$value');
  }
  return value;
}

bool _readBool(
  Map<Object?, Object?> map,
  String key, {
  required bool fallback,
}) {
  if (!map.containsKey(key)) return fallback;
  return _readRequiredBool(map, key);
}

/// 契约要求必有的布尔字段；缺失或类型不符整体拒绝，不能静默当作 false。
bool _readRequiredBool(Map<Object?, Object?> map, String key) {
  if (!map.containsKey(key)) throw FormatException('小组件外观缺少 $key');
  final value = map[key];
  if (value is! bool) throw FormatException('小组件外观字段 $key 不是布尔值：$value');
  return value;
}

String _readString(Map<Object?, Object?> map, String key, {String? fallback}) {
  if (!map.containsKey(key)) {
    if (fallback != null) return fallback;
    throw FormatException('小组件外观缺少 $key');
  }
  final value = map[key];
  if (value is! String) throw FormatException('小组件外观字段 $key 不是字符串：$value');
  return value;
}

String? _readNullableString(Map<Object?, Object?> map, String key) {
  if (!map.containsKey(key)) return null;
  final value = map[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('小组件外观字段 $key 不是字符串：$value');
  return value;
}

T _readEnum<T extends TodayWidgetWireValue>(
  Map<Object?, Object?> map,
  String key,
  List<T> values,
  T fallback,
) {
  if (!map.containsKey(key)) return fallback;
  return _parseEnumValue(map[key], key, values);
}

T _readRequiredEnum<T extends TodayWidgetWireValue>(
  Map<Object?, Object?> map,
  String key,
  List<T> values,
) {
  if (!map.containsKey(key)) throw FormatException('小组件外观缺少 $key');
  return _parseEnumValue(map[key], key, values);
}

T _parseEnumValue<T extends TodayWidgetWireValue>(
  Object? raw,
  String key,
  List<T> values,
) {
  if (raw is String) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
  }
  throw FormatException('小组件外观字段 $key 无效：$raw');
}

Map<Object?, Object?> _readMap(Map<Object?, Object?> map, String key) {
  if (!map.containsKey(key)) throw FormatException('小组件外观缺少 $key');
  return _readMapValue(map[key], key);
}

Map<Object?, Object?> _readMapValue(Object? value, String field) {
  if (value is Map<Object?, Object?>) return value;
  throw FormatException('小组件外观字段 $field 不是对象：$value');
}
