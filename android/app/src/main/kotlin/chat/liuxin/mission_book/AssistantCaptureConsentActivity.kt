package chat.liuxin.mission_book

import android.app.Activity
import android.content.Context
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.media.projection.MediaProjectionConfig
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.widget.Toast

@Suppress("DEPRECATION")
class AssistantCaptureConsentActivity : Activity() {
    private val ticket get() = intent.getStringExtra(AssistantScreenCaptureService.EXTRA_TICKET)
    private val watching get() = intent.getBooleanExtra(AssistantScreenCaptureService.EXTRA_WATCH, false)
    private var captureStarted = false
    private var captureCompleted = false
    private val handler = Handler(Looper.getMainLooper())
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.getStringExtra(AssistantScreenCaptureService.EXTRA_TICKET) != ticket) return
            captureCompleted = true
            finish()
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        unregisterReceiver(receiver)
        super.onDestroy()
    }

    override fun onBackPressed() {
        if (captureStarted && !captureCompleted) {
            try {
                startService(Intent(this, AssistantScreenCaptureService::class.java)
                    .setAction(AssistantScreenCaptureService.ACTION_CANCEL_CAPTURE)
                    .putExtra(AssistantScreenCaptureService.EXTRA_TICKET, ticket))
            } catch (error: Exception) {
                Log.w(TAG, "取消长截图服务失败", error)
            }
            handler.postDelayed({ AssistantOverlayService.captureDone(ticket, null) }, 300L)
        } else if (!captureCompleted) {
            AssistantOverlayService.captureDone(ticket, null)
        }
        super.onBackPressed()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 授权完成后由服务的截图遮罩接管触摸，底下保留原应用画面。
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE)
        window.attributes = window.attributes.apply { alpha = 0f }
        val filter = IntentFilter(AssistantScreenCaptureService.ACTION_CAPTURE_READY)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
        else registerReceiver(receiver, filter)
        if (ticket == null || watching) { finish(); return }
        // 系统重建授权页时由原请求返回，避免再次申请同一投影会话。
        if (savedInstanceState != null) return
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val request = try {
            if (watching && Build.VERSION.SDK_INT >= 34) manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
            else manager.createScreenCaptureIntent()
        } catch (error: Exception) {
            Log.e(TAG, "无法创建系统截屏授权", error)
            cancelCapture("无法打开系统截屏授权")
            return
        }
        try { startActivityForResult(request, REQUEST_CAPTURE) }
        catch (error: Exception) {
            Log.e(TAG, "无法打开系统截屏授权", error)
            cancelCapture("无法打开系统截屏授权")
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_CAPTURE) {
            cancelCapture(null)
            return
        }
        if (resultCode != RESULT_OK || data == null) {
            cancelCapture("已取消截屏授权")
            return
        }
        val capture = Intent(this, AssistantScreenCaptureService::class.java).apply {
            putExtra(AssistantScreenCaptureService.EXTRA_RESULT_CODE, resultCode)
            putExtra(AssistantScreenCaptureService.EXTRA_RESULT_DATA, data)
            putExtra(AssistantScreenCaptureService.EXTRA_TICKET, ticket)
            putExtra(AssistantScreenCaptureService.EXTRA_WATCH, watching)
        }
        try {
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(capture) else startService(capture)
            captureStarted = true
        } catch (error: Exception) {
            Log.e(TAG, "截屏服务启动失败", error)
            cancelCapture("截屏服务启动失败")
            return
        }
        if (watching) { finish(); return }
        // 选区现在由用户确认，不再用十秒定时器误关编辑中的截图。
        handler.postDelayed({
            if (!captureCompleted) {
                startService(Intent(this, AssistantScreenCaptureService::class.java)
                    .setAction(AssistantScreenCaptureService.ACTION_CANCEL_CAPTURE)
                    .putExtra(AssistantScreenCaptureService.EXTRA_TICKET, ticket))
            }
        }, 5 * 60 * 1000L)
    }

    private fun cancelCapture(reason: String?) {
        AssistantOverlayService.captureDone(ticket, null)
        reason?.let { Toast.makeText(this, it, Toast.LENGTH_SHORT).show() }
        finish()
    }


    companion object {
        private const val REQUEST_CAPTURE = 7404
        private const val TAG = "AssistantCapture"
    }
}
