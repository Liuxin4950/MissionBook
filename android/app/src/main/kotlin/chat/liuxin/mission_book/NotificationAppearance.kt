package chat.liuxin.mission_book

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.RemoteViews
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** 只负责系统通知内容布局；动作、身份和事实写入仍由原通知插件与 Dart 工作流处理。 */
object NotificationAppearance {
    private val handler = Handler(Looper.getMainLooper())
    // 撤销取消的是待呈现操作，不代表领域阶段；执行通知编号在终态后不再复用。
    private val cancelledIds = mutableSetOf<Int>()

    fun attach(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "mission_book/notification_appearance")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "invalidate" -> {
                        cancelledIds.add(requireNotNull(call.argument<Number>("id")).toInt())
                        result.success(null)
                    }
                    "decorateExecution" -> decorateWhenReady(context, call, result, 0)
                    else -> result.notImplemented()
                }
            }
    }

    private fun decorateWhenReady(context: Context, call: MethodCall, result: MethodChannel.Result, attempt: Int) {
        try {
            val id = requireNotNull(call.argument<Number>("id")).toInt()
            if (cancelledIds.contains(id) || decorate(context, call) || attempt >= 8) {
                result.success(null)
            } else {
                // notify() 在系统端异步入队；最多等待320ms，未就绪保留标准通知。
                // END 会先 invalidate，等待期间绝不重建或补发已撤销的通知。
                handler.postDelayed({ decorateWhenReady(context, call, result, attempt + 1) }, 40)
            }
        } catch (error: Exception) {
            result.error("notification_layout_failed", error.message, null)
        }
    }

    private fun decorate(context: Context, call: MethodCall): Boolean {
        if (Build.VERSION.SDK_INT < 24) return true // 旧系统保留标准展开样式。
        val id = requireNotNull(call.argument<Number>("id")).toInt()
        val title = requireNotNull(call.argument<String>("title"))
        val body = requireNotNull(call.argument<String>("body"))
        val manager = context.getSystemService(NotificationManager::class.java)
        val original = manager.activeNotifications.firstOrNull { it.id == id }?.notification ?: return false
        // END 可能已经撤销，另一引擎也可能已经更新；不复活被撤销或覆盖后来的通知。
        if (original.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() != title ||
            original.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() != body) return false
        val running = call.argument<Boolean>("running") == true
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
            setTextViewText(R.id.notification_state, if (behind) "请校正系统时间" else if (running) "正在专注" else "已暂停 · 专注已冻结")
            setImageViewResource(R.id.notification_state_icon, if (running) R.drawable.ic_stat_running else R.drawable.ic_stat_paused)
            setContentDescription(R.id.notification_state_icon, if (running) "执行中" else "已暂停")
            setViewVisibility(R.id.notification_clock, if (advancing) View.VISIBLE else View.GONE)
            setViewVisibility(R.id.notification_frozen, if (advancing) View.GONE else View.VISIBLE)
            setChronometer(R.id.notification_clock, SystemClock.elapsedRealtime() - currentFocus, null, advancing)
            setTextViewText(R.id.notification_frozen, frozen)
            if (layout == R.layout.notification_execution_expanded) {
                setTextViewText(R.id.notification_budget, "专注时长 · 当前额度 $budget 分钟")
            }
        }
        // recoverBuilder 继承插件已有的点击意图、动作按钮、payload、静默频道及撤销编号。
        manager.notify(id, Notification.Builder.recoverBuilder(context, original)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setCustomContentView(content(R.layout.notification_execution_compact))
            .setCustomBigContentView(content(R.layout.notification_execution_expanded))
            .setOnlyAlertOnce(true)
            .build())
        return true
    }
}
