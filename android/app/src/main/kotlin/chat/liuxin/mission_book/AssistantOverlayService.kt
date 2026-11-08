package chat.liuxin.mission_book

import android.app.Notification
import android.animation.ValueAnimator
import android.view.animation.PathInterpolator
import java.io.File
import org.json.JSONObject
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.BitmapFactory
import android.content.res.ColorStateList
import android.graphics.drawable.RippleDrawable
import android.util.Base64
import android.widget.FrameLayout
import android.widget.ImageView
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.ViewConfiguration
import android.widget.TextView
import android.widget.Toast
import android.widget.LinearLayout

class AssistantOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var bubble: View? = null
    private var menu: View? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WindowManager::class.java)
        createNotificationChannel()
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("助手悬浮球")
            .setOngoing(true)
            .addAction(
                0,
                "关闭",
                PendingIntent.getService(
                    this,
                    7403,
                    Intent(this, AssistantOverlayService::class.java).setAction(ACTION_STOP),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!Settings.canDrawOverlays(this)) {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(ENABLED_KEY, false).apply()
            stopSelf()
            return START_NOT_STICKY
        }
        when (intent?.action) {
            ACTION_HIDE -> removeBubble()
            ACTION_REFRESH -> {
                if (bubble != null) {
                    removeBubble()
                    showBubble()
                }
            }
            ACTION_STOP -> {
                getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(ENABLED_KEY, false).apply()
                stopSelf()
            }
            else -> showBubble()
        }
        return START_STICKY
    }

    private fun showBubble() {
        if (bubble != null || !Settings.canDrawOverlays(this)) return
        val size = (56 * resources.displayMetrics.density).toInt()
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val name = prefs.getString("persona_name", "书祺") ?: "书祺"
        val label = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xFFFFFFFF.toInt())
                setStroke(dp(1), 0xFFE0E7DF.toInt())
            }
            elevation = dp(4).toFloat()
            clipToOutline = true
            val inset = dp(3)
            setPadding(inset, inset, inset, inset)
            contentDescription = "$name，AI 助手"
            isClickable = true
        }
        val avatar = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(0xFFE7F1EA.toInt()) }
            clipToOutline = true
        }
        val custom = prefs.getString("persona_custom_avatar", null)
        val bitmap = try {
            if (custom != null) {
                val bytes = Base64.decode(custom, Base64.DEFAULT)
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            } else if (prefs.getString("persona_avatar", "spark") == "spark") {
                assets.open("flutter_assets/assets/branding/shuqi-avatar.png").use { BitmapFactory.decodeStream(it) }
            } else null
        } catch (error: Exception) { Log.w(TAG, "读取悬浮头像失败", error); null }
        if (bitmap != null) avatar.setImageBitmap(bitmap)
        else {
            avatar.setImageResource(if (prefs.getString("persona_avatar", "spark") == "compass") R.drawable.assistant_compass else R.drawable.assistant_book)
            avatar.setPadding(dp(8), dp(8), dp(8), dp(8))
        }
        label.addView(avatar, FrameLayout.LayoutParams(-1, -1))
        val layout = WindowManager.LayoutParams(
            size,
            size,
            if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = (12 * resources.displayMetrics.density).toInt()
            y = resources.displayMetrics.heightPixels / 3
        }
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var moved = false
        label.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    startX = layout.x
                    startY = layout.y
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - downX).toInt()
                    val dy = (event.rawY - downY).toInt()
                    if (kotlin.math.abs(dx) + kotlin.math.abs(dy) > ViewConfiguration.get(this).scaledTouchSlop) moved = true
                    if (moved) {
                        layout.x = (startX - dx).coerceAtLeast(0)
                        layout.y = (startY + dy).coerceAtLeast(0)
                        windowManager?.updateViewLayout(view, layout)
                        positionMenu(layout)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        if (menu == null) showMenu(layout) else removeMenu()
                        view.performClick()
                    }
                    true
                }
                else -> true
            }
        }
        try {
            windowManager?.addView(label, layout)
            bubble = label
        } catch (error: Exception) {
            bubble = null
            reportOverlayFailure("无法显示助手悬浮入口", error)
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun openAssistant() {
        removeBubble()
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            val capture = getSharedPreferences(PREFS, MODE_PRIVATE).getString(MainActivity.EXTRA_CAPTURE_PATH, null)
            if (capture != null) putExtra(MainActivity.EXTRA_CAPTURE_PATH, capture)
            else putExtra(MainActivity.EXTRA_OPEN_ASSISTANT, true)
        }
        try { startActivity(intent) }
        catch (error: Exception) { reportOverlayFailure("无法打开助手", error); showBubble() }
    }

    private fun showMenu(bubbleLayout: WindowManager.LayoutParams) {
        if (menu != null) return
        val density = resources.displayMetrics.density
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(8), dp(8), dp(8))
            background = GradientDrawable().apply {
                setColor(0xFFFFFFFF.toInt())
                cornerRadius = 16 * density
                setStroke((1 * density).toInt(), 0xFFE0E7DF.toInt())
            }
        }
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        panel.elevation = dp(8).toFloat()
        fun option(label: String, icon: Int, highlighted: Boolean = false, action: () -> Unit) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                minimumHeight = dp(48)
                setPadding(dp(12), 0, dp(12), 0)
                contentDescription = label
                isFocusable = true
                background = RippleDrawable(ColorStateList.valueOf(0x22244D3D), GradientDrawable().apply {
                    setColor(if (highlighted) 0xFFE7F1EA.toInt() else 0xFFFFFFFF.toInt())
                    cornerRadius = dp(12).toFloat()
                }, null)
                setOnClickListener { action() }
            }
            row.addView(ImageView(this).apply {
                setImageResource(icon)
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            }, LinearLayout.LayoutParams(dp(20), dp(20)))
            row.addView(TextView(this).apply {
                text = label
                textSize = 12f
                setTextColor(0xFF282E2A.toInt())
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            }, LinearLayout.LayoutParams(-1, -2).apply { marginStart = dp(12) })
            panel.addView(row)
        }
        val pending = prefs.getString(MainActivity.EXTRA_CAPTURE_PATH, null) != null
        option(if (pending) "截图已就绪 · 打开助手" else "打开 AI 助手", R.drawable.assistant_chat, pending) { openAssistant() }
        option("截屏提问", R.drawable.assistant_capture, true) {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(CAPTURE_PENDING_KEY, true).apply()
            removeBubble()
            try {
                startActivity(Intent(this, AssistantCaptureConsentActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } catch (error: Exception) {
                getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(CAPTURE_PENDING_KEY, false).apply()
                reportOverlayFailure("无法打开系统截屏授权", error)
                showBubble()
            }
        }
        option("关闭悬浮入口", R.drawable.assistant_close) {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(ENABLED_KEY, false).apply()
            stopSelf()
        }
        val params = WindowManager.LayoutParams(
            dp(192),
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = bubbleLayout.x
            y = bubbleLayout.y
        }
        try {
            val duration = menuMotionDuration()
            panel.alpha = if (duration == 0L) 1f else 0f
            panel.translationY = if (duration == 0L) 0f else dp(4).toFloat()
            windowManager?.addView(panel, params)
            menu = panel
            positionMenu(bubbleLayout)
            panel.post { if (menu === panel) positionMenu(bubbleLayout) }
            if (duration > 0L) {
                panel.animate().alpha(1f).translationY(0f)
                    .setDuration(duration)
                    .setInterpolator(PathInterpolator(.22f, .8f, .24f, 1f))
                    .start()
            }
        } catch (error: Exception) {
            if (menu === panel) removeMenu() else menu = null
            reportOverlayFailure("无法显示助手快捷菜单", error)
        }
    }

    private fun reportOverlayFailure(message: String, error: Exception) {
        Log.e(TAG, message, error)
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        if (error is SecurityException || !Settings.canDrawOverlays(this)) {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(ENABLED_KEY, false).apply()
            stopSelf()
        }
    }

    private fun positionMenu(bubbleLayout: WindowManager.LayoutParams) {
        val panel = menu ?: return
        val params = panel.layoutParams as? WindowManager.LayoutParams ?: return
        val metrics = resources.displayMetrics
        val gap = (8 * metrics.density).toInt()
        val panelWidth = params.width
        val panelHeight = panel.height.takeIf { it > 0 } ?: dp(160)
        val maxX = (metrics.widthPixels - panelWidth).coerceAtLeast(0)
        val leftOfBubble = bubbleLayout.x + bubbleLayout.width + gap
        val rightOfBubble = bubbleLayout.x - panelWidth - gap
        params.x = (if (leftOfBubble <= maxX) leftOfBubble else rightOfBubble).coerceIn(0, maxX)
        params.y = bubbleLayout.y.coerceIn(0, (metrics.heightPixels - panelHeight).coerceAtLeast(0))
        windowManager?.updateViewLayout(panel, params)
    }

    private fun removeMenu() {
        menu?.let { view ->
            view.animate().cancel()
            try { windowManager?.removeView(view) } catch (_: Exception) { }
        }
        menu = null
    }

    // 与 Flutter 的本机设置共用保存值，旧枚举格式仍可读取。
    private fun menuMotionDuration(): Long {
        val preference = runCatching {
            val saved = File(filesDir, "page_motion.txt").takeIf { it.exists() }
                ?.readText()?.trim().orEmpty()
            if (saved.startsWith("{")) JSONObject(saved).optString("preference") else saved
        }.getOrDefault("system")
        if (preference == "reduced") return 0L
        val systemEnabled = Build.VERSION.SDK_INT < 26 || ValueAnimator.areAnimatorsEnabled()
        return if (preference == "full" || systemEnabled) 180L else 0L
    }

    private fun removeBubble() {
        removeMenu()
        bubble?.let { view ->
            try { windowManager?.removeView(view) } catch (_: Exception) { }
        }
        bubble = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "AI 悬浮助手", NotificationManager.IMPORTANCE_LOW),
        )
    }

    @Suppress("DEPRECATION")
    override fun onDestroy() {
        removeBubble()
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE)
        else stopForeground(true)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_REFRESH = "chat.liuxin.mission_book.overlay.REFRESH"
        const val ACTION_SHOW = "chat.liuxin.mission_book.overlay.SHOW"
        const val ACTION_HIDE = "chat.liuxin.mission_book.overlay.HIDE"
        const val ACTION_STOP = "chat.liuxin.mission_book.overlay.STOP"
        const val PREFS = "assistant_overlay"
        const val ENABLED_KEY = "enabled"
        const val CAPTURE_PENDING_KEY = "capture_pending"
        private const val TAG = "AssistantOverlay"
        private const val CHANNEL_ID = "assistant_overlay"
        private const val NOTIFICATION_ID = 7402
    }
}
