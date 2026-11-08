package chat.liuxin.mission_book

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.provider.Settings
import android.widget.Toast
import android.view.WindowManager
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID

class AssistantScreenCaptureService : Service() {
    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private val handler = Handler(Looper.getMainLooper())
    private var completed = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            startCaptureForeground()
        } catch (error: Exception) {
            Log.e("AssistantCapture", "截屏前台服务启动失败", error)
            finishCapture(null)
            return START_NOT_STICKY
        }
        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, ActivityResultCanceled) ?: ActivityResultCanceled
        val data = getResultData(intent)
        if (resultCode != ActivityResultOk || data == null) {
            finishCapture(null)
            return START_NOT_STICKY
        }
        try {
            val manager = getSystemService(MediaProjectionManager::class.java)
            projection = manager.getMediaProjection(resultCode, data)
            val metrics = displayMetrics()
            val imageReader = ImageReader.newInstance(metrics.widthPixels, metrics.heightPixels, PixelFormat.RGBA_8888, 2)
            reader = imageReader
            imageReader.setOnImageAvailableListener({ source ->
                if (completed) return@setOnImageAvailableListener
                val image = try { source.acquireLatestImage() } catch (error: Exception) {
                    Log.e("AssistantCapture", "读取截屏帧失败", error)
                    finishCapture(null)
                    return@setOnImageAvailableListener
                } ?: return@setOnImageAvailableListener
                val file = try { writeCapture(image, metrics.widthPixels, metrics.heightPixels) }
                catch (error: Exception) { Log.e("AssistantCapture", "截屏编码失败", error); null }
                finally { image.close() }
                finishCapture(file)
            }, handler)
            projection?.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() { finishCapture(null) }
            }, handler)
            display = projection?.createVirtualDisplay(
                "MissionBookAssistantCapture",
                metrics.widthPixels,
                metrics.heightPixels,
                metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageReader.surface,
                null,
                handler,
            )
            handler.postDelayed({ finishCapture(null) }, 5000)
        } catch (_: Exception) {
            finishCapture(null)
        }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun getResultData(intent: Intent?): Intent? =
        if (Build.VERSION.SDK_INT >= 33) intent?.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        else intent?.getParcelableExtra(EXTRA_RESULT_DATA)

    private fun displayMetrics(): DisplayMetrics {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        val display = (getSystemService(WINDOW_SERVICE) as WindowManager).defaultDisplay
        @Suppress("DEPRECATION")
        display.getRealMetrics(metrics)
        return metrics
    }

    private fun writeCapture(image: android.media.Image, width: Int, height: Int): File {
        val plane = image.planes.single()
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val paddedWidth = rowStride / pixelStride
        val bitmap = Bitmap.createBitmap(paddedWidth, height, Bitmap.Config.ARGB_8888)
        bitmap.copyPixelsFromBuffer(plane.buffer)
        val cropped = Bitmap.createBitmap(bitmap, 0, 0, width, height)
        if (cropped !== bitmap) bitmap.recycle()
        val directory = File(cacheDir, MainActivity.ASSISTANT_CAPTURE_DIR).apply { mkdirs() }
        val file = File(directory, "capture-${UUID.randomUUID()}.jpg")
        var scaled = cropped
        var encoded: ByteArray
        do {
            val stream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 78, stream)
            encoded = stream.toByteArray()
            if (encoded.size <= MAX_CAPTURE_BYTES) break
            val smaller = Bitmap.createScaledBitmap(scaled, scaled.width / 2, scaled.height / 2, true)
            if (scaled !== cropped) scaled.recycle()
            scaled = smaller
        } while (scaled.width > 320 && scaled.height > 320)
        if (scaled !== cropped) scaled.recycle()
        cropped.recycle()
        check(encoded.size <= MAX_CAPTURE_BYTES) { "截屏压缩后仍超过大小限制" }
        file.writeBytes(encoded)
        return file
    }

    private fun startCaptureForeground() {
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "AI 单次屏幕截取", NotificationManager.IMPORTANCE_LOW),
            )
        }
        val notification = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("正在截取屏幕")
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun finishCapture(file: File?) {
        if (completed) return
        completed = true
        getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE)
            .edit().putBoolean(AssistantOverlayService.CAPTURE_PENDING_KEY, false).apply()
        handler.removeCallbacksAndMessages(null)
        display?.release()
        display = null
        reader?.close()
        reader = null
        projection?.stop()
        projection = null
        if (file != null) {
            getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE)
                .edit().putString(MainActivity.EXTRA_CAPTURE_PATH, file.absolutePath).apply()
            // 授权 Activity 保持存活，由可见 Activity 完成返回应用。
            sendBroadcast(Intent(ACTION_CAPTURE_READY).setPackage(packageName)
                .putExtra(MainActivity.EXTRA_CAPTURE_PATH, file.absolutePath))
        } else {
            Toast.makeText(this, "截屏失败，请重新截取", Toast.LENGTH_LONG).show()
            sendBroadcast(Intent(ACTION_CAPTURE_READY).setPackage(packageName))
            val prefs = getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE)
            if (prefs.getBoolean(AssistantOverlayService.ENABLED_KEY, false) && Settings.canDrawOverlays(this)) {
                try { startService(Intent(this, AssistantOverlayService::class.java)
                    .setAction(AssistantOverlayService.ACTION_SHOW)) }
                catch (error: Exception) { Log.e("AssistantCapture", "恢复悬浮入口失败", error) }
            }
        }
        stopSelf()
    }

    override fun onDestroy() {
        if (!completed) finishCapture(null)
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE)
        else stopForeground(true)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_CAPTURE_READY = "chat.liuxin.mission_book.CAPTURE_READY"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        private const val CHANNEL_ID = "assistant_screen_capture"
        private const val NOTIFICATION_ID = 7405
        private const val MAX_CAPTURE_BYTES = 4 * 1024 * 1024
        private const val ActivityResultOk = -1
        private const val ActivityResultCanceled = 0
    }
}
