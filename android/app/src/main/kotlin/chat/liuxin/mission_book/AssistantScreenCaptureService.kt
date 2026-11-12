package chat.liuxin.mission_book

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.PixelFormat
import android.graphics.Rect
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
import android.widget.Button
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
    private var busy = false
    private var frameCount = 0
    private var controls: View? = null
    private var combined: Bitmap? = null
    private var previous: Bitmap? = null
    private val manager by lazy { getSystemService(WindowManager::class.java) }
    private val frameTimeout = Runnable {
        if (awaitingFrame && !completed) {
            awaitingFrame = false
            busy = false
            if (longCapture) showControls("未收到画面，请轻触原页面后重试") else finishCapture(null)
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
            val source = ImageReader.newInstance(metrics.widthPixels, metrics.heightPixels, PixelFormat.RGBA_8888, 2)
            reader = source
            source.setOnImageAvailableListener({ captureAvailable(it, metrics.widthPixels, metrics.heightPixels) }, handler)
            projection?.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    if (!finalizing && !completed) cancelCapture()
                }
            }, handler)
            display = projection?.createVirtualDisplay(
                "MissionBookAssistantCapture", metrics.widthPixels, metrics.heightPixels, metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, source.surface, null, handler,
            )
            requestFrame()
            if (longCapture) handler.postDelayed({
                if (!completed && !finalizing) cancelCapture()
            }, 5 * 60 * 1000L)
        } catch (error: Exception) {
            Log.e(TAG, "截屏初始化失败", error)
            finishCapture(null)
        }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun getResultData(intent: Intent?): Intent? =
        if (Build.VERSION.SDK_INT >= 33) intent?.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        else intent?.getParcelableExtra(EXTRA_RESULT_DATA)

    private fun requestFrame() {
        if (completed || finalizing || busy) return
        busy = true
        val hadControls = controls != null
        hideControls()
        if (!hadControls) {
            awaitingFrame = true
            handler.postDelayed(frameTimeout, 2500)
            return
        }
        // 等待悬浮控制条从合成画面消失，再读取持续投影的新帧。
        handler.postDelayed({
            if (!completed && !finalizing) {
                awaitingFrame = true
                handler.postDelayed(frameTimeout, 2500)
            }
        }, 200)
    }

    private fun captureAvailable(source: ImageReader, width: Int, height: Int) {
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
            finishCapture(null)
            return
        } finally { image.close() }
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
                    if (longCapture) showControls(errorMessage)
                    else if (errorMessage == null) finishLongCapture() else finishCapture(null)
                }
            }
        }
    }

    private fun acceptFrame(raw: Bitmap) {
        val maxWidth = if (longCapture) 1080 else raw.width
        val frame = if (raw.width > maxWidth) Bitmap.createScaledBitmap(
            raw, maxWidth, (raw.height.toLong() * maxWidth / raw.width).toInt(), true,
        ) else raw.copy(Bitmap.Config.ARGB_8888, false)
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
        if (completed || finalizing || busy || frameCount == 0) return
        finalizing = true
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
                if (completed || cancelled.get()) result?.delete() else finishCapture(result)
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

    private fun showControls(message: String? = null) {
        if (completed || finalizing) return
        hideControls()
        try {
            check(Settings.canDrawOverlays(this))
            fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
            val panel = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(8), dp(4), dp(8), dp(4))
                setBackgroundColor(0xFFF7FAF6.toInt())
                addView(TextView(this@AssistantScreenCaptureService).apply {
                    text = message ?: "向下滚动，保留部分上一屏内容后采集"
                    textSize = 12f
                    setTextColor(0xFF244D3D.toInt())
                })
            }
            val buttons = LinearLayout(this)
            fun button(label: String, enabled: Boolean = true, action: () -> Unit) {
                buttons.addView(Button(this).apply {
                    text = label
                    textSize = 12f
                    minHeight = dp(48)
                    isEnabled = enabled
                    setOnClickListener { action() }
                })
            }
            button("采集一屏", frameCount < 12) { requestFrame() }
            button("完成 ($frameCount)", frameCount > 0) { finishLongCapture() }
            button("取消") { cancelCapture() }
            panel.addView(buttons)
            manager.addView(panel, WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT,
            ).apply { gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL; y = dp(20) })
            controls = panel
        } catch (error: Exception) {
            Log.e(TAG, "长截图控制条显示失败", error)
            finishCapture(null)
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

    private fun cancelCapture() {
        cancelled.set(true)
        finishCapture(null)
    }

    private fun releaseProjection() {
        awaitingFrame = false
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
        hideControls()
        releaseProjection()
        getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE).edit()
            .putBoolean(AssistantOverlayService.CAPTURE_PENDING_KEY, false).apply()
        if (file != null) getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE).edit()
            .putString(MainActivity.EXTRA_CAPTURE_PATH, file.absolutePath).apply()
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
