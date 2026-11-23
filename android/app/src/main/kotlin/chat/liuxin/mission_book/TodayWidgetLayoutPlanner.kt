package chat.liuxin.mission_book

import kotlin.math.roundToInt

/**
 * 尺寸类别与 provider 一一对应；public 因为它出现在 provider 构造参数上，
 * 其余规划器类型保持 internal。
 */
enum class WidgetSizeClass(val wire: String) {
    SMALL("small"),
    MEDIUM("medium"),
    LARGE("large"),
    ;

    companion object {
        fun fromWire(value: String?): WidgetSizeClass? = entries.firstOrNull { it.wire == value }
    }
}

/** 快照状态：没有当日快照是「等待同步」，有快照但零项才是真空日。 */
internal enum class WidgetSnapshotState { WAITING, EMPTY, DATA }

/** 一条待显示任务；文字与阶段都由快照方提供，规划器不查库、不推算。 */
internal data class WidgetItem(
    val id: String,
    val title: String,
    val startText: String?,
    val endText: String?,
    val statusText: String?,
    val flexibleTime: Boolean,
    val currentSlot: Boolean,
    val progressText: String?,
)

/**
 * 字体度量抽象：Android 用 `TextPaint` + `TypedValue.deriveDimension`（API 34+ 非线性缩放）实现，
 * 单测用可控的近似实现。单位统一为 px。
 */
internal interface WidgetTextMetrics {
    fun textWidthPx(text: String, sizeSp: Int): Float

    fun lineHeightPx(sizeSp: Int): Float
}

/** 契约第 3 节的颜色角色，ARGB。规划器只选角色，不做动态取色。 */
internal data class WidgetColors(
    val surface: Int,
    val content: Int,
    val rowSurface: Int,
    val spine: Int,
    val primaryText: Int,
    val secondaryText: Int,
    val accent: Int,
    val warn: Int,
    val hairline: Int,
)

/**
 * 已本地化的文案与格式。Android 从资源构造，单测直接给字面量。
 *
 * [more] 生成尾部「另有 N 项」；[count] 生成头部「+N」；[timeRange] 生成「开始–结束」；
 * [metaJoin] 把时间与阶段拼成一行辅助信息。
 */
internal class WidgetLabels(
    val title: String,
    val date: String,
    val waiting: String,
    val empty: String,
    val open: String,
    val untitled: String,
    val flexible: String,
    val more: (Int) -> String,
    val count: (Int) -> String,
    val timeRange: (String, String) -> String,
    val metaJoin: (String, String) -> String,
)

internal data class WidgetRowPlan(
    val id: String,
    val time: String?,
    val title: String,
    val status: String?,
    val showTime: Boolean,
    val showStatus: Boolean,
    val titleMaxLines: Int,
    val progress: String?,
    val currentSlot: Boolean,
    val contentDescription: String,
)

internal data class WidgetHeaderPlan(
    val visible: Boolean,
    val left: String,
    /** 关闭日期时为空串；渲染层据此隐藏日期槽。 */
    val right: String,
    /** 只有「头部 +N」这一种计数会放在题头。 */
    val count: String?,
)

internal data class WidgetFooterPlan(
    /** 只有尾部「另有 N 项」是可点尾部；头部计数时 `visible=false` 但 [kind] 仍是 `headerCount`。 */
    val visible: Boolean,
    val kind: String,
    val text: String?,
)

internal data class WidgetPlanMetrics(
    val horizontalPaddingDp: Int,
    val verticalPaddingDp: Int,
    val rowPaddingDp: Int,
    val rowGapDp: Int,
    val radiusDp: Int,
    val headerSp: Int,
    val taskSp: Int,
    val metaSp: Int,
    val headerHeightDp: Int,
    val footerHeightDp: Int,
    val rowHeightDp: Int,
    val horizontalPaddingPx: Int,
    val verticalPaddingPx: Int,
    val rowPaddingPx: Int,
    val rowGapPx: Int,
    val headerHeightPx: Int,
    val footerHeightPx: Int,
    val rowHeightPx: Int,
    val rowStartInsetPx: Int,
    val rowEndInsetPx: Int,
)

internal data class WidgetPlan(
    val sizeClass: WidgetSizeClass,
    val style: String,
    /** 已解析的 `light` / `dark`（`system` 由调用方按系统夜间模式解析后再传入）。 */
    val theme: String,
    val colors: WidgetColors,
    val metrics: WidgetPlanMetrics,
    val header: WidgetHeaderPlan,
    val rows: List<WidgetRowPlan>,
    val footer: WidgetFooterPlan,
    val empty: String,
    val overflow: String,
    /** `stack`（标题 + 辅助信息上下）或 `triSlot`（时间—任务—状态三槽）。 */
    val rowLayout: String,
    val spineVisible: Boolean,
    val dividerVisible: Boolean,
) {
    val visibleRowCount: Int get() = rows.size

    companion object {
        const val EMPTY_NONE = "none"
        const val EMPTY_WAITING = "waiting"
        const val EMPTY_EMPTY = "empty"

        const val OVERFLOW_NONE = "none"
        const val OVERFLOW_TIGHT = "tight"
        const val OVERFLOW_HEADER_ONLY = "headerOnly"

        const val FOOTER_NONE = "none"
        const val FOOTER_MORE = "more"
        const val FOOTER_HEADER_COUNT = "headerCount"

        const val ROW_LAYOUT_STACKED = "stacked"
        const val ROW_LAYOUT_WIDE = "wide"

        const val THEME_LIGHT = "light"
        const val THEME_DARK = "dark"
    }
}

internal data class WidgetPlanRequest(
    val sizeClass: WidgetSizeClass,
    /** Launcher 实际报出的可用宽（px），已含 Launcher 自己的内边距。 */
    val widthPx: Int,
    val heightPx: Int,
    val density: Float,
    val textMetrics: WidgetTextMetrics,
    val appearance: TodayWidgetAppearance,
    val state: WidgetSnapshotState,
    /** 快照里的条目（已按展示顺序、最多五条）；小号由调用方换成焦点条目。 */
    val items: List<WidgetItem>,
    /** 当日任务总数，用来算「另有 N 项」与头部 +N，不把上限当总数。 */
    val total: Int,
    val labels: WidgetLabels,
    /** 已解析主题：`light` / `dark`。 */
    val theme: String,
)

/**
 * 桌面小组件的纯布局规划器：**先算再建**。
 *
 * 输入是尺寸（px）、密度、字体度量（由调用方按系统 `fontScale` 与非线性缩放构造）、外观、
 * 条目列表、快照状态与文案；输出一份 [WidgetPlan]。桌面 `RemoteViews` 与设置内预览共用这份计划，
 * 因此这里不引用任何 Android 类型，可以在 JVM 单测覆盖容量、样式、字段开关和条数。
 *
 * 契约见 `docs/设计/小组件外观契约v2.md` 2.4 与 `docs/设计/桌面小组件与平板工作区改版计划.md` 4.2。
 * 关键约定：
 * - 容量先扣外侧上下留白，题头 `24dp`、尾部 `20dp` 是测量下限，字体变大可增高；
 * - 行高按实际字体度量 + 行内上下留白，触控下限 `32dp`（不减少行数且不隐藏尾部时才补到 `48dp`）；
 * - 从大到小逐个尝试 `n`，同一 `n` 先试尾部「另有 N 项」，尾部会挤掉一行而题头装得下时改用头部「+N」；
 * - 小号始终最多一行；中/大取 `min(rowLimit, 容量, 快照条数)`；
 * - `timeMode=range` 放不下先降级为开始时间，再不足优先保留阶段；不改保存值；
 * - 自选任务不填假时间；不按墙钟重算阶段（阶段文字由快照方给出）。
 */
internal object TodayWidgetLayoutPlanner {
    private const val HEADER_MIN_DP = 24f
    private const val FOOTER_MIN_DP = 20f
    private const val ROW_TOUCH_MIN_DP = 32f
    private const val ROW_TOUCH_COMFORT_DP = 48f
    private const val TRISLOT_MIN_WIDTH_DP = 220f
    private const val TRISLOT_TITLE_DP = 160f
    private const val ROW_START_INSET_DP = 2f
    private const val ROW_END_INSET_DP = 2f
    private const val SPINE_WIDTH_DP = 3f
    private const val SPINE_GAP_DP = 6f
    private const val META_GAP_DP = 2f
    private const val SLOT_GAP_DP = 6f
    private const val HEADER_SLOT_GAP_DP = 6f

    /** 契约第 3 节的明亮/深色令牌；深色额外给一条细线色，避免浅色细线在深底上发白。 */
    private val lightColors = WidgetColors(
        surface = 0xFFF7F8F5.toInt(),
        content = 0xFFFFFFFF.toInt(),
        rowSurface = 0xFFEEF2EC.toInt(),
        spine = 0xFF244D3D.toInt(),
        primaryText = 0xFF282E2A.toInt(),
        secondaryText = 0xFF626A64.toInt(),
        accent = 0xFF244D3D.toInt(),
        warn = 0xFF805D28.toInt(),
        hairline = 0xFFE0E5DD.toInt(),
    )
    private val darkColors = WidgetColors(
        surface = 0xFF1B251F.toInt(),
        content = 0xFF202C24.toInt(),
        rowSurface = 0xFF26382E.toInt(),
        spine = 0xFFA7C9B3.toInt(),
        primaryText = 0xFFEEF2EC.toInt(),
        secondaryText = 0xFFB8C9BE.toInt(),
        accent = 0xFFA7C9B3.toInt(),
        warn = 0xFFE7C48B.toInt(),
        hairline = 0xFF33453A.toInt(),
    )

    fun colors(theme: String): WidgetColors =
        if (theme == WidgetPlan.THEME_DARK) darkColors else lightColors

    fun plan(request: WidgetPlanRequest): WidgetPlan {
        val appearance = request.appearance
        val metrics = request.textMetrics
        val density = request.density
        val colors = colors(request.theme)
        val horizontalPaddingPx = px(appearance.horizontalPaddingDp, density)
        val verticalPaddingPx = px(appearance.verticalPaddingDp, density)
        val rowPaddingPx = px(appearance.rowPaddingDp, density)
        val rowGapPx = px(appearance.rowGapDp, density)
        val usableWidth = (request.widthPx - 2 * horizontalPaddingPx).coerceAtLeast(1).toFloat()
        val usableHeight = (request.heightPx - 2 * verticalPaddingPx).coerceAtLeast(1)
        // 题头/尾部先按测量下限预留；系统字号变大时按真实字体度量增高，而不是压字。
        val headerHeightPx = maxOf(
            dp(HEADER_MIN_DP, density),
            maxOf(metrics.lineHeightPx(appearance.headerSp), metrics.lineHeightPx(appearance.metaSp)),
        )
        val footerHeightPx = maxOf(dp(FOOTER_MIN_DP, density), metrics.lineHeightPx(appearance.metaSp))

        // 契约 2.4：index 使用左书脊，timeline 使用时间轨；两者都不用行分隔线。
        // paper/minimal 不铺行底并保留缩进分隔线。
        val spineVisible = appearance.style == TodayWidgetAppearance.STYLE_INDEX ||
            appearance.style == TodayWidgetAppearance.STYLE_TIMELINE
        val dividerVisible = appearance.style != TodayWidgetAppearance.STYLE_INDEX &&
            appearance.style != TodayWidgetAppearance.STYLE_TIMELINE
        val rowStartInsetPx = if (spineVisible) {
            px(SPINE_WIDTH_DP.roundToInt() + SPINE_GAP_DP.roundToInt(), density)
        } else {
            px(ROW_START_INSET_DP.roundToInt(), density)
        }
        val rowEndInsetPx = px(ROW_END_INSET_DP.roundToInt(), density)
        val rowInnerWidth = (usableWidth - rowStartInsetPx - rowEndInsetPx).coerceAtLeast(1f)

        val titleMaxLines = if (request.sizeClass == WidgetSizeClass.SMALL) 2 else 1
        val slotChoice = chooseSlots(request, usableWidth, rowInnerWidth, titleMaxLines)
        val timeMode = slotChoice.timeMode
        val hasMetaLine = appearance.showDetails &&
            (timeMode != TodayWidgetAppearance.TIME_NONE || appearance.showStatus)
        val rowHeight = rowHeight(
            layout = slotChoice.layout,
            metrics = metrics,
            appearance = appearance,
            titleMaxLines = titleMaxLines,
            hasMetaLine = hasMetaLine,
            rowPaddingPx = rowPaddingPx,
            density = density,
        )

        val metricsPlan = WidgetPlanMetrics(
            horizontalPaddingDp = appearance.horizontalPaddingDp,
            verticalPaddingDp = appearance.verticalPaddingDp,
            rowPaddingDp = appearance.rowPaddingDp,
            rowGapDp = appearance.rowGapDp,
            radiusDp = appearance.radiusDp,
            headerSp = appearance.headerSp,
            taskSp = appearance.taskSp,
            metaSp = appearance.metaSp,
            headerHeightDp = dpInt(headerHeightPx, density),
            footerHeightDp = dpInt(footerHeightPx, density),
            rowHeightDp = dpInt(rowHeight, density),
            horizontalPaddingPx = horizontalPaddingPx,
            verticalPaddingPx = verticalPaddingPx,
            rowPaddingPx = rowPaddingPx,
            rowGapPx = rowGapPx,
            headerHeightPx = headerHeightPx.toInt(),
            footerHeightPx = footerHeightPx.toInt(),
            rowHeightPx = rowHeight.toInt(),
            rowStartInsetPx = rowStartInsetPx,
            rowEndInsetPx = rowEndInsetPx,
        )

        val headerWidths = HeaderWidths(
            left = metrics.textWidthPx(request.labels.title, appearance.headerSp),
            right = if (appearance.showDate) {
                metrics.textWidthPx(request.labels.date, appearance.metaSp)
            } else {
                0f
            },
            gap = dp(HEADER_SLOT_GAP_DP, density),
        )

        if (request.state != WidgetSnapshotState.DATA || request.items.isEmpty()) {
            val empty = if (request.state == WidgetSnapshotState.WAITING) {
                WidgetPlan.EMPTY_WAITING
            } else {
                WidgetPlan.EMPTY_EMPTY
            }
            return WidgetPlan(
                sizeClass = request.sizeClass,
                style = appearance.style,
                theme = request.theme,
                colors = colors,
                metrics = metricsPlan,
                header = header(request, count = null),
                rows = emptyList(),
                footer = WidgetFooterPlan(false, WidgetPlan.FOOTER_NONE, null),
                empty = empty,
                overflow = WidgetPlan.OVERFLOW_NONE,
                rowLayout = slotChoice.layout,
                spineVisible = spineVisible,
                dividerVisible = dividerVisible,
            )
        }

        fun fits(rowCount: Int, withFooter: Boolean, height: Float = rowHeight): Boolean {
            if (rowCount <= 0) return true
            var required = headerHeightPx + rowCount * height + (rowCount - 1) * rowGapPx
            if (withFooter) required += rowGapPx + footerHeightPx
            return required <= usableHeight + 0.01f
        }

        fun headerFitsCount(countText: String): Boolean {
            val countWidth = metrics.textWidthPx(countText, appearance.metaSp)
            var required = headerWidths.left + headerWidths.gap + countWidth
            if (headerWidths.right > 0f) required += headerWidths.right + headerWidths.gap
            return required <= usableWidth + 0.01f
        }

        val rowCapacity = minOf(
            appearance.rowLimit,
            request.items.size,
            if (request.sizeClass == WidgetSizeClass.SMALL) 1 else Int.MAX_VALUE,
        )

        var visibleRows = 0
        var footerKind = WidgetPlan.FOOTER_NONE
        var footerText: String? = null
        for (candidate in rowCapacity downTo 1) {
            val hidden = (request.total - candidate).coerceAtLeast(0)
            val wantsCount = hidden > 0
            if (wantsCount && appearance.showMore && fits(candidate, withFooter = true)) {
                visibleRows = candidate
                footerKind = WidgetPlan.FOOTER_MORE
                footerText = request.labels.more(hidden)
                break
            }
            if (fits(candidate, withFooter = false)) {
                visibleRows = candidate
                if (wantsCount && appearance.showMore) {
                    // 尾部会挤掉一行，题头装得下就改成头部 +N；装不下则不显示计数。
                    val countText = request.labels.count(hidden)
                    if (headerFitsCount(countText)) {
                        footerKind = WidgetPlan.FOOTER_HEADER_COUNT
                        footerText = countText
                    }
                }
                break
            }
        }
        if (visibleRows <= 0) {
            // 连一整行都放不下时只留可点题头入口，不硬塞行，也不假装是空日。
            return WidgetPlan(
                sizeClass = request.sizeClass,
                style = appearance.style,
                theme = request.theme,
                colors = colors,
                metrics = metricsPlan,
                header = header(request, count = null),
                rows = emptyList(),
                footer = WidgetFooterPlan(false, WidgetPlan.FOOTER_NONE, null),
                empty = WidgetPlan.EMPTY_NONE,
                overflow = WidgetPlan.OVERFLOW_HEADER_ONLY,
                rowLayout = slotChoice.layout,
                spineVisible = spineVisible,
                dividerVisible = dividerVisible,
            )
        }

        // 触控舒适高度只在不减少行数、不隐藏尾部时补到 48dp，不继续随余量变高。
        val comfortableRowHeight = maxOf(rowHeight, dp(ROW_TOUCH_COMFORT_DP, density))
        val finalRowHeight = if (
            comfortableRowHeight > rowHeight &&
            fits(visibleRows, withFooter = footerKind == WidgetPlan.FOOTER_MORE, height = comfortableRowHeight)
        ) {
            comfortableRowHeight
        } else {
            rowHeight
        }

        val rows = request.items.take(visibleRows).map { item ->
            row(
                item = item,
                appearance = appearance,
                labels = request.labels,
                layout = slotChoice.layout,
                timeMode = timeMode,
                titleMaxLines = if (slotChoice.layout == WidgetPlan.ROW_LAYOUT_WIDE) 1 else titleMaxLines,
            )
        }
        val hidden = (request.total - visibleRows).coerceAtLeast(0)
        val overflow = when {
            footerKind == WidgetPlan.FOOTER_HEADER_COUNT -> WidgetPlan.OVERFLOW_TIGHT
            hidden > 0 && footerKind == WidgetPlan.FOOTER_NONE -> WidgetPlan.OVERFLOW_TIGHT
            visibleRows < rowCapacity -> WidgetPlan.OVERFLOW_TIGHT
            else -> WidgetPlan.OVERFLOW_NONE
        }
        return WidgetPlan(
            sizeClass = request.sizeClass,
            style = appearance.style,
            theme = request.theme,
            colors = colors,
            metrics = metricsPlan.copy(
                rowHeightPx = finalRowHeight.toInt(),
                rowHeightDp = dpInt(finalRowHeight, density),
            ),
            header = header(
                request,
                count = if (footerKind == WidgetPlan.FOOTER_HEADER_COUNT) footerText else null,
            ),
            rows = rows,
            footer = WidgetFooterPlan(
                visible = footerKind == WidgetPlan.FOOTER_MORE,
                kind = footerKind,
                text = if (footerKind == WidgetPlan.FOOTER_MORE) footerText else null,
            ),
            empty = WidgetPlan.EMPTY_NONE,
            overflow = overflow,
            rowLayout = slotChoice.layout,
            spineVisible = spineVisible,
            dividerVisible = dividerVisible,
        )
    }

    private data class HeaderWidths(val left: Float, val right: Float, val gap: Float)

    private data class SlotChoice(val layout: String, val timeMode: String)

    /**
     * 宽槽判定：可用宽 ≥ `220dp` **且** 时间/状态槽之外还能给任务名槽它需要的宽度
     * （需要量按实际字体度量算，最多按 `160dp` 计）。任何一条不满足就回退上下布局。
     *
     * 时间文字按「开始–结束」先试；放不下先降级为开始时间；再不足优先保留阶段（隐藏时间）。
     */
    private fun chooseSlots(
        request: WidgetPlanRequest,
        usableWidth: Float,
        rowInnerWidth: Float,
        titleMaxLines: Int,
    ): SlotChoice {
        val appearance = request.appearance
        val labels = request.labels
        if (!appearance.showDetails) {
            // 关闭详情时只显示任务名，三槽没有意义。
            return SlotChoice(WidgetPlan.ROW_LAYOUT_STACKED, TodayWidgetAppearance.TIME_NONE)
        }
        // 契约的「可用宽」指扣掉外侧左右留白后、行内边距之前的宽度。
        val wideEnough = usableWidth >= dp(TRISLOT_MIN_WIDTH_DP, request.density)
        if (!wideEnough || request.sizeClass == WidgetSizeClass.SMALL) {
            return SlotChoice(WidgetPlan.ROW_LAYOUT_STACKED, stackedTimeMode(request, rowInnerWidth))
        }
        val titleNeed = minOf(
            dp(TRISLOT_TITLE_DP, request.density),
            request.items.maxOfOrNull {
                request.textMetrics.textWidthPx(it.title.ifBlank { labels.untitled }, appearance.taskSp)
            } ?: 0f,
        )
        val statusWidth = if (appearance.showStatus) {
            request.items.maxOfOrNull {
                request.textMetrics.textWidthPx(it.statusText.orEmpty(), appearance.metaSp)
            } ?: 0f
        } else {
            0f
        }
        val slotGap = dp(SLOT_GAP_DP, request.density)
        val timeModes = when (appearance.timeMode) {
            TodayWidgetAppearance.TIME_RANGE -> listOf(
                TodayWidgetAppearance.TIME_RANGE,
                TodayWidgetAppearance.TIME_START,
            )
            TodayWidgetAppearance.TIME_START -> listOf(TodayWidgetAppearance.TIME_START)
            else -> listOf(TodayWidgetAppearance.TIME_NONE)
        }
        for (mode in timeModes) {
            val timeWidth = if (mode == TodayWidgetAppearance.TIME_NONE) {
                0f
            } else {
                request.items.maxOfOrNull { item ->
                    request.textMetrics.textWidthPx(
                        timeText(item, mode, labels).orEmpty(), appearance.metaSp,
                    )
                } ?: 0f
            }
            val gaps = (if (timeWidth > 0f) slotGap else 0f) + (if (statusWidth > 0f) slotGap else 0f)
            val titleWidth = rowInnerWidth - timeWidth - statusWidth - gaps
            // 时间槽存在时，任务名槽至少要有它需要的宽度（不超过 160dp）才算宽槽成立。
            if (titleWidth >= titleNeed && titleWidth > 0f) {
                return SlotChoice(WidgetPlan.ROW_LAYOUT_WIDE, mode)
            }
        }
        return SlotChoice(WidgetPlan.ROW_LAYOUT_STACKED, stackedTimeMode(request, rowInnerWidth))
    }

    /** 上下布局只有一行辅助信息：范围放不下先降级开始时间，再不足保留阶段。 */
    private fun stackedTimeMode(request: WidgetPlanRequest, rowInnerWidth: Float): String {
        val appearance = request.appearance
        if (!appearance.showDetails || appearance.timeMode == TodayWidgetAppearance.TIME_NONE) {
            return TodayWidgetAppearance.TIME_NONE
        }
        if (appearance.timeMode != TodayWidgetAppearance.TIME_RANGE) {
            return TodayWidgetAppearance.TIME_START
        }
        fun tooWide(mode: String): Boolean = request.items.any { item ->
            val time = timeText(item, mode, request.labels).orEmpty()
            val status = if (appearance.showStatus) item.statusText.orEmpty() else ""
            val text = when {
                time.isNotEmpty() && status.isNotEmpty() -> request.labels.metaJoin(time, status)
                else -> time + status
            }
            request.textMetrics.textWidthPx(text, appearance.metaSp) > rowInnerWidth
        }
        return when {
            !tooWide(TodayWidgetAppearance.TIME_RANGE) -> TodayWidgetAppearance.TIME_RANGE
            !tooWide(TodayWidgetAppearance.TIME_START) -> TodayWidgetAppearance.TIME_START
            // 阶段已关闭时优先保留时间（宁可省略号），不把辅助信息整行清空。
            appearance.showStatus -> TodayWidgetAppearance.TIME_NONE
            else -> TodayWidgetAppearance.TIME_START
        }
    }

    private fun rowHeight(
        layout: String,
        metrics: WidgetTextMetrics,
        appearance: TodayWidgetAppearance,
        titleMaxLines: Int,
        hasMetaLine: Boolean,
        rowPaddingPx: Int,
        density: Float,
    ): Float {
        val verticalPadding = rowPaddingPx * 2f
        val content = if (layout == WidgetPlan.ROW_LAYOUT_WIDE) {
            maxOf(
                metrics.lineHeightPx(appearance.taskSp),
                if (hasMetaLine) metrics.lineHeightPx(appearance.metaSp) else 0f,
            ) + verticalPadding
        } else {
            titleMaxLines * metrics.lineHeightPx(appearance.taskSp) +
                (if (hasMetaLine) metrics.lineHeightPx(appearance.metaSp) + dp(META_GAP_DP, density) else 0f) +
                verticalPadding
        }
        return maxOf(content, dp(ROW_TOUCH_MIN_DP, density))
    }

    private fun row(
        item: WidgetItem,
        appearance: TodayWidgetAppearance,
        labels: WidgetLabels,
        layout: String,
        timeMode: String,
        titleMaxLines: Int,
    ): WidgetRowPlan {
        val title = item.title.ifBlank { labels.untitled }
        val time = if (appearance.showDetails) timeText(item, timeMode, labels) else null
        val status = if (appearance.showDetails && appearance.showStatus) item.statusText else null
        val description = buildList {
            add(title)
            if (!time.isNullOrEmpty()) add(time)
            if (!status.isNullOrEmpty()) add(status)
        }.joinToString(", ")
        return WidgetRowPlan(
            id = item.id,
            time = time,
            title = title,
            status = status,
            showTime = !time.isNullOrEmpty(),
            showStatus = !status.isNullOrEmpty(),
            titleMaxLines = titleMaxLines,
            // 进度文案只给当前时段行，桌面 RemoteViews 不新增控件，预览按契约绘制。
            progress = if (item.currentSlot) item.progressText else null,
            currentSlot = item.currentSlot,
            contentDescription = description,
        )
    }

    /** 时间文案：`none` 不显示；自选/无开始时间显示「自选时间」，不填假时间。 */
    private fun timeText(item: WidgetItem, mode: String, labels: WidgetLabels): String? {
        if (mode == TodayWidgetAppearance.TIME_NONE) return null
        val start = item.startText
        if (item.flexibleTime || start.isNullOrEmpty()) return labels.flexible
        val end = item.endText
        if (mode == TodayWidgetAppearance.TIME_RANGE && !end.isNullOrEmpty() && end != start) {
            return labels.timeRange(start, end)
        }
        return start
    }

    private fun header(request: WidgetPlanRequest, count: String?): WidgetHeaderPlan = WidgetHeaderPlan(
        visible = true,
        left = request.labels.title,
        right = if (request.appearance.showDate) request.labels.date else "",
        count = count,
    )

    private fun px(dp: Int, density: Float): Int = Math.round(dp * density)

    private fun dp(value: Float, density: Float): Float = value * density

    private fun dpInt(px: Float, density: Float): Int = Math.round(px / density)
}

/**
 * `previewAppearance` 回执的纯组装：把同一份 [WidgetPlan] 投影成契约 2.4 的字段集合。
 *
 * 放在纯 Kotlin 里是为了让键名、枚举字符串、`rowLayout` 映射与行字段都能在 JVM 单测对拍；
 * Android 侧只补充尺寸来源与示例快照，不在这里推导版式或颜色。
 */
internal object TodayWidgetPreviewPayload {
    fun build(
        plan: WidgetPlan,
        sizeClass: WidgetSizeClass,
        sizeSource: String,
        widthDp: Int,
        heightDp: Int,
    ): Map<String, Any?> = linkedMapOf(
        "version" to TodayWidgetAppearance.VERSION,
        "sizeClass" to sizeClass.wire,
        "sizeSource" to sizeSource,
        "widthDp" to widthDp,
        "heightDp" to heightDp,
        "theme" to plan.theme,
        "style" to plan.style,
        "colors" to linkedMapOf(
            "surface" to plan.colors.surface,
            "content" to plan.colors.content,
            "rowSurface" to plan.colors.rowSurface,
            "spine" to plan.colors.spine,
            "primaryText" to plan.colors.primaryText,
            "secondaryText" to plan.colors.secondaryText,
            "accent" to plan.colors.accent,
            "warn" to plan.colors.warn,
            "hairline" to plan.colors.hairline,
        ),
        "metrics" to linkedMapOf(
            "horizontalPadding" to plan.metrics.horizontalPaddingDp,
            "verticalPadding" to plan.metrics.verticalPaddingDp,
            "rowPadding" to plan.metrics.rowPaddingDp,
            "rowGap" to plan.metrics.rowGapDp,
            "radius" to plan.metrics.radiusDp,
            "headerSp" to plan.metrics.headerSp,
            "taskSp" to plan.metrics.taskSp,
            "metaSp" to plan.metrics.metaSp,
            "headerHeight" to plan.metrics.headerHeightDp,
            "footerHeight" to plan.metrics.footerHeightDp,
            "rowHeight" to plan.metrics.rowHeightDp,
        ),
        "header" to linkedMapOf(
            "visible" to plan.header.visible,
            "left" to plan.header.left,
            "right" to plan.header.right,
            "count" to plan.header.count,
        ),
        "rows" to plan.rows.map { row ->
            linkedMapOf(
                "time" to row.time,
                "title" to row.title,
                "status" to row.status,
                "showTime" to row.showTime,
                "showStatus" to row.showStatus,
                "titleMaxLines" to row.titleMaxLines,
                "progress" to row.progress,
                "currentSlot" to row.currentSlot,
            )
        },
        "footer" to linkedMapOf(
            "visible" to plan.footer.visible,
            "kind" to plan.footer.kind,
            "text" to plan.footer.text,
        ),
        "empty" to plan.empty,
        "overflow" to plan.overflow,
        // 契约 2.4：行版式只有 wide / stacked 两种对外取值，书脊与分隔线由样式决定。
        "rowLayout" to plan.rowLayout,
        "spineVisible" to plan.spineVisible,
        "dividerVisible" to plan.dividerVisible,
        "sample" to true,
    )
}
