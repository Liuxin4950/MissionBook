package chat.liuxin.mission_book

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.RemoteViews
import android.graphics.drawable.Icon
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors

/** 只负责系统通知内容布局；动作、身份和事实写入仍由原通知插件与 Dart 工作流处理。 */
object NotificationAppearance {
    private val handler = Handler(Looper.getMainLooper())
    private val capabilityExecutor = Executors.newSingleThreadExecutor()
    // 每次呈现都有独立代次：允许合法重用编号，取消后迟到的装饰也不能复活通知。
    private val generations = mutableMapOf<Int, Long>()
    private var nextGeneration = 0L

    fun attach(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "mission_book/notification_appearance")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> {
                        val id = requireNotNull(call.argument<Number>("id")).toInt()
                        val token = ++nextGeneration
                        generations[id] = token
                        result.success(token)
                    }
                    "invalidate" -> {
                        generations.remove(requireNotNull(call.argument<Number>("id")).toInt())
                        result.success(null)
                    }
                    "decorateExecution" -> {
                        // 小米权限查询涉及 ContentProvider，不能在通知主线程等待。
                        capabilityExecutor.execute {
                            val support = try { XiaomiFocusSupport.read(context) } catch (_: Exception) { null }
                            handler.post { decorateWhenReady(context, call, result, support, 0) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun decorateWhenReady(context: Context, call: MethodCall, result: MethodChannel.Result, support: XiaomiFocusSupport?, attempt: Int) {
        try {
            val id = requireNotNull(call.argument<Number>("id")).toInt()
            val token = requireNotNull(call.argument<Number>("token")).toLong()
            if (generations[id] != token || decorate(context, call, support, token) || attempt >= 8) {
                result.success(null)
            } else {
                // notify() 在系统端异步入队；最多等待320ms，未就绪保留标准通知。
                // END 会先 invalidate，等待期间绝不重建或补发已撤销的通知。
                handler.postDelayed({ decorateWhenReady(context, call, result, support, attempt + 1) }, 40)
            }
        } catch (error: Exception) {
            result.error("notification_layout_failed", error.message, null)
        }
    }

    private fun decorate(context: Context, call: MethodCall, support: XiaomiFocusSupport?, token: Long): Boolean {
        if (Build.VERSION.SDK_INT < 24) return true // 旧系统保留标准展开样式。
        val id = requireNotNull(call.argument<Number>("id")).toInt()
        val title = requireNotNull(call.argument<String>("title"))
        val body = requireNotNull(call.argument<String>("body"))
        val manager = context.getSystemService(NotificationManager::class.java)
        val original = manager.activeNotifications.firstOrNull { it.id == id }?.notification ?: return false
        if (original.extras.containsKey("mission_book.appearance_token") &&
            original.extras.getLong("mission_book.appearance_token") != token) return false
        // END 可能已经撤销，另一引擎也可能已经更新；不复活被撤销或覆盖后来的通知。
        if (original.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() != title ||
            original.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() != body) return false
        val running = call.argument<Boolean>("running") == true
        val stopped = call.argument<Boolean>("stopped") == true
        val behind = call.argument<Boolean>("clockBehind") == true
        val projectedAt = requireNotNull(call.argument<Number>("projectedAt")).toLong()
        val focus = requireNotNull(call.argument<Number>("focusMilliseconds")).toLong().coerceAtLeast(0)
        val budget = requireNotNull(call.argument<Number>("budgetMinutes")).toInt()
        val advancing = running && !behind
        val currentFocus = focus + if (advancing) (System.currentTimeMillis() - projectedAt).coerceAtLeast(0) else 0
        val seconds = currentFocus / 1000
        val frozen = if (seconds >= 3600)
            String.format(Locale.ROOT, "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            else String.format(Locale.ROOT, "%02d:%02d", seconds / 60, seconds % 60)
        fun content(layout: Int) = RemoteViews(context.packageName, layout).apply {
            setTextViewText(R.id.notification_title, title)
            setTextViewText(R.id.notification_state, if (behind) "请校时" else if (running) "执行中" else if (stopped) "待确认" else "已暂停")
            setImageViewResource(R.id.notification_state_icon, if (running) R.drawable.ic_stat_running else R.drawable.ic_stat_paused)
            setContentDescription(R.id.notification_state_icon, if (running) "执行中" else if (stopped) "待确认" else "已暂停")
            setViewVisibility(R.id.notification_clock, if (advancing) View.VISIBLE else View.GONE)
            setViewVisibility(R.id.notification_frozen, if (advancing) View.GONE else View.VISIBLE)
            setChronometer(R.id.notification_clock, SystemClock.elapsedRealtime() - currentFocus, null, advancing)
            setTextViewText(R.id.notification_frozen, frozen)
            if (layout == R.layout.notification_execution_expanded) {
                setTextViewText(R.id.notification_budget, "总时长 $budget 分钟")
            }
        }
        // recoverBuilder 继承插件已有的点击意图、动作按钮、payload、静默频道及撤销编号。
        val extras = Bundle().apply { putLong("mission_book.appearance_token", token) }
        if (support?.enabled == true) {
            extras.putString("miui.focus.param", requireNotNull(call.argument<String>("focusParams")))
            extras.putBundle("miui.focus.pics", Bundle().apply {
                putParcelable("miui.focus.pic_execution", Icon.createWithResource(context,
                    if (running) R.drawable.ic_stat_running else R.drawable.ic_stat_paused))
            })
            original.actions?.firstOrNull()?.let { action ->
                // 复用插件的 PendingIntent，仍经原动作身份与 MissionService 校验。
                extras.putBundle("miui.focus.actions", Bundle().apply {
                    putParcelable("miui.focus.action_primary", action)
                })
            }
        }
        manager.notify(id, Notification.Builder.recoverBuilder(context, original)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setCustomContentView(content(R.layout.notification_execution_compact))
            .setCustomBigContentView(content(R.layout.notification_execution_expanded))
            .addExtras(extras)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build())
        return true
    }
}
