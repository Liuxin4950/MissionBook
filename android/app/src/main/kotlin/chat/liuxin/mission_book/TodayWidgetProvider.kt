package chat.liuxin.mission_book

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.AtomicFile
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.time.ZoneId
import java.time.ZonedDateTime

/** Three picker entries share one read-only snapshot, one appearance and one renderer. */
class TodayWidgetSmall : TodayWidgetProvider(WidgetSizeClass.SMALL, 109, 109)
class TodayWidgetMedium : TodayWidgetProvider(WidgetSizeClass.MEDIUM, 220, 109)
class TodayWidgetLarge : TodayWidgetProvider(WidgetSizeClass.LARGE, 220, 220)

/**
 * 三个 provider 保持原有类名与缓存/深链入口：桌面既有实例原地升级。
 *
 * 渲染流程：读一次外观快照 → 读缓存快照 → 纯规划器出 [WidgetPlan] → RemoteViews 逐项显式设置。
 * 外观保存/预览不触发任务查询，也不按墙钟重算阶段。
 */
abstract class TodayWidgetProvider(
    internal val sizeClass: WidgetSizeClass,
    internal val defaultWidthDp: Int,
    internal val defaultHeightDp: Int,
) : AppWidgetProvider() {
    override fun onEnabled(context: Context) {
        refreshDate(context)
        TodayWidgetRefreshJob.request(context)
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val today = ZonedDateTime.now(scheduleZone).toLocalDate()
        val days = readDays(context)
        val day = days[today.toString()]
        val appearance = TodayWidgetAppearanceStore.read(context)
        val spec = specFor(sizeClass)
        for (id in ids) render(context, manager, id, spec, appearance, day, today.toString())
        scheduleMidnight(context, day != null && days.containsKey(today.plusDays(1).toString()))
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) {
        val date = ZonedDateTime.now(scheduleZone).toLocalDate().toString()
        render(
            context, manager, id, specFor(sizeClass),
            TodayWidgetAppearanceStore.read(context), readDays(context)[date], date,
        )
    }

    override fun onDisabled(context: Context) {
        if (hasInstances(context)) return
        synchronized(snapshotLock) { snapshotFile(context).delete() }
        val pending = midnightIntent(context, PendingIntent.FLAG_NO_CREATE) ?: return
        context.getSystemService(AlarmManager::class.java).cancel(pending)
        pending.cancel()
    }

    companion object {
        const val OPEN_ACTION = "chat.liuxin.mission_book.OPEN_TODAY_WIDGET"
        const val MISSION_ID = "missionId"
        internal const val MIDNIGHT_ACTION = "chat.liuxin.mission_book.TODAY_WIDGET_MIDNIGHT"
        internal const val WIDGETS_NO_INSTANCES = "noInstances"
        internal const val WIDGETS_REQUESTED = "requested"
        internal const val WIDGETS_PARTIAL_FAILURE = "partialFailure"
        internal const val WIDGETS_FAILED = "failed"
        private const val MAX_CACHE_BYTES = 128 * 1024
        private const val ALARM_REQUEST = 7031
        private val scheduleZone = ZoneId.of("Asia/Shanghai")
        private val snapshotLock = Any()
        private val datePattern = Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}")

        internal data class WidgetProviderSpec(
            val provider: Class<out TodayWidgetProvider>,
            val sizeClass: WidgetSizeClass,
            val defaultWidthDp: Int,
            val defaultHeightDp: Int,
        )

        internal val specs = listOf(
            WidgetProviderSpec(TodayWidgetSmall::class.java, WidgetSizeClass.SMALL, 109, 109),
            WidgetProviderSpec(TodayWidgetMedium::class.java, WidgetSizeClass.MEDIUM, 220, 109),
            WidgetProviderSpec(TodayWidgetLarge::class.java, WidgetSizeClass.LARGE, 220, 220),
        )

        internal fun specFor(sizeClass: WidgetSizeClass): WidgetProviderSpec =
            specs.first { it.sizeClass == sizeClass }

        private data class Day(val total: Int, val rows: List<Row>, val featured: Row?)
        private data class Row(
            val id: String,
            val title: String,
            val start: String?,
            val end: String?,
            val phase: String,
        )

        /** Dart supplies a bounded, derived snapshot; neither the launcher nor Kotlin writes tasks. */
        fun publish(context: Context, json: String) {
            val bytes = json.toByteArray(Charsets.UTF_8)
            require(bytes.size <= MAX_CACHE_BYTES) { "Widget snapshot is too large" }
            parseDays(json)
            synchronized(snapshotLock) {
                val file = snapshotFile(context)
                val output = file.startWrite()
                try {
                    output.write(bytes)
                    file.finishWrite(output)
                } catch (error: Exception) {
                    file.failWrite(output)
                    throw error
                }
            }
            updateAll(context)
        }

        /** Re-render from cache only. Never schedules a Dart read in response to a publish. */
        fun updateAll(context: Context) {
            redrawAll(context)
        }

        /**
         * 用已保存外观 + 已缓存快照重绘，返回契约 2.2 的四态之一。
         *
         * 每批共用同一份外观快照；单个实例异常不影响其它实例。`requested` 只表示
         * `updateAppWidget` 已交给系统，不代表 Launcher 已绘制。
         */
        fun redrawAll(context: Context): String {
            val date = ZonedDateTime.now(scheduleZone).toLocalDate().toString()
            return renderAll(context, TodayWidgetAppearanceStore.read(context), readDays(context)[date], date)
        }

        /** 通道回执用：重绘整体异常（非单实例失败）也只报 `failed`，不回滚已保存外观。 */
        internal fun redrawSafely(context: Context): String = runCatching {
            redrawAll(context)
        }.getOrElse {
            android.util.Log.w("MissionBook", "桌面小组件批量重绘失败", it)
            WIDGETS_FAILED
        }

        fun hasInstances(context: Context): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            return specs.any { manager.getAppWidgetIds(ComponentName(context, it.provider)).isNotEmpty() }
        }

        internal fun refreshDate(context: Context) {
            if (!hasInstances(context)) return
            val date = ZonedDateTime.now(scheduleZone).toLocalDate()
            val days = readDays(context)
            val day = days[date.toString()]
            renderAll(context, TodayWidgetAppearanceStore.read(context), day, date.toString())
            scheduleMidnight(context, day != null && days.containsKey(date.plusDays(1).toString()))
        }

        private fun scheduleMidnight(context: Context, hasBothDays: Boolean) {
            val midnight = ZonedDateTime.now(scheduleZone).toLocalDate().plusDays(1)
                .atStartOfDay(scheduleZone).toInstant().toEpochMilli()
            // Best effort: no exact-alarm permission or permanent background service for display.
            val pending = midnightIntent(context, PendingIntent.FLAG_UPDATE_CURRENT)
            if (pending != null) {
                context.getSystemService(AlarmManager::class.java)
                    .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, midnight, pending)
            }
            if (!hasBothDays) TodayWidgetRefreshJob.request(context)
        }

        private fun midnightIntent(context: Context, flag: Int): PendingIntent? =
            PendingIntent.getBroadcast(
                context, ALARM_REQUEST,
                Intent(context, TodayWidgetDateReceiver::class.java).setAction(MIDNIGHT_ACTION),
                PendingIntent.FLAG_IMMUTABLE or flag,
            )

        private fun snapshotFile(context: Context) =
            AtomicFile(File(context.noBackupFilesDir, "today-widget-v1.json"))

        private fun readDays(context: Context): Map<String, Day> = synchronized(snapshotLock) {
            // No missing/invalid/old snapshot is displayed as a real empty schedule.
            runCatching {
                val bytes = snapshotFile(context).readFully()
                require(bytes.size <= MAX_CACHE_BYTES)
                parseDays(bytes.toString(Charsets.UTF_8))
            }.getOrDefault(emptyMap())
        }

        private fun parseDays(json: String): Map<String, Day> {
            val root = JSONObject(json)
            require(root.getInt("schemaVersion") == 1)
            val days = root.getJSONArray("days")
            require(days.length() <= 2)
            return buildMap {
                for (index in 0 until days.length()) {
                    val day = days.getJSONObject(index)
                    val date = day.getString("date")
                    val total = day.getInt("total")
                    val rows = day.getJSONArray("rows")
                    require(datePattern.matches(date) && date !in this && total >= rows.length())
                    require(rows.length() <= 5)
                    put(date, Day(total, List(rows.length()) { i ->
                        parseRow(rows.getJSONObject(i))
                    }, day.optJSONObject("featured")?.let(::parseRow)))
                }
            }
        }

        private fun parseRow(row: JSONObject) = Row(
            id = row.getString("id"),
            title = row.getString("title"),
            start = row.optionalString("start"),
            end = row.optionalString("end"),
            phase = row.getString("phase"),
        )

        private fun JSONObject.optionalString(key: String): String? =
            if (isNull(key)) null else getString(key)

        private fun renderAll(
            context: Context,
            appearance: AppearanceSnapshot,
            day: Day?,
            date: String,
        ): String {
            val manager = AppWidgetManager.getInstance(context)
            var total = 0
            var failed = 0
            for (spec in specs) {
                for (id in manager.getAppWidgetIds(ComponentName(context, spec.provider))) {
                    total++
                    try {
                        render(context, manager, id, spec, appearance, day, date)
                    } catch (error: Exception) {
                        failed++
                        android.util.Log.w("MissionBook", "桌面小组件重绘失败：$id", error)
                    }
                }
            }
            return when {
                total == 0 -> WIDGETS_NO_INSTANCES
                failed == 0 -> WIDGETS_REQUESTED
                failed == total -> WIDGETS_FAILED
                else -> WIDGETS_PARTIAL_FAILURE
            }
        }

        private fun render(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            spec: WidgetProviderSpec,
            appearance: AppearanceSnapshot,
            day: Day?,
            date: String,
        ) {
            val options = manager.getAppWidgetOptions(id)
            val density = context.resources.displayMetrics.density
            // 当前实例尺寸优先取 MIN_WIDTH/MIN_HEIGHT：多数 Launcher（含 MIUI「桌面」）
            // 不会使用 RemoteViews 的尺寸映射，混合尺寸反而会被裁到某一档；
            // 只有 Launcher 完全不报当前尺寸时才退回 OPTION_APPWIDGET_SIZES 的保守值。
            val size = TodayWidgetSizes.current(options, spec.defaultWidthDp, spec.defaultHeightDp)
            val pixels = toPx(size, density)
            manager.updateAppWidget(
                id, buildViews(context, id, spec, appearance, day, date, pixels),
            )
        }

        private fun toPx(size: SizeF, density: Float): WidgetPixels = WidgetPixels(
            width = Math.round(size.width * density).coerceAtLeast(1),
            height = Math.round(size.height * density).coerceAtLeast(1),
        )

        /** dp 之外的另一个单位边界：规划器只认 px，这里一次换算。 */
        internal data class WidgetPixels(val width: Int, val height: Int)

        private fun buildViews(
            context: Context,
            widgetId: Int,
            spec: WidgetProviderSpec,
            appearance: AppearanceSnapshot,
            day: Day?,
            date: String,
            size: WidgetPixels,
        ): RemoteViews {
            val draft = appearance.appearance
            val theme = resolveTheme(context, draft.theme)
            val metrics = AndroidWidgetTextMetrics(context)
            val state = when {
                day == null -> WidgetSnapshotState.WAITING
                day.total <= 0 -> WidgetSnapshotState.EMPTY
                else -> WidgetSnapshotState.DATA
            }
            val labels = labels(context, spec.sizeClass, date)
            val items = itemsFor(context, spec.sizeClass, day)
            fun planFor(appearance: TodayWidgetAppearance) = TodayWidgetLayoutPlanner.plan(
                WidgetPlanRequest(
                    sizeClass = spec.sizeClass,
                    widthPx = size.width,
                    heightPx = size.height,
                    density = context.resources.displayMetrics.density,
                    textMetrics = metrics,
                    appearance = appearance,
                    state = state,
                    items = items,
                    total = day?.total ?: 0,
                    labels = labels,
                    theme = theme,
                ),
            )
            var effective = draft
            var plan = planFor(effective)
            if (plan.rows.isEmpty() && state == WidgetSnapshotState.DATA &&
                spec.sizeClass != WidgetSizeClass.SMALL
            ) {
                // 已有任务却一行都排不下时，先让位给任务：去掉日期与尾部计数再规划一次，
                // 避免宿主上报的可用高度偏小时只剩题头，看起来像“没有数据”。
                val compact = draft.copy(showDate = false, showMore = false)
                val retry = planFor(compact)
                if (retry.rows.isNotEmpty()) {
                    effective = compact
                    plan = retry
                }
            }
            // 真机排查：把本次实际使用的尺寸与排出的行写进私有文件，便于在无日志环境核对。
            runCatching {
                File(context.noBackupFilesDir, "today-widget-render.txt").writeText(
                    buildString {
                        appendLine("widgetId=$widgetId class=${spec.sizeClass.wire}")
                        appendLine("sizePx=${size.width}x${size.height} density=${context.resources.displayMetrics.density}")
                        appendLine("state=$state rows=${plan.rows.size} layout=${plan.rowLayout} overflow=${plan.overflow}")
                        appendLine("style=${effective.style} taskSp=${effective.taskSp} headerSp=${effective.headerSp}")
                        appendLine("header=${plan.header.left} | ${plan.header.right} | ${plan.header.count}")
                        plan.rows.forEach { appendLine("row=${it.time} | ${it.title} | ${it.status}") }
                        append("footer=${plan.footer.visible} ${plan.footer.kind} ${plan.footer.text}")
                    },
                )
            }
            return applyPlan(context, widgetId, plan, effective, labels)
        }

        private fun itemsFor(context: Context, sizeClass: WidgetSizeClass, day: Day?): List<WidgetItem> {
            if (day == null) return emptyList()
            val rows = if (sizeClass == WidgetSizeClass.SMALL) {
                // 小号沿用现有焦点排序：优先进行中/待确认/下一项。
                listOfNotNull(day.featured ?: day.rows.firstOrNull())
            } else {
                day.rows
            }
            return rows.map { row ->
                WidgetItem(
                    id = row.id,
                    title = row.title,
                    startText = row.start,
                    endText = row.end,
                    statusText = phaseLabel(context, row.phase),
                    // 自选任务没有固定开始时间：不填假时间，显示「自选时间」。
                    flexibleTime = row.start == null,
                    currentSlot = row.phase == "running",
                    progressText = null,
                )
            }
        }

        private fun phaseLabel(context: Context, phase: String): String? = when (phase) {
            "notStarted" -> R.string.today_widget_phase_not_started
            "running" -> R.string.today_widget_phase_running
            "paused" -> R.string.today_widget_phase_paused
            "reportPending" -> R.string.today_widget_phase_report_pending
            "evidencePending" -> R.string.today_widget_phase_evidence_pending
            "closed" -> R.string.today_widget_phase_closed
            "cancelled" -> R.string.today_widget_phase_cancelled
            else -> null
        }?.let(context::getString)

        internal fun labels(context: Context, sizeClass: WidgetSizeClass, date: String): WidgetLabels {
            val month = date.substring(5, 7).toIntOrNull() ?: 0
            val dayOfMonth = date.substring(8, 10).toIntOrNull() ?: 0
            return WidgetLabels(
                title = context.getString(
                    if (sizeClass == WidgetSizeClass.SMALL) R.string.today_widget_title_small
                    else R.string.today_widget_title,
                ),
                date = context.getString(
                    if (sizeClass == WidgetSizeClass.SMALL) R.string.today_widget_date_short
                    else R.string.today_widget_date_long,
                    month, dayOfMonth,
                ),
                waiting = context.getString(R.string.today_widget_load),
                empty = context.getString(R.string.today_widget_empty),
                open = context.getString(R.string.today_widget_open),
                untitled = context.getString(R.string.today_widget_untitled),
                flexible = context.getString(R.string.today_widget_flexible),
                more = { count -> context.getString(R.string.today_widget_more, count) },
                count = { count -> context.getString(R.string.today_widget_header_count, count) },
                timeRange = { start, end ->
                    context.getString(R.string.today_widget_time_range, start, end)
                },
                metaJoin = { time, status ->
                    context.getString(R.string.today_widget_row_subtitle, time, status)
                },
            )
        }

        internal fun resolveTheme(context: Context, theme: String): String = when (theme) {
            TodayWidgetAppearance.THEME_LIGHT -> WidgetPlan.THEME_LIGHT
            TodayWidgetAppearance.THEME_DARK -> WidgetPlan.THEME_DARK
            else -> if (isNight(context)) WidgetPlan.THEME_DARK else WidgetPlan.THEME_LIGHT
        }

        private fun isNight(context: Context): Boolean =
            (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES

        /**
         * 显式设置可见性、文字、字号、颜色、间距、背景与点击，包括「显式深色切回系统」。
         * 每个实例的点击意图仍按组件实例与任务区分。
         */
        private fun applyPlan(
            context: Context,
            widgetId: Int,
            plan: WidgetPlan,
            appearance: TodayWidgetAppearance,
            labels: WidgetLabels,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.today_widget)
            val explicit = appearance.theme != TodayWidgetAppearance.THEME_SYSTEM
            val colors = plan.colors
            val metrics = plan.metrics
            val openToday = activityIntent(context, widgetId, null)

            // 圆角用真实 shape 资源（不是只改 outline），并显式换回系统主题资源。
            views.setInt(
                R.id.today_widget_root,
                "setBackgroundResource",
                surfaceDrawable(appearance.theme, appearance.radiusDp),
            )
            views.setViewPadding(
                R.id.today_widget_root,
                metrics.horizontalPaddingPx,
                metrics.verticalPaddingPx,
                metrics.horizontalPaddingPx,
                metrics.verticalPaddingPx,
            )
            views.setOnClickPendingIntent(R.id.today_widget_root, openToday)
            views.setOnClickPendingIntent(R.id.today_widget_header, openToday)
            views.setOnClickPendingIntent(R.id.today_widget_empty, openToday)
            views.setOnClickPendingIntent(R.id.today_widget_more, openToday)

            views.setInt(R.id.today_widget_header, "setMinimumHeight", metrics.headerHeightPx)
            views.setTextViewText(R.id.today_widget_title, plan.header.left)
            views.setTextViewTextSize(
                R.id.today_widget_title, TypedValue.COMPLEX_UNIT_SP, appearance.headerSp.toFloat(),
            )
            views.textColor(
                context, R.id.today_widget_title, R.color.today_widget_primary,
                if (explicit) colors.primaryText else null,
            )
            views.setTextViewText(R.id.today_widget_date, plan.header.right)
            views.setTextViewTextSize(
                R.id.today_widget_date, TypedValue.COMPLEX_UNIT_SP, appearance.metaSp.toFloat(),
            )
            views.setViewVisibility(
                R.id.today_widget_date,
                if (plan.header.right.isEmpty()) View.GONE else View.VISIBLE,
            )
            views.textColor(
                context, R.id.today_widget_date, R.color.today_widget_secondary,
                if (explicit) colors.secondaryText else null,
            )
            views.setTextViewText(R.id.today_widget_count, plan.header.count.orEmpty())
            views.setTextViewTextSize(
                R.id.today_widget_count, TypedValue.COMPLEX_UNIT_SP, appearance.metaSp.toFloat(),
            )
            views.setViewVisibility(
                R.id.today_widget_count,
                if (plan.header.count == null) View.GONE else View.VISIBLE,
            )
            views.textColor(
                context, R.id.today_widget_count, R.color.today_widget_accent,
                if (explicit) colors.accent else null,
            )

            views.removeAllViews(R.id.today_widget_rows)
            for (row in plan.rows) {
                views.addView(
                    R.id.today_widget_rows,
                    buildRow(context, widgetId, row, plan, appearance),
                )
            }
            views.setViewVisibility(
                R.id.today_widget_rows,
                if (plan.rows.isEmpty()) View.GONE else View.VISIBLE,
            )

            // 空间不足退化为题头入口时也保留可点「查看今日任务」，不把拥挤当成空日。
            val emptyVisible = plan.empty != WidgetPlan.EMPTY_NONE ||
                plan.overflow == WidgetPlan.OVERFLOW_HEADER_ONLY
            val emptyText = when {
                plan.overflow == WidgetPlan.OVERFLOW_HEADER_ONLY -> labels.open
                plan.empty == WidgetPlan.EMPTY_WAITING -> labels.waiting
                plan.empty == WidgetPlan.EMPTY_EMPTY -> labels.empty
                else -> ""
            }
            views.setTextViewText(R.id.today_widget_empty, emptyText)
            views.setTextViewTextSize(
                R.id.today_widget_empty, TypedValue.COMPLEX_UNIT_SP, appearance.metaSp.toFloat(),
            )
            views.setViewVisibility(
                R.id.today_widget_empty, if (emptyVisible) View.VISIBLE else View.GONE,
            )
            views.textColor(
                context, R.id.today_widget_empty, R.color.today_widget_secondary,
                if (explicit) colors.secondaryText else null,
            )

            views.setInt(R.id.today_widget_more, "setMinimumHeight", metrics.footerHeightPx)
            views.setTextViewText(R.id.today_widget_more, plan.footer.text.orEmpty())
            views.setTextViewTextSize(
                R.id.today_widget_more, TypedValue.COMPLEX_UNIT_SP, appearance.metaSp.toFloat(),
            )
            views.setViewVisibility(
                R.id.today_widget_more,
                if (plan.footer.visible) View.VISIBLE else View.GONE,
            )
            views.textColor(
                context, R.id.today_widget_more, R.color.today_widget_accent,
                if (explicit) colors.accent else null,
            )
            return views
        }

        private fun buildRow(
            context: Context,
            widgetId: Int,
            row: WidgetRowPlan,
            plan: WidgetPlan,
            appearance: TodayWidgetAppearance,
        ): RemoteViews {
            val layout = when {
                plan.rowLayout == WidgetPlan.ROW_LAYOUT_WIDE -> R.layout.today_widget_row_compact
                plan.sizeClass == WidgetSizeClass.SMALL -> R.layout.today_widget_row_featured
                else -> R.layout.today_widget_row
            }
            val views = RemoteViews(context.packageName, layout)
            val explicit = appearance.theme != TodayWidgetAppearance.THEME_SYSTEM
            val colors = plan.colors
            val metrics = plan.metrics
            views.setInt(R.id.today_widget_row, "setMinimumHeight", metrics.rowHeightPx)
            views.setViewPadding(
                R.id.today_widget_row, 0, metrics.rowPaddingPx, 0, metrics.rowPaddingPx,
            )
            views.setViewPadding(
                R.id.today_widget_row_content,
                metrics.rowStartInsetPx, 0, metrics.rowEndInsetPx, 0,
            )
            // 行底/书脊/分隔线每次显式设置：样式与浅深切换后宿主可能复用旧视图。
            if (appearance.style == TodayWidgetAppearance.STYLE_INDEX) {
                views.setInt(
                    R.id.today_widget_row,
                    "setBackgroundResource",
                    rowBackground(appearance.theme),
                )
            } else {
                views.setInt(R.id.today_widget_row, "setBackgroundColor", Color.TRANSPARENT)
            }
            views.setViewVisibility(
                R.id.today_widget_row_spine,
                if (plan.spineVisible) View.VISIBLE else View.GONE,
            )
            if (plan.spineVisible) {
                views.backgroundColor(
                    context, R.id.today_widget_row_spine, R.color.today_widget_spine,
                    if (explicit) colors.spine else null,
                )
            }
            views.setViewVisibility(
                R.id.today_widget_row_divider,
                if (plan.dividerVisible) View.VISIBLE else View.GONE,
            )
            if (plan.dividerVisible) {
                views.backgroundColor(
                    context, R.id.today_widget_row_divider, R.color.today_widget_hairline,
                    if (explicit) colors.hairline else null,
                )
            }

            views.setTextViewText(R.id.today_widget_row_title, row.title)
            views.setTextViewTextSize(
                R.id.today_widget_row_title, TypedValue.COMPLEX_UNIT_SP, appearance.taskSp.toFloat(),
            )
            // 行数由布局资源固定：featured 两行，row/compact 一行；规划器只会给出这两种组合，
            // 这里不再用 setName 反射调用，避免宿主远程方法白名单差异。
            views.textColor(
                context, R.id.today_widget_row_title, R.color.today_widget_primary,
                if (explicit) colors.primaryText else null,
            )
            if (plan.rowLayout == WidgetPlan.ROW_LAYOUT_WIDE) {
                views.setTextViewText(R.id.today_widget_row_time, row.time.orEmpty())
                views.setTextViewTextSize(
                    R.id.today_widget_row_time, TypedValue.COMPLEX_UNIT_SP,
                    appearance.metaSp.toFloat(),
                )
                views.setViewVisibility(
                    R.id.today_widget_row_time,
                    if (row.showTime) View.VISIBLE else View.GONE,
                )
                views.textColor(
                    context, R.id.today_widget_row_time, R.color.today_widget_secondary,
                    if (explicit) colors.secondaryText else null,
                )
                views.setTextViewText(R.id.today_widget_row_status, row.status.orEmpty())
                views.setTextViewTextSize(
                    R.id.today_widget_row_status, TypedValue.COMPLEX_UNIT_SP,
                    appearance.metaSp.toFloat(),
                )
                views.setViewVisibility(
                    R.id.today_widget_row_status,
                    if (row.showStatus) View.VISIBLE else View.GONE,
                )
                views.textColor(
                    context, R.id.today_widget_row_status, R.color.today_widget_accent,
                    if (explicit) colors.accent else null,
                )
            } else {
                val subtitle = when {
                    row.showTime && row.showStatus ->
                        context.getString(R.string.today_widget_row_subtitle, row.time, row.status)
                    row.showTime -> row.time.orEmpty()
                    row.showStatus -> row.status.orEmpty()
                    else -> ""
                }
                views.setTextViewText(R.id.today_widget_row_subtitle, subtitle)
                views.setTextViewTextSize(
                    R.id.today_widget_row_subtitle, TypedValue.COMPLEX_UNIT_SP,
                    appearance.metaSp.toFloat(),
                )
                views.setViewVisibility(
                    R.id.today_widget_row_subtitle,
                    if (row.showTime || row.showStatus) View.VISIBLE else View.GONE,
                )
                views.textColor(
                    context, R.id.today_widget_row_subtitle, R.color.today_widget_secondary,
                    if (explicit) colors.secondaryText else null,
                )
            }
            // 读屏摘要只用快照里的完整任务名称与已开启的真实详情。
            views.setContentDescription(R.id.today_widget_row, row.contentDescription)
            views.setOnClickPendingIntent(
                R.id.today_widget_row, activityIntent(context, widgetId, row.id),
            )
            return views
        }

        // 显式主题用具体 ARGB；跟随系统时在 API 31+ 交给宿主解析资源，低版本用 App 上下文解析。
        private fun RemoteViews.textColor(context: Context, id: Int, resource: Int, explicit: Int?) {
            if (explicit == null && Build.VERSION.SDK_INT >= 31) {
                setColor(id, "setTextColor", resource)
            } else {
                setTextColor(id, explicit ?: context.getColor(resource))
            }
        }

        private fun RemoteViews.backgroundColor(context: Context, id: Int, resource: Int, explicit: Int?) {
            if (explicit == null && Build.VERSION.SDK_INT >= 31) {
                setColor(id, "setBackgroundColor", resource)
            } else {
                setInt(id, "setBackgroundColor", explicit ?: context.getColor(resource))
            }
        }

        private fun surfaceDrawable(theme: String, radiusDp: Int): Int = when (theme) {
            TodayWidgetAppearance.THEME_LIGHT -> when (radiusDp) {
                8 -> R.drawable.today_widget_background_light_r8
                12 -> R.drawable.today_widget_background_light_r12
                else -> R.drawable.today_widget_background_light
            }
            TodayWidgetAppearance.THEME_DARK -> when (radiusDp) {
                8 -> R.drawable.today_widget_background_dark_r8
                12 -> R.drawable.today_widget_background_dark_r12
                else -> R.drawable.today_widget_background_dark
            }
            else -> when (radiusDp) {
                8 -> R.drawable.today_widget_background_r8
                12 -> R.drawable.today_widget_background_r12
                else -> R.drawable.today_widget_background
            }
        }

        private fun rowBackground(theme: String): Int = when (theme) {
            TodayWidgetAppearance.THEME_LIGHT -> R.drawable.today_widget_row_background_light
            TodayWidgetAppearance.THEME_DARK -> R.drawable.today_widget_row_background_dark
            else -> R.drawable.today_widget_row_background
        }

        private fun activityIntent(context: Context, widgetId: Int, missionId: String?): PendingIntent {
            // Extras do not participate in PendingIntent identity; include instance and row in data.
            val data = Uri.Builder().scheme("missionbook").authority("today-widget")
                .appendPath(widgetId.toString()).apply { if (missionId != null) appendPath(missionId) }
                .build()
            val intent = Intent(context, MainActivity::class.java).setAction(OPEN_ACTION).setData(data)
            if (missionId != null) intent.putExtra(MISSION_ID, missionId)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            return PendingIntent.getActivity(context, widgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}

/**
 * Launcher 尺寸归一：API 31+ 读 `OPTION_APPWIDGET_SIZES`（过滤非有限/非正、去重、最多 16 个，
 * 超限取最小面积的保守有效尺寸），API 24–30 / OEM 不报时用 `MIN_WIDTH`/`MIN_HEIGHT`，
 * 无效再回落到 provider 声明尺寸。返回单位是 dp。
 */
internal object TodayWidgetSizes {
    private const val MAX_ENTRIES = 16

    /**
     * 当前实例的尺寸（dp）：先读 MIN_WIDTH/MIN_HEIGHT，缺失或非法时才用尺寸列表里
     * 面积最小的保守值，最后回落 provider 声明尺寸。只返回一个尺寸，不做尺寸映射。
     */
    fun current(options: Bundle, defaultWidthDp: Int, defaultHeightDp: Int): SizeF {
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        if (width > 0 && height > 0) return SizeF(width.toFloat(), height.toFloat())
        val reported = resolve(options, defaultWidthDp, defaultHeightDp)
        return reported.firstOrNull() ?: SizeF(
            defaultWidthDp.toFloat(), defaultHeightDp.toFloat(),
        )
    }

    fun resolve(options: Bundle, defaultWidthDp: Int, defaultHeightDp: Int): List<SizeF> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            val reported = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            val valid = reported.orEmpty()
                .filter { it.width.isFinite() && it.height.isFinite() && it.width > 0f && it.height > 0f }
                .distinctBy { it.width to it.height }
            if (valid.isNotEmpty()) {
                if (valid.size > MAX_ENTRIES) {
                    val conservative = valid.minByOrNull { it.width.toDouble() * it.height } ?: valid.first()
                    return listOf(conservative)
                }
                return valid
            }
        }
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, defaultWidthDp)
            .takeIf { it > 0 } ?: defaultWidthDp
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, defaultHeightDp)
            .takeIf { it > 0 } ?: defaultHeightDp
        return listOf(SizeF(width.toFloat(), height.toFloat()))
    }
}

/**
 * 规划器的字体度量适配。
 *
 * 字号用 `TypedValue.deriveDimension`（API 34+ 支持非线性字体缩放），低版本退回
 * `applyDimension`；行高取 `Paint.FontMetrics` 的真实 ascent/descent，不用 `sp × fontScale` 估算。
 */
internal class AndroidWidgetTextMetrics(context: Context) : WidgetTextMetrics {
    private val displayMetrics = context.resources.displayMetrics
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
    }

    override fun textWidthPx(text: String, sizeSp: Int): Float {
        paint.textSize = sizePx(sizeSp)
        return paint.measureText(text)
    }

    override fun lineHeightPx(sizeSp: Int): Float {
        paint.textSize = sizePx(sizeSp)
        val fontMetrics = paint.fontMetrics
        return fontMetrics.descent - fontMetrics.ascent
    }

    private fun sizePx(sizeSp: Int): Float = if (Build.VERSION.SDK_INT >= 34) {
        TypedValue.deriveDimension(
            TypedValue.COMPLEX_UNIT_SP, sizeSp.toFloat(), displayMetrics,
        )
    } else {
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP, sizeSp.toFloat(), displayMetrics,
        )
    }
}

/** System time/package events and the app's best-effort Shanghai date rollover alarm. */
class TodayWidgetDateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_DATE_CHANGED,
            TodayWidgetProvider.MIDNIGHT_ACTION -> TodayWidgetProvider.refreshDate(context)
        }
    }
}

/**
 * 设置内预览回执：纯计算，不写偏好、不查 SQLite、不更新 Launcher。
 *
 * 与桌面同一份 [TodayWidgetLayoutPlanner]、同一份颜色角色与固定 6 条示例快照；
 * 尺寸优先取该尺寸类别已有实例的真实有效尺寸（`sizeSource=widget`），否则用参考尺寸。
 */
internal object TodayWidgetPreview {
    private const val REFERENCE_SMALL = 109
    private const val REFERENCE_MEDIUM_WIDTH = 220
    private const val REFERENCE_MEDIUM_HEIGHT = 109
    private const val REFERENCE_LARGE = 220

    fun build(context: Context, arguments: Any?): Map<String, Any?> {
        val args = arguments as? Map<*, *> ?: throw IllegalArgumentException("参数必须是 Map")
        val appearanceMap = args["appearance"] as? Map<*, *>
            ?: throw IllegalArgumentException("appearance 必须是 Map")
        val draft = TodayWidgetAppearance.fromMap(appearanceMap)
        val sizeClass = WidgetSizeClass.fromWire(args["sizeClass"] as? String)
            ?: throw IllegalArgumentException("sizeClass 取值非法")
        val themeArgument = (args["theme"] as? String) ?: TodayWidgetAppearance.THEME_SYSTEM
        require(themeArgument in TodayWidgetAppearance.THEMES) { "theme 取值非法：$themeArgument" }
        val theme = TodayWidgetProvider.resolveTheme(context, themeArgument)
        val size = previewSize(context, sizeClass)
        val density = context.resources.displayMetrics.density
        val plan = TodayWidgetLayoutPlanner.plan(
            WidgetPlanRequest(
                sizeClass = sizeClass,
                widthPx = Math.round(size.widthDp * density).coerceAtLeast(1),
                heightPx = Math.round(size.heightDp * density).coerceAtLeast(1),
                density = density,
                textMetrics = AndroidWidgetTextMetrics(context),
                appearance = draft,
                state = WidgetSnapshotState.DATA,
                items = sampleItems(context),
                total = SAMPLE_TOTAL,
                labels = TodayWidgetProvider.labels(context, sizeClass, todayDate()),
                theme = theme,
            ),
        )
        return TodayWidgetPreviewPayload.build(
            plan = plan,
            sizeClass = sizeClass,
            sizeSource = size.source,
            widthDp = size.widthDp,
            heightDp = size.heightDp,
        )
    }

    private data class PreviewSize(val widthDp: Int, val heightDp: Int, val source: String)

    private fun previewSize(context: Context, sizeClass: WidgetSizeClass): PreviewSize {
        val spec = TodayWidgetProvider.specFor(sizeClass)
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, spec.provider))
        for (id in ids) {
            val sizes = TodayWidgetSizes.resolve(
                manager.getAppWidgetOptions(id), spec.defaultWidthDp, spec.defaultHeightDp,
            )
            val size = sizes.firstOrNull() ?: continue
            return PreviewSize(
                widthDp = Math.round(size.width).coerceAtLeast(1),
                heightDp = Math.round(size.height).coerceAtLeast(1),
                source = "widget",
            )
        }
        return when (sizeClass) {
            WidgetSizeClass.SMALL -> PreviewSize(REFERENCE_SMALL, REFERENCE_SMALL, "reference")
            WidgetSizeClass.MEDIUM -> PreviewSize(
                REFERENCE_MEDIUM_WIDTH, REFERENCE_MEDIUM_HEIGHT, "reference",
            )
            WidgetSizeClass.LARGE -> PreviewSize(REFERENCE_LARGE, REFERENCE_LARGE, "reference")
        }
    }

    private const val SAMPLE_TOTAL = 6

    /** 固定 6 条示例：第 1 条当前时段（带计划进度文案），第 2–5 条待开始，第 6 条自选时间。 */
    private fun sampleItems(context: Context): List<WidgetItem> {
        val titles = context.resources.getStringArray(R.array.today_widget_sample_titles)
        fun title(index: Int): String =
            titles.getOrNull(index) ?: context.getString(R.string.today_widget_untitled)
        val progress = context.getString(R.string.today_widget_sample_progress)
        return listOf(
            WidgetItem(
                id = "sample-1", title = title(0), startText = "08:00", endText = "09:40",
                statusText = context.getString(R.string.today_widget_phase_running),
                flexibleTime = false, currentSlot = true, progressText = progress,
            ),
            WidgetItem(
                id = "sample-2", title = title(1), startText = "10:00", endText = "11:40",
                statusText = context.getString(R.string.today_widget_phase_not_started),
                flexibleTime = false, currentSlot = false, progressText = null,
            ),
            WidgetItem(
                id = "sample-3", title = title(2), startText = "14:00", endText = "15:40",
                statusText = context.getString(R.string.today_widget_phase_not_started),
                flexibleTime = false, currentSlot = false, progressText = null,
            ),
            WidgetItem(
                id = "sample-4", title = title(3), startText = "16:00", endText = "16:50",
                statusText = context.getString(R.string.today_widget_phase_not_started),
                flexibleTime = false, currentSlot = false, progressText = null,
            ),
            WidgetItem(
                id = "sample-5", title = title(4), startText = "18:30", endText = "19:20",
                statusText = context.getString(R.string.today_widget_phase_not_started),
                flexibleTime = false, currentSlot = false, progressText = null,
            ),
            WidgetItem(
                id = "sample-6", title = title(5), startText = null, endText = null,
                statusText = context.getString(R.string.today_widget_phase_not_started),
                flexibleTime = true, currentSlot = false, progressText = null,
            ),
        )
    }

    private fun todayDate(): String =
        ZonedDateTime.now(ZoneId.of("Asia/Shanghai")).toLocalDate().toString()
}

/** The same narrow channel is used by the visible and headless Flutter engines. */
internal object TodayWidgetChannel {
    private var generation = 0L
    private var lastPublished = 0L

    fun attach(engine: io.flutter.embedding.engine.FlutterEngine, context: Context, onFinished: ((Boolean) -> Unit)? = null): MethodChannel {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "mission_book/today_widget")
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getAppearance" -> result.success(appearanceEnvelope(context))
                    "setAppearance" -> {
                        val arguments = call.arguments as? Map<*, *>
                            ?: throw IllegalArgumentException("appearance 必须是 Map")
                        val values = arguments["appearance"] as? Map<*, *>
                            ?: throw IllegalArgumentException("appearance 必须是 Map")
                        val saved = TodayWidgetAppearanceStore.save(context, values)
                        // 保存与重绘是两个结果：保存成功不因重绘失败报失败。
                        result.success(
                            mapOf(
                                "appearance" to saved.toMap(),
                                "widgets" to TodayWidgetProvider.redrawSafely(context),
                            ),
                        )
                    }
                    "redrawWidgets" -> result.success(
                        mapOf("widgets" to TodayWidgetProvider.redrawSafely(context)),
                    )
                    "previewAppearance" -> result.success(TodayWidgetPreview.build(context, call.arguments))
                    "beginSnapshot" -> {
                        result.success(if (TodayWidgetProvider.hasInstances(context)) ++generation else null)
                    }
                    "publish" -> {
                        val token = call.argument<Number>("token")?.toLong()
                        val json = call.argument<String>("json")
                        if (token != null && token == generation && token > lastPublished &&
                            json != null && TodayWidgetProvider.hasInstances(context)) {
                            TodayWidgetProvider.publish(context, json)
                            lastPublished = token
                        }
                        result.success(null)
                    }
                    "finished" -> {
                        result.success(null)
                        val success = call.arguments == true
                        onFinished?.let { android.os.Handler(android.os.Looper.getMainLooper()).post { it(success) } }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: IllegalArgumentException) {
                // 契约：非法外观一律 invalidAppearance + 中文 message，Dart 保留草稿并显示。
                result.error("invalidAppearance", error.message ?: "外观取值非法", null)
            } catch (error: Exception) {
                result.error("today_widget_failed", error.message, null)
            }
        }
        return channel
    }

    private fun appearanceEnvelope(context: Context): Map<String, Any?> {
        val snapshot = TodayWidgetAppearanceStore.read(context)
        return linkedMapOf(
            "version" to TodayWidgetAppearance.VERSION,
            "appearance" to snapshot.appearance.toMap(),
            "defaults" to TodayWidgetAppearance.defaults.toMap(),
            "recovered" to snapshot.recovered,
            "source" to snapshot.source.wire,
        )
    }
}

/** A bounded headless Flutter read, requested only when a widget needs a missing day. */
object TodayWidgetRefreshJob {
    private const val JOB_ID = 7032

    fun request(context: Context) {
        if (!TodayWidgetProvider.hasInstances(context)) return
        val scheduler = context.getSystemService(android.app.job.JobScheduler::class.java)
        if (scheduler.getPendingJob(JOB_ID) != null) return
        scheduler.schedule(
            android.app.job.JobInfo.Builder(
                JOB_ID,
                android.content.ComponentName(context, TodayWidgetRefreshJobService::class.java),
            ).setMinimumLatency(500).setOverrideDeadline(30_000).build(),
        )
    }
}

class TodayWidgetRefreshJobService : android.app.job.JobService() {
    private var worker: TodayWidgetRefreshWorker? = null

    override fun onStartJob(params: android.app.job.JobParameters): Boolean {
        if (!TodayWidgetProvider.hasInstances(this)) return false
        val next = TodayWidgetRefreshWorker(applicationContext) { retry ->
            worker = null
            jobFinished(params, retry)
        }
        worker = next
        next.start()
        return true
    }

    override fun onStopJob(params: android.app.job.JobParameters): Boolean {
        worker?.cancel()
        worker = null
        return TodayWidgetProvider.hasInstances(this)
    }
}

private class TodayWidgetRefreshWorker(
    private val context: Context,
    private val done: (Boolean) -> Unit,
) {
    private var engine: io.flutter.embedding.engine.FlutterEngine? = null
    private var closed = false
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private val timeout = Runnable { finish(false) }

    fun start() {
        handler.postDelayed(timeout, 45_000)
        try {
            val loader = io.flutter.FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
            val created = io.flutter.embedding.engine.FlutterEngine(context)
            engine = created
            TodayWidgetChannel.attach(created, context, ::finish)
            created.dartExecutor.executeDartEntrypoint(
                io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(), "todayWidgetBackgroundMain",
                ),
            )
        } catch (error: Exception) {
            android.util.Log.w("MissionBook", "桌面小组件后台入口失败", error)
            handler.post { finish(false) }
        }
    }

    fun cancel() {
        if (closed) return
        closed = true
        handler.removeCallbacks(timeout)
        engine?.destroy()
        engine = null
    }

    private fun finish(success: Boolean) {
        if (closed) return
        cancel()
        done(!success && TodayWidgetProvider.hasInstances(context))
    }
}
