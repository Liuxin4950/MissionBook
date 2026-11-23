package chat.liuxin.mission_book

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.BitmapFactory
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.text.TextUtils
import android.text.InputType
import android.text.InputFilter
import android.text.TextWatcher
import android.text.Editable
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** 只呈现 Dart 工作区快照；草稿、回合和确认仍由应用持有。 */
internal class AssistantOverlayPanel(
    context: Context,
    onCapture: () -> Unit,
    onVoice: () -> Unit,
    private val onOpen: () -> Unit,
    private val onMission: (String) -> Unit,
    private val onRecord: (String) -> Unit,
    private val enableIme: () -> Unit,
    private val noticeOnly: Boolean = false,
) : LinearLayout(context) {
    private val heading = textView("书祺", AssistantNativeTheme.textBody, AssistantNativeTheme.textPrimary).apply {
        setTypeface(null, Typeface.BOLD); maxLines = 1; ellipsize = TextUtils.TruncateAt.END
    }
    private val hint = textView("正在准备助手…", AssistantNativeTheme.textCaption, AssistantNativeTheme.textSecondary)
    private val images = LinearLayout(context).apply { orientation = HORIZONTAL }
    private val imageStrip = HorizontalScrollView(context).apply {
        isHorizontalScrollBarEnabled = false
        addView(images, LayoutParams(-2, -2))
        visibility = GONE
    }
    private val timeline = LinearLayout(context).apply { orientation = VERTICAL }
    private val noticeArea = LinearLayout(context).apply { orientation = VERTICAL; visibility = GONE }
    private val moreArea = LinearLayout(context).apply { visibility = GONE; orientation = VERTICAL }
    private val tools = LinearLayout(context).apply { orientation = HORIZONTAL }
    private val body = LinearLayout(context).apply { orientation = VERTICAL }
    private val scroll = ScrollView(context).apply {
        isFillViewport = false
        addView(body, LayoutParams(-1, -2))
    }
    private val input = EditText(context).apply {
        hint = "问书祺…"
        textSize = AssistantNativeTheme.textMetadata
        minHeight = dp(AssistantNativeTheme.minTouchDp)
        inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
        imeOptions = EditorInfo.IME_ACTION_SEND or EditorInfo.IME_FLAG_NO_EXTRACT_UI
        maxLines = 3
        filters = arrayOf(InputFilter.LengthFilter(16000))
        setPadding(dp(AssistantNativeTheme.spaceSm), dp(AssistantNativeTheme.spaceXs),
            dp(AssistantNativeTheme.spaceSm), dp(AssistantNativeTheme.spaceXs))
        setTextColor(AssistantNativeTheme.textPrimary)
        setHintTextColor(AssistantNativeTheme.textSecondary)
        background = shape(AssistantNativeTheme.surfaceMuted, AssistantNativeTheme.radiusMd)
    }
    private val sendButton = icon(R.drawable.assistant_arrow_up, "发送", AssistantNativeTheme.primarySoft, AssistantNativeTheme.primary) {
        if (running) requestStop() else requestSend()
    }
    private val composer = LinearLayout(context).apply {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        addView(input, LayoutParams(0, -2, 1f))
        addView(sendButton, LayoutParams(dp(AssistantNativeTheme.minTouchDp), dp(AssistantNativeTheme.minTouchDp)).apply {
            marginStart = dp(AssistantNativeTheme.spaceSm)
        })
        setPadding(0, dp(AssistantNativeTheme.spaceXs), 0, 0)
        visibility = GONE
    }
    private var key: String? = null
    private var synced = ""
    private var editing = false
    private var hostWrite = false
    private var sendPending = false
    private var sending = false
    private var stopping = false
    private var busy = false
    private var changingInput = false
    private var photoIds = emptyList<String>()
    private var history: List<Map<*, *>> = emptyList()
    private var operations: List<Map<*, *>> = emptyList()
    private var partial = ""
    private var running = false
    var inConversation = false
        private set
    private var heightLimit = Int.MAX_VALUE
    private var previewId: String? = null
    private var snapshotRevision = -1
    private var snapshotGeneration = -1
    private var expectedDraft: String? = null
    private var draftMismatch: (() -> Unit)? = null
    private var pendingVoiceDraft: String? = null
    /** 当前仍在提醒面上的主动提醒身份；截图来源会带上它，恢复时据此保住提醒。 */
    var activeNoticeId: String? = null
        private set
    val showingNoticeOnly: Boolean get() = noticeOnly
    private val back = icon(R.drawable.assistant_back, "返回工具") { showTools() }.apply { visibility = GONE }

    init {
        orientation = VERTICAL
        descendantFocusability = FOCUS_BEFORE_DESCENDANTS
        isFocusableInTouchMode = true
        setPadding(dp(AssistantNativeTheme.spaceMd), dp(AssistantNativeTheme.spaceXs),
            dp(AssistantNativeTheme.spaceMd), dp(AssistantNativeTheme.spaceMd))
        background = AssistantNativeTheme.surface(
            context,
            AssistantNativeTheme.cardSurface,
            AssistantNativeTheme.radiusLg,
            AssistantNativeTheme.hairline,
            1f,
        )
        elevation = dp(4).toFloat()
        val titleRow = LinearLayout(context).apply {
            gravity = Gravity.CENTER_VERTICAL
            addView(back)
            addView(heading, LayoutParams(0, -2, 1f))
            addView(icon(R.drawable.assistant_more, "更多操作") {
                if (moreArea.visibility == VISIBLE) moreArea.visibility = GONE else showMore()
            })
        }
        addView(titleRow, LayoutParams(-1, -2))
        tools.addView(tool(R.drawable.assistant_capture, "截图", onCapture))
        tools.addView(tool(R.drawable.assistant_mic, "语音", onVoice))
        tools.addView(tool(R.drawable.assistant_chat, "文字") { openComposer(true) })
        body.addView(tools)
        body.addView(moreArea)
        body.addView(imageStrip)
        body.addView(noticeArea)
        body.addView(timeline)
        body.addView(hint)
        addView(scroll, LayoutParams(-1, -2, 1f))
        addView(composer, LayoutParams(-1, -2))
        timeline.visibility = GONE
        sendButton.isEnabled = false
        input.setOnTouchListener { _, event ->
            if (event.actionMasked == MotionEvent.ACTION_DOWN && !editing) {
                editing = true; enableIme()
                input.post { input.requestFocus(); context.getSystemService(InputMethodManager::class.java).showSoftInput(input, InputMethodManager.SHOW_IMPLICIT) }
            }
            false
        }
        input.setOnEditorActionListener { _, action, _ ->
            if (action == EditorInfo.IME_ACTION_SEND) { requestSend(); true } else false
        }
        input.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) {
                if (!changingInput) { updateSend(); syncDraft() }
            }
        })
        if (noticeOnly) {
            // 主动提醒面只承载提醒内容与动作，不重新出现“书祺 + 截图/语音/文字”的矩形工具首页。
            tools.visibility = GONE
            moreArea.visibility = GONE
            back.visibility = GONE
        }
        updateSend()
    }

    fun limitHeight(pixels: Int) {
        if (heightLimit != pixels) { heightLimit = pixels; requestLayout() }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val available = if (MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.UNSPECIFIED) heightLimit
            else minOf(heightLimit, MeasureSpec.getSize(heightMeasureSpec))
        super.onMeasure(widthMeasureSpec, MeasureSpec.makeMeasureSpec(available, MeasureSpec.AT_MOST))
    }

    private fun showMore() {
        moreArea.removeAllViews()
        moreArea.visibility = VISIBLE
        fun option(title: String, action: () -> Unit) {
            moreArea.addView(textView(title, AssistantNativeTheme.textMetadata, AssistantNativeTheme.textPrimary).apply {
                gravity = Gravity.CENTER_VERTICAL
                minHeight = dp(AssistantNativeTheme.minTouchDp)
                isFocusable = true
                background = touchSurface(AssistantNativeTheme.cardSurface, AssistantNativeTheme.radiusSm)
                setOnClickListener { moreArea.visibility = GONE; action() }
            }, LayoutParams(-1, -2).apply { topMargin = dp(AssistantNativeTheme.spaceXs) })
        }
        option("打开完整会话", onOpen)
        val status = AssistantUsageMonitorService.status(context)
        if (status["enabled"] != true) return
        val paused = status["paused"] == true
        option(if (paused) "恢复应用感知" else "暂停应用感知") {
            try { AssistantUsageMonitorService.configure(context, mapOf("paused" to !paused)) }
            catch (_: Exception) { showError("请在助手设置中恢复监督") }
        }
        scroll.scrollTo(0, 0)
    }

    fun load(onLoaded: (() -> Unit)? = null) = AssistantWorkspaceHost.call(
        "watch",
        failure = ::showError,
        success = {
            accept(it)
            onLoaded?.invoke()
        },
    )

    private fun accept(result: Any?) { (result as? Map<*, *>)?.let(::render) }

    fun render(state: Map<*, *>) {
        val target = state["key"] as? String ?: return
        val generation = state["generation"] as? Int ?: return
        val revision = state["revision"] as? Int ?: return
        if (generation == snapshotGeneration && revision <= snapshotRevision) return
        snapshotGeneration = generation; snapshotRevision = revision
        val draft = state["draft"] as? String ?: ""
        if (target != key || (!hostWrite && input.text.toString() == synced && draft != synced)) {
            key = target
            synced = draft
            changeInput(draft)
            sendPending = false
        }
        // 截图/语音恢复只认发起时绑定的草稿；会话已切换时明确报错，不把结果写到其它草稿。
        expectedDraft?.let { wanted ->
            expectedDraft = null
            if (wanted != key) {
                showError("原会话已切换，截图已保存在发起时的草稿")
                draftMismatch?.invoke()
                draftMismatch = null
                if (inConversation) showTools()
            }
        }
        pendingVoiceDraft?.let { wanted ->
            pendingVoiceDraft = null
            if (wanted == key) openComposer(false)
            else showError("语音结果已保存在原草稿，当前会话已切换")
        }
        heading.text = state["name"] as? String ?: "书祺"
        busy = state["busy"] == true
        val error = state["error"] as? String
        applyHint(error)
        hint.text = error ?: if (busy && inConversation && (state["partial"] as? String).isNullOrBlank()) "正在处理…" else ""
        hint.visibility = if (hint.text.isEmpty()) GONE else VISIBLE
        val photos = maps(state["images"])
        val nextIds = photos.mapNotNull { it["id"] as? String }
        if (nextIds != photoIds) {
            photoIds = nextIds
            images.removeAllViews()
            photos.forEach { addPhoto(target, it) }
            imageStrip.visibility = if (nextIds.isEmpty()) GONE else VISIBLE
            if (previewId != null && previewId !in nextIds) { previewId = null; redrawConversation() }
        }
        val messages = maps(state["messages"])
        val pending = maps(state["operations"])
        val body = state["partial"] as? String ?: ""
        val isRunning = state["running"] == true
        if (!isRunning) stopping = false
        if (messages != history || pending != operations || body != partial || running != isRunning) {
            history = messages; operations = pending; partial = body; running = isRunning
            redrawConversation()
        }
        updateSend()
    }

    fun showError(message: String) {
        applyHint(message)
        hint.visibility = VISIBLE
        hint.text = message
    }

    /** 错误状态用错误色与浅错误底；正常提示使用次要文字色，与悬浮主题保持同一套语义。 */
    private fun applyHint(error: String?) {
        hint.setTextColor(if (error == null) AssistantNativeTheme.textSecondary else AssistantNativeTheme.error)
        hint.background = if (error == null) null else shape(AssistantNativeTheme.errorSoft, AssistantNativeTheme.radiusSm)
    }

    fun notice(value: Map<*, *>, clear: () -> Unit) {
        val id = value["sessionId"] as? String ?: return
        val task = value["missionId"] as? String
        val message = value["message"] as? String ?: return
        activeNoticeId = id
        fun gone() {
            activeNoticeId = null
            noticeArea.visibility = GONE
            noticeArea.removeAllViews()
            clear()
        }
        fun dismiss(later: Boolean) {
            AssistantWorkspaceHost.call("dismissNotice", mapOf("later" to later), ::showError) { gone() }
        }
        noticeArea.removeAllViews()
        noticeArea.addView(textView(message, AssistantNativeTheme.textMetadata, AssistantNativeTheme.textPrimary).apply {
            background = shape(AssistantNativeTheme.primarySoft, AssistantNativeTheme.radiusMd)
        }, LayoutParams(-1, -2).apply { bottomMargin = dp(AssistantNativeTheme.spaceXs) })
        noticeArea.addView(actions("回复" to {
            AssistantWorkspaceHost.call("openNotice", mapOf("sessionId" to id), ::showError) { snapshot ->
                gone(); accept(snapshot); openComposer(true)
            }
        }, "稍后" to { dismiss(true) }, "本次不再" to { dismiss(false) }))
        if (task != null) noticeArea.addView(actions("回到任务" to { gone(); onMission(task) }))
        noticeArea.visibility = VISIBLE
    }

    /**
     * 截图来源是已有会话时，等工作区快照确认仍是同一草稿后再进入原会话。
     * [onMismatch] 让服务关闭面板回到主球，而不是把矩形工具首页当失败兜底。
     */
    fun expectDraft(target: String?, onMismatch: (() -> Unit)? = null) {
        expectedDraft = target
        draftMismatch = onMismatch
    }

    /** 语音结果回填：只有当前草稿仍是票据绑定的草稿时才打开输入区。 */
    fun showVoiceDraft(target: String) {
        val current = key
        if (current != null) {
            if (current != target) { showError("语音结果已保存在原草稿，当前会话已切换"); return }
            openComposer(false)
            load()
            return
        }
        pendingVoiceDraft = target
        load()
    }

    fun draftKey(): String? = key

    private fun changeInput(text: String) {
        changingInput = true
        input.setText(text)
        input.setSelection(input.text.length)
        changingInput = false
    }

    private fun syncDraft() {
        val target = key ?: return
        if (hostWrite) return
        val value = input.text.toString()
        if (value == synced) {
            if (sendPending) {
                sendPending = false
                sending = true
                updateSend()
                AssistantWorkspaceHost.call("send", mapOf("key" to target), failure = {
                    sending = false; updateSend(); showError(it)
                }) { sending = false; accept(it); updateSend() }
            }
            return
        }
        hostWrite = true
        AssistantWorkspaceHost.call("draft", mapOf("key" to target, "previous" to synced, "text" to value),
            failure = { hostWrite = false; sendPending = false; updateSend(); showError(it) }) {
            hostWrite = false
            if (key == target) { synced = value; syncDraft() }
        }
    }

    private fun requestSend() {
        if (running || !sendButton.isEnabled) return
        sendPending = true
        updateSend()
        syncDraft()
        hideKeyboard()
    }

    private fun requestStop() {
        val target = key ?: return
        if (!running || stopping) return
        stopping = true
        updateSend()
        AssistantWorkspaceHost.call("stop", mapOf("key" to target), failure = {
            stopping = false
            updateSend()
            showError(it)
        }, success = ::accept)
    }

    private fun updateSend() {
        val label = if (stopping) "正在停止" else if (running) "停止回复" else "发送"
        if (sendButton.contentDescription != label) {
            sendButton.setImageResource(if (running) R.drawable.assistant_stop else R.drawable.assistant_arrow_up)
            sendButton.contentDescription = label
            if (android.os.Build.VERSION.SDK_INT >= 26) sendButton.tooltipText = label
        }
        val enabled = key != null && if (running) !stopping else
            !busy && !sending && !sendPending && (input.text.isNotBlank() || photoIds.isNotEmpty())
        sendButton.isEnabled = enabled
        // 禁用状态用语义色而不是只降透明度，按压/焦点由统一水波纹提供。
        sendButton.background = AssistantNativeTheme.clickableSurface(
            context,
            if (enabled) AssistantNativeTheme.primarySoft else AssistantNativeTheme.disabled,
            AssistantNativeTheme.radiusXxl,
        )
        sendButton.imageTintList = ColorStateList.valueOf(
            if (enabled) AssistantNativeTheme.primary else AssistantNativeTheme.onDisabled,
        )
        sendButton.alpha = 1f
    }

    fun openConversation() = openComposer(false)

    private fun openComposer(focus: Boolean) {
        composer.visibility = VISIBLE
        inConversation = true
        // 提醒面进入会话后不再提供“返回工具”，避免把主动提醒面变成矩形工具首页。
        back.visibility = if (noticeOnly) GONE else VISIBLE
        tools.visibility = GONE; moreArea.visibility = GONE
        previewId = null
        redrawConversation()
        if (focus) {
            editing = true
            enableIme()
            input.requestFocus()
            input.post { context.getSystemService(InputMethodManager::class.java).showSoftInput(input, InputMethodManager.SHOW_IMPLICIT) }
        }
    }

    private fun showTools() {
        if (noticeOnly) return
        hideKeyboard(); requestFocus(); editing = false
        inConversation = false; previewId = null
        back.visibility = GONE; composer.visibility = GONE; moreArea.visibility = GONE
        tools.visibility = VISIBLE; timeline.visibility = GONE; timeline.removeAllViews()
        if (busy && hint.currentTextColor != AssistantNativeTheme.error) hint.visibility = GONE
        scroll.scrollTo(0, 0)
    }

    fun hideKeyboard() {
        if (editing) {
            context.getSystemService(InputMethodManager::class.java).hideSoftInputFromWindow(input.windowToken, 0)
        }
    }

    private fun command(method: String, extra: Map<String, Any?> = emptyMap()) {
        val target = key ?: return
        AssistantWorkspaceHost.call(method, extra + ("key" to target), ::showError, ::accept)
    }

    private fun addPhoto(target: String, photo: Map<*, *>) {
        val id = photo["id"] as? String ?: return
        val thumb = icon(R.drawable.assistant_capture, photo["name"] as? String ?: "预览附件", AssistantNativeTheme.primarySoft) { preview(target, id) }
        thumb.setPadding(0, 0, 0, 0); thumb.clipToOutline = true
        images.addView(thumb, LayoutParams(dp(AssistantNativeTheme.minTouchDp), dp(AssistantNativeTheme.minTouchDp)).apply {
            setMargins(0, dp(AssistantNativeTheme.spaceXs), dp(AssistantNativeTheme.spaceXs), 0)
        })
        AssistantWorkspaceHost.call("image", mapOf("key" to target, "image" to id), failure = {}) { payload ->
            if (key != target || id !in photoIds) return@call
            val bytes = payload as? ByteArray ?: return@call
            val bitmap = decode(bytes, 84) ?: return@call
            thumb.imageTintList = null
            thumb.scaleType = ImageView.ScaleType.CENTER_CROP
            thumb.setImageBitmap(bitmap)
        }
    }

    private fun preview(target: String, id: String) {
        AssistantWorkspaceHost.call("image", mapOf("key" to target, "image" to id), ::showError) { payload ->
            val bytes = payload as? ByteArray ?: return@call
            if (key != target || id !in photoIds || !isAttachedToWindow) return@call
            val image = decode(bytes, 640) ?: return@call
            previewId = id
            timeline.removeAllViews()
            addToTimeline(ImageView(context).apply {
                adjustViewBounds = true
                setImageBitmap(image)
                contentDescription = "截图预览"
            })
            addToTimeline(actions("返回" to { previewId = null; redrawConversation() }, "移除图片" to {
                previewId = null; command("removeImage", mapOf("image" to id)); redrawConversation()
            }))
            addToTimeline(actions("保存为记录" to {
                AssistantWorkspaceHost.call("stageRecord", mapOf("key" to target, "image" to id), ::showError) {
                    (it as? String)?.let(onRecord)
                }
            }))
            timeline.visibility = VISIBLE
        }
    }

    private fun redrawConversation() {
        if (previewId != null) return
        if (!inConversation) { timeline.visibility = GONE; return }
        val priorScroll = scroll.scrollY
        val following = !scroll.canScrollVertically(1)
        timeline.removeAllViews()
        for (message in history) {
            val user = message["user"] == true
            val count = message["images"] as? Int ?: 0
            val body = message["text"] as? String ?: ""
            val content = if (count == 0) body else if (body.isBlank()) "$count 张图片" else body + "\n$count 张图片"
            addMessage(content, user)
        }
        if (running && partial.isNotBlank()) addMessage(partial, false)
        for (operation in operations) {
            val id = operation["id"] as? String ?: continue
            val state = operation["status"]
            if (state !in setOf("waitingConfirmation", "unknown", "succeeded", "failed")) continue
            val label = operation["label"] as? String ?: "操作"
            val detail = (operation["detail"] as? String).orEmpty()
            val preview = (operation["preview"] as? String).orEmpty()
            val status = when (state) { "succeeded" -> if (operation["writes"] == true) "已保存" else "已读取"; "failed" -> "未完成"; "unknown" -> "结果待核对"; else -> "待确认" }
            addToTimeline(textView(listOf("$label · $status", preview, detail).filter(String::isNotBlank).joinToString("\n"), AssistantNativeTheme.textMetadata, AssistantNativeTheme.textPrimary))
            if (state == "waitingConfirmation") {
                val reject = "取消" to { command("reject", mapOf("operation" to id)) }
                if (operation["confirmable"] == true) addToTimeline(actions(reject, "确认" to { command("confirm", mapOf("operation" to id, "version" to operation["version"])) }))
                else addToTimeline(actions(reject, "打开核对" to onOpen))
            } else if (state == "unknown") {
                addToTimeline(actions("核对结果" to { command("checkOutcome", mapOf("operation" to id)) }))
            } else if (state == "succeeded") {
                (operation["missionId"] as? String)?.let { mission ->
                    addToTimeline(actions("查看日程" to { onMission(mission) }))
                }
            }
        }
        timeline.visibility = if (timeline.childCount == 0) GONE else VISIBLE
        scroll.post { scroll.scrollTo(0, if (following && moreArea.visibility != VISIBLE) body.height else priorScroll) }
    }

    private fun addMessage(content: String, user: Boolean) {
        val message = textView(content, AssistantNativeTheme.textMetadata, AssistantNativeTheme.textPrimary).apply {
            setPadding(dp(AssistantNativeTheme.spaceSm), dp(AssistantNativeTheme.spaceXs),
                dp(AssistantNativeTheme.spaceSm), dp(AssistantNativeTheme.spaceXs))
            background = shape(
                if (user) AssistantNativeTheme.primarySoft else AssistantNativeTheme.pageBackground,
                AssistantNativeTheme.radiusMd,
            )
        }
        timeline.addView(message, LayoutParams(-2, -2).apply {
            gravity = if (user) Gravity.END else Gravity.START
            setMargins(
                if (user) dp(AssistantNativeTheme.spaceXl) else 0, dp(AssistantNativeTheme.spaceXs),
                if (user) 0 else dp(AssistantNativeTheme.spaceXl), dp(AssistantNativeTheme.spaceXs),
            )
        })
    }

    private fun addToTimeline(view: View, left: Int = 0, right: Int = 0) {
        timeline.addView(view, LayoutParams(-1, -2).apply { setMargins(left, 0, right, dp(AssistantNativeTheme.spaceXs)) })
    }

    private fun actions(vararg items: Pair<String, () -> Unit>) = LinearLayout(context).apply {
        gravity = Gravity.END
        items.forEach { (title, action) ->
            addView(textView(title, AssistantNativeTheme.textMetadata, AssistantNativeTheme.primary).apply {
                minHeight = dp(AssistantNativeTheme.minTouchDp)
                gravity = Gravity.CENTER
                isFocusable = true
                background = RippleDrawable(ColorStateList.valueOf(AssistantNativeTheme.ripple), null, null)
                setOnClickListener { action() }
            }, LayoutParams(0, -2, 1f))
        }
    }

    private fun textView(value: String, size: Float, color: Int) = TextView(context).apply {
        text = value; textSize = size; setTextColor(color)
        setPadding(dp(AssistantNativeTheme.spaceSm), dp(AssistantNativeTheme.spaceXs),
            dp(AssistantNativeTheme.spaceSm), dp(AssistantNativeTheme.spaceXs))
    }

    private fun tool(resource: Int, label: String, action: () -> Unit) = LinearLayout(context).apply {
        orientation = VERTICAL; gravity = Gravity.CENTER
        layoutParams = LayoutParams(0, -2, 1f)
        minimumHeight = dp(AssistantNativeTheme.minTouchDp)
        addView(ImageView(context).apply {
            setImageResource(resource); imageTintList = ColorStateList.valueOf(AssistantNativeTheme.primary)
            setPadding(dp(AssistantNativeTheme.spaceSm), dp(AssistantNativeTheme.spaceSm),
                dp(AssistantNativeTheme.spaceSm), dp(AssistantNativeTheme.spaceSm))
            background = shape(AssistantNativeTheme.primarySoft, AssistantNativeTheme.radiusXxl)
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LayoutParams(dp(40), dp(40)))
        addView(textView(label, AssistantNativeTheme.textCaption, AssistantNativeTheme.textPrimary).apply {
            gravity = Gravity.CENTER
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        })
        contentDescription = label; isFocusable = true
        background = touchSurface(AssistantNativeTheme.cardSurface, AssistantNativeTheme.radiusSm)
        if (android.os.Build.VERSION.SDK_INT >= 26) tooltipText = label
        setOnClickListener { action() }
    }

    private fun icon(resource: Int, label: String, fill: Int = AssistantNativeTheme.cardSurface, tint: Int = AssistantNativeTheme.primary, action: () -> Unit) = ImageButton(context).apply {
        layoutParams = LayoutParams(dp(AssistantNativeTheme.minTouchDp), dp(AssistantNativeTheme.minTouchDp))
        setPadding(dp(AssistantNativeTheme.spaceMd), dp(AssistantNativeTheme.spaceMd),
            dp(AssistantNativeTheme.spaceMd), dp(AssistantNativeTheme.spaceMd))
        setImageResource(resource); imageTintList = ColorStateList.valueOf(tint)
        contentDescription = label
        if (android.os.Build.VERSION.SDK_INT >= 26) tooltipText = label
        background = touchSurface(fill, AssistantNativeTheme.radiusXxl)
        setOnClickListener { action() }
    }

    private fun touchSurface(color: Int, radiusDp: Float): RippleDrawable =
        AssistantNativeTheme.clickableSurface(context, color, radiusDp)

    private fun shape(color: Int, radiusDp: Float): GradientDrawable =
        AssistantNativeTheme.surface(context, color, radiusDp)

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun maps(value: Any?) = (value as? List<*>)?.filterIsInstance<Map<*, *>>() ?: emptyList()
    private fun decode(bytes: ByteArray, size: Int) = BitmapFactory.Options().run {
        inJustDecodeBounds = true
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, this)
        inSampleSize = 1
        while (maxOf(outWidth, outHeight) / inSampleSize > size * 2) inSampleSize *= 2
        inJustDecodeBounds = false
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, this)
    }
}
