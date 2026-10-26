package chat.liuxin.mission_book

import android.app.*
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.*
import android.content.pm.ServiceInfo
import android.content.pm.PackageManager
import android.Manifest
import android.os.*
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** AlarmManager 负责唤醒，Dart 仓储负责重读/事务；不在 Kotlin 复制业务状态机。 */
object PlannedAlarm {
    private const val REQUEST = 71001
    private const val PREFS = "planned_execution"
    private var syncVersion = 0L
    private var primary: MethodChannel? = null

    fun attach(engine: FlutterEngine, context: Context, onFinished: (() -> Unit)? = null) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "mission_book/plans")
        if (onFinished == null) primary = channel
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "beginSync" -> { syncVersion++; result.success(syncVersion) }
                    "schedule" -> {
                        if (call.argument<Number>("token")?.toLong() == syncVersion) {
                            schedule(context, call.argument<Number>("at")?.toLong())
                        }
                        result.success(null)
                    }
                    "failed" -> {
                        showFailure(context)
                        result.success(null)
                    }
                    "finished" -> {
                        if (call.argument<Boolean>("failed") != true) {
                            context.getSystemService(NotificationManager::class.java).cancel(-71003)
                        }
                        primary?.invokeMethod("factsChanged", null)
                        result.success(null)
                        Handler(Looper.getMainLooper()).post { onFinished?.invoke() }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("planned_alarm_failed", error.message, null)
            }
        }
    }

    fun showFailure(context: Context) {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel("planned_failures", "计划任务执行异常", NotificationManager.IMPORTANCE_DEFAULT))
        val launch = PendingIntent.getActivity(context, 71003, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, "planned_failures")
            else Notification.Builder(context)
        manager.notify(-71003, builder.setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("计划任务自动开始暂未完成")
            .setContentText("请打开应用查看任务，系统将稍后重试")
            .setContentIntent(launch).setOnlyAlertOnce(true).setAutoCancel(true).build())
    }

    fun detachPrimary() { primary = null }

    fun schedule(context: Context, at: Long?) {
        val manager = context.getSystemService(AlarmManager::class.java)
        val pending = PendingIntent.getBroadcast(context, REQUEST,
            Intent(context, PlannedAlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        if (at == null) {
            manager.cancel(pending)
            check(context.getSharedPreferences(PREFS, 0).edit().remove("next").commit()) { "无法保存计划唤醒设置" }
            return
        }
        val trigger = maxOf(at, System.currentTimeMillis() + 1000)
        val exact = Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()
        try {
            if (exact) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pending)
            else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pending)
        } catch (error: SecurityException) {
            // 权限可能在检查后撤回；同一动作降级，避免让应用或服务崩溃。
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pending)
        }
        check(context.getSharedPreferences(PREFS, 0).edit().putLong("next", at).commit()) { "无法保存计划唤醒设置" }
    }

    fun restore(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, 0)
        if (prefs.contains("next")) schedule(context, prefs.getLong("next", 0))
    }

    fun enqueueJob(context: Context) {
        context.getSystemService(JobScheduler::class.java).schedule(
            JobInfo.Builder(REQUEST, ComponentName(context, PlannedExecutionJob::class.java))
                .setMinimumLatency(0).setOverrideDeadline(1000).build())
    }
}

class PlannedAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != null) {
            PlannedAlarm.restore(context)
            return
        }
        // 精确闹钟触发的用户定时动作可启动短前台服务；无授权时走系统后台作业。
        val manager = context.getSystemService(AlarmManager::class.java)
        val exact = Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()
        if (exact) {
            try {
                val service = Intent(context, PlannedExecutionService::class.java)
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service)
                else context.startService(service)
                return
            } catch (error: Exception) {
                Log.w("MissionBook", "自动执行转交系统作业", error)
            }
        }
        PlannedAlarm.enqueueJob(context)
    }
}

/** 每次只存活到事务与通知对账完成；不维持每秒后台 Dart 计时。 */
private class PlanWorker(private val context: Context, private val done: () -> Unit) {
    private var engine: FlutterEngine? = null
    private var closed = false
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable {
        Log.e("MissionBook", "计划任务后台执行超时，稍后重试")
        PlannedAlarm.showFailure(context)
        PlannedAlarm.schedule(context, System.currentTimeMillis() + 30000)
        close()
    }
    fun start() {
        // 本次闹钟已被消费；预留恢复唤醒，避免进程在事务前被回收后永久失去调度。
        PlannedAlarm.schedule(context, System.currentTimeMillis() + 65000)
        handler.postDelayed(timeout, 60000)
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
            val created = FlutterEngine(context)
            engine = created
            PlannedAlarm.attach(created, context, ::close)
            created.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "plannedMissionBackgroundMain"))
        } catch (error: Exception) {
            Log.e("MissionBook", "计划任务后台入口失败", error)
            PlannedAlarm.showFailure(context)
            PlannedAlarm.schedule(context, System.currentTimeMillis() + 30000)
            close()
        }
    }
    fun cancel() {
        if (closed) return
        closed = true
        handler.removeCallbacks(timeout)
        engine?.destroy()
        engine = null
    }
    fun close() {
        if (closed) return
        cancel()
        done()
    }
}

class PlannedExecutionService : Service() {
    private var worker: PlanWorker? = null
    private var wakeLock: PowerManager.WakeLock? = null
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel("planned_execution", "计划任务自动执行", NotificationManager.IMPORTANCE_LOW))
        val launch = PendingIntent.getActivity(this, 71002, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "planned_execution")
            else Notification.Builder(this)).setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("正在处理计划任务")
            .setContentText("正在确认排期并启动执行")
            .setContentIntent(launch).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(-71002, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE)
        else startForeground(-71002, notification)
        if (worker == null) {
            wakeLock = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "missionbook:planned-start").apply { acquire(65000) }
            worker = PlanWorker(applicationContext) {
                worker = null
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }.also { it.start() }
        }
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        worker?.cancel()
        worker = null
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }
}

class PlannedExecutionJob : JobService() {
    private var worker: PlanWorker? = null
    override fun onStartJob(params: JobParameters): Boolean {
        worker = PlanWorker(applicationContext) { worker = null; jobFinished(params, false) }
            .also { it.start() }
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean {
        worker?.cancel()
        worker = null
        return true
    }
}
