package chat.liuxin.mission_book

import android.app.Activity
import android.content.Context
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.widget.Toast

@Suppress("DEPRECATION")
class AssistantCaptureConsentActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val path = intent?.getStringExtra(MainActivity.EXTRA_CAPTURE_PATH)
            if (path != null) {
                try {
                    startActivity(MainActivity.assistantIntent(this@AssistantCaptureConsentActivity, path))
                } catch (error: Exception) {
                    Log.e(TAG, "打开助手失败", error)
                    Toast.makeText(this@AssistantCaptureConsentActivity, "截图已保留，请打开 MissionBook 重试", Toast.LENGTH_LONG).show()
                    restoreOverlayIfEnabled()
                }
            }
            // 部分系统静默拒绝后台启动；保留可点按的截图入口。
            restoreOverlayIfEnabled()
            finish()
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        unregisterReceiver(receiver)
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(AssistantScreenCaptureService.ACTION_CAPTURE_READY)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
        else registerReceiver(receiver, filter)
        // 系统重建授权页时由原请求返回，避免再次申请同一投影会话。
        if (savedInstanceState != null) return
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val request = try {
            manager.createScreenCaptureIntent()
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
        }
        try {
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(capture) else startService(capture)
        } catch (error: Exception) {
            Log.e(TAG, "截屏服务启动失败", error)
            cancelCapture("截屏服务启动失败")
            return
        }
        handler.postDelayed({ cancelCapture("截屏超时，请重试") }, 10000)
    }

    private fun cancelCapture(reason: String?) {
        getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE)
            .edit().putBoolean(AssistantOverlayService.CAPTURE_PENDING_KEY, false).apply()
        restoreOverlayIfEnabled()
        reason?.let { Toast.makeText(this, it, Toast.LENGTH_SHORT).show() }
        finish()
    }

    private fun restoreOverlayIfEnabled() {
        val prefs = getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean(AssistantOverlayService.ENABLED_KEY, false)) return
        if (!Settings.canDrawOverlays(this)) return
        try {
            val intent = Intent(this, AssistantOverlayService::class.java)
                .setAction(AssistantOverlayService.ACTION_SHOW)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
        } catch (error: Exception) {
            Log.e(TAG, "恢复助手悬浮入口失败", error)
        }
    }

    companion object {
        private const val REQUEST_CAPTURE = 7404
        private const val TAG = "AssistantCapture"
    }
}
