package chat.liuxin.mission_book

import android.app.Activity
import android.content.Context
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.media.projection.MediaProjectionConfig
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast

@Suppress("DEPRECATION")
class AssistantCaptureConsentActivity : Activity() {
    private val ticket get() = intent.getStringExtra(AssistantScreenCaptureService.EXTRA_TICKET)
    private val watching get() = intent.getBooleanExtra(AssistantScreenCaptureService.EXTRA_WATCH, false)
    private var captureStarted = false
    private var captureCompleted = false
    private var editorVisible = false
    /** 长截图等已经把处理交给截图服务；Activity 退出时不能再当成来源恢复。 */
    private var handoff = false
    private val handler = Handler(Looper.getMainLooper())
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.getStringExtra(AssistantScreenCaptureService.EXTRA_TICKET) != ticket) return
            if (captureCompleted) return
            captureCompleted = true
            clearEditorRequest(ticket)
            returnToPreviousApp()
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        unregisterReceiver(receiver)
        editorBitmap = null
        // 系统回收、异常退出等没有走完正常回传时也要释放投影并恢复截图发起来源；
        // 旋转重建和长截图交接由后续 Activity/截图服务继续处理，不能提前结束票据。
        if (!captureCompleted && !handoff && !isChangingConfigurations && !watching) {
            captureCompleted = true
            // 截图服务可能仍在持有 MediaProjection，先让它结束并释放资源，再恢复悬浮来源。
            sendCaptureAction(AssistantScreenCaptureService.ACTION_CANCEL_CAPTURE, ticket)
            AssistantOverlayService.captureDone(ticket, null, CaptureOutcome.Failed)
        }
        super.onDestroy()
    }

    override fun onBackPressed() {
        if (captureStarted && !captureCompleted) {
            sendCaptureAction(AssistantScreenCaptureService.ACTION_CANCEL_CAPTURE)
            captureCompleted = true
            clearEditorRequest(ticket)
            returnToPreviousApp()
        } else if (!captureCompleted) {
            captureCompleted = true
            AssistantOverlayService.captureDone(ticket, null, CaptureOutcome.Cancelled)
            returnToPreviousApp()
        } else {
            super.onBackPressed()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 授权完成后由服务的截图遮罩接管触摸，底下保留原应用画面。
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE)
        window.attributes = window.attributes.apply { alpha = 0f }
        val filter = IntentFilter(AssistantScreenCaptureService.ACTION_CAPTURE_READY)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
        else registerReceiver(receiver, filter)
        if (intent?.action == ACTION_SHOW_EDITOR) {
            showPendingEditor(intent.getStringExtra(AssistantScreenCaptureService.EXTRA_TICKET))
            return
        }
        if (ticket == null || watching) { finish(); return }
        // 系统重建授权页时由原请求返回，避免再次申请同一投影会话。
        if (savedInstanceState != null) return
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val request = try {
            if (watching && Build.VERSION.SDK_INT >= 34) manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
            else manager.createScreenCaptureIntent()
        } catch (error: Exception) {
            Log.e(TAG, "无法创建系统截屏授权", error)
            cancelCapture("无法打开系统截屏授权", CaptureOutcome.Failed)
            return
        }
        try { startActivityForResult(request, REQUEST_CAPTURE) }
        catch (error: Exception) {
            Log.e(TAG, "无法打开系统截屏授权", error)
            cancelCapture("无法打开系统截屏授权", CaptureOutcome.Failed)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ACTION_SHOW_EDITOR) {
            showPendingEditor(intent.getStringExtra(AssistantScreenCaptureService.EXTRA_TICKET))
        }
    }

    private fun showPendingEditor(requestedTicket: String?) {
        if (editorVisible) return
        val request = synchronized(editorLock) {
            editorRequest?.takeIf { it.ticket == requestedTicket }
        } ?: run {
            Log.e(TAG, "截图编辑页没有对应的帧，ticket=$requestedTicket")
            // 没有可编辑的帧时结束票据，让截图服务释放投影并恢复悬浮来源。
            sendCaptureAction(AssistantScreenCaptureService.ACTION_CANCEL_CAPTURE, requestedTicket)
            captureCompleted = true
            AssistantOverlayService.captureDone(requestedTicket, null, CaptureOutcome.Failed)
            finish()
            return
        }
        editorBitmap = request.bitmap
        captureStarted = true
        editorVisible = true
        window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE)
        window.attributes = window.attributes.apply { alpha = 1f }
        window.decorView.setBackgroundColor(android.graphics.Color.BLACK)
        setContentView(CaptureEditorView(
            this,
            request.bitmap,
            onConfirm = { submitSelection(request.ticket, it, scrolling = false) },
            onLongCapture = {
                submitSelection(request.ticket, it, scrolling = true)
                // 截图源应用要恢复到前台继续滚动；选区和首帧已交给服务保留。
                finish()
            },
            onCancel = {
                sendCaptureAction(AssistantScreenCaptureService.ACTION_CANCEL_CAPTURE, request.ticket)
                clearEditorRequest(request.ticket)
            },
        ))
    }

    private fun submitSelection(ticket: String, region: Rect, scrolling: Boolean) {
        captureStarted = true
        handoff = true
        clearEditorRequest(ticket)
        window.decorView.setBackgroundColor(AssistantNativeTheme.mediaBackground)
        setContentView(android.widget.TextView(this).apply {
            text = if (scrolling) "长截图准备中…" else "正在处理截图…"
            setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, AssistantNativeTheme.textTitle)
            gravity = android.view.Gravity.CENTER
            setTextColor(AssistantNativeTheme.textPrimary)
            setBackgroundColor(AssistantNativeTheme.pageBackground)
            setPadding(AssistantNativeTheme.dp(this@AssistantCaptureConsentActivity, AssistantNativeTheme.spaceLg), 0,
                AssistantNativeTheme.dp(this@AssistantCaptureConsentActivity, AssistantNativeTheme.spaceLg), 0)
        })
        val action = Intent(this, AssistantScreenCaptureService::class.java)
            .setAction(AssistantScreenCaptureService.ACTION_CONFIRM_SELECTION)
            .putExtra(AssistantScreenCaptureService.EXTRA_TICKET, ticket)
            .putExtra(AssistantScreenCaptureService.EXTRA_SCROLLING, scrolling)
            .putExtra(AssistantScreenCaptureService.EXTRA_REGION, region)
        try { startService(action) }
        catch (error: Exception) {
            Log.e(TAG, "提交截图选区失败", error)
            captureCompleted = true
            AssistantOverlayService.captureDone(ticket, null, CaptureOutcome.Failed)
            finish()
        }
    }

    private fun sendCaptureAction(action: String, captureTicket: String? = ticket) {
        try {
            startService(Intent(this, AssistantScreenCaptureService::class.java)
                .setAction(action)
                .putExtra(AssistantScreenCaptureService.EXTRA_TICKET, captureTicket))
        } catch (error: Exception) {
            Log.w(TAG, "提交截图操作失败：$action", error)
            captureCompleted = true
            AssistantOverlayService.captureDone(captureTicket, null, CaptureOutcome.Failed)
        }
    }

    private fun clearEditorRequest(ticket: String?) {
        synchronized(editorLock) {
            if (editorRequest?.ticket == ticket) editorRequest = null
        }
    }

    private fun returnToPreviousApp() {
        // 截图结果由悬浮服务交给当前草稿；这里只关闭授权/编辑 Activity，
        // 让 Android 返回截图前的应用，避免强制把 MissionBook AI 页面置前。
        finish()
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        Log.d(TAG, "MediaProjection returned request=$requestCode result=$resultCode hasData=${data != null}")
        if (requestCode != REQUEST_CAPTURE) {
            cancelCapture(null, CaptureOutcome.Cancelled)
            return
        }
        if (resultCode != RESULT_OK || data == null) {
            cancelCapture("已取消截屏授权", CaptureOutcome.ConsentDenied)
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
            cancelCapture("截屏服务启动失败", CaptureOutcome.Failed)
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

    private fun cancelCapture(reason: String?, outcome: CaptureOutcome = CaptureOutcome.Cancelled) {
        captureCompleted = true
        AssistantOverlayService.captureDone(ticket, null, outcome)
        reason?.let { Toast.makeText(this, it, Toast.LENGTH_SHORT).show() }
        returnToPreviousApp()
    }


    companion object {
        private data class EditorRequest(val ticket: String, val bitmap: Bitmap)
        private val editorLock = Any()
        @Volatile private var editorRequest: EditorRequest? = null
        @Volatile private var editorBitmap: Bitmap? = null
        const val ACTION_SHOW_EDITOR = "chat.liuxin.mission_book.SHOW_CAPTURE_EDITOR"
        private const val REQUEST_CAPTURE = 7404
        private const val TAG = "AssistantCapture"

        internal fun presentEditor(context: Context, ticket: String, bitmap: Bitmap) {
            synchronized(editorLock) {
                editorRequest?.bitmap?.takeIf { it !== bitmap && !it.isRecycled }?.recycle()
                editorRequest = EditorRequest(ticket, bitmap)
            }
            val intent = Intent(context, AssistantCaptureConsentActivity::class.java)
                .setAction(ACTION_SHOW_EDITOR)
                .putExtra(AssistantScreenCaptureService.EXTRA_TICKET, ticket)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            try { context.startActivity(intent) }
            catch (error: Exception) {
                synchronized(editorLock) { if (editorRequest?.ticket == ticket) editorRequest = null }
                Log.e(TAG, "无法显示截图编辑页", error)
                cancelServiceCapture(context, ticket)
                AssistantOverlayService.captureDone(ticket, null, CaptureOutcome.Failed)
            }
        }

        /** 编辑页无法显示时让截图服务结束票据并释放投影，避免后台继续持有画面。 */
        private fun cancelServiceCapture(context: Context, ticket: String) {
            runCatching {
                context.startService(Intent(context, AssistantScreenCaptureService::class.java)
                    .setAction(AssistantScreenCaptureService.ACTION_CANCEL_CAPTURE)
                    .putExtra(AssistantScreenCaptureService.EXTRA_TICKET, ticket))
            }
        }
    }
}
