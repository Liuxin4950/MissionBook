package chat.liuxin.mission_book

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.ViewConfiguration
import android.widget.TextView
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
            .setContentTitle("MissionBook 助手悬浮入口已开启")
            .setContentText("点按气泡打开助手；返回其他应用后气泡会再次显示。")
            .setOngoing(true)
            .addAction(
                0,
                "关闭悬浮",
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
        if (!android.provider.Settings.canDrawOverlays(this)) {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(ENABLED_KEY, false).apply()
            stopSelf()
            return START_NOT_STICKY
        }
        when (intent?.action) {
            ACTION_HIDE -> removeBubble()
            ACTION_STOP -> {
                getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(ENABLED_KEY, false).apply()
                stopSelf()
            }
            else -> showBubble()
        }
        return START_STICKY
    }

    private fun showBubble() {
        if (bubble != null || !android.provider.Settings.canDrawOverlays(this)) return
        val size = (56 * resources.displayMetrics.density).toInt()
        val label = TextView(this).apply {
            text = "AI"
            textSize = 16f
            setTextColor(android.graphics.Color.WHITE)
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xFF3A705C.toInt())
                setStroke((1 * resources.displayMetrics.density).toInt(), 0xFFE7F1EA.toInt())
            }
            contentDescription = "MissionBook AI 助手"
        }
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
        } catch (_: Exception) {
            bubble = null
        }
    }

    private fun openAssistant() {
        removeBubble()
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(MainActivity.EXTRA_OPEN_ASSISTANT, true)
        }
        startActivity(intent)
    }

    private fun showMenu(bubbleLayout: WindowManager.LayoutParams) {
        if (menu != null) return
        val density = resources.displayMetrics.density
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((8 * density).toInt(), (8 * density).toInt(), (8 * density).toInt(), (8 * density).toInt())
            background = GradientDrawable().apply {
                setColor(0xFFF8FAF8.toInt())
                cornerRadius = 12 * density
                setStroke((1 * density).toInt(), 0xFFB7C9BE.toInt())
            }
        }
        fun option(label: String, action: () -> Unit) {
            panel.addView(TextView(this).apply {
                text = label
                textSize = 15f
                setTextColor(0xFF24352C.toInt())
                gravity = Gravity.CENTER_VERTICAL
                setPadding((14 * density).toInt(), 0, (14 * density).toInt(), 0)
                minHeight = (48 * density).toInt()
                setOnClickListener { action() }
            })
        }
        option("打开 AI 助手") { openAssistant() }
        option("截屏提问") {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(CAPTURE_PENDING_KEY, true).apply()
            removeBubble()
            startActivity(Intent(this, AssistantCaptureConsentActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        option("关闭悬浮入口") {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(ENABLED_KEY, false).apply()
            stopSelf()
        }
        val params = WindowManager.LayoutParams(
            (200 * density).toInt(),
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
            windowManager?.addView(panel, params)
            menu = panel
            positionMenu(bubbleLayout)
            panel.post { if (menu === panel) positionMenu(bubbleLayout) }
        } catch (_: Exception) {
            menu = null
        }
    }

    private fun positionMenu(bubbleLayout: WindowManager.LayoutParams) {
        val panel = menu ?: return
        val params = panel.layoutParams as? WindowManager.LayoutParams ?: return
        val metrics = resources.displayMetrics
        val gap = (8 * metrics.density).toInt()
        val panelWidth = params.width
        val panelHeight = panel.height.takeIf { it > 0 } ?: (160 * metrics.density).toInt()
        val maxX = (metrics.widthPixels - panelWidth).coerceAtLeast(0)
        val leftOfBubble = bubbleLayout.x + bubbleLayout.width + gap
        val rightOfBubble = bubbleLayout.x - panelWidth - gap
        params.x = (if (leftOfBubble <= maxX) leftOfBubble else rightOfBubble).coerceIn(0, maxX)
        params.y = bubbleLayout.y.coerceIn(0, (metrics.heightPixels - panelHeight).coerceAtLeast(0))
        windowManager?.updateViewLayout(panel, params)
    }

    private fun removeMenu() {
        menu?.let { view ->
            try { windowManager?.removeView(view) } catch (_: Exception) { }
        }
        menu = null
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
        const val ACTION_SHOW = "chat.liuxin.mission_book.overlay.SHOW"
        const val ACTION_HIDE = "chat.liuxin.mission_book.overlay.HIDE"
        const val ACTION_STOP = "chat.liuxin.mission_book.overlay.STOP"
        const val PREFS = "assistant_overlay"
        const val ENABLED_KEY = "enabled"
        const val CAPTURE_PENDING_KEY = "capture_pending"
        private const val CHANNEL_ID = "assistant_overlay"
        private const val NOTIFICATION_ID = 7402
    }
}
