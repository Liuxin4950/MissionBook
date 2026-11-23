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
    private var ticket: String? = null
    private var watching = false
    private var stopping = false
    private var frameResult: ((ByteArray?) -> Unit)? = null
    private var requestSerial = 0
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
    private var emptyFrameRetries = 0
    private var controls: View? = null
    private var combined: Bitmap? = null
    private var previous: Bitmap? = null
    private var preview: Bitmap? = null
    private var editor: View? = null
    private var captureRegion: Rect? = null
    private var finishRequested = false
    private var captureWidth = 0
    private var captureHeight = 0
    private var initialContentSizeResolved = false
    private var capturedContentSizeReceived = false
    private var manualSelectionStarted = false
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
            Log.w(TAG, "等待投影帧超时，选区预览=${preview != null}，重试=$emptyFrameRetries")
            if (frameResult != null) { finishSample(null); return@Runnable }
            awaitingFrame = false
            busy = false
            if (finishRequested && frameCount > 0) finishLongCapture()
            else if (longCapture) {
                showControls("未收到画面，滚动页面后系统会继续尝试")
                scheduleLongPoll(500L)
            } else if (preview == null && emptyFrameRetries < MAX_EMPTY_FRAME_RETRIES) {
                emptyFrameRetries++
                if (emptyFrameRetries == 1) {
                    android.widget.Toast.makeText(this, "正在等待所选应用画面…", android.widget.Toast.LENGTH_SHORT).show()
                }
                handler.postDelayed({
                    if (ticket != null && !completed && !finalizing && preview == null) requestFrame()
                }, EMPTY_FRAME_RETRY_DELAY_MS)
            } else failCapture("暂未收到屏幕画面，请重试")
        }
    }
    private val initialContentSizeTimeout = Runnable {
        if (!initialContentSizeResolved && !watching && ticket != null && !completed) {
            // Android 14+ reports the chosen app size immediately; fall back to display metrics on OEMs that omit it.
            initialContentSizeResolved = true
            requestFrame()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL_CAPTURE) {
            if (ticket != null && intent.getStringExtra(EXTRA_TICKET) == ticket) cancelCapture()
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_CONFIRM_SELECTION) {
            val targetTicket = intent.getStringExtra(EXTRA_TICKET)
            val region = getResultRegion(intent)
            if (targetTicket == ticket && region != null && preview != null && !completed && !finalizing) {
                completeSelection(region, intent.getBooleanExtra(EXTRA_SCROLLING, false))
            } else {
                Log.w(TAG, "忽略失效的截图选区 ticketMatch=${targetTicket == ticket} hasRegion=${region != null}")
            }
            return START_NOT_STICKY
        }
        if (projection != null || finalizing || completed) return START_NOT_STICKY
        ticket = intent?.getStringExtra(EXTRA_TICKET)
        Log.d(TAG, "Capture service start; ticket=${ticket != null}, startId=$startId")
        watching = intent?.getBooleanExtra(EXTRA_WATCH, false) == true
        emptyFrameRetries = 0
        initialContentSizeResolved = watching || Build.VERSION.SDK_INT < 34
        capturedContentSizeReceived = false
        manualSelectionStarted = false
        contentWidth = 0
        contentHeight = 0
        try {
            startCaptureForeground()
            // 主动画面监督搁置；只接受手动截图的票据，不获取持续投影。
            if (watching || ticket == null) {
                stopSelf()
                return START_NOT_STICKY
            }
            val code = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
            val data = getResultData(intent)
            check(code == -1 && data != null)
            projection = getSystemService(MediaProjectionManager::class.java).getMediaProjection(code, data)
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            manager.defaultDisplay.getRealMetrics(metrics)
            captureWidth = metrics.widthPixels
            captureHeight = metrics.heightPixels
            val source = openReader(captureWidth, captureHeight)
            projection?.registerCallback(object : MediaProjection.Callback() {
                override fun onCapturedContentResize(width: Int, height: Int) {
                    if (watching) resizeObservation(width, height)
                    else resizeManualCapture(width, height)
                }
                override fun onStop() {
                    if (projection == null) return
                    if (watching) endObservation()
                    else if (!finalizing && !completed) cancelCapture()
                }
            }, handler)
            display = projection?.createVirtualDisplay(
                "MissionBookAssistantCapture", metrics.widthPixels, metrics.heightPixels, metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, if (watching) null else source.surface, null, handler,
            )
            check(display != null)
            Log.d(TAG, "VirtualDisplay created ${captureWidth}x$captureHeight; waitingForContentSize=${!initialContentSizeResolved}")
            if (watching) observer = this else beginManualTimer()
        } catch (error: Exception) {
            Log.e(TAG, "截屏初始化失败", error)
            if (watching) endObservation() else failCapture("截屏未能启动，请重试")
        }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun getResultData(intent: Intent?): Intent? =
        if (Build.VERSION.SDK_INT >= 33) intent?.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        else intent?.getParcelableExtra(EXTRA_RESULT_DATA)

    @Suppress("DEPRECATION")
    private fun getResultRegion(intent: Intent?): Rect? =
        if (Build.VERSION.SDK_INT >= 33) intent?.getParcelableExtra(EXTRA_REGION, Rect::class.java)
        else intent?.getParcelableExtra(EXTRA_REGION)

    private fun scheduleLongPoll(delayMillis: Long) {
        if (!longCapture || completed || finalizing || cancelled.get()) return
        handler.removeCallbacks(longPoll)
        handler.postDelayed(longPoll, delayMillis)
    }

    private fun openReader(width: Int, height: Int): ImageReader {
        val source = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        reader = source
        source.setOnImageAvailableListener({ captureAvailable(it, width, height) }, handler)
        return source
    }

    private fun beginManualTimer() {
        val current = ticket
        if (initialContentSizeResolved) requestFrame()
        else handler.postDelayed(initialContentSizeTimeout, 600L)
        handler.postDelayed({
            if (current == ticket && ticket != null && !completed && !finalizing) cancelCapture()
        }, 5 * 60 * 1000L)
    }

    /** 单应用投影要等系统返回所选窗口尺寸，再同步调整虚拟屏与 ImageReader 输出面。 */
    private fun resizeManualCapture(width: Int, height: Int) {
        if (stopping || completed || finalizing || width <= 0 || height <= 0) return
        val firstSize = !capturedContentSizeReceived
        capturedContentSizeReceived = true
        initialContentSizeResolved = true
        handler.removeCallbacks(initialContentSizeTimeout)
        contentWidth = width
        contentHeight = height
        Log.d(TAG, "手动投影内容尺寸：${width}x$height，首次=$firstSize")
        if (width == captureWidth && height == captureHeight) {
            if (firstSize && !busy) requestFrame()
            return
        }
        if (manualSelectionStarted) {
            failCapture("被截应用窗口尺寸已改变，请重新截图")
            return
        }

        val activeTicket = ticket ?: return
        if (preview != null) {
            android.widget.Toast.makeText(this, "所选应用画面已调整，正在更新截图", android.widget.Toast.LENGTH_SHORT).show()
        }
        requestSerial++
        handler.removeCallbacks(frameTimeout)
        awaitingFrame = false
        settlingFrame = false
        busy = false
        emptyFrameRetries = 0
        hideEditor()
        preview?.recycle()
        preview = null
        try {
            display?.surface = null
            reader?.setOnImageAvailableListener(null, null)
            reader?.close()
            reader = null
            checkNotNull(display).resize(width, height, resources.configuration.densityDpi)
            val source = openReader(width, height)
            display?.surface = source.surface
            captureWidth = width
            captureHeight = height
            handler.post {
                if (ticket == activeTicket && !completed && !finalizing) requestFrame()
            }
        } catch (error: Exception) {
            Log.e(TAG, "调整单应用截图尺寸失败 ($width x $height)", error)
            failCapture("所选应用画面暂时无法读取，请重新截图")
        }
    }

    private fun resizeObservation(width: Int, height: Int) {
        if (stopping || (width == captureWidth && height == captureHeight)) return
        capturedContentSizeReceived = true
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        manager.defaultDisplay.getRealMetrics(metrics)
        if (width != metrics.widthPixels || height != metrics.heightPixels) {
            endObservation() // 单应用/未知范围不能当作跨应用观察。
            return
        }
        if (ticket != null && !completed) cancelCapture()
        if (frameResult != null) finishSample(null)
        runCatching {
            display?.surface = null
            reader?.close()
            display?.resize(width, height, metrics.densityDpi)
            val source = openReader(width, height)
            display?.surface = source.surface
            captureWidth = width
            captureHeight = height
        }.onFailure { endObservation() }
    }

    private fun observeFrame(result: (ByteArray?) -> Unit) {
        if (stopping || !watching || busy || ticket != null || completed || frameResult != null) {
            result(null); return
        }
        frameResult = result
        AssistantOverlayService.maskForSample(true)
        requestFrame()
    }

    private fun finishSample(bytes: ByteArray?) {
        val result = frameResult ?: return
        frameResult = null
        requestSerial++
        busy = false; awaitingFrame = false; settlingFrame = false
        handler.removeCallbacks(frameTimeout)
        runCatching { display?.surface = null }
        AssistantOverlayService.maskForSample(false)
        result(bytes)
    }

    private fun encodeSample(bitmap: Bitmap): ByteArray? {
        val maxSize = maxOf(bitmap.width, bitmap.height)
        val scaled = if (maxSize <= 720) bitmap else Bitmap.createScaledBitmap(bitmap,
            maxOf(1, bitmap.width * 720 / maxSize), maxOf(1, bitmap.height * 720 / maxSize), true)
        try {
            // 不发送近乎全黑的系统保护画面或无效帧。
            var visible = 0
            for (row in 1..8) for (column in 1..8) {
                if (scaled.getPixel(column * scaled.width / 9, row * scaled.height / 9) and 0x00FFFFFF > 0x101010) visible++
            }
            if (visible < 5) return null
            return ByteArrayOutputStream().use { bytes ->
                if (scaled.compress(Bitmap.CompressFormat.JPEG, 66, bytes) && bytes.size() <= 256 * 1024) bytes.toByteArray()
                else null
            }
        } finally { if (scaled !== bitmap) scaled.recycle() }
    }

    private fun requestFrame() {
        if (completed || finalizing || busy) return
        Log.d(TAG, "Requesting frame ${captureWidth}x$captureHeight")
        busy = true
        // 先丢弃旧缓冲；等待合成期间持续释放过渡帧，settle 结束后再取稳定帧。
        runCatching { reader?.acquireLatestImage()?.close() }
        settlingFrame = true
        hideControls()
        val current = ++requestSerial
        try { if (watching) display?.surface = reader?.surface }
        catch (_: Exception) {
            if (frameResult != null) finishSample(null) else failCapture("暂时无法使用当前投影")
            return
        }
        handler.postDelayed({
            if (current != requestSerial) return@postDelayed
            settlingFrame = false
            if (!completed && !finalizing) {
                awaitingFrame = true
                reader?.let { captureAvailable(it, captureWidth, captureHeight) }
                if (awaitingFrame) handler.postDelayed(frameTimeout, 900)
            }
        }, 200)
    }

    private fun captureAvailable(source: ImageReader, width: Int, height: Int) {
        if (source !== reader) return
        if (settlingFrame) {
            // 过渡帧也需释放，否则 ImageReader 的 maxImages 缓冲会被系统切换帧占满。
            runCatching { source.acquireLatestImage()?.close() }
            return
        }
        val image = try { source.acquireLatestImage() } catch (error: Exception) {
            Log.e(TAG, "读取截屏帧失败", error)
            if (frameResult != null) finishSample(null) else cancelCapture()
            return
        } ?: return
        Log.d(TAG, "收到投影帧 ${image.width}x${image.height}，目标缓冲=${width}x$height，等待=$awaitingFrame")
        if (!awaitingFrame || completed) {
            image.close()
            return
        }
        awaitingFrame = false
        emptyFrameRetries = 0
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
            if (frameResult != null) finishSample(null) else failCapture("无法读取屏幕画面，请重试")
            return
        } finally { image.close() }
        val sample = frameResult
        if (sample != null) {
            worker.execute {
                val output = try { encodeSample(bitmap) } catch (_: Exception) { null }
                finally { bitmap.recycle() }
                handler.post { if (frameResult === sample) finishSample(output) }
            }
            return
        }
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
        if (!watching) releaseProjection() else runCatching { display?.surface = null }
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
            val activeTicket = checkNotNull(ticket)
            // MediaProjection 的单应用隐私模式会隐藏 TYPE_APPLICATION_OVERLAY；编辑界面改由可见 Activity 承载。
            AssistantCaptureConsentActivity.presentEditor(this, activeTicket, bitmap)
            Log.d(TAG, "已请求截图编辑 Activity，预览=${bitmap.width}x${bitmap.height}")
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
        manualSelectionStarted = true
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
            fun dp(value: Int) = AssistantNativeTheme.dp(this, value)
            val panel = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(AssistantNativeTheme.spaceSm), dp(AssistantNativeTheme.spaceXs),
                    dp(AssistantNativeTheme.spaceSm), dp(AssistantNativeTheme.spaceXs))
                background = AssistantNativeTheme.surface(
                    this@AssistantScreenCaptureService,
                    AssistantNativeTheme.cardSurface,
                    AssistantNativeTheme.radiusLg,
                    AssistantNativeTheme.hairline,
                    1f,
                )
                elevation = dp(3).toFloat()
            }
            val failed = message != null && !message.contains("滚动页面") && !message.contains("达到")
            val warning = message?.contains("达到") == true
            val statusColor = when {
                failed -> AssistantNativeTheme.error
                warning -> AssistantNativeTheme.warning
                else -> AssistantNativeTheme.primary
            }
            panel.addView(TextView(this).apply {
                text = when {
                    message?.contains("达到") == true -> "已采集满 · $frameCount/12"
                    message == null || message.contains("滚动页面") -> "滚动采集 · $frameCount/12"
                    else -> "本屏未加入 · $frameCount/12"
                }
                setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, AssistantNativeTheme.textMetadata)
                setTextColor(statusColor)
                setPadding(dp(AssistantNativeTheme.spaceSm), 0, dp(AssistantNativeTheme.spaceSm), 0)
                contentDescription = message ?: "长截图，已采集 $frameCount 屏，滚动原页面继续"
                if (Build.VERSION.SDK_INT >= 26) tooltipText = message
            }, LinearLayout.LayoutParams(0, -2, 1f))
            fun action(label: String, enabled: Boolean = true, callback: () -> Unit) {
                panel.addView(TextView(this).apply {
                    text = label
                    setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, AssistantNativeTheme.textBody)
                    gravity = Gravity.CENTER
                    minWidth = dp(AssistantNativeTheme.minTouchDp)
                    minimumHeight = dp(AssistantNativeTheme.minTouchDp)
                    isEnabled = enabled
                    isFocusable = true
                    contentDescription = label
                    setTextColor(if (enabled) AssistantNativeTheme.primary else AssistantNativeTheme.onDisabled)
                    background = RippleDrawable(ColorStateList.valueOf(AssistantNativeTheme.ripple), null, null)
                    setOnClickListener { callback() }
                }, LinearLayout.LayoutParams(-2, -2))
            }
            action("完成", frameCount > 0) { finishLongCapture() }
            action("取消") { cancelCapture() }
            manager.addView(panel, WindowManager.LayoutParams(
                minOf(dp(360), resources.displayMetrics.widthPixels - dp(AssistantNativeTheme.spaceXl)), -2,
                if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT,
            ).apply { gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL; y = dp(AssistantNativeTheme.spaceMd) })
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
            .setContentTitle(if (watching) "书祺 · 画面取样已授权" else "正在截取屏幕").setOngoing(true).build()
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
        requestSerial++
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
        if (completed) { file?.delete(); return }
        completed = true
        requestSerial++
        handler.removeCallbacks(longPoll)
        handler.removeCallbacks(frameTimeout)
        handler.removeCallbacks(initialContentSizeTimeout)
        awaitingFrame = false; settlingFrame = false
        emptyFrameRetries = 0
        hideControls()
        hideEditor()
        preview?.recycle()
        preview = null
        val done = ticket
        ticket = null
        AssistantOverlayService.captureDone(done, file)
        if (done != null) sendBroadcast(Intent(ACTION_CAPTURE_READY).setPackage(packageName).putExtra(EXTRA_TICKET, done))
        if (!watching || stopping) {
            releaseProjection()
            stopSelf()
        } else {
            runCatching { display?.surface = null }
            // 取消旧长截图后，等 worker 完成再允许下一张复用投影。
            worker.execute {
                recycleFrames()
                handler.post {
                    if (stopping) return@post
                    completed = false; finalizing = false; busy = false; longCapture = false
                    frameCount = 0; finishRequested = false; captureRegion = null; lastIssue = null
                    cancelled.set(false)
                }
            }
        }
    }

    private fun endObservation() {
        if (stopping) return
        stopping = true
        if (observer === this) observer = null
        AssistantWorkspaceHost.call("invalidateObservation", failure = {})
        finishSample(null)
        if (ticket != null && !completed) cancelCapture() else releaseProjection()
        stopSelf()
    }

    override fun onDestroy() {
        cancelled.set(true)
        handler.removeCallbacks(initialContentSizeTimeout)
        if (watching) endObservation() else if (!completed) finishCapture(null)
        worker.execute { recycleFrames() }
        worker.shutdown()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        if (ticket != null && !completed && !finalizing) {
            android.widget.Toast.makeText(this, "屏幕方向已改变，请重新截图", android.widget.Toast.LENGTH_SHORT).show()
            cancelCapture()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private var observer: AssistantScreenCaptureService? = null
        internal val observationActive get() = observer?.projection != null

        internal fun stopObservation() { observer?.endObservation() }

        internal fun takeObservationFrame(result: (ByteArray?) -> Unit) {
            val source = observer
            if (source == null) result(null) else source.observeFrame(result)
        }

        /** 返回 null 表示没有可复用投影；false 表示当前资源忙。 */
        internal fun manualFromObservation(id: String): Boolean? {
            val source = observer ?: return null
            if (source.stopping || source.completed || source.busy || source.ticket != null || source.frameResult != null) return false
            source.ticket = id
            source.beginManualTimer()
            return true
        }
        const val ACTION_CAPTURE_READY = "chat.liuxin.mission_book.CAPTURE_READY"
        const val ACTION_CANCEL_CAPTURE = "chat.liuxin.mission_book.CANCEL_CAPTURE"
        const val ACTION_CONFIRM_SELECTION = "chat.liuxin.mission_book.CONFIRM_SELECTION"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        const val EXTRA_TICKET = "assistant_capture_ticket"
        const val EXTRA_WATCH = "assistant_enable_projection"
        const val EXTRA_SCROLLING = "assistant_capture_scrolling"
        const val EXTRA_REGION = "assistant_capture_region"
        private const val CHANNEL_ID = "assistant_screen_capture"
        private const val NOTIFICATION_ID = 7405
        private const val MAX_EMPTY_FRAME_RETRIES = 2
        private const val EMPTY_FRAME_RETRY_DELAY_MS = 350L
        private const val TAG = "AssistantCapture"
    }
}
