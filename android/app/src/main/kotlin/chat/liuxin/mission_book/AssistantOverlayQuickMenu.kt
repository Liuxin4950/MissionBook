package chat.liuxin.mission_book

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Rect
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
    private val usageTitle: () -> String,
) : FrameLayout(context) {
    init {
        layoutDirection = LAYOUT_DIRECTION_LTR
        showPrimary()
    }

    private fun showPrimary() {
        removeAllViews()
        addItem("文字", R.drawable.assistant_chat, onText)
        addItem("语音", R.drawable.assistant_mic, onVoice)
        addItem("截图", R.drawable.assistant_capture, onCapture)
        addItem("更多", R.drawable.assistant_more, { showMoreActions() })
    }

    fun showMoreActions(animate: Boolean = true) {
        removeAllViews()
        addItem("会话", R.drawable.assistant_chat, onOpen, animate)
        addItem("截图", R.drawable.assistant_capture, onCapture, animate)
        addItem(usageTitle(), R.drawable.assistant_compass, onUsage, animate)
        addItem("返回", R.drawable.assistant_back, ::showPrimary, animate)
    }

    private fun addItem(title: String, icon: Int, action: () -> Unit, animate: Boolean = true) {
        val index = childCount
        val target = placement.buttons[index]
        val item = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            isClickable = true
            isFocusable = true
            contentDescription = title
            if (android.os.Build.VERSION.SDK_INT >= 26) tooltipText = title
            background = RippleDrawable(
                ColorStateList.valueOf(0x33244D3D),
                shape(CARD),
                shape(android.graphics.Color.WHITE),
            )
            elevation = dp(5).toFloat()
            setOnClickListener { action() }
        }
        item.addView(ImageView(context).apply {
            setImageResource(icon)
            imageTintList = ColorStateList.valueOf(GREEN)
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LayoutParams(dp(21), dp(21)))
        item.addView(TextView(context).apply {
            text = title
            textSize = 10f
            setTextColor(GREEN)
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
            item.translationX = placement.anchorX - target.exactCenterX()
            item.translationY = placement.anchorY - target.exactCenterY()
        }
        addView(item, LayoutParams(target.width(), target.height(), Gravity.TOP or Gravity.LEFT).apply {
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

    private fun shape(color: Int) = GradientDrawable().apply {
        shape = GradientDrawable.OVAL
        setColor(color)
        setStroke(dp(1), 0xFFD5E1D8.toInt())
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density + .5f).toInt()

    internal data class Placement(
        val window: Rect,
        val buttons: List<Rect>,
        val anchorX: Float,
        val anchorY: Float,
    )

    companion object {
        private const val GREEN = 0xFF244D3D.toInt()
        private const val CARD = 0xFFF7F8F5.toInt()

        /** 在球的内侧布置四个等角度动作；窗口不覆盖主球的触控区域。 */
        fun place(frame: Rect, ball: Rect, dp: (Int) -> Int): Placement? {
            val anchorX = ball.exactCenterX()
            val anchorY = ball.exactCenterY()
            val opensLeft = anchorX >= frame.exactCenterX()
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
                Rect(left, top, left + size, top + size)
            }
            if (buttons.any { !frame.contains(it) } || buttons.indices.any { i ->
                buttons.drop(i + 1).any { Rect.intersects(buttons[i], it) }
            }) return null
            val window = Rect(
                if (opensLeft) maxOf(frame.left, buttons.minOf { it.left } - pad) else edge,
                minOf(buttons.first().top - pad, anchorY.roundToInt()),
                if (opensLeft) edge else minOf(frame.right, buttons.maxOf { it.right } + pad),
                maxOf(buttons.last().bottom + pad, anchorY.roundToInt() + 1),
            )
            return Placement(window, buttons, anchorX, anchorY)
        }
    }
}
