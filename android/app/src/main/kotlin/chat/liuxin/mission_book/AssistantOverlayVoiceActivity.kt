package chat.liuxin.mission_book

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.drawable.GradientDrawable
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/** 用户点麦克风后才可见并录音；普通助手负责选择转写模型。 */
class AssistantOverlayVoiceActivity : Activity() {
    private val ticket = UUID.randomUUID().toString()
    private val recording = AtomicBoolean(false)
    private var recorder: AudioRecord? = null
    private var submitted = false
    private var cancelled = false
    private var finishedVoice = false
    private lateinit var title: TextView
    private lateinit var finishButton: Button
    private val draft get() = intent.getStringExtra(EXTRA_DRAFT)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (draft == null || AssistantWorkspaceHost.generation == null) { finish(); return }
        title = TextView(this).apply {
            text = "麦克风 · 准备中"; textSize = 16f; setTextColor(0xFF282E2A.toInt())
            setPadding(dp(6), dp(6), dp(6), dp(6))
        }
        finishButton = Button(this).apply {
            text = "完成"; isEnabled = false; setOnClickListener { endRecording() }
        }
        val surface = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = GradientDrawable().apply {
                setColor(0xFFF7F8F5.toInt()); cornerRadius = dp(16).toFloat()
            }
            addView(title)
            addView(LinearLayout(this@AssistantOverlayVoiceActivity).apply {
                gravity = Gravity.END
                addView(Button(this@AssistantOverlayVoiceActivity).apply {
                    text = "取消"; setOnClickListener { cancelVoice(); finish() }
                })
                addView(finishButton)
            })
        }
        setContentView(FrameLayout(this).apply {
            addView(surface, FrameLayout.LayoutParams(minOf(dp(320), resources.displayMetrics.widthPixels - dp(24)), -2, Gravity.CENTER))
        })
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) begin()
        else requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) begin()
        else title.text = "麦克风未授权，可使用文字输入"
    }

    private fun begin() {
        if (cancelled || recording.get()) return
        val rate = 16000
        val size = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (size <= 0) { title.text = "设备暂不能录音"; return }
        val audio = try {
            AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, rate,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(4096, size))
        } catch (_: Exception) { title.text = "麦克风不可用"; return }
        try {
            check(audio.state == AudioRecord.STATE_INITIALIZED)
            audio.startRecording()
            check(audio.recordingState == AudioRecord.RECORDSTATE_RECORDING)
        } catch (_: Exception) {
            audio.release()
            title.text = "无法开始录音"
            return
        }
        recorder = audio
        recording.set(true)
        title.text = "正在录音"
        finishButton.isEnabled = true
        Thread {
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(4096)
            var failed = false
            try {
                while (recording.get() && output.size() < LIMIT) {
                    val count = audio.read(buffer, 0, minOf(buffer.size, LIMIT - output.size()))
                    if (count < 0) { failed = recording.get(); break }
                    if (count > 0) output.write(buffer, 0, count)
                }
            } catch (_: Exception) { failed = recording.get() }
            finally {
                recording.set(false)
                runCatching { audio.stop() }
                audio.release()
            }
            runOnUiThread {
                recorder = null
                if (!cancelled && !isDestroyed) {
                    if (failed) { title.text = "录音中断"; finishButton.isEnabled = false }
                    else submit(output.toByteArray())
                }
            }
        }.start()
    }

    private fun endRecording() {
        finishButton.isEnabled = false
        title.text = "正在转写"
        if (recording.getAndSet(false)) runCatching { recorder?.stop() }
    }

    private fun submit(bytes: ByteArray) {
        val key = draft ?: return
        finishButton.isEnabled = false
        if (bytes.size < 3200) { title.text = "录音太短"; return }
        submitted = true
        title.text = "正在转写"
        AssistantWorkspaceHost.call("voice", mapOf("key" to key, "ticket" to ticket, "pcm" to bytes), failure = {
            if (!cancelled && !isDestroyed) title.text = it
        }) { result ->
            if (!cancelled && !isDestroyed) {
                if (result == true) {
                    finishedVoice = true
                    AssistantOverlayService.voiceDone(ticket, key)
                    finish()
                } else title.text = "转写已取消"
            }
        }
    }

    private fun cancelVoice() {
        cancelled = true
        if (recording.getAndSet(false)) runCatching { recorder?.stop() }
        if (submitted && !finishedVoice) {
            AssistantWorkspaceHost.call("cancelVoice", mapOf("ticket" to ticket), failure = {})
        }
    }

    override fun onPause() {
        if (!finishedVoice && (recording.get() || submitted)) {
            cancelVoice()
            finish()
        }
        super.onPause()
    }

    override fun onDestroy() {
        cancelVoice()
        super.onDestroy()
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    companion object {
        /** 悬浮快捷菜单生成的语音票据；录音与转写都按它校验，避免迟到结果写错草稿。 */
        const val EXTRA_TICKET = "assistant_voice_ticket"
        const val EXTRA_DRAFT = "assistant_voice_draft"
        private const val PERMISSION = 7412
        private const val LIMIT = 960000
    }
}
