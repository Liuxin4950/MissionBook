package chat.liuxin.mission_book

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.AtomicFile
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.time.ZoneId
import java.time.ZonedDateTime

/** Three picker entries share one read-only snapshot and renderer. */
class TodayWidgetSmall : TodayWidgetProvider(1, 109, 109)
class TodayWidgetMedium : TodayWidgetProvider(5, 220, 109)
class TodayWidgetLarge : TodayWidgetProvider(5, 220, 220)

abstract class TodayWidgetProvider(
    private val maxRows: Int,
    private val defaultWidth: Int,
    private val defaultHeight: Int,
) : AppWidgetProvider() {
    override fun onEnabled(context: Context) {
        refreshDate(context)
        TodayWidgetRefreshJob.request(context)
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val date = ZonedDateTime.now(scheduleZone).toLocalDate()
        val days = readDays(context)
        val day = days[date.toString()]
        for (id in ids) render(context, manager, id, day, date.toString(), maxRows, defaultWidth, defaultHeight)
        scheduleMidnight(context, day != null && days.containsKey(date.plusDays(1).toString()))
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) {
        val date = ZonedDateTime.now(scheduleZone).toLocalDate().toString()
        render(context, manager, id, readDays(context)[date], date, maxRows, defaultWidth, defaultHeight)
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
        private const val MAX_CACHE_BYTES = 128 * 1024
        private const val ALARM_REQUEST = 7031
        private val scheduleZone = ZoneId.of("Asia/Shanghai")
        private val snapshotLock = Any()
        private val datePattern = Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}")

        private data class ProviderSize(
            val provider: Class<out TodayWidgetProvider>,
            val rows: Int,
            val width: Int,
            val height: Int,
        )
        private val sizes = listOf(
            ProviderSize(TodayWidgetSmall::class.java, 1, 109, 109),
            ProviderSize(TodayWidgetMedium::class.java, 5, 220, 109),
            ProviderSize(TodayWidgetLarge::class.java, 5, 220, 220),
        )

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
            val date = ZonedDateTime.now(scheduleZone).toLocalDate().toString()
            renderAll(context, readDays(context)[date], date)
        }

        fun hasInstances(context: Context): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            return sizes.any { manager.getAppWidgetIds(ComponentName(context, it.provider)).isNotEmpty() }
        }

        internal fun refreshDate(context: Context) {
            if (!hasInstances(context)) return
            val date = ZonedDateTime.now(scheduleZone).toLocalDate()
            val days = readDays(context)
            val day = days[date.toString()]
            renderAll(context, day, date.toString())
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

        private fun renderAll(context: Context, day: Day?, date: String) {
            val manager = AppWidgetManager.getInstance(context)
            for ((provider, rows, width, height) in sizes) {
                for (id in manager.getAppWidgetIds(ComponentName(context, provider))) {
                    render(context, manager, id, day, date, rows, width, height)
                }
            }
        }

        private fun render(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            day: Day?,
            date: String,
            maxRows: Int,
            defaultWidth: Int,
            defaultHeight: Int,
        ) {
            val options = manager.getAppWidgetOptions(id)
            val sizesForWidget = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                @Suppress("DEPRECATION")
                options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
                    ?.filter { it.width > 0f && it.height > 0f }
                    ?.distinctBy { it.width to it.height }
            } else null

            if (!sizesForWidget.isNullOrEmpty()) {
                val variants = LinkedHashMap<SizeF, RemoteViews>()
                for (size in sizesForWidget) {
                    variants[size] = renderAtSize(
                        context, id, day, date, maxRows, size.width, size.height,
                    )
                }
                manager.updateAppWidget(id, RemoteViews(variants))
            } else {
                // Older Android and some OEM launchers omit OPTION_APPWIDGET_SIZES.
                // Their current min bounds are used when valid; manifest dimensions are fallback.
                val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, defaultWidth)
                    .takeIf { it > 0 } ?: defaultWidth
                val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, defaultHeight)
                    .takeIf { it > 0 } ?: defaultHeight
                manager.updateAppWidget(
                    id, renderAtSize(context, id, day, date, maxRows, width.toFloat(), height.toFloat()),
                )
            }
        }

        private fun renderAtSize(
            context: Context,
            widgetId: Int,
            day: Day?,
            date: String,
            maxRows: Int,
            widthDp: Float,
            heightDp: Float,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.today_widget)
            val small = maxRows == 1
            val wide = widthDp >= 180f
            val largeText = TodayWidgetAppearance.read(context).largeText
            val height = heightDp.toInt().coerceAtLeast(1)
            val ordered = if (small) listOfNotNull(day?.featured ?: day?.rows?.firstOrNull())
                else day?.rows.orEmpty()
            val rows = ordered.take(rowCapacity(height, day?.total ?: 0, maxRows, largeText))
            val more = ((day?.total ?: 0) - rows.size).coerceAtLeast(0)
            val month = date.substring(5, 7).toInt()
            val dayOfMonth = date.substring(8, 10).toInt()
            val headerSize = if (largeText) 15f else 13f
            val supportingSize = if (largeText) 13f else 11f

            views.setTextViewTextSize(R.id.today_widget_title, android.util.TypedValue.COMPLEX_UNIT_SP, headerSize)
            views.setTextViewTextSize(R.id.today_widget_date, android.util.TypedValue.COMPLEX_UNIT_SP, supportingSize)
            views.setTextViewTextSize(R.id.today_widget_empty, android.util.TypedValue.COMPLEX_UNIT_SP, supportingSize + 1f)
            views.setTextViewTextSize(R.id.today_widget_more, android.util.TypedValue.COMPLEX_UNIT_SP, supportingSize)
            views.setTextViewText(R.id.today_widget_title, context.getString(
                if (small) R.string.today_widget_title_small else R.string.today_widget_title,
            ))
            views.setTextViewText(R.id.today_widget_date, context.getString(
                if (small) R.string.today_widget_date_short else R.string.today_widget_date_long,
                month, dayOfMonth,
            ))
            TodayWidgetAppearance.read(context).applyRoot(context, views)

            val openToday = activityIntent(context, widgetId, null)
            views.setOnClickPendingIntent(R.id.today_widget_root, openToday)
            views.setOnClickPendingIntent(R.id.today_widget_header, openToday)
            views.setOnClickPendingIntent(R.id.today_widget_more, openToday)
            views.setOnClickPendingIntent(R.id.today_widget_empty, openToday)
            views.removeAllViews(R.id.today_widget_rows)
            for (row in rows) {
                views.addView(
                    R.id.today_widget_rows,
                    renderRow(context, widgetId, row, small, wide, largeText),
                )
            }

            val isEmpty = rows.isEmpty()
            if (isEmpty) {
                views.setTextViewText(R.id.today_widget_empty, context.getString(when {
                    day == null -> R.string.today_widget_load
                    day.total > 0 -> R.string.today_widget_open
                    else -> R.string.today_widget_empty
                }))
            }
            views.setViewVisibility(R.id.today_widget_empty, if (isEmpty) View.VISIBLE else View.GONE)
            if (more > 0 && !isEmpty) {
                views.setTextViewText(R.id.today_widget_more, context.getString(R.string.today_widget_more, more))
            }
            views.setViewVisibility(
                R.id.today_widget_more, if (more > 0 && !isEmpty) View.VISIBLE else View.GONE,
            )
            return views
        }

        private fun rowCapacity(heightDp: Int, total: Int, maxRows: Int, largeText: Boolean): Int {
            // Reserve actual chrome and the overflow footer; rows share all remaining height evenly.
            // Compact rows are deliberately short enough for a real 4×2 card; large text
            // raises the threshold and may reduce rows instead of shrinking glyphs.
            val minimumRowHeight = if (largeText) 30 else 25
            val withoutFooter = (heightDp - 16 - 24).coerceAtLeast(1)
            var count = (withoutFooter / minimumRowHeight).coerceAtLeast(1).coerceAtMost(maxRows)
            if (total > count) {
                val withFooter = (heightDp - 16 - 24 - 16).coerceAtLeast(1)
                count = (withFooter / minimumRowHeight).coerceAtLeast(1).coerceAtMost(maxRows)
            }
            return count
        }

        private fun renderRow(
            context: Context,
            widgetId: Int,
            row: Row,
            small: Boolean,
            wide: Boolean,
            largeText: Boolean,
        ): RemoteViews {
            // Small cards use the single featured focus layout; wide rows retain time-left semantics.
            val layout = when {
                small -> R.layout.today_widget_row_featured
                wide -> R.layout.today_widget_row_compact
                else -> R.layout.today_widget_row
            }
            val views = RemoteViews(context.packageName, layout)
            TodayWidgetAppearance.read(context).applyRow(context, views, hasTimeColumn = wide)
            val titleSize = when {
                small && largeText -> 20f
                small -> 18f
                largeText -> 15f
                else -> 13f
            }
            val metadataSize = when {
                small && largeText -> 14f
                small -> 13f
                largeText -> 13f
                else -> 11f
            }
            views.setTextViewTextSize(R.id.today_widget_row_title, android.util.TypedValue.COMPLEX_UNIT_SP, titleSize)
            views.setTextViewTextSize(R.id.today_widget_row_subtitle, android.util.TypedValue.COMPLEX_UNIT_SP, metadataSize)
            if (!small && wide) {
                views.setTextViewTextSize(R.id.today_widget_row_time, android.util.TypedValue.COMPLEX_UNIT_SP, if (small) titleSize else metadataSize)
            }
            val title = row.title.ifBlank { context.getString(R.string.today_widget_untitled) }
            val time = when {
                row.start == null -> context.getString(R.string.today_widget_flexible)
                small || row.end == null -> row.start
                else -> context.getString(R.string.today_widget_time_range, row.start, row.end)
            }
            val phase = when (row.phase) {
                "notStarted" -> R.string.today_widget_phase_not_started
                "running" -> R.string.today_widget_phase_running
                "paused" -> R.string.today_widget_phase_paused
                "reportPending" -> R.string.today_widget_phase_report_pending
                "evidencePending" -> R.string.today_widget_phase_evidence_pending
                "closed" -> R.string.today_widget_phase_closed
                "cancelled" -> R.string.today_widget_phase_cancelled
                else -> null
            }?.let(context::getString)
            val subtitle = if (phase == null) time
                else context.getString(R.string.today_widget_row_subtitle, time, phase)
            views.setTextViewText(R.id.today_widget_row_title, title)
            // Narrow medium cards keep time and state together; wide cards split time to the left.
            views.setTextViewText(
                R.id.today_widget_row_subtitle,
                if (small || !wide) subtitle else phase.orEmpty(),
            )
            if (wide) views.setTextViewText(R.id.today_widget_row_time, time)
            views.setContentDescription(R.id.today_widget_row, "${title}, ${subtitle}")
            views.setOnClickPendingIntent(R.id.today_widget_row, activityIntent(context, widgetId, row.id))
            return views
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

/** The same narrow channel is used by the visible and headless Flutter engines. */
internal object TodayWidgetChannel {
    private var generation = 0L
    private var lastPublished = 0L

    fun attach(engine: io.flutter.embedding.engine.FlutterEngine, context: Context, onFinished: ((Boolean) -> Unit)? = null): MethodChannel {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "mission_book/today_widget")
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getAppearance" -> result.success(TodayWidgetAppearance.read(context).toMap())
                    "setAppearance" -> {
                        val values = call.arguments as? Map<*, *>
                            ?: throw IllegalArgumentException("appearance 必须是 Map")
                        TodayWidgetAppearance.save(context, values)
                        // Style updates reuse the current native cache; no Dart query or widget re-add.
                        TodayWidgetProvider.updateAll(context)
                        result.success(TodayWidgetAppearance.read(context).toMap())
                    }
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
            } catch (error: Exception) {
                result.error("today_widget_failed", error.message, null)
            }
        }
        return channel
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
