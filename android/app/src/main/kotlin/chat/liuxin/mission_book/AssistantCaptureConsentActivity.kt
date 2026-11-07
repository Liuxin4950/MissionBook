package chat.liuxin.mission_book

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.widget.Toast

@Suppress("DEPRECATION")
class AssistantCaptureConsentActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val request = try {
            manager.createScreenCaptureIntent()
        } catch (error: Exception) {
            Log.e(TAG, "无法创建系统截屏授权", error)
            cancelCapture("无法打开系统截屏授权")
            return
        }
        startActivityForResult(request, REQUEST_CAPTURE)
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
        finish()
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
