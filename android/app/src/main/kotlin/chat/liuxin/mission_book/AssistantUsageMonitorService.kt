package chat.liuxin.mission_book

import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import java.util.concurrent.Executors

/** 有使用情况授权才读取前台信号；采样不会上传，日程提醒由应用层判断。 */
class AssistantUsageMonitorService : Service() {
    private data class Sample(val pkg: String, val app: String, val since: Long, val seconds: Int) {
        val id get() = "$pkg:$since"
    }

    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val lease = Any()
    private var current: Sample? = null
    private var checking = false
    private var revisionRead = -1
    private var nextCheck = 0L
    private var lastQuery = 0L
    private var lastEvent = 0L
    private var activePackage: String? = null
    private var since = 0L
    private var inactive = 0L
    private var sampling = false

    override fun onCreate() {
        super.onCreate()
        active = this
        val notification = builder(this).setContentTitle("书祺 · 应用使用情况")
            .setOngoing(true)
            .addAction(0, "暂停", PendingIntent.getService(this, ID,
                Intent(this, javaClass).setAction(PAUSE), PendingIntent.FLAG_IMMUTABLE))
            .build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(ID, notification)
        AssistantWorkspaceHost.acquire(this, lease)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == PAUSE) configure(this, mapOf("paused" to true))
        if (!enabled(this)) { stopSelf(); return START_NOT_STICKY }
        if (revisionRead != revision) {
            revisionRead = revision
            current = null
            nextCheck = 0L
        }
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_NOT_STICKY
    }

    private val tick = object : Runnable {
        override fun run() {
            if (active !== this@AssistantUsageMonitorService) return
            if (!enabled(this@AssistantUsageMonitorService)) { stopSelf(); return }
            if (!sampling) {
                sampling = true
                val epoch = revision
                worker.execute {
                    val value = runCatching { sample() }.getOrNull()
                    handler.post {
                        sampling = false
                        if (active === this@AssistantUsageMonitorService && epoch == revision) {
                            if (!usageAllowed(this@AssistantUsageMonitorService)) {
                                stopSelf()
                            } else update(value)
                        }
                    }
                }
            }
            handler.postDelayed(this, 3500)
        }
    }

    private fun sample(): Sample? {
        val now = System.currentTimeMillis()
        if (!usageAllowed(this) || !unlocked(this)) {
            lastQuery = now; lastEvent = now; activePackage = null; inactive = 0
            return null
        }
        if (now < lastQuery) {
            lastQuery = 0; lastEvent = 0; activePackage = null; inactive = 0
        }
        val from = if (lastQuery == 0L) now - 60 * 60_000 else maxOf(lastQuery - 1500, now - 5 * 60_000)
        val events = getSystemService(UsageStatsManager::class.java).queryEvents(from, now) ?: return null
        lastQuery = now
        val event = UsageEvents.Event()
        var seen = 0
        val previousEvent = lastEvent
        while (events.hasNextEvent() && seen++ < 600 && events.getNextEvent(event)) {
            if (event.timeStamp <= previousEvent) continue
            lastEvent = maxOf(lastEvent, event.timeStamp)
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    if (event.packageName != activePackage || (inactive > 0 && event.timeStamp - inactive > 1200)) {
                        since = event.timeStamp
                    }
                    activePackage = event.packageName
                    inactive = 0
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> if (event.packageName == activePackage) inactive = event.timeStamp
                UsageEvents.Event.SCREEN_NON_INTERACTIVE, UsageEvents.Event.KEYGUARD_SHOWN -> {
                    activePackage = null; inactive = 0
                }
            }
        }
        // 事件上限命中时，不把不完整的结果视为可靠前台。
        if (events.hasNextEvent()) { activePackage = null; inactive = 0; return null }
        val pkg = activePackage ?: return null
        if (inactive > 0 || pkg == "com.android.systemui" || pkg == "android") return null
        val label = runCatching { packageManager.getApplicationInfo(pkg, 0).loadLabel(packageManager).toString() }.getOrNull()
        return Sample(pkg, label?.take(80) ?: pkg, since, ((now - since).coerceAtLeast(0) / 1000).toInt())
    }

    private fun update(sample: Sample?) {
        if (current?.id != sample?.id) {
            current = sample
            AssistantWorkspaceHost.call("invalidateObservation", failure = {})
        } else current = sample
        if (sample == null || sample.pkg == packageName || sample.seconds < 90 || checking || SystemClock.elapsedRealtime() < nextCheck) return
        val marks = mapOf("revision" to revision,
            "observationId" to sample.id, "app" to sample.app, "seconds" to sample.seconds)
        checking = true
        nextCheck = SystemClock.elapsedRealtime() + 15000
        AssistantWorkspaceHost.call("observation", marks, failure = { checking = false }) { value ->
            checking = false
            if (!valid(this, marks)) return@call
            val notice = value as? Map<*, *> ?: return@call
            if (!AssistantOverlayService.showNotice(notice)) {
                val id = notice["sessionId"] as? String ?: return@call
                if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return@call
                getSystemService(NotificationManager::class.java).notify(NOTICE_ID, builder(this)
                    .setContentTitle("书祺 · 主动提醒").setContentText(notice["message"] as? String)
                    .setAutoCancel(true).setContentIntent(PendingIntent.getActivity(this, NOTICE_ID,
                        MainActivity.assistantIntent(this, sessionId = id),
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)).build())
            }
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        worker.shutdown()
        if (active === this) active = null
        AssistantWorkspaceHost.call("invalidateObservation", failure = {})
        AssistantWorkspaceHost.release(lease)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val PREFS = "assistant_observation_local"
        private const val CHANNEL = "assistant_observation"
        private const val ID = 7416
        private const val NOTICE_ID = 7417
        private const val PAUSE = "observation_pause"
        private var active: AssistantUsageMonitorService? = null
        private var revision = 0
        private fun prefs(context: Context) = context.getSharedPreferences(PREFS, MODE_PRIVATE)

        internal fun usageAllowed(context: Context): Boolean {
            val ops = context.getSystemService(AppOpsManager::class.java)
            @Suppress("DEPRECATION")
            val mode = ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
            return mode == AppOpsManager.MODE_ALLOWED
        }

        private fun unlocked(context: Context) = context.getSystemService(PowerManager::class.java).isInteractive &&
            !context.getSystemService(KeyguardManager::class.java).isDeviceLocked

        private const val ENABLED = "foreground_app_context"

        internal fun enabled(context: Context) = prefs(context).getBoolean(ENABLED, false) && !prefs(context).getBoolean("paused", false)

        internal fun resumeIfAuthorized(context: Context) {
            if (active == null && enabled(context) && usageAllowed(context)) {
                val intent = Intent(context, AssistantUsageMonitorService::class.java)
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
            }
        }

        internal fun valid(context: Context, request: Map<*, *>): Boolean = enabled(context) && usageAllowed(context) &&
            unlocked(context) && request["revision"] == revision && active?.current?.id == request["observationId"] && active?.current != null

        /** 提醒前重新核对应用，不把定时缓存当作当前事实。 */
        internal fun verify(context: Context, request: Map<*, *>, result: (Boolean) -> Unit) {
            val service = active
            if (service == null || !valid(context, request)) { result(false); return }
            service.worker.execute {
                val fresh = runCatching { service.sample() }.getOrNull()
                service.handler.post {
                    val current = active === service && valid(context, request) && fresh?.id == request["observationId"]
                    result(current)
                }
            }
        }

        /** 聊天发送时读取，不等后台提醒阈值；不返回包名、历史或画面。 */
        internal fun currentUse(context: Context, result: (Map<String, Any>?) -> Unit) {
            val service = active
            if (service == null || !enabled(context) || !usageAllowed(context) || !unlocked(context)) {
                result(null)
                return
            }
            val epoch = revision
            service.worker.execute {
                val fresh = runCatching { service.sample() }.getOrNull()
                service.handler.post {
                    result(fresh?.takeIf {
                        active === service && epoch == revision && enabled(context) && usageAllowed(context) && unlocked(context)
                    }?.let { mapOf("app" to it.app, "seconds" to it.seconds) })
                }
            }
        }

        internal fun status(context: Context): Map<String, Any?> {
            val source = prefs(context)
            val sample = active?.current?.takeIf { enabled(context) && usageAllowed(context) && unlocked(context) }
            return mapOf("enabled" to source.getBoolean(ENABLED, false), "paused" to source.getBoolean("paused", false),
                "granted" to usageAllowed(context), "running" to (active != null && enabled(context) && usageAllowed(context)),
                "app" to sample?.app, "seconds" to sample?.seconds)
        }

        internal fun configure(context: Context, args: Map<*, *>) {
            val editor = prefs(context).edit()
            (args["enabled"] as? Boolean)?.let { editor.clear().putBoolean(ENABLED, it) }
            (args["paused"] as? Boolean)?.let { editor.putBoolean("paused", it) }
            editor.apply()
            revision++
            active?.current = null
            active?.checking = false
            AssistantWorkspaceHost.call("invalidateObservation", failure = {})
            val intent = Intent(context, AssistantUsageMonitorService::class.java)
            if (enabled(context) && usageAllowed(context)) {
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
            } else context.stopService(intent)
        }

        private fun builder(context: Context): Notification.Builder {
            val manager = context.getSystemService(NotificationManager::class.java)
            val builder = if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(CHANNEL, "书祺监督", NotificationManager.IMPORTANCE_LOW))
                Notification.Builder(context, CHANNEL)
            } else Notification.Builder(context)
            return builder.setSmallIcon(R.mipmap.ic_launcher)
        }
    }
}
