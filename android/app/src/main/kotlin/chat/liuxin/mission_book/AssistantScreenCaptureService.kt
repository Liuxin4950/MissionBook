package chat.liuxin.mission_book

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.res.ColorStateList
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class AssistantScreenCaptureService : Service() {
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val cancelled = AtomicBoolean(false)
    private var completed = false
    private var finalizing = false
    private var longCapture = false
    private var awaitingFrame = false
    private var settlingFrame = false
    private var busy = false
    private var frameCount = 0
    private var controls: View? = null
    private var combined: Bitmap? = null
    private var previous: Bitmap? = null
    private var preview: Bitmap? = null
    private var editor: View? = null
    private var captureRegion: Rect? = null
    private var finishRequested = false
    private var captureWidth = 0
    private var captureHeight = 0
    private var contentWidth = 0
    private var contentHeight = 0
    private var lastIssue: String? = null
    private val manager by lazy { getSystemService(WindowManager::class.java) }
    private val longPoll = Runnable {
        if (longCapture && !completed && !finalizing && !cancelled.get()) {
            requestFrame()
        }
    }
    private val frameTimeout = Runnable {
        if (awaitingFrame && !completed) {
            awaitingFrame = false
            busy = false
            if (finishRequested && frameCount > 0) finishLongCapture()
            else if (longCapture) {
                showControls("未收到画面，滚动页面后系统会继续尝试")
                scheduleLongPoll(500L)
            } else failCapture("暂未收到屏幕画面，请重试")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL_CAPTURE) {
            cancelCapture()
            return START_NOT_STICKY
        }
        if (projection != null || finalizing || completed) return START_NOT_STICKY
        longCapture = intent?.getBooleanExtra(EXTRA_LONG_CAPTURE, false) == true
        try {
            startCaptureForeground()
            val code = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
            val data = getResultData(intent)
            check(code == -1 && data != null)
            projection = getSystemService(MediaProjectionManager::class.java).getMediaProjection(code, data)
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            manager.defaultDisplay.getRealMetrics(metrics)
            captureWidth = metrics.widthPixels
            captureHeight = metrics.heightPixels
            val source = ImageReader.newInstance(captureWidth, captureHeight, PixelFormat.RGBA_8888, 2)
            reader = source
            source.setOnImageAvailableListener({ captureAvailable(it, metrics.widthPixels, metrics.heightPixels) }, handler)
            projection?.registerCallback(object : MediaProjection.Callback() {
                override fun onCapturedContentResize(width: Int, height: Int) {
                    if (contentWidth != 0 && (contentWidth != width || contentHeight != height)) {
                        failCapture("被截画面尺寸已改变，请重新截图")
                    }
                    contentWidth = width
                    contentHeight = height
                }
                override fun onStop() {
                    if (!finalizing && !completed) cancelCapture()
                }
            }, handler)
            display = projection?.createVirtualDisplay(
                "MissionBookAssistantCapture", metrics.widthPixels, metrics.heightPixels, metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, source.surface, null, handler,
            )
            requestFrame()
            handler.postDelayed({
                if (!completed && !finalizing) cancelCapture()
            }, 5 * 60 * 1000L)
        } catch (error: Exception) {
            Log.e(TAG, "截屏初始化失败", error)
            failCapture("截屏未能启动，请重试")
        }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun getResultData(intent: Intent?): Intent? =
        if (Build.VERSION.SDK_INT >= 33) intent?.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        else intent?.getParcelableExtra(EXTRA_RESULT_DATA)

    private fun scheduleLongPoll(delayMillis: Long) {
        if (!longCapture || completed || finalizing || cancelled.get()) return
        handler.removeCallbacks(longPoll)
        handler.postDelayed(longPoll, delayMillis)
    }

    private fun requestFrame() {
        if (completed || finalizing || busy) return
        busy = true
        // 先丢弃带工具条的旧缓冲；等待合成期间不消费新帧，避免静止页面
        // 在工具条消失后只产出一帧却被旧监听提前丢弃。
        runCatching { reader?.acquireLatestImage()?.close() }
        settlingFrame = true
        hideControls()
        handler.postDelayed({
            settlingFrame = false
            if (!completed && !finalizing) {
                awaitingFrame = true
                reader?.let { captureAvailable(it, captureWidth, captureHeight) }
                if (awaitingFrame) handler.postDelayed(frameTimeout, 900)
            }
        }, 200)
    }

    private fun captureAvailable(source: ImageReader, width: Int, height: Int) {
        if (settlingFrame) return
        val image = try { source.acquireLatestImage() } catch (error: Exception) {
            Log.e(TAG, "读取截屏帧失败", error)
            cancelCapture()
            return
        } ?: return
        if (!awaitingFrame || completed) {
            image.close()
            return
        }
        awaitingFrame = false
        handler.removeCallbacks(frameTimeout)
        val bitmap = try {
            val plane = image.planes.single()
            val padded = Bitmap.createBitmap(plane.rowStride / plane.pixelStride, height, Bitmap.Config.ARGB_8888)
            padded.copyPixelsFromBuffer(plane.buffer)
            val crop = Bitmap.createBitmap(padded, 0, 0, width, height)
            if (crop !== padded) padded.recycle()
            crop
        } catch (error: Exception) {
            Log.e(TAG, "复制截屏失败", error)
            failCapture("无法读取屏幕画面，请重试")
            return
        } finally { image.close() }
        // 普通截图先冻结当前画面，等待用户选择；不提前返回聊天。
        if (!longCapture) {
            busy = false
            preview = bitmap
            showEditor(bitmap)
            return
        }
        worker.execute {
            var errorMessage: String? = null
            try {
                if (!cancelled.get()) acceptFrame(bitmap)
            } catch (error: Exception) {
                Log.w(TAG, "长截图帧未加入", error)
                errorMessage = error.message ?: "图片处理失败，请重试"
            } finally {
                bitmap.recycle()
            }
            handler.post {
                if (!completed) {
                    busy = false
                    if (errorMessage == null) frameCount++
                    if (finishRequested && frameCount > 0) {
                        finishLongCapture()
                    } else if (longCapture) {
                        val noChange = errorMessage?.contains("画面没有变化") == true
                        if (frameCount >= 12) {
                            showControls("已达到 12 屏，请完成长截图")
                        } else if (noChange) {
                            showControls("滚动页面后，系统会自动记录下一屏")
                            scheduleLongPoll(1200L)
                        } else {
                            showControls(errorMessage)
                            scheduleLongPoll(if (errorMessage == null) 1200L else 1600L)
                        }
                    } else if (errorMessage == null) finishLongCapture() else finishCapture(null)
                }
            }
        }
    }

    private fun acceptFrame(raw: Bitmap) {
        val region = captureRegion
        val cropped = if (region != null) {
            require(raw.width == captureWidth && raw.height == captureHeight) { "屏幕尺寸已改变，请重新截图" }
            Bitmap.createBitmap(raw, region.left, region.top, region.width(), region.height())
        } else raw
        val maxWidth = if (longCapture) 1080 else cropped.width
        val frame = try {
            if (cropped.width > maxWidth) Bitmap.createScaledBitmap(
                cropped, maxWidth, (cropped.height.toLong() * maxWidth / cropped.width).toInt(), true,
            ) else cropped.copy(Bitmap.Config.ARGB_8888, false)
        } finally { if (cropped !== raw) cropped.recycle() }
        try {
            val last = previous
            val old = combined
            if (last == null || old == null) {
                combined = frame
                previous = frame
                return
            }
            require(last.width == frame.width && last.height == frame.height) { "屏幕方向已改变，请结束本段后重新截图" }
            fun samples(bitmap: Bitmap): IntArray {
                val small = Bitmap.createScaledBitmap(bitmap, 64, minOf(1000, bitmap.height), true)
                val pixels = IntArray(small.width * small.height)
                small.getPixels(pixels, 0, small.width, 0, 0, small.width, small.height)
                small.recycle()
                return pixels
            }
            val sampleHeight = minOf(1000, frame.height)
            val join = LongCaptureMatcher.match(samples(last), samples(frame), 64, sampleHeight)
            val shift = join.shift * frame.height / sampleHeight
            val bottom = join.bottom * frame.height / sampleHeight
            val kept = old.height - bottom
            val start = frame.height - bottom - shift
            val outputHeight = kept + frame.height - start
            require(outputHeight <= 20000) { "长截图已达高度上限，请完成后分段提问" }
            val output = Bitmap.createBitmap(old.width, outputHeight, Bitmap.Config.ARGB_8888)
            Canvas(output).apply {
                drawBitmap(old, Rect(0, 0, old.width, kept), Rect(0, 0, old.width, kept), null)
                drawBitmap(frame, Rect(0, start, frame.width, frame.height), Rect(0, kept, frame.width, outputHeight), null)
            }
            if (last !== old) last.recycle()
            old.recycle()
            combined = output
            previous = frame
        } catch (error: Exception) {
            frame.recycle()
            throw error
        }
    }

    private fun finishLongCapture() {
        if (completed || finalizing) return
        if (busy) { finishRequested = true; return }
        if (frameCount == 0) return
        finalizing = true
        handler.removeCallbacks(longPoll)
        hideControls()
        releaseProjection()
        worker.execute {
            var file: File? = null
            try {
                if (!cancelled.get()) {
                    val root = File(cacheDir, MainActivity.ASSISTANT_CAPTURE_DIR).apply { mkdirs() }
                    val output = File(root, "capture-${UUID.randomUUID()}.jpg")
                    writeCompressed(checkNotNull(combined), output)
                    file = output
                }
            } catch (error: Exception) {
                Log.e(TAG, "截图编码失败", error)
            } finally { recycleFrames() }
            val result = file
            handler.post {
                if (completed || cancelled.get()) result?.delete()
                else if (result == null) failCapture("截图未能保存，请重试")
                else finishCapture(result)
            }
        }
    }

    private fun writeCompressed(source: Bitmap, file: File) {
        var bitmap = source
        try {
            while (true) {
                val stream = ByteArrayOutputStream()
                check(bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream))
                if (stream.size() <= MainActivity.MAX_ASSISTANT_CAPTURE_BYTES) {
                    file.writeBytes(stream.toByteArray())
                    return
                }
                require(bitmap.width > 320) { "截图过大，请分段提问" }
                val next = Bitmap.createScaledBitmap(bitmap, bitmap.width * 3 / 4, maxOf(1, bitmap.height * 3 / 4), true)
                if (bitmap !== source) bitmap.recycle()
                bitmap = next
            }
        } finally { if (bitmap !== source) bitmap.recycle() }
    }

    private fun showEditor(bitmap: Bitmap) {
        try {
            check(Settings.canDrawOverlays(this))
            val view = CaptureEditorView(this, bitmap,
                onConfirm = { region -> completeSelection(region, false) },
                onLongCapture = { region -> completeSelection(region, true) },
                onCancel = { cancelCapture() },
            )
            manager.addView(view, WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.LEFT
                if (Build.VERSION.SDK_INT >= 30) {
                    setFitInsetsTypes(0)
                    layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                } else if (Build.VERSION.SDK_INT >= 28) {
                    layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            })
            editor = view
        } catch (error: Exception) {
            Log.e(TAG, "截图选区显示失败", error)
            failCapture("无法显示截图工具，请检查悬浮窗权限")
        }
    }

    private fun hideEditor() {
        editor?.let { try { manager.removeView(it) } catch (_: Exception) { } }
        editor = null
    }

    private fun completeSelection(region: Rect, scrolling: Boolean) {
        val image = preview ?: return
        preview = null
        captureRegion = region
        hideEditor()
        longCapture = scrolling
        busy = true
        worker.execute {
            var failed = false
            try { if (!cancelled.get()) acceptFrame(image) }
            catch (error: Exception) { Log.e(TAG, "选区裁剪失败", error); failed = true }
            finally { image.recycle() }
            handler.post {
                busy = false
                if (completed) return@post
                if (failed) { failCapture("截图裁剪失败，请重试"); return@post }
                frameCount = 1
                if (scrolling) { showControls(); scheduleLongPoll(1200L) }
                else finishLongCapture()
            }
        }
    }

    private fun showControls(message: String? = null) {
        if (completed || finalizing) return
        hideControls()
        try {
            check(Settings.canDrawOverlays(this))
            fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
            val panel = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(8), dp(4), dp(8), dp(4))
                background = GradientDrawable().apply {
                    setColor(0xFFF7F8F5.toInt()); cornerRadius = dp(16).toFloat()
                    setStroke(dp(1), 0xFFE0E7DF.toInt())
                }
                elevation = dp(3).toFloat()
            }
            panel.addView(TextView(this).apply {
                text = when {
                    message?.contains("达到") == true -> "已采集满 · $frameCount/12"
                    message == null || message.contains("滚动页面") -> "滚动采集 · $frameCount/12"
                    else -> "本屏未加入 · $frameCount/12"
                }
                textSize = 12f; setTextColor(0xFF244D3D.toInt())
                setPadding(dp(8), 0, dp(8), 0)
                contentDescription = message ?: "长截图，已采集 $frameCount 屏，滚动原页面继续"
                if (Build.VERSION.SDK_INT >= 26) tooltipText = message
            }, LinearLayout.LayoutParams(0, -2, 1f))
            fun action(label: String, callback: () -> Unit) {
                panel.addView(TextView(this).apply {
                    text = label; textSize = 13f; gravity = Gravity.CENTER
                    minWidth = dp(48); minimumHeight = dp(48)
                    setTextColor(0xFF244D3D.toInt()); isFocusable = true
                    background = RippleDrawable(ColorStateList.valueOf(0x22244D3D), null, null)
                    setOnClickListener { callback() }
                }, LinearLayout.LayoutParams(-2, -2))
            }
            action("完成") { finishLongCapture() }
            action("取消") { cancelCapture() }
            manager.addView(panel, WindowManager.LayoutParams(
                minOf(dp(360), resources.displayMetrics.widthPixels - dp(24)), -2,
                if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT,
            ).apply { gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL; y = dp(12) })
            controls = panel
            if (message != null && message != lastIssue && !message.contains("滚动页面")) {
                android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_SHORT).show()
            }
            lastIssue = message
        } catch (error: Exception) {
            Log.e(TAG, "长截图控制条显示失败", error)
            failCapture("无法显示长截图操作栏，请检查悬浮窗权限")
        }
    }

    private fun hideControls() {
        controls?.let { try { manager.removeView(it) } catch (_: Exception) { } }
        controls = null
    }

    private fun startCaptureForeground() {
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "AI 屏幕截取", NotificationManager.IMPORTANCE_LOW),
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        val notification = builder.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(if (longCapture) "正在采集长截图" else "正在截取屏幕").setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        else startForeground(NOTIFICATION_ID, notification)
    }

    private fun failCapture(message: String) {
        if (completed) return
        android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_SHORT).show()
        cancelCapture()
    }

    private fun cancelCapture() {
        cancelled.set(true)
        handler.removeCallbacks(longPoll)
        finishCapture(null)
    }

    private fun releaseProjection() {
        awaitingFrame = false
        settlingFrame = false
        display?.release()
        display = null
        reader?.close()
        reader = null
        val session = projection
        projection = null
        session?.stop()
    }

    private fun recycleFrames() {
        if (previous !== combined) previous?.recycle()
        combined?.recycle()
        previous = null
        combined = null
    }

    private fun finishCapture(file: File?) {
        if (completed) return
        completed = true
        handler.removeCallbacksAndMessages(null)
        handler.removeCallbacks(longPoll)
        hideControls()
        hideEditor()
        preview?.recycle()
        preview = null
        releaseProjection()
        getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE).edit()
            .putBoolean(AssistantOverlayService.CAPTURE_PENDING_KEY, false).apply()
        if (file != null) {
            getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE).edit()
                .putString(MainActivity.EXTRA_CAPTURE_PATH, file.absolutePath).apply()
            Log.i(TAG, "截图文件已就绪，发送完成广播: ${file.absolutePath}")
        } else {
            Log.w(TAG, "截图未生成，发送失败广播")
        }
        sendBroadcast(Intent(ACTION_CAPTURE_READY).setPackage(packageName).apply {
            if (file != null) putExtra(MainActivity.EXTRA_CAPTURE_PATH, file.absolutePath)
        })
        stopSelf()
    }

    override fun onDestroy() {
        cancelled.set(true)
        if (!completed) finishCapture(null)
        worker.execute { recycleFrames() }
        worker.shutdown()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        if (!completed && !finalizing) {
            android.widget.Toast.makeText(this, "屏幕方向已改变，请重新截图", android.widget.Toast.LENGTH_SHORT).show()
            cancelCapture()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_CAPTURE_READY = "chat.liuxin.mission_book.CAPTURE_READY"
        const val ACTION_CANCEL_CAPTURE = "chat.liuxin.mission_book.CANCEL_CAPTURE"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        const val EXTRA_LONG_CAPTURE = "long_capture"
        private const val CHANNEL_ID = "assistant_screen_capture"
        private const val NOTIFICATION_ID = 7405
        private const val TAG = "AssistantCapture"
    }
}
