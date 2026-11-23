package chat.liuxin.mission_book

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.window.OnBackInvokedDispatcher
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

// ---------------------------------------------------------------------------
// 常量：录音上限、通行协议
// ---------------------------------------------------------------------------

/** 录音上限 30 秒；到点自动停止并转写，界面按真实毫秒计时，不显示百分比。 */
internal const val MAX_VOICE_MILLIS = 30_000L
internal const val MAX_VOICE_SECONDS = 30

/** 16 kHz 单声道 PCM16：30 秒 ≈ 960000 字节，与 Dart 契约的上下限一致。 */
internal const val VOICE_SAMPLE_RATE = 16_000
internal const val MAX_VOICE_PCM_BYTES = 960_000
internal const val MIN_VOICE_PCM_BYTES = 3_200

/** 计时刷新间隔；只影响计时文本与进度条，不暗示识别进度。 */
private const val TIMER_TICK_MILLIS = 250L

/** 等待 Dart 回复的本地看门狗：只防止通道回调丢失后界面永久停留。 */
private const val BEGIN_TIMEOUT_MILLIS = 30_000L
private const val VOICE_TIMEOUT_MILLIS = 120_000L

/**
 * 原生「打开语音设置」交给 MainActivity 的一次性路由常量。
 *
 * 契约冻结值，A/D 只引用 [AssistantOverlayVoiceActivity.EXTRA_ASSISTANT_ROUTE] 与
 * [AssistantOverlayVoiceActivity.ROUTE_VOICE_SETTINGS]，不得各自复制字符串。
 */
internal object AssistantVoiceRoute {
    const val EXTRA = "assistant_route"
    const val VOICE_SETTINGS = "voiceSettings"
}

// ---------------------------------------------------------------------------
// 纯状态模型：界面只按这里渲染，JVM 单测只测这里
// ---------------------------------------------------------------------------

/** 一次语音输入的阶段。任意时刻只有一个，界面与按钮都由它派生。 */
internal enum class VoicePhase {
    /** 已发出 beginVoice，等待 Dart 准备识别后端（不确定进度）。 */
    PREPARING,

    /** ready=true：已绑定草稿与识别方式，等待麦克风授权后录音。 */
    PERMISSION,
    RECORDING,
    TRANSCRIBING,

    /** 转写成功，Activity 正在关闭。 */
    SUCCEEDED,

    /** 用户取消或上层关闭，迟到结果一律丢弃。 */
    CANCELLED,
    FAILED,
}

/** 识别方式只由 Dart 决定；原生只展示名称，不判断模型或凭据。 */
internal enum class VoiceMode(val wire: String) {
    OFFLINE("offline"),
    REMOTE("remote"),
    ;

    companion object {
        /** 只认契约里的两个 wire 值；未知（含通道层失败）按离线名称兜底。 */
        fun fromWire(value: String?): VoiceMode = entries.firstOrNull { it.wire == value } ?: OFFLINE
    }
}

/** 失败类别，只影响说明文字，不改变按钮映射。 */
internal enum class VoiceFailureKind { PREPARE, PERMISSION, TRANSCRIBE, DEVICE }

/** 由原生直显的中文原因；Dart 已给 message 时优先用 message。 */
internal enum class VoiceText {
    PREPARE_TIMEOUT,
    TRANSCRIBE_TIMEOUT,
    MIC_UNAVAILABLE,
    RECORDER_FAILED,
    RECORDING_INTERRUPTED,
    RECORDING_TOO_SHORT,
    PERMISSION_DENIED,
    PERMISSION_BLOCKED,
    RECREATED_RECORDING,
    RECREATED_TRANSCRIBING,
    PAUSED_PREPARE,
    TRANSCRIBE_CANCELLED,
    GENERIC,
}

/** 面板动作；顺序即主次层级，第一个是主行动作。 */
internal enum class VoiceAction {
    FINISH_RECORDING,
    GRANT_PERMISSION,
    RETRY,
    RETRY_TRANSCRIPTION,
    RECORD_AGAIN,
    USE_TEXT,
    OPEN_VOICE_SETTINGS,
    OPEN_APP_SETTINGS,
}

/** 面板右上角的终结按钮：工作进行中是「取消」，失败时是「关闭」。 */
internal enum class VoiceHeader { CANCEL, CLOSE }

internal data class VoiceFailure(
    val code: String,
    /** Dart 给出的中文可展示原因，原生直接显示；为 null 时用 [text]。 */
    val message: String?,
    val text: VoiceText?,
    val kind: VoiceFailureKind,
    val actions: List<VoiceAction>,
    /** voice 返回 cancelled：静默关闭，不显示错误。 */
    val silent: Boolean = false,
) {
    /** 主行动作；界面用森林绿实心按钮，其余按顺序作为次要动作。 */
    val primary: VoiceAction? get() = actions.firstOrNull()
}

/** 冻结契约的错误码 → 动作映射；未知码按可重试处理，不吞掉用户路径。 */
internal object VoiceFailures {
    const val PERMISSION_DENIED = "permissionDenied"
    const val PERMISSION_BLOCKED = "permissionBlocked"
    const val TIMEOUT = "timeout"

    fun begin(code: String?, message: String?, text: VoiceText? = null): VoiceFailure {
        val actions = when (code) {
            "offlineModelMissing", "offlineModelInvalid" ->
                listOf(VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.USE_TEXT)
            "offlineModelInitFailed" ->
                listOf(VoiceAction.RETRY, VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.USE_TEXT)
            "remoteConfigMissing", "remoteConfigInvalid" ->
                listOf(VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.USE_TEXT)
            else -> listOf(VoiceAction.RETRY, VoiceAction.USE_TEXT)
        }
        return VoiceFailure(code.orEmpty(), message, text, VoiceFailureKind.PREPARE, actions)
    }

    /** 拒绝与永久拒绝给不同文案和不同权限入口。 */
    fun permission(blocked: Boolean): VoiceFailure = VoiceFailure(
        code = if (blocked) PERMISSION_BLOCKED else PERMISSION_DENIED,
        message = null,
        text = if (blocked) VoiceText.PERMISSION_BLOCKED else VoiceText.PERMISSION_DENIED,
        kind = VoiceFailureKind.PERMISSION,
        actions = if (blocked) {
            // 永久拒绝：先去系统设置开启，回来还能就地重新授权。
            listOf(VoiceAction.OPEN_APP_SETTINGS, VoiceAction.GRANT_PERMISSION, VoiceAction.USE_TEXT)
        } else {
            listOf(VoiceAction.GRANT_PERMISSION, VoiceAction.USE_TEXT)
        },
    )

    fun transcribe(code: String?, message: String?, text: VoiceText? = null): VoiceFailure {
        val actions = when (code) {
            "noSpeech", "emptyAudio", "ticketInvalid", "draftChanged" ->
                listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT)
            "remoteAuthFailed" ->
                listOf(VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.RETRY_TRANSCRIPTION, VoiceAction.USE_TEXT)
            "cancelled" -> emptyList()
            else -> listOf(
                VoiceAction.RETRY_TRANSCRIPTION,
                VoiceAction.RECORD_AGAIN,
                VoiceAction.USE_TEXT,
            )
        }
        return VoiceFailure(
            code = code.orEmpty(),
            message = message,
            text = text,
            kind = VoiceFailureKind.TRANSCRIBE,
            actions = actions,
            silent = code == "cancelled",
        )
    }

    /** 麦克风/设备问题：可整体重试，或改用文字。 */
    fun device(text: VoiceText): VoiceFailure = VoiceFailure(
        code = "",
        message = null,
        text = text,
        kind = VoiceFailureKind.DEVICE,
        actions = listOf(VoiceAction.RETRY, VoiceAction.USE_TEXT),
    )

    /** 录音太短或没有内容：只能重录，不能把空音频再提交一次。 */
    fun unusableAudio(text: VoiceText): VoiceFailure = VoiceFailure(
        code = "emptyAudio",
        message = null,
        text = text,
        kind = VoiceFailureKind.DEVICE,
        actions = listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
    )

    /** 界面重建导致本次录音/转写中断；不伪造成功，也不写部分结果。 */
    fun interrupted(text: VoiceText): VoiceFailure = VoiceFailure(
        code = "",
        message = null,
        text = text,
        kind = VoiceFailureKind.DEVICE,
        actions = listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
    )

    /** 准备/授权阶段被切到后台：票据已作废，回来只能重试或改用文字。 */
    fun paused(text: VoiceText): VoiceFailure = VoiceFailure(
        code = "",
        message = null,
        text = text,
        kind = VoiceFailureKind.DEVICE,
        actions = listOf(VoiceAction.RETRY, VoiceAction.USE_TEXT),
    )

    /** 按保存的类别重建失败状态，让 Activity 重建后仍显示同一原因和同一组动作。 */
    fun restore(
        kind: VoiceFailureKind,
        code: String?,
        message: String?,
        text: VoiceText?,
    ): VoiceFailure = when (kind) {
        VoiceFailureKind.PREPARE -> begin(code, message, text)
        VoiceFailureKind.PERMISSION -> permission(blocked = code == PERMISSION_BLOCKED)
        VoiceFailureKind.TRANSCRIBE -> transcribe(code, message, text).let { failure ->
            // 重建后内存里的 PCM 已释放，「重试转写」不可用，只保留重录/设置/文字入口。
            val actions = failure.actions.filter { it != VoiceAction.RETRY_TRANSCRIPTION }
            failure.copy(actions = actions.ifEmpty { listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT) })
        }
        VoiceFailureKind.DEVICE -> when {
            code == "emptyAudio" -> unusableAudio(text ?: VoiceText.RECORDING_TOO_SHORT)
            text == VoiceText.RECORDING_INTERRUPTED ||
                text == VoiceText.RECREATED_RECORDING ||
                text == VoiceText.RECREATED_TRANSCRIBING -> interrupted(text)
            else -> paused(text ?: VoiceText.PAUSED_PREPARE)
        }
    }
}

/**
 * 语音面板的唯一状态。
 *
 * 所有迁移都带阶段与票据守卫：重复点击、旧票据的迟到回调、取消后的迟到成功都不会改变状态。
 * 这里不碰 Android 类，可直接被 JVM 单测覆盖。
 */
internal data class VoiceUiState(
    val ticket: String,
    val phase: VoicePhase = VoicePhase.PREPARING,
    val mode: VoiceMode = VoiceMode.OFFLINE,
    /** Dart 是否已明确本轮识别方式；通道层失败时不能凭空显示「离线语音」。 */
    val modeKnown: Boolean = false,
    /** beginVoice 返回的识别方式名称（「离线语音」/「录音转写服务」）。 */
    val label: String? = null,
    /** beginVoice 绑定的草稿；成功时以它通知悬浮服务。 */
    val draftKey: String? = null,
    val failure: VoiceFailure? = null,
    val elapsedMillis: Long = 0L,
    /** 本次票据是否已提交过 voice；相同票据第二次提交直接拒绝。 */
    val submitted: Boolean = false,
    /** 失败后再次 beginVoice 时，准备完成后直接复用上次 PCM 重试转写。 */
    val retryPcm: Boolean = false,
    val limitReached: Boolean = false,
) {
    val remainingMillis: Long get() = (MAX_VOICE_MILLIS - elapsedMillis).coerceAtLeast(0L)
    val elapsedSeconds: Int get() = (elapsedMillis / 1000L).toInt()

    /** 重新准备：新票据，清掉旧失败与旧草稿；重试 PCM 只在用户选择「重试转写」时为 true。 */
    fun startPreparing(ticket: String, retryPcm: Boolean = false): VoiceUiState = copy(
        ticket = ticket,
        phase = VoicePhase.PREPARING,
        modeKnown = if (retryPcm) modeKnown else false,
        label = if (retryPcm) label else null,
        draftKey = if (retryPcm) draftKey else null,
        failure = null,
        elapsedMillis = 0L,
        submitted = false,
        retryPcm = retryPcm,
        limitReached = false,
    )

    /** ready=true 才允许进入授权/录音；旧票据的迟到结果按 ticket 丢弃。 */
    fun beginReady(replyTicket: String, mode: VoiceMode, label: String?, draftKey: String): VoiceUiState =
        if (phase != VoicePhase.PREPARING || replyTicket != ticket) {
            this
        } else {
            copy(
                phase = VoicePhase.PERMISSION,
                mode = mode,
                modeKnown = true,
                label = label,
                draftKey = draftKey,
                failure = null,
            )
        }

    fun beginFailed(
        replyTicket: String,
        code: String?,
        message: String?,
        text: VoiceText? = null,
        mode: VoiceMode? = null,
    ): VoiceUiState = if (phase != VoicePhase.PREPARING || replyTicket != ticket) {
        this
    } else {
        copy(
            phase = VoicePhase.FAILED,
            // 失败响应也带 mode：失败页不能把远程配置错误显示成离线语音。
            mode = mode ?: this.mode,
            modeKnown = mode != null || this.modeKnown,
            failure = VoiceFailures.begin(code, message, text),
        )
    }

    /** ready=false 绝不申请麦克风，所以这里只从 PERMISSION 进入。 */
    fun beginRecording(): VoiceUiState =
        if (phase != VoicePhase.PERMISSION) this
        else copy(phase = VoicePhase.RECORDING, elapsedMillis = 0L, failure = null, limitReached = false)

    fun tick(elapsedMillis: Long): VoiceUiState {
        if (phase != VoicePhase.RECORDING) return this
        val capped = elapsedMillis.coerceIn(0L, MAX_VOICE_MILLIS)
        return copy(elapsedMillis = capped, limitReached = capped >= MAX_VOICE_MILLIS)
    }

    /** 结束录音进入转写；重复点击（已经是 TRANSCRIBING）被忽略。 */
    fun startTranscribing(): VoiceUiState = when {
        phase == VoicePhase.RECORDING -> copy(phase = VoicePhase.TRANSCRIBING, submitted = false, failure = null)
        // 重试现有 PCM：准备完成后不再录音，直接提交。
        phase == VoicePhase.PERMISSION && retryPcm ->
            copy(phase = VoicePhase.TRANSCRIBING, submitted = false, failure = null)
        else -> this
    }

    /** 同一票据只允许提交一次 voice；第二次点击返回原状态。 */
    fun markSubmitted(): VoiceUiState =
        if (phase != VoicePhase.TRANSCRIBING || submitted) this else copy(submitted = true)

    fun transcribeSucceeded(draftKey: String?): VoiceUiState =
        if (phase != VoicePhase.TRANSCRIBING) this
        else copy(
            phase = VoicePhase.SUCCEEDED,
            draftKey = draftKey?.takeIf { it.isNotBlank() } ?: this.draftKey,
            failure = null,
        )

    fun transcribeFailed(code: String?, message: String?, text: VoiceText? = null): VoiceUiState =
        if (phase != VoicePhase.TRANSCRIBING) this
        else copy(
            phase = VoicePhase.FAILED,
            failure = VoiceFailures.transcribe(code, message, text),
            submitted = false,
        )

    fun permissionDenied(blocked: Boolean): VoiceUiState =
        if (phase != VoicePhase.PERMISSION) this
        else copy(phase = VoicePhase.FAILED, failure = VoiceFailures.permission(blocked))

    fun deviceFailed(text: VoiceText): VoiceUiState =
        if (phase != VoicePhase.RECORDING && phase != VoicePhase.PERMISSION) this
        else copy(phase = VoicePhase.FAILED, failure = VoiceFailures.device(text), submitted = false)

    fun audioUnusable(text: VoiceText): VoiceUiState =
        if (phase != VoicePhase.RECORDING && phase != VoicePhase.TRANSCRIBING) this
        else copy(phase = VoicePhase.FAILED, failure = VoiceFailures.unusableAudio(text), submitted = false)

    /** 界面重建时展示中断原因；不恢复录音，也不写部分结果。 */
    fun interrupted(text: VoiceText, elapsedMillis: Long = 0L): VoiceUiState = copy(
        phase = VoicePhase.FAILED,
        failure = VoiceFailures.interrupted(text),
        elapsedMillis = elapsedMillis.coerceIn(0L, MAX_VOICE_MILLIS),
        submitted = false,
    )

    /** 准备/授权阶段离开前台：作废本轮，回来后可重试。 */
    fun pausedForBackground(text: VoiceText): VoiceUiState = copy(
        phase = VoicePhase.FAILED,
        failure = VoiceFailures.paused(text),
        submitted = false,
    )

    /** Activity 重建后按保存的字段还原失败页，不重启录音，也不丢已录时长。 */
    fun restoreFailure(
        elapsedMillis: Long,
        mode: VoiceMode,
        label: String?,
        draftKey: String?,
        kind: VoiceFailureKind,
        code: String?,
        message: String?,
        text: VoiceText?,
    ): VoiceUiState = copy(
        phase = VoicePhase.FAILED,
        mode = mode,
        modeKnown = true,
        label = label,
        draftKey = draftKey,
        elapsedMillis = elapsedMillis.coerceIn(0L, MAX_VOICE_MILLIS),
        failure = VoiceFailures.restore(kind, code, message, text),
        submitted = false,
        retryPcm = false,
    )

    /** 取消是终态：成功之后不再降级为取消，迟到结果也不会覆盖它。 */
    fun cancel(): VoiceUiState =
        if (phase == VoicePhase.SUCCEEDED) this else copy(phase = VoicePhase.CANCELLED, failure = null)
}

/** 每阶段可见的动作：第一个是主行动作。 */
internal object VoiceActions {
    fun forState(state: VoiceUiState): List<VoiceAction> = when (state.phase) {
        VoicePhase.PREPARING, VoicePhase.TRANSCRIBING, VoicePhase.SUCCEEDED, VoicePhase.CANCELLED -> emptyList()
        VoicePhase.PERMISSION -> listOf(VoiceAction.GRANT_PERMISSION, VoiceAction.USE_TEXT)
        VoicePhase.RECORDING -> listOf(VoiceAction.FINISH_RECORDING)
        VoicePhase.FAILED -> state.failure?.actions.orEmpty()
    }

    fun header(state: VoiceUiState): VoiceHeader =
        if (state.phase == VoicePhase.FAILED) VoiceHeader.CLOSE else VoiceHeader.CANCEL
}

/** Activity 重建后的恢复策略：能安全重来的重新准备，否则如实显示中断。 */
internal object VoiceRestore {
    enum class Decision { PREPARE, INTERRUPTED_RECORDING, INTERRUPTED_TRANSCRIBING }

    fun decide(savedPhase: String?): Decision = when (savedPhase) {
        VoicePhase.RECORDING.name -> Decision.INTERRUPTED_RECORDING
        VoicePhase.TRANSCRIBING.name -> Decision.INTERRUPTED_TRANSCRIBING
        else -> Decision.PREPARE
    }
}

/**
 * 面板宽度：两侧留 [SIDE_MARGIN_DP]，最多 [MAX_CARD_DP]。
 *
 * 320dp 窄屏得到约 288dp 卡片；大屏/横屏不无限拉宽，双倍字号靠可滚动高度承载。
 */
internal object VoicePanelMetrics {
    const val SIDE_MARGIN_DP = 16
    const val MAX_CARD_DP = 480

    fun cardWidthPx(windowWidthPx: Int, density: Float): Int {
        if (windowWidthPx <= 0 || density <= 0f) return 0
        val margins = (2 * SIDE_MARGIN_DP * density + .5f).toInt()
        val maxPx = (MAX_CARD_DP * density + .5f).toInt()
        return (windowWidthPx - margins).coerceAtMost(maxPx).coerceAtLeast(0)
    }
}

// ---------------------------------------------------------------------------
// Activity：状态渲染、权限、录音线程、生命周期
// ---------------------------------------------------------------------------

/**
 * 用户点按语音后出现：先 beginVoice 准备识别后端，ready=true 才申请麦克风并录音。
 *
 * 识别后端、模型与凭据都归 Dart；这里只做麦克风采集、计时、状态展示和票据转发，
 * 不把 AudioRecord 当成语音识别 API，也不在原生判断模型目录。
 */
class AssistantOverlayVoiceActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private val audio = AtomicReference<AudioRecord?>(null)
    private val recordingFlag = AtomicBoolean(false)
    private val stopRequested = AtomicBoolean(false)

    private var state = VoiceUiState(ticket = "")
    private var pcm: ByteArray? = null
    private var startedAtMillis = 0L
    private var lastShownSecond = -1
    private var destroyed = false
    private var completed = false
    private var permissionRequestInFlight = false
    private var autoStartRecording = true
    /**
     * 整个面板会话复用同一个票据：悬浮服务只认它自己发出的 ticket，
     * 面板内重试也必须沿用它，成功时 [AssistantOverlayService.voiceDone] 才能回到原草稿。
     */
    private var sessionTicket = ""
    /** 面板内的第几轮（重试会加一）；用来丢弃上一轮的迟到回调。 */
    private var roundId = 0
    /** 已发过 cancelVoice 的轮次；同一轮只终结一次，换轮后仍可终结同一票据。 */
    private var cancelledRound = -1
    private var watchdog: Runnable? = null
    private var lastActionSignature: String? = null

    private lateinit var root: View
    private lateinit var shell: LinearLayout
    private lateinit var card: LinearLayout
    private lateinit var title: TextView
    private lateinit var close: Button
    private lateinit var statusRow: LinearLayout
    private lateinit var spinner: ProgressBar
    private lateinit var status: TextView
    private lateinit var elapsed: TextView
    private lateinit var progress: ProgressBar
    private lateinit var mode: TextView
    private lateinit var detail: TextView
    private lateinit var actions: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        configureSoftInput()
        setContentView(R.layout.assistant_voice_panel)
        bindViews()
        applyTheme()
        applySpacing()
        applyInsets()
        registerBackHandler()
        animateIn()

        sessionTicket = savedTicket(savedInstanceState)
        state = VoiceUiState(ticket = sessionTicket)
        when (VoiceRestore.decide(savedInstanceState?.getString(KEY_PHASE))) {
            VoiceRestore.Decision.INTERRUPTED_RECORDING -> state = state.interrupted(
                VoiceText.RECREATED_RECORDING,
                savedInstanceState?.getLong(KEY_ELAPSED, 0L) ?: 0L,
            )
            VoiceRestore.Decision.INTERRUPTED_TRANSCRIBING -> state = state.interrupted(
                VoiceText.RECREATED_TRANSCRIBING,
                savedInstanceState?.getLong(KEY_ELAPSED, 0L) ?: 0L,
            )
            VoiceRestore.Decision.PREPARE -> restoreOrPrepare(savedInstanceState)
        }
        render()
    }

    /**
     * 重建后不擅自重开麦克风：能安全重来的一律重新准备，但要由用户点「允许录音」；
     * 只有首次进入才在授权后直接开始录音。
     */
    private fun restoreOrPrepare(saved: Bundle?) {
        val savedPhase = saved?.getString(KEY_PHASE)
        val elapsed = saved?.getLong(KEY_ELAPSED, 0L) ?: 0L
        val mode = runCatching { VoiceMode.valueOf(saved?.getString(KEY_MODE) ?: VoiceMode.OFFLINE.name) }
            .getOrDefault(VoiceMode.OFFLINE)
        val label = saved?.getString(KEY_LABEL)
        val draftKey = saved?.getString(KEY_DRAFT)
        val kindName = saved?.getString(KEY_FAILURE_KIND)
        val kind = kindName?.let { runCatching { VoiceFailureKind.valueOf(it) }.getOrNull() }
        val code = saved?.getString(KEY_FAILURE_CODE)
        val message = saved?.getString(KEY_FAILURE_MESSAGE)
        val text = saved?.getString(KEY_FAILURE_TEXT)?.let { runCatching { VoiceText.valueOf(it) }.getOrNull() }
        if (savedPhase == VoicePhase.FAILED.name && (kind != null || !message.isNullOrBlank() || text != null)) {
            // 重建后仍显示同一失败原因与动作（例如模型缺失、权限被拒、后台中断）。
            state = state.restoreFailure(elapsed, mode, label, draftKey, kind ?: VoiceFailureKind.DEVICE, code, message, text)
            return
        }
        startPreparation(autoStart = saved == null)
    }

    /**
     * 本面板没有输入框，但窗口仍按 adjustResize 配置：旧版本系统靠它避让键盘，
     * Android 11+ 则由 [applyInsets] 的 ime inset 处理。
     */
    @Suppress("DEPRECATION")
    private fun configureSoftInput() {
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
                WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN,
        )
    }

    // -- 视图 ---------------------------------------------------------------

    private fun bindViews() {
        root = findViewById(R.id.assistant_voice_root)
        shell = findViewById(R.id.assistant_voice_shell)
        card = findViewById(R.id.assistant_voice_card)
        title = findViewById(R.id.assistant_voice_title)
        close = findViewById(R.id.assistant_voice_close)
        statusRow = findViewById(R.id.assistant_voice_status_row)
        spinner = findViewById(R.id.assistant_voice_progress_spinner)
        status = findViewById(R.id.assistant_voice_status)
        elapsed = findViewById(R.id.assistant_voice_elapsed)
        progress = findViewById(R.id.assistant_voice_progress)
        mode = findViewById(R.id.assistant_voice_mode)
        detail = findViewById(R.id.assistant_voice_detail)
        actions = findViewById(R.id.assistant_voice_actions)
    }

    /** 颜色、字号、圆角全部取 [AssistantNativeTheme]，资源文件里不再放第二套色值。 */
    private fun applyTheme() {
        // 面板沿用 App 页面的暖白基调（pageBackground），主行动作用森林绿；
        // 白色 cardSurface 留给悬浮聊天等其他表面，避免同屏两套底色。
        card.background = AssistantNativeTheme.surface(
            this,
            AssistantNativeTheme.pageBackground,
            AssistantNativeTheme.radiusXl,
            AssistantNativeTheme.hairline,
            1f,
        )
        card.elevation = AssistantNativeTheme.dpFloat(this, AssistantNativeTheme.spaceSm)
        AssistantNativeTheme.text(title, AssistantNativeTheme.textTitle, AssistantNativeTheme.textPrimary, bold = true)
        AssistantNativeTheme.text(status, AssistantNativeTheme.textBody, AssistantNativeTheme.textPrimary, bold = true)
        AssistantNativeTheme.text(elapsed, AssistantNativeTheme.textTitle, AssistantNativeTheme.primary, bold = true)
        AssistantNativeTheme.text(mode, AssistantNativeTheme.textMetadata, AssistantNativeTheme.textSecondary)
        AssistantNativeTheme.text(detail, AssistantNativeTheme.textBody, AssistantNativeTheme.textSecondary)
        status.accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        // 不确定进度与计时条只是视觉反馈，语义由状态文字与计时的 contentDescription 承担。
        spinner.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        progress.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        spinner.indeterminateTintList = ColorStateList.valueOf(AssistantNativeTheme.primary)
        progress.progressTintList = ColorStateList.valueOf(AssistantNativeTheme.primary)
        progress.progressBackgroundTintList = ColorStateList.valueOf(AssistantNativeTheme.hairline)
        progress.max = MAX_VOICE_MILLIS.toInt()
        close.setOnClickListener { cancelAndFinish() }
        if (Build.VERSION.SDK_INT >= 28) title.isAccessibilityHeading = true
    }

    /** 间距、触控尺寸、进度条粗细也由 token 换算，避免 XML 与主题各写一套。 */
    private fun applySpacing() {
        card.setPadding(
            AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceXl),
            AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceLg),
            AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceXl),
            AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceLg),
        )
        shell.setPadding(
            AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceLg),
            AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceLg),
            AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceLg),
            AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceLg),
        )
        marginStart(title, AssistantNativeTheme.spaceSm)
        marginTop(statusRow, AssistantNativeTheme.spaceMd)
        marginEnd(spinner, AssistantNativeTheme.spaceSm)
        marginTop(elapsed, AssistantNativeTheme.spaceSm)
        marginTop(progress, AssistantNativeTheme.spaceSm)
        marginTop(mode, AssistantNativeTheme.spaceXs)
        marginTop(detail, AssistantNativeTheme.spaceSm)
        marginTop(actions, AssistantNativeTheme.spaceMd)
        progress.layoutParams = progress.layoutParams.also {
            it.height = AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceSm)
        }
        spinner.layoutParams = spinner.layoutParams.also {
            it.width = AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceXl)
            it.height = AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceXl)
        }
        close.minimumHeight = AssistantNativeTheme.dp(this, AssistantNativeTheme.minTouchDp)
        close.minimumWidth = AssistantNativeTheme.dp(this, AssistantNativeTheme.minTouchDp)
        AssistantNativeTheme.text(close, AssistantNativeTheme.textBody, AssistantNativeTheme.textSecondary, bold = true)
        close.background = AssistantNativeTheme.clickableSurface(
            this,
            Color.TRANSPARENT,
            AssistantNativeTheme.radiusSm,
            AssistantNativeTheme.ripple,
        )
    }

    /**
     * 刘海、系统栏与键盘：Android 11+ 显式关闭 decor 自适应后由 insets 补 padding；
     * 低版本沿用窗口自身避让，只保证 adjustResize 不被遮挡。
     */
    @Suppress("DEPRECATION") // Android 15 起强制 edge-to-edge；这里仍显式关闭 decor 自适应并自绘 insets。
    private fun applyInsets() {
        if (Build.VERSION.SDK_INT < 30) {
            applyCardWidth()
            return
        }
        window.setDecorFitsSystemWindows(false)
        applyCardWidth()
        window.insetsController?.setSystemBarsAppearance(
            0,
            WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
        )
        root.setOnApplyWindowInsetsListener { view, insets ->
            val bars = insets.getInsets(
                WindowInsets.Type.systemBars() or
                    WindowInsets.Type.displayCutout() or
                    WindowInsets.Type.ime(),
            )
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            applyCardWidth()
            insets
        }
    }

    /**
     * Android 13+ 注册返回回调；Android 16（targetSdk 36）默认启用预测性返回后
     * 不再调用 `onBackPressed`，两种入口都指向同一个取消关闭路径。
     */
    private fun registerBackHandler() {
        if (Build.VERSION.SDK_INT < 33) return
        onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_DEFAULT,
        ) { cancelAndFinish() }
    }

    private fun applyCardWidth() {
        val params = card.layoutParams as? LinearLayout.LayoutParams ?: return
        val available = resources.displayMetrics.widthPixels - root.paddingLeft - root.paddingRight
        val width = VoicePanelMetrics.cardWidthPx(available, resources.displayMetrics.density)
        if (width <= 0 || params.width == width) return
        params.width = width
        params.gravity = Gravity.CENTER_HORIZONTAL
        card.layoutParams = params
    }

    /** 入场动画跟随「减少动效」偏好；偏好为 reduced 时直接显示。 */
    private fun animateIn() {
        val duration = AssistantNativeTheme.motionDuration(this)
        if (duration <= 0L) return
        card.alpha = 0f
        card.translationY = AssistantNativeTheme.dpFloat(this, AssistantNativeTheme.spaceSm)
        card.animate().alpha(1f).translationY(0f).setDuration(duration).start()
    }

    private fun marginTop(view: View, dp: Int) {
        val params = view.layoutParams as? ViewGroup.MarginLayoutParams ?: return
        params.topMargin = AssistantNativeTheme.dp(this, dp)
        view.layoutParams = params
    }

    private fun marginStart(view: View, dp: Int) {
        val params = view.layoutParams as? ViewGroup.MarginLayoutParams ?: return
        params.marginStart = AssistantNativeTheme.dp(this, dp)
        view.layoutParams = params
    }

    private fun marginEnd(view: View, dp: Int) {
        val params = view.layoutParams as? ViewGroup.MarginLayoutParams ?: return
        params.marginEnd = AssistantNativeTheme.dp(this, dp)
        view.layoutParams = params
    }

    // -- 渲染 ---------------------------------------------------------------

    private fun render() {
        if (destroyed) return
        val current = state
        if (current.phase == VoicePhase.SUCCEEDED || current.phase == VoicePhase.CANCELLED) return
        val label = current.label ?: getString(
            if (current.mode == VoiceMode.REMOTE) R.string.assistant_voice_mode_remote
            else R.string.assistant_voice_mode_offline,
        )
        when (current.phase) {
            VoicePhase.PREPARING -> {
                title.text = getString(R.string.assistant_voice_title_preparing)
                status.text = getString(R.string.assistant_voice_status_preparing)
                detail.text = getString(R.string.assistant_voice_detail_preparing)
            }
            VoicePhase.PERMISSION -> {
                title.text = label
                status.text = getString(
                    if (current.mode == VoiceMode.REMOTE) R.string.assistant_voice_status_permission_remote
                    else R.string.assistant_voice_status_permission,
                )
                detail.text = getString(
                    if (current.mode == VoiceMode.REMOTE) R.string.assistant_voice_detail_permission_remote
                    else R.string.assistant_voice_detail_permission,
                )
            }
            VoicePhase.RECORDING -> {
                title.text = getString(R.string.assistant_voice_title_recording)
                status.text = getString(R.string.assistant_voice_status_recording, label)
                detail.text = getString(R.string.assistant_voice_detail_recording)
            }
            VoicePhase.TRANSCRIBING -> {
                title.text = getString(R.string.assistant_voice_title_transcribing)
                status.text = getString(R.string.assistant_voice_status_transcribing)
                detail.text = getString(R.string.assistant_voice_detail_transcribing, label)
            }
            VoicePhase.FAILED -> {
                title.text = getString(R.string.assistant_voice_title_failed)
                status.text = failureText(current)
                detail.text = failureDetail(current)
            }
            VoicePhase.SUCCEEDED, VoicePhase.CANCELLED -> return
        }
        spinner.visibility = if (
            current.phase == VoicePhase.PREPARING || current.phase == VoicePhase.TRANSCRIBING
        ) View.VISIBLE else View.GONE
        // 失败状态用错误色文字与 errorSoft 底条；其余状态保持主文字色。
        applyStatusTone(current.phase == VoicePhase.FAILED)
        mode.text = getString(R.string.assistant_voice_mode_format, label)
        mode.visibility = if (current.phase == VoicePhase.PREPARING || !current.modeKnown) View.GONE else View.VISIBLE
        val showTimer = current.phase == VoicePhase.RECORDING
        elapsed.visibility = if (showTimer) View.VISIBLE else View.GONE
        progress.visibility = if (showTimer) View.VISIBLE else View.GONE
        if (showTimer) {
            progress.progress = current.elapsedMillis.toInt()
            updateTimer(current)
        }
        close.text = getString(
            if (VoiceActions.header(current) == VoiceHeader.CLOSE) R.string.assistant_voice_close
            else R.string.assistant_voice_cancel,
        )
        close.contentDescription = getString(
            if (VoiceActions.header(current) == VoiceHeader.CLOSE) R.string.assistant_voice_close_a11y
            else R.string.assistant_voice_cancel_a11y,
        )
        rebuildActions(current)
    }

    private fun applyStatusTone(failed: Boolean) {
        status.setTextColor(
            if (failed) AssistantNativeTheme.error else AssistantNativeTheme.textPrimary,
        )
        if (failed) {
            statusRow.background = AssistantNativeTheme.surface(
                this,
                AssistantNativeTheme.errorSoft,
                AssistantNativeTheme.radiusSm,
            )
            val horizontal = AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceMd)
            val vertical = AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceSm)
            statusRow.setPadding(horizontal, vertical, horizontal, vertical)
        } else {
            statusRow.background = null
            statusRow.setPadding(0, 0, 0, 0)
        }
    }

    private fun updateTimer(current: VoiceUiState) {
        elapsed.text = getString(R.string.assistant_voice_elapsed, current.elapsedSeconds, MAX_VOICE_SECONDS)
        elapsed.contentDescription =
            getString(R.string.assistant_voice_elapsed, current.elapsedSeconds, MAX_VOICE_SECONDS)
    }

    private fun failureText(current: VoiceUiState): String {
        val failure = current.failure ?: return getString(R.string.assistant_voice_text_generic)
        failure.message?.takeIf { it.isNotBlank() }?.let { return it }
        failure.text?.let { return nativeText(it) }
        return getString(R.string.assistant_voice_text_generic)
    }

    private fun failureDetail(current: VoiceUiState): String {
        val failure = current.failure ?: return ""
        return when (failure.text) {
            VoiceText.RECREATED_RECORDING, VoiceText.RECREATED_TRANSCRIBING ->
                getString(R.string.assistant_voice_detail_recreated, current.elapsedSeconds)
            VoiceText.RECORDING_INTERRUPTED -> getString(R.string.assistant_voice_detail_recording_interrupted)
            VoiceText.PAUSED_PREPARE -> getString(R.string.assistant_voice_detail_paused)
            VoiceText.TRANSCRIBE_CANCELLED -> getString(R.string.assistant_voice_detail_transcribe_cancelled)
            else -> when (failure.kind) {
                VoiceFailureKind.PREPARE -> getString(R.string.assistant_voice_detail_prepare_failed)
                VoiceFailureKind.PERMISSION -> getString(R.string.assistant_voice_detail_permission_failed)
                VoiceFailureKind.DEVICE -> getString(R.string.assistant_voice_detail_device_failed)
                VoiceFailureKind.TRANSCRIBE -> getString(
                    if (pcm != null) R.string.assistant_voice_detail_transcribe_failed
                    else R.string.assistant_voice_detail_transcribe_failed_dropped,
                )
            }
        }
    }

    private fun nativeText(text: VoiceText): String = getString(
        when (text) {
            VoiceText.PREPARE_TIMEOUT -> R.string.assistant_voice_text_prepare_timeout
            VoiceText.TRANSCRIBE_TIMEOUT -> R.string.assistant_voice_text_transcribe_timeout
            VoiceText.MIC_UNAVAILABLE -> R.string.assistant_voice_text_mic_unavailable
            VoiceText.RECORDER_FAILED -> R.string.assistant_voice_text_recorder_failed
            VoiceText.RECORDING_INTERRUPTED -> R.string.assistant_voice_text_recording_interrupted
            VoiceText.RECORDING_TOO_SHORT -> R.string.assistant_voice_text_recording_too_short
            VoiceText.PERMISSION_DENIED -> R.string.assistant_voice_text_permission_denied
            VoiceText.PERMISSION_BLOCKED -> R.string.assistant_voice_text_permission_blocked
            VoiceText.RECREATED_RECORDING -> R.string.assistant_voice_text_recreated_recording
            VoiceText.RECREATED_TRANSCRIBING -> R.string.assistant_voice_text_recreated_transcribing
            VoiceText.PAUSED_PREPARE -> R.string.assistant_voice_text_paused
            VoiceText.TRANSCRIBE_CANCELLED -> R.string.assistant_voice_text_transcribe_cancelled
            VoiceText.GENERIC -> R.string.assistant_voice_text_generic
        },
    )

    /** 动作按钮：第一个是森林绿主按钮，其余为浅绿次要按钮；全部保证 48dp 触控。 */
    private fun rebuildActions(current: VoiceUiState) {
        val signature = buildString {
            append(current.phase.name)
            append('|')
            append(current.failure?.code.orEmpty())
            append('|')
            append(current.failure?.text?.name.orEmpty())
        }
        if (signature == lastActionSignature) return
        lastActionSignature = signature
        actions.removeAllViews()
        VoiceActions.forState(current).forEachIndexed { index, action ->
            actions.addView(actionButton(action, primary = index == 0))
        }
    }

    private fun actionButton(action: VoiceAction, primary: Boolean): Button {
        val button = Button(this, null, 0, R.style.AssistantVoiceAction)
        button.text = actionLabel(action)
        button.isAllCaps = false
        button.minimumHeight = AssistantNativeTheme.dp(this, AssistantNativeTheme.minTouchDp)
        button.minimumWidth = AssistantNativeTheme.dp(this, AssistantNativeTheme.minTouchDp)
        button.background = AssistantNativeTheme.clickableSurface(
            this,
            if (primary) AssistantNativeTheme.primary else AssistantNativeTheme.primarySoft,
            AssistantNativeTheme.radiusMd,
        )
        AssistantNativeTheme.text(
            button,
            AssistantNativeTheme.textBody,
            if (primary) AssistantNativeTheme.onPrimary else AssistantNativeTheme.primary,
            bold = true,
        )
        button.setOnClickListener { onAction(action) }
        val params = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )
        params.topMargin = AssistantNativeTheme.dp(this, AssistantNativeTheme.spaceSm)
        button.layoutParams = params
        return button
    }

    private fun actionLabel(action: VoiceAction): String = getString(
        when (action) {
            VoiceAction.FINISH_RECORDING -> R.string.assistant_voice_action_finish
            VoiceAction.GRANT_PERMISSION -> R.string.assistant_voice_action_grant
            VoiceAction.RETRY -> R.string.assistant_voice_action_retry
            VoiceAction.RETRY_TRANSCRIPTION -> R.string.assistant_voice_action_retry_transcription
            VoiceAction.RECORD_AGAIN -> R.string.assistant_voice_action_record_again
            VoiceAction.USE_TEXT -> R.string.assistant_voice_action_use_text
            VoiceAction.OPEN_VOICE_SETTINGS -> R.string.assistant_voice_action_voice_settings
            VoiceAction.OPEN_APP_SETTINGS -> R.string.assistant_voice_action_app_settings
        },
    )

    // -- 开始一轮：beginVoice → 权限/录音 -----------------------------------

    private fun startPreparation(retryPcm: Boolean = false, autoStart: Boolean = true) {
        if (destroyed || completed) return
        // 上一轮会话可能还活着（设备失败、权限拒绝后重试）：先幂等终结同一票据，避免撞 busy。
        cancelVoiceOnce()
        roundId += 1
        val requestRound = roundId
        autoStartRecording = autoStart
        state = state.startPreparing(sessionTicket, retryPcm)
        lastActionSignature = null
        render()
        armWatchdog(BEGIN_TIMEOUT_MILLIS) {
            if (destroyed || roundId != requestRound) return@armWatchdog
            state = state.beginFailed(sessionTicket, VoiceFailures.TIMEOUT, null, VoiceText.PREPARE_TIMEOUT)
            render()
        }
        AssistantWorkspaceHost.call(
            "beginVoice",
            mapOf("ticket" to sessionTicket),
            failure = { message ->
                if (destroyed || roundId != requestRound) return@call
                disarmWatchdog()
                // 通道层失败（工作区未就绪/代次切换）按可重试原因展示。
                state = state.beginFailed(sessionTicket, "workspaceUnavailable", message)
                render()
            },
        ) { result ->
            if (destroyed || roundId != requestRound) return@call
            disarmWatchdog()
            onBeginResult(result)
        }
    }

    private fun onBeginResult(result: Any?) {
        val map = result as? Map<*, *>
        if (map == null) {
            state = state.beginFailed(sessionTicket, "workspaceUnavailable", null)
            render()
            return
        }
        if (map["ready"] != true) {
            val code = map["errorCode"] as? String
            val message = (map["message"] as? String)?.takeIf { it.isNotBlank() }
            val failureMode = VoiceMode.fromWire(map["mode"] as? String)
            state = state.beginFailed(sessionTicket, code, message, mode = failureMode)
            render()
            return
        }
        val draftKey = (map["draftKey"] as? String)?.takeIf { it.isNotBlank() }
        if (draftKey == null) {
            // 契约要求 ready=true 必须带草稿；缺失时按工作区不可用处理，不写其它草稿。
            state = state.beginFailed(sessionTicket, "workspaceUnavailable", null)
            render()
            return
        }
        val voiceMode = VoiceMode.fromWire(map["mode"] as? String)
        val label = (map["label"] as? String)?.takeIf { it.isNotBlank() }
        val accepted = state.beginReady(sessionTicket, voiceMode, label, draftKey)
        // 只有本轮仍处于准备阶段时才继续；暂停/取消后的迟到结果不能开麦克风。
        if (accepted.phase != VoicePhase.PERMISSION) return
        state = accepted
        // 远程模式先让用户读完「录音会上传」的一次性说明，再点按授权（契约第 2 节）。
        if (voiceMode == VoiceMode.REMOTE) autoStartRecording = false
        lastActionSignature = null
        render()
        val retained = pcm
        when {
            // 重试现有 PCM：不再录音，直接提交。
            state.retryPcm && retained != null -> {
                state = state.startTranscribing()
                render()
                submit(retained)
            }
            // 用户主动点按进入时才直接开录；界面重建后先停在授权说明，由用户再确认。
            !autoStartRecording -> Unit
            // 契约要求 ready=true 才请求麦克风；已授权时直接进入录音。
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED ->
                startRecording()
            else -> requestMicrophone()
        }
    }

    private fun requestMicrophone() {
        if (destroyed || state.phase != VoicePhase.PERMISSION) return
        // 重复点按不再叠加系统权限请求。
        if (permissionRequestInFlight) return
        permissionRequestInFlight = true
        try {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_MICROPHONE)
        } catch (error: Exception) {
            permissionRequestInFlight = false
            state = state.permissionDenied(blocked = false)
            render()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_MICROPHONE) return
        permissionRequestInFlight = false
        if (destroyed) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        if (granted) {
            startRecording()
        } else {
            // 拒绝后仍不能弹说明即视为「不再询问」。
            val blocked = !shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO)
            state = state.permissionDenied(blocked)
            lastActionSignature = null
            render()
        }
    }

    // -- 录音 ----------------------------------------------------------------

    private fun startRecording() {
        if (destroyed || state.phase != VoicePhase.PERMISSION) return
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestMicrophone()
            return
        }
        val minBuffer = AudioRecord.getMinBufferSize(
            VOICE_SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuffer <= 0) {
            failDevice(VoiceText.MIC_UNAVAILABLE)
            return
        }
        val recorder = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                VOICE_SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuffer, 4096),
            )
        } catch (error: Exception) {
            null
        }
        if (recorder == null || recorder.state != AudioRecord.STATE_INITIALIZED) {
            runCatching { recorder?.release() }
            failDevice(VoiceText.RECORDER_FAILED)
            return
        }
        try {
            recorder.startRecording()
            check(recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING)
        } catch (error: Exception) {
            runCatching { recorder.release() }
            failDevice(VoiceText.RECORDER_FAILED)
            return
        }
        audio.set(recorder)
        recordingFlag.set(true)
        stopRequested.set(false)
        startedAtMillis = SystemClock.elapsedRealtime()
        lastShownSecond = -1
        pcm = null
        state = state.beginRecording()
        lastActionSignature = null
        render()
        capture(recorder)
        main.post(timerTick)
    }

    /** 采集线程只负责读 PCM 与释放 AudioRecord；UI 只接收结果，不在这里碰视图。 */
    private fun capture(recorder: AudioRecord) {
        val thread = Thread({
            val output = ByteArrayOutputStream()
            var failed = false
            val buffer = ByteArray(4096)
            try {
                while (recordingFlag.get() && output.size() < MAX_VOICE_PCM_BYTES) {
                    val count = recorder.read(buffer, 0, minOf(buffer.size, MAX_VOICE_PCM_BYTES - output.size()))
                    if (count < 0) {
                        failed = true
                        break
                    }
                    if (count > 0) output.write(buffer, 0, count)
                }
            } catch (error: Exception) {
                failed = true
            } finally {
                recordingFlag.set(false)
                if (audio.compareAndSet(recorder, null)) {
                    runCatching { recorder.stop() }
                    runCatching { recorder.release() }
                }
            }
            val bytes = output.toByteArray()
            main.post { onSamplesReady(bytes, failed) }
        }, "assistant-voice-record")
        thread.isDaemon = true
        thread.start()
    }

    private fun onSamplesReady(bytes: ByteArray, failed: Boolean) {
        if (destroyed) return
        val phase = state.phase
        if (phase != VoicePhase.RECORDING && phase != VoicePhase.TRANSCRIBING) return
        // 用户点「完成」或 30 秒上限触发的停止会让 read 返回错误，这种终止不算录音失败。
        if (failed && !stopRequested.get()) {
            failDevice(VoiceText.RECORDING_INTERRUPTED)
            return
        }
        if (bytes.size < MIN_VOICE_PCM_BYTES) {
            state = state.audioUnusable(VoiceText.RECORDING_TOO_SHORT)
            lastActionSignature = null
            render()
            return
        }
        // Dart 契约要求偶数长度 PCM16。
        val audioBytes = if (bytes.size % 2 == 0) bytes else bytes.copyOf(bytes.size - 1)
        pcm = audioBytes
        if (state.phase == VoicePhase.RECORDING) state = state.startTranscribing()
        lastActionSignature = null
        render()
        submit(audioBytes)
    }

    private val timerTick = object : Runnable {
        override fun run() {
            if (destroyed || state.phase != VoicePhase.RECORDING) return
            state = state.tick(SystemClock.elapsedRealtime() - startedAtMillis)
            progress.progress = state.elapsedMillis.toInt()
            val seconds = state.elapsedSeconds
            if (seconds != lastShownSecond) {
                lastShownSecond = seconds
                updateTimer(state)
            }
            if (state.limitReached) {
                // 30 秒上限：自动停止并转写，不显示虚假进度。
                finishRecording()
                return
            }
            main.postDelayed(this, TIMER_TICK_MILLIS)
        }
    }

    /** 「完成」与 30 秒上限共用：停止采集，等采集线程交回 PCM 后提交。 */
    private fun finishRecording() {
        if (destroyed || state.phase != VoicePhase.RECORDING) return
        stopRequested.set(true)
        recordingFlag.set(false)
        runCatching { audio.get()?.stop() }
        stopTimer()
        state = state.startTranscribing()
        lastActionSignature = null
        render()
    }

    // -- 转写 ----------------------------------------------------------------

    private fun submit(audioBytes: ByteArray) {
        if (destroyed || completed) return
        if (state.phase != VoicePhase.TRANSCRIBING) return
        if (state.submitted) return
        val requestRound = roundId
        state = state.markSubmitted()
        armWatchdog(VOICE_TIMEOUT_MILLIS) {
            if (destroyed || completed || roundId != requestRound) return@armWatchdog
            if (state.phase != VoicePhase.TRANSCRIBING) return@armWatchdog
            // 超时不无限等待：作废本票据，让迟到结果在 Dart 与原生两侧都被丢弃。
            cancelVoiceOnce()
            state = state.transcribeFailed(VoiceFailures.TIMEOUT, null, VoiceText.TRANSCRIBE_TIMEOUT)
            lastActionSignature = null
            render()
        }
        AssistantWorkspaceHost.call(
            "voice",
            mapOf("ticket" to sessionTicket, "pcm" to audioBytes),
            failure = { message ->
                if (destroyed || completed || roundId != requestRound) return@call
                disarmWatchdog()
                state = state.transcribeFailed(null, message)
                lastActionSignature = null
                render()
            },
        ) { result ->
            if (destroyed || completed || roundId != requestRound) return@call
            disarmWatchdog()
            onVoiceResult(result)
        }
    }

    private fun onVoiceResult(result: Any?) {
        val map = result as? Map<*, *>
        if (map?.get("accepted") == true) {
            val draftKey = (map["draftKey"] as? String)?.takeIf { it.isNotBlank() } ?: state.draftKey
            val accepted = state.transcribeSucceeded(draftKey)
            // 取消或超时之后到达的成功不再打开草稿，避免把已终结的面板又拉回来。
            if (accepted.phase != VoicePhase.SUCCEEDED) return
            state = accepted
            render()
            completeSuccess(accepted.draftKey)
            return
        }
        val code = map?.get("errorCode") as? String
        val message = (map?.get("message") as? String)?.takeIf { it.isNotBlank() }
        if (code == "cancelled") {
            // 取消是静默终态：不写提示，也不把部分结果当成成功。
            state = state.cancel()
            finishNow()
            return
        }
        state = state.transcribeFailed(code, message)
        lastActionSignature = null
        render()
    }

    /** 成功：先通知悬浮服务回到原草稿输入区，再关闭面板；不自动发送。 */
    private fun completeSuccess(draftKey: String?) {
        if (completed) return
        completed = true
        disarmWatchdog()
        stopTimer()
        if (draftKey != null) {
            runCatching { AssistantOverlayService.voiceDone(state.ticket, draftKey) }
        }
        finishNow()
    }

    // -- 动作 ----------------------------------------------------------------

    private fun onAction(action: VoiceAction) {
        if (destroyed || completed) return
        when (action) {
            // 授权阶段就地请求；失败页的「允许录音」重开一轮，避免用已终结的票据录音。
            VoiceAction.GRANT_PERMISSION ->
                if (state.phase == VoicePhase.PERMISSION) requestMicrophone() else startPreparation()
            VoiceAction.FINISH_RECORDING -> finishRecording()
            VoiceAction.RETRY -> startPreparation(retryPcm = false)
            VoiceAction.RECORD_AGAIN -> startPreparation(retryPcm = false)
            VoiceAction.RETRY_TRANSCRIPTION -> startPreparation(retryPcm = pcm != null)
            VoiceAction.USE_TEXT -> openTextEntry()
            VoiceAction.OPEN_VOICE_SETTINGS -> openVoiceSettings()
            VoiceAction.OPEN_APP_SETTINGS -> openAppPermissionSettings()
        }
    }

    /** 使用文字：关闭本面板，打开助手文字输入；不假装语音已经完成。 */
    private fun openTextEntry() {
        cancelWork()
        val intent = MainActivity.assistantIntent(this).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { startActivity(intent) }
        finishNow()
    }

    /** 打开语音设置：交给 MainActivity 的一次性路由 assistant_route=voiceSettings。 */
    private fun openVoiceSettings() {
        cancelWork()
        val intent = MainActivity.assistantIntent(this)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .putExtra(EXTRA_ASSISTANT_ROUTE, ROUTE_VOICE_SETTINGS)
        runCatching { startActivity(intent) }
        finishNow()
    }

    /** 永久拒绝时去系统应用设置页；系统权限 UI 由 Android 控制，面板不伪装。 */
    private fun openAppPermissionSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { startActivity(intent) }
    }

    private fun failDevice(text: VoiceText) {
        stopTimer()
        state = state.deviceFailed(text)
        lastActionSignature = null
        render()
    }

    /** 取消并关闭：停止采集、释放录音、停止计时、作废票据，迟到结果全部丢弃。 */
    private fun cancelAndFinish() {
        cancelWork()
        finishNow()
    }

    private fun cancelWork() {
        if (completed) return
        state = state.cancel()
        stopTimer()
        disarmWatchdog()
        stopRecordingHardware()
        cancelVoiceOnce()
    }

    private fun stopRecordingHardware() {
        stopRequested.set(true)
        recordingFlag.set(false)
        audio.getAndSet(null)?.let { recorder ->
            runCatching { recorder.stop() }
            runCatching { recorder.release() }
        }
    }

    /** cancelVoice 幂等；同一轮只终结一次，重试的新一轮仍可终结同一票据。 */
    private fun cancelVoiceOnce() {
        if (completed || cancelledRound == roundId || sessionTicket.isBlank()) return
        cancelledRound = roundId
        AssistantWorkspaceHost.call("cancelVoice", mapOf("ticket" to sessionTicket), failure = {})
    }

    private fun stopTimer() {
        main.removeCallbacks(timerTick)
    }

    private fun armWatchdog(timeoutMillis: Long, action: () -> Unit) {
        disarmWatchdog()
        val runnable = Runnable { action() }
        watchdog = runnable
        main.postDelayed(runnable, timeoutMillis)
    }

    private fun disarmWatchdog() {
        watchdog?.let { main.removeCallbacks(it) }
        watchdog = null
    }

    @Suppress("DEPRECATION")
    private fun finishNow() {
        if (isFinishing || isDestroyed) return
        finish()
        overridePendingTransition(0, 0)
    }

    /**
     * 本面板的票据：优先沿用调用方（悬浮菜单）通过 [EXTRA_TICKET] 传入的值，缺失时自生成；
     * 重建也沿用它，这样服务端的票据身份和面板会话一致。
     */
    private fun savedTicket(saved: Bundle?): String {
        saved?.getString(KEY_TICKET)?.takeIf { it.isNotBlank() }?.let { return it }
        intent?.getStringExtra(EXTRA_TICKET)?.takeIf { it.isNotBlank() }?.let { return it }
        return UUID.randomUUID().toString()
    }

    // -- 生命周期 ------------------------------------------------------------

    /** 保存票据、阶段、已录时长与失败原因；重建后据此恢复，不延续已释放的录音线程。 */
    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString(KEY_TICKET, state.ticket)
        outState.putString(KEY_PHASE, state.phase.name)
        outState.putLong(KEY_ELAPSED, state.elapsedMillis)
        outState.putString(KEY_MODE, state.mode.name)
        outState.putString(KEY_LABEL, state.label)
        outState.putString(KEY_DRAFT, state.draftKey)
        state.failure?.let { failure ->
            outState.putString(KEY_FAILURE_KIND, failure.kind.name)
            outState.putString(KEY_FAILURE_CODE, failure.code)
            outState.putString(KEY_FAILURE_MESSAGE, failure.message)
            outState.putString(KEY_FAILURE_TEXT, failure.text?.name)
        }
    }

    /**
     * 离开前台就结束本轮：停止并释放音频、停止计时、作废票据，不在后台继续录音。
     *
     * 系统权限弹窗也会触发暂停（[permissionRequestInFlight]），这种情况不算中断；
     * 屏幕重建同样经过 onPause，这里会按「中断」保存原因，重建后如实显示，而不是悄悄续录。
     */
    override fun onPause() {
        super.onPause()
        if (permissionRequestInFlight || completed) return
        if (state.phase == VoicePhase.SUCCEEDED || state.phase == VoicePhase.CANCELLED) return
        when (state.phase) {
            VoicePhase.PREPARING, VoicePhase.PERMISSION -> {
                state = state.pausedForBackground(VoiceText.PAUSED_PREPARE)
            }
            VoicePhase.RECORDING -> {
                // 已录内容直接丢弃：取消不写入部分结果，也不在后台继续录音。
                val elapsed = state.elapsedMillis
                stopRecordingHardware()
                state = state.interrupted(VoiceText.RECORDING_INTERRUPTED, elapsed)
            }
            VoicePhase.TRANSCRIBING ->
                state = state.transcribeFailed(null, null, VoiceText.TRANSCRIBE_CANCELLED)
            VoicePhase.FAILED, VoicePhase.SUCCEEDED, VoicePhase.CANCELLED -> Unit
        }
        // 任何阶段离开前台都终结本轮票据：不在后台保留会话，下一轮 beginVoice 也不会撞 busy。
        stopTimer()
        disarmWatchdog()
        cancelVoiceOnce()
        render()
    }

    override fun onDestroy() {
        destroyed = true
        main.removeCallbacksAndMessages(null)
        watchdog = null
        recordingFlag.set(false)
        stopRequested.set(true)
        stopRecordingHardware()
        // 票据必须终结；成功（completed）后不再重复 cancel。
        cancelVoiceOnce()
        super.onDestroy()
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        cancelAndFinish()
    }

    // -- 常量 ----------------------------------------------------------------

    companion object {
        /** 悬浮快捷菜单生成的语音票据；缺失时本界面自行生成，保证「点按才录音」仍可用。 */
        const val EXTRA_TICKET = "assistant_voice_ticket"

        /** 旧调用方仍会附带该草稿键；草稿身份现在由 beginVoice 返回的 draftKey 绑定。 */
        const val EXTRA_DRAFT = "assistant_voice_draft"

        /** 「打开语音设置」路由 extra；契约冻结，A/D 只引用，不复制字符串。 */
        const val EXTRA_ASSISTANT_ROUTE = AssistantVoiceRoute.EXTRA

        /** 该 extra 的取值：助手设置 → 语音输入页。 */
        const val ROUTE_VOICE_SETTINGS = AssistantVoiceRoute.VOICE_SETTINGS

        private const val REQUEST_MICROPHONE = 7412
        private const val KEY_TICKET = "assistant_voice_state_ticket"
        private const val KEY_PHASE = "assistant_voice_state_phase"
        private const val KEY_ELAPSED = "assistant_voice_state_elapsed"
        private const val KEY_MODE = "assistant_voice_state_mode"
        private const val KEY_LABEL = "assistant_voice_state_label"
        private const val KEY_DRAFT = "assistant_voice_state_draft"
        private const val KEY_FAILURE_KIND = "assistant_voice_state_failure_kind"
        private const val KEY_FAILURE_CODE = "assistant_voice_state_failure_code"
        private const val KEY_FAILURE_MESSAGE = "assistant_voice_state_failure_message"
        private const val KEY_FAILURE_TEXT = "assistant_voice_state_failure_text"
    }
}
