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
import android.content.Context
import android.content.pm.ServiceInfo
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.graphics.PixelFormat
import android.graphics.BitmapFactory
import android.content.res.ColorStateList
import android.graphics.drawable.RippleDrawable
import android.util.Base64
import android.widget.FrameLayout
import android.widget.ImageView
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.InsetDrawable
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.Display
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.view.ViewConfiguration
import android.widget.TextView
import android.widget.Toast
import java.util.concurrent.Executors

class AssistantOverlayService : Service() {
    private lateinit var overlayContext: Context
    private val windowType get() = if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE
    private var windowManager: WindowManager? = null
    private var bubble: FrameLayout? = null
    private var menu: View? = null
    private var docked = false
    private var dockLeft = false
    private var positionX = -1
    private var positionY = -1
    private var takingCapture = false
    private var captureTicket: String? = null
    private var latestNotice: Map<*, *>? = null
    private var pendingPanelAction: (() -> Unit)? = null
    private val workspaceLease = Any()
    private val fileReader = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        overlayContext = if (Build.VERSION.SDK_INT >= 30) {
            val display = getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)
            createDisplayContext(display).createWindowContext(windowType, null)
        } else this
        windowManager = overlayContext.getSystemService(WindowManager::class.java)
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
        active = this
        AssistantWorkspaceHost.acquire(this, workspaceLease)
        AssistantWorkspaceHost.onReady = { (menu as? AssistantOverlayPanel)?.let(::loadPanel) }
        AssistantWorkspaceHost.onState = { (menu as? AssistantOverlayPanel)?.render(it) }
        AssistantWorkspaceHost.onError = { (menu as? AssistantOverlayPanel)?.showError(it) }
        AssistantWorkspaceHost.onUnavailable = {
            takingCapture = false
            captureTicket = null
            latestNotice = null
            removeMenu()
            showBubble()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_STOP && !getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(ENABLED_KEY, false)) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!Settings.canDrawOverlays(this)) {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(ENABLED_KEY, false).apply()
            stopSelf()
            return START_NOT_STICKY
        }
        when (intent?.action) {
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
        if (bubble != null || takingCapture || !Settings.canDrawOverlays(this)) return
        val size = dp(56)
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val name = prefs.getString("persona_name", "书祺") ?: "书祺"
        val label = FrameLayout(overlayContext).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xFFFFFFFF.toInt())
                setStroke(dp(1), 0xFFE0E7DF.toInt())
            }
            elevation = dp(4).toFloat()
            clipToOutline = true
            contentDescription = "$name，AI 助手"
            isClickable = true
        }
        val avatar = ImageView(overlayContext).apply {
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
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            useScreenCoordinates(this)
            val bounds = safeFrame()
            if (docked) { width = dp(48); height = dp(64) }
            x = if (docked) { if (dockLeft) bounds.left else bounds.right - width }
                else if (positionX < 0) bounds.right - width - dp(12) else positionX
            y = if (positionY < 0) bounds.top + bounds.height() / 3 else positionY
            clampBall(this, bounds)
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
                        removeMenu()
                        val bounds = safeFrame()
                        if (docked) {
                            val inward = OverlayEdgeGeometry.inwardDistance(dockLeft, dx)
                            if (inward > dp(24)) {
                                revealBall(label, layout, bounds)
                                downX = event.rawX
                                downY = event.rawY
                                startX = layout.x
                                startY = layout.y
                            } else layout.y = startY + dy
                        } else {
                            layout.x = startX + dx
                            layout.y = startY + dy
                        }
                        clampBall(layout, bounds)
                        windowManager?.updateViewLayout(view, layout)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        view.performClick()
                    } else if (!docked) {
                        val bounds = safeFrame()
                        if (OverlayEdgeGeometry.nearEdge(layout.x - bounds.left, bounds.width(), size, dp(12))) {
                            dockLeft = layout.x + size / 2 < bounds.centerX()
                            docked = true
                            layout.width = dp(48)
                            layout.height = dp(64)
                            layout.x = if (dockLeft) bounds.left else bounds.right - layout.width
                            clampBall(layout, bounds)
                            renderDock(label)
                            windowManager?.updateViewLayout(view, layout)
                        }
                        positionX = layout.x
                        positionY = layout.y
                    }
                    positionX = layout.x
                    positionY = layout.y
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    // 取消手势只保留位置，不误开菜单或触发吸边。
                    positionX = layout.x
                    positionY = layout.y
                    true
                }
                else -> true
            }
        }
        label.setOnClickListener {
            if (menu == null) showMenu(layout) else removeMenu()
        }
        renderDock(label)
        try {
            windowManager?.addView(label, layout)
            bubble = label
        } catch (error: Exception) {
            bubble = null
            reportOverlayFailure("无法显示助手悬浮入口", error)
        }
    }

    private fun revealBall(label: FrameLayout, layout: WindowManager.LayoutParams, bounds: Rect) {
        val size = dp(56)
        docked = false
        layout.x = bounds.left + OverlayEdgeGeometry.revealedX(dockLeft, bounds.width(), size, dp(16))
        layout.y += (layout.height - size) / 2
        layout.width = size
        layout.height = size
        clampBall(layout, bounds)
        positionX = layout.x
        positionY = layout.y
        renderDock(label)
    }

    private fun renderDock(label: FrameLayout) {
        label.getChildAt(0).visibility = if (docked) View.GONE else View.VISIBLE
        val shape = GradientDrawable().apply {
            this.shape = GradientDrawable.OVAL
            setColor(0xFFFFFFFF.toInt())
            setStroke(dp(1), 0xFFD5E1D8.toInt())
        }
        // 只缩窄可见把手，48dp × 64dp 的触控区域保持不变。
        val gripX = if (dockLeft) 8 else 36
        label.background = if (docked) android.graphics.drawable.ColorDrawable(android.graphics.Color.TRANSPARENT) else shape
        label.foreground = if (docked) GradientDrawable().apply {
            setColor(0xFF244D3D.toInt())
            cornerRadius = dp(2).toFloat()
        }.let { InsetDrawable(it, dp(gripX), dp(11), dp(44 - gripX), dp(11)) } else null
        // 把手的 InsetDrawable 不能改变 View 的实际触控范围；切回头像时清除残留内边距。
        val padding = if (docked) 0 else dp(3)
        label.setPadding(padding, padding, padding, padding)
        label.clipToOutline = !docked
        label.elevation = if (docked) 0f else dp(4).toFloat()
        label.contentDescription = if (docked) "助手已收起，向屏幕内滑动或轻点展开" else "AI 助手，轻点打开，拖到边缘收起"
        if (Build.VERSION.SDK_INT >= 29) {
            label.post {
                // 仅让可见把手区域接收侧滑，保留其余系统返回手势。
                label.systemGestureExclusionRects = if (docked) {
                    listOf(Rect(dp(gripX), dp(11), dp(gripX + 4), label.height - dp(11)))
                } else emptyList()
            }
        }
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        val shown = bubble != null
        val reopen = menu != null
        val chatting = (menu as? AssistantOverlayPanel)?.inConversation == true
        removeBubble()
        if (shown) showBubble()
        if (shown && reopen) {
            (bubble?.layoutParams as? WindowManager.LayoutParams)?.let {
                if (chatting) showPanel(it, true) else showMenu(it)
            }
        }
    }

    private fun dp(value: Int): Int = (value * overlayContext.resources.displayMetrics.density + .5f).toInt()

    private fun useScreenCoordinates(params: WindowManager.LayoutParams) {
        params.gravity = Gravity.TOP or Gravity.LEFT
        params.flags = params.flags or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
        params.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
        if (Build.VERSION.SDK_INT >= 30) {
            params.fitInsetsTypes = 0
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        } else if (Build.VERSION.SDK_INT >= 28) {
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    @Suppress("DEPRECATION")
    private fun safeFrame(withIme: Boolean = false): Rect {
        val wm = requireNotNull(windowManager)
        if (Build.VERSION.SDK_INT >= 30) {
            val metrics = wm.currentWindowMetrics
            val insets = metrics.windowInsets
            val bars = insets.getInsetsIgnoringVisibility(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            val keyboard = if (withIme) insets.getInsets(WindowInsets.Type.ime()).bottom else 0
            return Rect(bars.left, bars.top, metrics.bounds.width() - bars.right,
                metrics.bounds.height() - maxOf(bars.bottom, keyboard)).also { frame ->
                // 某些输入法只向获得焦点的窗口报告可视区域，而不是向 WindowContext 报告。
                if (withIme) (menu ?: bubble)?.takeIf { it.isAttachedToWindow }?.let { view ->
                    val visible = Rect().also(view::getWindowVisibleDisplayFrame)
                    if (!visible.isEmpty) frame.intersect(visible)
                }
            }
        }
        val real = android.util.DisplayMetrics().also { wm.defaultDisplay.getRealMetrics(it) }
        val bounds = Rect(0, 0, real.widthPixels, real.heightPixels)
        val view = if (withIme) menu ?: bubble else bubble
        view?.takeIf { it.isAttachedToWindow }?.let {
            val visible = Rect().also(it::getWindowVisibleDisplayFrame)
            if (!visible.isEmpty) bounds.intersect(visible)
        }
        return bounds
    }

    private fun clampBall(params: WindowManager.LayoutParams, frame: Rect) {
        params.x = params.x.coerceIn(frame.left, maxOf(frame.left, frame.right - params.width))
        params.y = params.y.coerceIn(frame.top, maxOf(frame.top, frame.bottom - params.height))
    }

    private fun openAssistant(missionId: String? = null) {
        try {
            startActivity(MainActivity.assistantIntent(this, missionId))
            removeMenu()
        } catch (error: Exception) {
            reportOverlayFailure("无法打开任务或会话", error)
        }
    }

    private fun showMenu(bubbleLayout: WindowManager.LayoutParams) {
        if (menu != null) return
        if (docked) {
            val label = bubble ?: return
            revealBall(label, bubbleLayout, safeFrame())
            windowManager?.updateViewLayout(label, bubbleLayout)
        }
        val ball = Rect(bubbleLayout.x, bubbleLayout.y,
            bubbleLayout.x + bubbleLayout.width, bubbleLayout.y + bubbleLayout.height)
        val placement = AssistantOverlayQuickMenu.place(safeFrame(), ball, ::dp)
            ?: return showPanel(bubbleLayout)
        val quick = AssistantOverlayQuickMenu(
            overlayContext,
            placement,
            menuMotionDuration(),
            onText = ::openChat,
            onVoice = ::openVoice,
            onCapture = ::startCapture,
            onOpen = { openAssistant() },
            onUsage = ::toggleUsage,
            usageTitle = ::usageTitle,
        )
        val params = WindowManager.LayoutParams(
            placement.window.width(),
            placement.window.height(),
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            useScreenCoordinates(this)
            x = placement.window.left
            y = placement.window.top
        }
        try {
            windowManager?.addView(quick, params)
            menu = quick
        } catch (error: Exception) {
            reportOverlayFailure("无法显示助手操作菜单", error)
        }
    }

    private fun showPanel(
        bubbleLayout: WindowManager.LayoutParams,
        conversation: Boolean = false,
        afterLoad: (() -> Unit)? = null,
    ) {
        if (menu is AssistantOverlayPanel) return
        if (menu != null) removeMenu()
        if (docked) {
            val label = bubble ?: return
            revealBall(label, bubbleLayout, safeFrame())
            windowManager?.updateViewLayout(label, bubbleLayout)
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            useScreenCoordinates(this)
        }
        val panel = AssistantOverlayPanel(
            overlayContext,
            ::startCapture,
            ::startVoice,
            { openAssistant() },
            ::openAssistant,
            onRecord = { id ->
                try { startActivity(MainActivity.assistantIntent(this, recordId = id)); removeMenu() }
                catch (_: Exception) { (menu as? AssistantOverlayPanel)?.showError("无法打开记录") }
            },
        ) {
            params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()
            menu?.let { windowManager?.updateViewLayout(it, params) }
        }
        try {
            if (conversation) panel.openConversation()
            if (!placePanel(panel, params, bubbleLayout)) return
            windowManager?.addView(panel, params)
            menu = panel
            latestNotice?.let { panel.notice(it) { latestNotice = null } }
            var queued = false
            fun reposition() {
                if (queued || menu !== panel) return
                queued = true
                panel.postOnAnimation {
                    queued = false
                    if (menu !== panel) return@postOnAnimation
                    val oldX = params.x; val oldY = params.y; val oldWidth = params.width
                    if (placePanel(panel, params, bubbleLayout) &&
                        (params.x != oldX || params.y != oldY || params.width != oldWidth)) {
                        windowManager?.updateViewLayout(panel, params)
                    }
                }
            }
            panel.viewTreeObserver.addOnGlobalLayoutListener { reposition() }
            panel.setOnApplyWindowInsetsListener { view, insets -> reposition(); view.onApplyWindowInsets(insets) }
            val duration = menuMotionDuration()
            if (duration > 0L) {
                panel.alpha = 0f
                panel.animate().alpha(1f).setDuration(duration)
                    .setInterpolator(PathInterpolator(.22f, .8f, .24f, 1f)).start()
            }
            pendingPanelAction = afterLoad
            loadPanel(panel)
        } catch (error: Exception) {
            if (menu === panel) removeMenu()
            reportOverlayFailure("无法显示助手对话", error)
        }
    }

    private fun openChat() {
        (bubble?.layoutParams as? WindowManager.LayoutParams)?.let { showPanel(it, true) }
    }

    private fun loadPanel(panel: AssistantOverlayPanel) {
        panel.load {
            if (menu === panel) {
                pendingPanelAction?.also {
                    pendingPanelAction = null
                    it()
                }
            }
        }
    }

    private fun openVoice() {
        (bubble?.layoutParams as? WindowManager.LayoutParams)?.let { showPanel(it, false) { startVoice() } }
    }

    private fun usageTitle(): String {
        val status = AssistantUsageMonitorService.status(this)
        return if (status["enabled"] == true && status["paused"] != true) "监督中" else "监督"
    }

    private fun toggleUsage() {
        val status = AssistantUsageMonitorService.status(this)
        if (status["enabled"] != true) {
            Toast.makeText(this, "请先在助手设置中开启应用感知", Toast.LENGTH_SHORT).show()
            return
        }
        AssistantUsageMonitorService.configure(this, mapOf("paused" to (status["paused"] != true)))
        (menu as? AssistantOverlayQuickMenu)?.showMoreActions(animate = false)
    }

    private fun startCapture() {
        if (takingCapture) return
        takingCapture = true
        AssistantWorkspaceHost.call("beginCapture", failure = {
            takingCapture = false
            (menu as? AssistantOverlayPanel)?.showError(it)
                ?: Toast.makeText(this, it, Toast.LENGTH_SHORT).show()
        }) { value ->
            val ticket = value as? String
            if (ticket == null) { takingCapture = false; return@call }
            if (active !== this) {
                takingCapture = false
                AssistantWorkspaceHost.call("capture", mapOf("ticket" to ticket), failure = {})
                return@call
            }
            captureTicket = ticket
            removeBubble()
            try {
                startActivity(Intent(this, AssistantCaptureConsentActivity::class.java)
                    .putExtra(AssistantScreenCaptureService.EXTRA_TICKET, ticket)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } catch (error: Exception) {
                finishCapture(ticket, null)
                reportOverlayFailure("无法打开系统截屏授权", error)
            }
        }
    }

    private fun finishCapture(ticket: String, file: File?) {
        if (ticket != captureTicket) { file?.delete(); return }
        captureTicket = null
        fun deliver(bytes: ByteArray?) {
            if (active !== this) return
            takingCapture = false
            AssistantWorkspaceHost.call("capture", mapOf("ticket" to ticket, "bytes" to bytes), failure = {
                Toast.makeText(this, it, Toast.LENGTH_SHORT).show()
                reopenAfterCapture()
            }) { reopenAfterCapture() }
        }
        if (file == null) { deliver(null); return }
        fileReader.execute {
            val bytes = try {
                file.takeIf { it.length() in 1L..MainActivity.MAX_ASSISTANT_CAPTURE_BYTES }?.readBytes()
            } catch (_: Exception) { null }
            finally { file.delete() }
            mainHandler.post {
                if (bytes == null && active === this) Toast.makeText(this, "截图读取失败", Toast.LENGTH_SHORT).show()
                deliver(bytes)
            }
        }
    }

    private fun reopenAfterCapture() {
        if (active !== this) return
        showBubble()
        (bubble?.layoutParams as? WindowManager.LayoutParams)?.let { showPanel(it) }
    }

    private fun startVoice() {
        val target = (menu as? AssistantOverlayPanel)?.draftKey() ?: return
        (menu as? AssistantOverlayPanel)?.hideKeyboard()
        try {
            startActivity(Intent(this, AssistantOverlayVoiceActivity::class.java)
                .putExtra(AssistantOverlayVoiceActivity.EXTRA_DRAFT, target)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (error: Exception) {
            (menu as? AssistantOverlayPanel)?.showError("无法打开录音，请使用文字输入")
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

    private fun placePanel(panel: AssistantOverlayPanel, params: WindowManager.LayoutParams,
                           ball: WindowManager.LayoutParams): Boolean {
        val frame = safeFrame(withIme = true).apply { inset(dp(8), dp(8)) }
        val location = intArrayOf(ball.x, ball.y)
        // 刚从把手展开时，旧 View 仍在边缘；这帧先用新头像窗口的布局参数。
        bubble?.takeIf { it.isLaidOut && it.width == ball.width && it.height == ball.height }
            ?.getLocationOnScreen(location)
        val (x, y) = location
        val slot = OverlayPanelPlacement.choose(
            OverlayPanelPlacement.Box(frame.left, frame.top, frame.right, frame.bottom),
            OverlayPanelPlacement.Box(x, y, x + ball.width, y + ball.height),
            dp(if (panel.inConversation) 328 else 220), dp(if (panel.inConversation) 256 else 172), dp(10),
        ) ?: return false
        panel.limitHeight(minOf(slot.height, dp(if (panel.inConversation) 384 else 316)))
        panel.measure(View.MeasureSpec.makeMeasureSpec(slot.width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(slot.height, View.MeasureSpec.AT_MOST))
        params.x = slot.x
        params.y = slot.y(panel.measuredHeight)
        params.width = slot.width
        return true
    }

    private fun removeMenu() {
        pendingPanelAction = null
        menu?.let { view ->
            (view as? AssistantOverlayPanel)?.hideKeyboard()
            AssistantWorkspaceHost.call("unwatch", failure = {})
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
        captureTicket?.let { AssistantWorkspaceHost.call("capture", mapOf("ticket" to it), failure = {}) }
        captureTicket = null
        removeBubble()
        fileReader.shutdown()
        if (active === this) {
            active = null
            AssistantWorkspaceHost.onReady = null
            AssistantWorkspaceHost.onState = null
            AssistantWorkspaceHost.onUnavailable = null
            AssistantWorkspaceHost.onError = null
        }
        AssistantWorkspaceHost.release(workspaceLease)
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE)
        else stopForeground(true)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private var active: AssistantOverlayService? = null

        internal fun showNotice(notice: Map<*, *>): Boolean {
            val service = active ?: return false
            if (service.takingCapture || !Settings.canDrawOverlays(service)) return false
            if (service.latestNotice != null) return false
            service.latestNotice = notice
            val panel = service.menu as? AssistantOverlayPanel
            if (panel != null) panel.notice(notice) { service.latestNotice = null }
            else service.reopenAfterCapture()
            return service.menu != null
        }

        internal fun maskForSample(masked: Boolean) {
            val value = if (masked) View.INVISIBLE else View.VISIBLE
            active?.bubble?.visibility = value
            active?.menu?.visibility = value
        }

        internal fun captureDone(ticket: String?, file: File?) {
            val service = active
            if (service == null || ticket == null) file?.delete()
            else service.finishCapture(ticket, file)
        }

        internal fun voiceDone(draft: String) {
            val panel = active?.menu as? AssistantOverlayPanel ?: return
            panel.showVoiceDraft(draft)
        }
        const val ACTION_REFRESH = "chat.liuxin.mission_book.overlay.REFRESH"
        const val ACTION_SHOW = "chat.liuxin.mission_book.overlay.SHOW"
        const val ACTION_STOP = "chat.liuxin.mission_book.overlay.STOP"
        const val PREFS = "assistant_overlay"
        const val ENABLED_KEY = "enabled"
        private const val TAG = "AssistantOverlay"
        private const val CHANNEL_ID = "assistant_overlay"
        private const val NOTIFICATION_ID = 7402
    }
}
