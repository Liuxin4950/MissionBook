package chat.liuxin.mission_book

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.view.animation.PathInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/** 圆形动作层的动作身份；主层与“更多”层的顺序由各自常量唯一给出，几何与渲染共用。 */
internal enum class QuickMenuAction(val label: String) {
    Text("文字"),
    Voice("语音"),
    Capture("截图"),
    More("更多"),
    Conversation("会话"),
    Usage("感知"),
    Close("关闭"),
    Back("返回"),
}

/** 纯几何包含判断：动作必须完整落在屏幕可用区域内。 */
private fun OverlayPanelPlacement.Box.containsBox(other: OverlayPanelPlacement.Box): Boolean =
    other.left >= left && other.top >= top && other.right <= right && other.bottom <= bottom

/** 纯几何相交判断：圆形动作之间不能互相遮挡触控。 */
private fun OverlayPanelPlacement.Box.intersectsBox(other: OverlayPanelPlacement.Box): Boolean =
    left < other.right && other.left < right && top < other.bottom && other.top < bottom

/** 主悬浮球展开后的轻量圆形动作层；聊天内容仍由 AssistantOverlayPanel 承担。 */
internal class AssistantOverlayQuickMenu(
    context: Context,
    private val placement: Placement,
    private val duration: Long,
    private val onText: () -> Unit,
    private val onVoice: () -> Unit,
    private val onCapture: () -> Unit,
    private val onOpen: () -> Unit,
    private val onUsage: () -> Unit,
    private val onClose: () -> Unit,
    private val usageTitle: () -> String,
) : FrameLayout(context) {
    init {
        layoutDirection = LAYOUT_DIRECTION_LTR
        showPrimary()
    }

    private fun showPrimary() {
        removeAllViews()
        primaryActions.forEach { action -> addItem(titleFor(action), iconFor(action), handlerFor(action)) }
    }

    fun showMoreActions(animate: Boolean = true) {
        removeAllViews()
        moreActions.forEach { action ->
            addItem(titleFor(action), iconFor(action), handlerFor(action), animate,
                description = if (action == QuickMenuAction.Close) "关闭悬浮球" else titleFor(action))
        }
    }

    private fun titleFor(action: QuickMenuAction): String =
        if (action == QuickMenuAction.Usage) usageTitle() else action.label

    private fun iconFor(action: QuickMenuAction): Int = when (action) {
        QuickMenuAction.Text -> R.drawable.assistant_chat
        QuickMenuAction.Voice -> R.drawable.assistant_mic
        QuickMenuAction.Capture -> R.drawable.assistant_capture
        QuickMenuAction.More -> R.drawable.assistant_more
        QuickMenuAction.Conversation -> R.drawable.assistant_chat
        QuickMenuAction.Usage -> R.drawable.assistant_compass
        QuickMenuAction.Close -> R.drawable.assistant_close
        QuickMenuAction.Back -> R.drawable.assistant_back
    }

    private fun handlerFor(action: QuickMenuAction): () -> Unit = when (action) {
        QuickMenuAction.Text -> onText
        QuickMenuAction.Voice -> onVoice
        QuickMenuAction.Capture -> onCapture
        QuickMenuAction.More -> ({ showMoreActions() })
        QuickMenuAction.Conversation -> onOpen
        QuickMenuAction.Usage -> onUsage
        QuickMenuAction.Close -> onClose
        QuickMenuAction.Back -> ({ showPrimary() })
    }

    private fun addItem(title: String, icon: Int, action: () -> Unit, animate: Boolean = true,
                        description: String = title) {
        val index = childCount
        val target = placement.buttons[index]
        val contentColors = contentColors()
        val item = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            isClickable = true
            isFocusable = true
            contentDescription = description
            if (android.os.Build.VERSION.SDK_INT >= 26) tooltipText = description
            background = RippleDrawable(
                ColorStateList.valueOf(AssistantNativeTheme.ripple),
                oval(AssistantNativeTheme.pageBackground),
                oval(AssistantNativeTheme.cardSurface),
            )
            elevation = dp(5).toFloat()
            setOnClickListener { action() }
        }
        item.addView(ImageView(context).apply {
            setImageResource(icon)
            imageTintList = contentColors
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LayoutParams(dp(21), dp(21)))
        item.addView(TextView(context).apply {
            text = title
            setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, AssistantNativeTheme.textCaption)
            setTextColor(contentColors)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            maxLines = 1
            includeFontPadding = false
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LayoutParams(-1, LayoutParams.WRAP_CONTENT))
        val window = placement.window
        if (animate && duration > 0L) {
            // 首帧以真实球心为起点，沿各自半径向外移，不依赖子 View 已完成测量。
            item.alpha = 0f
            item.scaleX = .55f
            item.scaleY = .55f
            item.translationX = placement.anchorX - (target.left + target.right) / 2f
            item.translationY = placement.anchorY - (target.top + target.bottom) / 2f
        }
        addView(item, LayoutParams(target.width, target.height, Gravity.TOP or Gravity.LEFT).apply {
            leftMargin = target.left - window.left
            topMargin = target.top - window.top
        })
        if (animate && duration > 0L) {
            item.postOnAnimation {
                if (!item.isAttachedToWindow || item.parent !== this) return@postOnAnimation
                item.animate().alpha(1f).scaleX(1f).scaleY(1f).translationX(0f).translationY(0f)
                    .setStartDelay(index * 22L).setDuration(duration + 40L)
                    .setInterpolator(PathInterpolator(.22f, .75f, .25f, 1f)).start()
            }
        }
    }

    /** 图标与文字共用的状态色：按压/焦点加深，禁用回到弱化色，其余用主色。 */
    private fun contentColors(): ColorStateList = ColorStateList(
        arrayOf(
            intArrayOf(android.R.attr.state_enabled, android.R.attr.state_pressed),
            intArrayOf(android.R.attr.state_enabled, android.R.attr.state_focused),
            intArrayOf(-android.R.attr.state_enabled),
            intArrayOf(),
        ),
        intArrayOf(
            AssistantNativeTheme.primaryPressed,
            AssistantNativeTheme.primaryPressed,
            AssistantNativeTheme.onDisabled,
            AssistantNativeTheme.primary,
        ),
    )

    private fun oval(color: Int, strokeColor: Int? = null) = GradientDrawable().apply {
        shape = GradientDrawable.OVAL
        setColor(color)
        setStroke(dp(1), strokeColor ?: AssistantNativeTheme.hairline)
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density + .5f).toInt()

    /** 窗口与四个动作的纯几何（屏幕坐标），不依赖 Android Rect，便于 JVM 回归。 */
    internal data class Placement(
        val window: OverlayPanelPlacement.Box,
        val buttons: List<OverlayPanelPlacement.Box>,
        val anchorX: Float,
        val anchorY: Float,
    )

    companion object {
        /** 主层动作顺序：文字、语音、截图、更多。 */
        internal val primaryActions = listOf(
            QuickMenuAction.Text,
            QuickMenuAction.Voice,
            QuickMenuAction.Capture,
            QuickMenuAction.More,
        )

        /** 更多层动作顺序：会话、应用感知、关闭悬浮球、返回。 */
        internal val moreActions = listOf(
            QuickMenuAction.Conversation,
            QuickMenuAction.Usage,
            QuickMenuAction.Close,
            QuickMenuAction.Back,
        )

        /** 在球的内侧布置四个等角度动作；窗口不覆盖主球的触控区域。 */
        fun place(frame: OverlayPanelPlacement.Box, ball: OverlayPanelPlacement.Box, dp: (Int) -> Int): Placement? {
            val anchorX = (ball.left + ball.right) / 2f
            val anchorY = (ball.top + ball.bottom) / 2f
            val opensLeft = anchorX >= (frame.left + frame.right) / 2f
            val edge = if (opensLeft) ball.left else ball.right
            val available = if (opensLeft) edge - frame.left else frame.right - edge
            val size = dp(50)
            val pad = dp(5)
            val radius = minOf(dp(101).toFloat(), (available - size / 2f - pad) / .95f)
            if (radius <= size) return null
            val angles = listOf(-60.0, -20.0, 20.0, 60.0).map(Math::toRadians)
            val offsetsY = angles.map { (sin(it) * radius).roundToInt() }
            val upper = frame.top + pad + size / 2 - offsetsY.first()
            val lower = frame.bottom - pad - (size - size / 2) - offsetsY.last()
            if (upper > lower) return null
            val centerY = anchorY.roundToInt().coerceIn(upper, lower)
            val direction = if (opensLeft) -1 else 1
            val limit = ((if (opensLeft) anchorX - edge else edge - anchorX) + size / 2f + pad).roundToInt()
            val buttons = angles.mapIndexed { index, angle ->
                val dx = (cos(angle) * radius).roundToInt().coerceAtLeast(limit)
                val left = (anchorX + direction * dx).roundToInt() - size / 2
                val top = centerY + offsetsY[index] - size / 2
                OverlayPanelPlacement.Box(left, top, left + size, top + size)
            }
            if (buttons.any { !frame.containsBox(it) } || buttons.indices.any { i ->
                buttons.drop(i + 1).any { buttons[i].intersectsBox(it) }
            }) return null
            val window = OverlayPanelPlacement.Box(
                if (opensLeft) maxOf(frame.left, buttons.minOf { it.left } - pad) else edge,
                minOf(buttons.first().top - pad, anchorY.roundToInt()),
                if (opensLeft) edge else minOf(frame.right, buttons.maxOf { it.right } + pad),
                maxOf(buttons.last().bottom + pad, anchorY.roundToInt() + 1),
            )
            return Placement(window, buttons, anchorX, anchorY)
        }
    }
}
