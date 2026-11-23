package chat.liuxin.mission_book

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 悬浮语音面板的纯逻辑回归：阶段迁移、防重、迟到结果、错误码→动作、路由值与窄屏几何。
 *
 * 这里不加载 Android 视图、不碰麦克风、不连 Dart：权限弹窗、刘海、TalkBack 和真实模型
 * 仍须目标设备验收，不能拿本测试替代。
 */
class AssistantVoiceStateTest {
    private fun preparing(ticket: String = "t1") = VoiceUiState(ticket = ticket)

    private fun ready(ticket: String = "t1") = preparing(ticket).beginReady(
        replyTicket = ticket,
        mode = VoiceMode.OFFLINE,
        label = "离线语音",
        draftKey = "draft-1",
    )

    private fun recording(ticket: String = "t1") = ready(ticket).beginRecording()

    private fun transcribing(ticket: String = "t1") = recording(ticket).startTranscribing()

    @Test
    fun `recognition mode follows the frozen wire values`() {
        assertEquals("offline", VoiceMode.OFFLINE.wire)
        assertEquals("remote", VoiceMode.REMOTE.wire)
        assertEquals(VoiceMode.REMOTE, VoiceMode.fromWire("remote"))
        assertEquals(VoiceMode.OFFLINE, VoiceMode.fromWire("offline"))
        assertEquals(VoiceMode.OFFLINE, VoiceMode.fromWire(null))
        assertEquals(VoiceMode.OFFLINE, VoiceMode.fromWire("somethingElse"))
    }

    @Test
    fun `begin failure keeps the reported recognition mode`() {
        val remoteFailure = preparing().beginFailed(
            replyTicket = "t1",
            code = "remoteConfigMissing",
            message = "录音转写服务未配置，请先完成语音设置",
            mode = VoiceMode.REMOTE,
        )
        assertEquals(VoiceMode.REMOTE, remoteFailure.mode)
        assertTrue(remoteFailure.modeKnown)
        assertEquals(VoicePhase.FAILED, remoteFailure.phase)

        // 通道层失败没带 mode：不能凭空显示「离线语音」。
        val transportFailure = preparing().beginFailed("t1", "workspaceUnavailable", "助手正在准备，请稍后重试")
        assertFalse(transportFailure.modeKnown)

        // ready 后已知识别方式；重新准备会清掉旧标签。
        val ready = ready()
        assertTrue(ready.modeKnown)
        assertEquals("离线语音", ready.label)
        val retried = ready.permissionDenied(blocked = true).startPreparing("t2")
        assertFalse(retried.modeKnown)
        assertNull(retried.label)
    }

    @Test
    fun `preparing to success follows the frozen contract`() {
        val prepared = preparing()
        assertEquals(VoicePhase.PREPARING, prepared.phase)
        assertEquals(VoicePhase.PERMISSION, ready().phase)

        val recording = recording()
        assertEquals(VoicePhase.RECORDING, recording.phase)
        assertEquals(0L, recording.elapsedMillis)
        assertEquals(30_000L, recording.remainingMillis)

        val transcribing = recording.startTranscribing()
        assertEquals(VoicePhase.TRANSCRIBING, transcribing.phase)
        assertFalse(transcribing.submitted)

        val succeeded = transcribing.markSubmitted().transcribeSucceeded("draft-1")
        assertEquals(VoicePhase.SUCCEEDED, succeeded.phase)
        assertEquals("draft-1", succeeded.draftKey)
        assertEquals("t1", succeeded.ticket)
        // 成功不是取消，重复取消也不能把结果降级。
        assertEquals(VoicePhase.SUCCEEDED, succeeded.cancel().phase)
    }

    @Test
    fun `ready false never reaches recording`() {
        val failed = preparing().beginFailed(
            replyTicket = "t1",
            code = "offlineModelMissing",
            message = "离线语音模型未安装，请先在语音设置中下载",
        )
        assertEquals(VoicePhase.FAILED, failed.phase)
        assertEquals("离线语音模型未安装，请先在语音设置中下载", failed.failure?.message)
        // 未拿到 ready=true 时不能启动录音，也不能提交空音频。
        assertEquals(VoicePhase.FAILED, failed.beginRecording().phase)
        assertEquals(VoicePhase.FAILED, failed.startTranscribing().phase)
        assertEquals(VoicePhase.FAILED, failed.markSubmitted().phase)

        val denied = ready().permissionDenied(blocked = false)
        assertEquals(VoicePhase.FAILED, denied.phase)
        assertEquals(VoicePhase.FAILED, denied.beginRecording().phase)
        assertEquals(VoicePhase.FAILED, denied.startTranscribing().phase)
    }

    @Test
    fun `ready result must match the ticket of this round`() {
        val stale = preparing("new").beginReady(
            replyTicket = "old",
            mode = VoiceMode.REMOTE,
            label = "录音转写服务",
            draftKey = "other",
        )
        assertEquals(VoicePhase.PREPARING, stale.phase)
        assertNull(stale.draftKey)

        val staleFailure = preparing("new").beginFailed("old", "busy", "语音正在使用中，请稍后重试")
        assertEquals(VoicePhase.PREPARING, staleFailure.phase)
        assertNull(staleFailure.failure)
    }

    @Test
    fun `thirty second cap stops automatically and freezes the timer`() {
        val started = recording()
        val beforeLimit = started.tick(29_999L)
        assertEquals(29_999L, beforeLimit.elapsedMillis)
        assertFalse(beforeLimit.limitReached)
        assertEquals(1L, beforeLimit.remainingMillis)

        val atLimit = started.tick(30_000L)
        assertTrue(atLimit.limitReached)
        assertEquals(0L, atLimit.remainingMillis)

        val overLimit = started.tick(45_000L)
        assertEquals(30_000L, overLimit.elapsedMillis)
        assertEquals(30, overLimit.elapsedSeconds)
        assertTrue(overLimit.limitReached)
        // 自动停止后进入转写，计时不再增长。
        val transcribing = overLimit.startTranscribing()
        assertEquals(VoicePhase.TRANSCRIBING, transcribing.phase)
        assertEquals(30_000L, transcribing.tick(50_000L).elapsedMillis)
    }

    @Test
    fun `duplicate taps are ignored`() {
        val recording = recording()
        val first = recording.startTranscribing()
        assertEquals(VoicePhase.TRANSCRIBING, first.phase)
        assertEquals(first, first.startTranscribing())

        val once = first.markSubmitted()
        assertTrue(once.submitted)
        assertEquals(once, once.markSubmitted())

        // 转写中再次「完成」不会重新进入录音。
        assertEquals(VoicePhase.TRANSCRIBING, first.beginRecording().phase)
    }

    @Test
    fun `cancel drops late results and partial audio`() {
        val cancelled = transcribing().markSubmitted().cancel()
        assertEquals(VoicePhase.CANCELLED, cancelled.phase)
        assertEquals(cancelled, cancelled.transcribeSucceeded("draft-1"))
        assertEquals(cancelled, cancelled.transcribeFailed("failed", "语音识别失败，请重试或改用文字"))
        assertEquals(cancelled, cancelled.beginReady("t1", VoiceMode.OFFLINE, "离线语音", "draft-1"))
        assertEquals(cancelled, cancelled.beginFailed("t1", "busy", "语音正在使用中，请稍后重试"))
        assertEquals(cancelled, cancelled.tick(1_000L))
    }

    @Test
    fun `late begin result after a retry stays on the retried state`() {
        val failed = transcribing().transcribeFailed("noSpeech", "没有识别到清晰语音，请重试或改用文字")
        val retried = failed.startPreparing("t2")
        assertEquals(VoicePhase.PREPARING, retried.phase)
        assertEquals("t2", retried.ticket)
        assertNull(retried.failure)

        // 上一轮票据的迟到结果不能覆盖新一轮。
        val afterStale = retried.beginReady("t1", VoiceMode.OFFLINE, "离线语音", "draft-1")
        assertEquals(VoicePhase.PREPARING, afterStale.phase)
        assertNull(afterStale.draftKey)
    }

    @Test
    fun `retry transcription reuses retained pcm without recording`() {
        val failed = transcribing().transcribeFailed("transcribeTimeout", "语音识别超时，请重试或改用文字")
        val retry = failed.startPreparing("t2", retryPcm = true)
        assertTrue(retry.retryPcm)
        assertEquals(VoicePhase.PREPARING, retry.phase)

        val retryReady = retry.beginReady("t2", VoiceMode.OFFLINE, "离线语音", "draft-1")
        assertEquals(VoicePhase.PERMISSION, retryReady.phase)
        // 重试现有 PCM 时不再录音，直接进入转写。
        assertEquals(VoicePhase.TRANSCRIBING, retryReady.startTranscribing().phase)
        // 普通授权阶段不能跳过录音直接转写。
        assertEquals(VoicePhase.PERMISSION, ready().startTranscribing().phase)
    }

    @Test
    fun `begin error codes map to reachable actions`() {
        assertEquals(
            listOf(VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.USE_TEXT),
            VoiceFailures.begin("offlineModelMissing", "离线语音模型未安装，请先在语音设置中下载").actions,
        )
        assertEquals(
            listOf(VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.USE_TEXT),
            VoiceFailures.begin("offlineModelInvalid", "离线语音模型已损坏，请重新下载").actions,
        )
        assertEquals(
            listOf(VoiceAction.RETRY, VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.USE_TEXT),
            VoiceFailures.begin("offlineModelInitFailed", "离线语音模型未能加载，请重试或改用文字").actions,
        )
        assertEquals(
            listOf(VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.USE_TEXT),
            VoiceFailures.begin("remoteConfigMissing", "录音转写服务未配置，请先完成语音设置").actions,
        )
        assertEquals(
            listOf(VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.USE_TEXT),
            VoiceFailures.begin("remoteConfigInvalid", "录音转写服务配置无效，请检查语音设置").actions,
        )
        assertEquals(
            listOf(VoiceAction.RETRY, VoiceAction.USE_TEXT),
            VoiceFailures.begin("busy", "语音正在使用中，请稍后重试").actions,
        )
        assertEquals(
            listOf(VoiceAction.RETRY, VoiceAction.USE_TEXT),
            VoiceFailures.begin("workspaceUnavailable", "助手正在准备，请稍后重试").actions,
        )
        // 通道层失败没有错误码，仍要给出重试与文字入口。
        assertEquals(
            listOf(VoiceAction.RETRY, VoiceAction.USE_TEXT),
            VoiceFailures.begin(null, "助手正在准备，请稍后重试").actions,
        )
        // 原生看门狗超时：可重试，且使用原生中文原因。
        val timeout = VoiceFailures.begin(VoiceFailures.TIMEOUT, null, VoiceText.PREPARE_TIMEOUT)
        assertEquals(listOf(VoiceAction.RETRY, VoiceAction.USE_TEXT), timeout.actions)
        assertEquals(VoiceText.PREPARE_TIMEOUT, timeout.text)
        assertNull(timeout.message)
    }

    @Test
    fun `transcribe error codes map to retry record or text`() {
        assertEquals(
            listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
            VoiceFailures.transcribe("noSpeech", "没有识别到清晰语音，请重试或改用文字").actions,
        )
        assertEquals(
            listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
            VoiceFailures.transcribe("emptyAudio", "录音为空或长度超出限制，请重新录音").actions,
        )
        assertEquals(
            listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
            VoiceFailures.transcribe("ticketInvalid", "语音会话已失效，请重新开始录音").actions,
        )
        assertEquals(
            listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
            VoiceFailures.transcribe("draftChanged", "原草稿已失效，请重新开始语音").actions,
        )
        assertEquals(
            listOf(VoiceAction.RETRY_TRANSCRIPTION, VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
            VoiceFailures.transcribe("workspaceUnavailable", "助手正在准备，请稍后重试").actions,
        )
        assertEquals(
            listOf(VoiceAction.RETRY_TRANSCRIPTION, VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
            VoiceFailures.transcribe("offlineModelInitFailed", "离线语音模型未能加载，请重试或改用文字").actions,
        )
        assertEquals(
            listOf(VoiceAction.RETRY_TRANSCRIPTION, VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
            VoiceFailures.transcribe("remoteRequestFailed", "录音转写服务请求失败，请检查服务地址、模型或网络").actions,
        )
        assertEquals(
            listOf(VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.RETRY_TRANSCRIPTION, VoiceAction.USE_TEXT),
            VoiceFailures.transcribe("remoteAuthFailed", "录音转写服务拒绝访问，请检查独立转写 API Key").actions,
        )
        assertEquals(
            listOf(VoiceAction.RETRY_TRANSCRIPTION, VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
            VoiceFailures.transcribe("failed", "语音识别失败，请重试或改用文字").actions,
        )
        // 未知码按可重试处理，不把用户卡死在失败页。
        assertEquals(
            VoiceAction.RETRY_TRANSCRIPTION,
            VoiceFailures.transcribe("somethingNew", "新原因").primary,
        )
        // cancelled 静默关闭：没有可点动作，也不渲染错误文案。
        val cancelled = VoiceFailures.transcribe("cancelled", "已取消录音")
        assertTrue(cancelled.silent)
        assertTrue(cancelled.actions.isEmpty())
    }

    @Test
    fun `permission denial and permanent denial differ`() {
        val denied = VoiceFailures.permission(blocked = false)
        val blocked = VoiceFailures.permission(blocked = true)
        assertEquals(listOf(VoiceAction.GRANT_PERMISSION, VoiceAction.USE_TEXT), denied.actions)
        assertEquals(
            listOf(VoiceAction.OPEN_APP_SETTINGS, VoiceAction.GRANT_PERMISSION, VoiceAction.USE_TEXT),
            blocked.actions,
        )
        assertEquals(VoiceText.PERMISSION_DENIED, denied.text)
        assertEquals(VoiceText.PERMISSION_BLOCKED, blocked.text)
        assertNotEquals(denied.text, blocked.text)
        assertNotEquals(denied.code, blocked.code)
    }

    @Test
    fun `actions and header follow the phase`() {
        assertTrue(VoiceActions.forState(preparing()).isEmpty())
        assertEquals(
            listOf(VoiceAction.GRANT_PERMISSION, VoiceAction.USE_TEXT),
            VoiceActions.forState(ready()),
        )
        assertEquals(listOf(VoiceAction.FINISH_RECORDING), VoiceActions.forState(recording()))
        assertTrue(VoiceActions.forState(transcribing()).isEmpty())
        assertTrue(VoiceActions.forState(transcribing().cancel()).isEmpty())

        val failed = ready().permissionDenied(blocked = true)
        assertEquals(
            listOf(VoiceAction.OPEN_APP_SETTINGS, VoiceAction.GRANT_PERMISSION, VoiceAction.USE_TEXT),
            VoiceActions.forState(failed),
        )
        assertEquals(VoiceHeader.CLOSE, VoiceActions.header(failed))
        assertEquals(VoiceHeader.CANCEL, VoiceActions.header(recording()))
        assertEquals(VoiceHeader.CANCEL, VoiceActions.header(transcribing()))
    }

    @Test
    fun `activity recreation interrupts instead of resuming secretly`() {
        assertEquals(VoiceRestore.Decision.PREPARE, VoiceRestore.decide(null))
        assertEquals(VoiceRestore.Decision.PREPARE, VoiceRestore.decide(VoicePhase.PREPARING.name))
        assertEquals(VoiceRestore.Decision.PREPARE, VoiceRestore.decide(VoicePhase.PERMISSION.name))
        assertEquals(VoiceRestore.Decision.PREPARE, VoiceRestore.decide(VoicePhase.FAILED.name))
        assertEquals(VoiceRestore.Decision.INTERRUPTED_RECORDING, VoiceRestore.decide(VoicePhase.RECORDING.name))
        assertEquals(VoiceRestore.Decision.INTERRUPTED_TRANSCRIBING, VoiceRestore.decide(VoicePhase.TRANSCRIBING.name))

        val interrupted = preparing().interrupted(VoiceText.RECREATED_RECORDING, 8_000L)
        assertEquals(VoicePhase.FAILED, interrupted.phase)
        assertEquals(8_000L, interrupted.elapsedMillis)
        assertEquals(listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT), interrupted.failure?.actions)
        // 中断后不会自动回到录音或转写。
        assertEquals(VoicePhase.FAILED, interrupted.beginRecording().phase)
        assertEquals(VoicePhase.FAILED, interrupted.startTranscribing().phase)
    }

    @Test
    fun `local device failures offer retry or text`() {
        val unavailable = recording().deviceFailed(VoiceText.MIC_UNAVAILABLE)
        assertEquals(VoicePhase.FAILED, unavailable.phase)
        assertEquals(listOf(VoiceAction.RETRY, VoiceAction.USE_TEXT), unavailable.failure?.actions)

        val interrupted = recording().deviceFailed(VoiceText.RECORDING_INTERRUPTED)
        assertEquals(listOf(VoiceAction.RETRY, VoiceAction.USE_TEXT), interrupted.failure?.actions)

        val tooShort = transcribing().audioUnusable(VoiceText.RECORDING_TOO_SHORT)
        assertEquals(VoicePhase.FAILED, tooShort.phase)
        assertEquals(listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT), tooShort.failure?.actions)
    }

    @Test
    fun `background pause ends the round without losing the reason`() {
        val pausedPrepare = preparing().pausedForBackground(VoiceText.PAUSED_PREPARE)
        assertEquals(VoicePhase.FAILED, pausedPrepare.phase)
        assertEquals(VoiceText.PAUSED_PREPARE, pausedPrepare.failure?.text)
        assertEquals(listOf(VoiceAction.RETRY, VoiceAction.USE_TEXT), pausedPrepare.failure?.actions)
        // 暂停后不会自动回到录音或转写。
        assertEquals(VoicePhase.FAILED, pausedPrepare.beginRecording().phase)
        assertEquals(VoicePhase.FAILED, pausedPrepare.startTranscribing().phase)

        val pausedTranscribe = transcribing().transcribeFailed(null, null, VoiceText.TRANSCRIBE_CANCELLED)
        assertEquals(VoicePhase.FAILED, pausedTranscribe.phase)
        assertEquals(VoiceText.TRANSCRIBE_CANCELLED, pausedTranscribe.failure?.text)
        assertEquals(
            listOf(VoiceAction.RETRY_TRANSCRIPTION, VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
            pausedTranscribe.failure?.actions,
        )
    }

    @Test
    fun `restored state keeps reason actions and elapsed time`() {
        val restoredPrepare = preparing("t9").restoreFailure(
            elapsedMillis = 12_000L,
            mode = VoiceMode.OFFLINE,
            label = "离线语音",
            draftKey = "draft-9",
            kind = VoiceFailureKind.PREPARE,
            code = "offlineModelMissing",
            message = "离线语音模型未安装，请先在语音设置中下载",
            text = null,
        )
        assertEquals(VoicePhase.FAILED, restoredPrepare.phase)
        assertEquals(12_000L, restoredPrepare.elapsedMillis)
        assertEquals(12, restoredPrepare.elapsedSeconds)
        assertEquals("离线语音", restoredPrepare.label)
        assertEquals("draft-9", restoredPrepare.draftKey)
        assertEquals(
            listOf(VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.USE_TEXT),
            restoredPrepare.failure?.actions,
        )
        assertEquals(VoicePhase.FAILED, restoredPrepare.beginRecording().phase)

        val restoredDenied = preparing().restoreFailure(
            0L, VoiceMode.REMOTE, "录音转写服务", null,
            VoiceFailureKind.PERMISSION, VoiceFailures.PERMISSION_BLOCKED, null, null,
        )
        assertEquals(
            listOf(VoiceAction.OPEN_APP_SETTINGS, VoiceAction.GRANT_PERMISSION, VoiceAction.USE_TEXT),
            restoredDenied.failure?.actions,
        )

        val restoredTranscribe = preparing().restoreFailure(
            0L, VoiceMode.REMOTE, "录音转写服务", "draft-1",
            VoiceFailureKind.TRANSCRIBE, "remoteRequestFailed", "录音转写服务请求失败，请检查服务地址、模型或网络", null,
        )
        // 重建后 PCM 已释放：不能出现「重试转写」这种实际做不到的动作。
        assertEquals(
            listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT),
            restoredTranscribe.failure?.actions,
        )
        val restoredAuth = preparing().restoreFailure(
            0L, VoiceMode.REMOTE, "录音转写服务", "draft-1",
            VoiceFailureKind.TRANSCRIBE, "remoteAuthFailed", "录音转写服务拒绝访问，请检查独立转写 API Key", null,
        )
        assertEquals(
            listOf(VoiceAction.OPEN_VOICE_SETTINGS, VoiceAction.USE_TEXT),
            restoredAuth.failure?.actions,
        )

        val restoredInterrupted = preparing().restoreFailure(
            8_000L, VoiceMode.OFFLINE, "离线语音", "draft-1",
            VoiceFailureKind.DEVICE, null, null, VoiceText.RECORDING_INTERRUPTED,
        )
        assertEquals(VoiceText.RECORDING_INTERRUPTED, restoredInterrupted.failure?.text)
        assertEquals(listOf(VoiceAction.RECORD_AGAIN, VoiceAction.USE_TEXT), restoredInterrupted.failure?.actions)
    }

    @Test
    fun `voice settings route uses the frozen extras`() {
        // 字面值来自冻结契约，A/D 只引用这两个常量。
        assertEquals("assistant_route", AssistantOverlayVoiceActivity.EXTRA_ASSISTANT_ROUTE)
        assertEquals("voiceSettings", AssistantOverlayVoiceActivity.ROUTE_VOICE_SETTINGS)
        assertEquals(AssistantVoiceRoute.EXTRA, AssistantOverlayVoiceActivity.EXTRA_ASSISTANT_ROUTE)
        assertEquals(AssistantVoiceRoute.VOICE_SETTINGS, AssistantOverlayVoiceActivity.ROUTE_VOICE_SETTINGS)
        // 语音票据与旧草稿 extra 仍保持兼容，避免服务端调用方编译或行为中断。
        assertEquals("assistant_voice_ticket", AssistantOverlayVoiceActivity.EXTRA_TICKET)
        assertEquals("assistant_voice_draft", AssistantOverlayVoiceActivity.EXTRA_DRAFT)
    }

    @Test
    fun `panel geometry keeps narrow screens usable`() {
        // 320dp 窄屏、2 倍密度：卡片 288dp，两侧各留 16dp。
        assertEquals(576, VoicePanelMetrics.cardWidthPx(640, 2f))
        assertEquals(268, VoicePanelMetrics.cardWidthPx(300, 1f))
        // 大屏与横屏不无限拉宽：上限 480dp。
        assertEquals(960, VoicePanelMetrics.cardWidthPx(2_160, 2f))
        assertEquals(0, VoicePanelMetrics.cardWidthPx(0, 2f))
        assertTrue(VoicePanelMetrics.cardWidthPx(320, 1f) <= 320)
        assertTrue(VoicePanelMetrics.cardWidthPx(320, 1f) > 0)
        // 触控下限与主题令牌同源，按钮不小于 48dp。
        assertTrue(AssistantNativeTheme.minTouchDp >= 48)
    }

    @Test
    fun `pcm limits match the frozen contract`() {
        assertEquals(30_000L, MAX_VOICE_MILLIS)
        assertEquals(30, MAX_VOICE_SECONDS)
        // 16 kHz 单声道 PCM16 × 30 秒。
        assertEquals(960_000, MAX_VOICE_PCM_BYTES)
        assertEquals(16_000, VOICE_SAMPLE_RATE)
        assertTrue(MIN_VOICE_PCM_BYTES < MAX_VOICE_PCM_BYTES)
        assertEquals(0, MAX_VOICE_PCM_BYTES % 2)
    }
}
