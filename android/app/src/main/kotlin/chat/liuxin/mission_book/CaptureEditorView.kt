package chat.liuxin.mission_book

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.view.KeyEvent
import android.view.WindowInsets
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * 顶部单行工具栏；窄屏 / 大字号可横向滚动，不挤压截图画布。
 * 画布保持黑色媒体画布，控制条使用暖白 + 森林绿语义 token。
 */
internal class CaptureEditorView(
    context: Context,
    image: Bitmap,
    onConfirm: (android.graphics.Rect) -> Unit,
    onLongCapture: (android.graphics.Rect) -> Unit,
    private val onCancel: () -> Unit,
) : FrameLayout(context) {
    private fun dp(value: Int) = AssistantNativeTheme.dp(context, value)
    private val canvas = CaptureSelectionView(context, image)
    init {
        addView(canvas, LayoutParams(-1, -1))
        val toolbar = LinearLayout(context).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(AssistantNativeTheme.spaceXs), dp(AssistantNativeTheme.spaceXs),
                dp(AssistantNativeTheme.spaceXs), dp(AssistantNativeTheme.spaceXs))
            background = AssistantNativeTheme.surface(
                context,
                AssistantNativeTheme.cardSurface,
                AssistantNativeTheme.radiusLg,
                AssistantNativeTheme.hairline,
                1f,
            )
            elevation = dp(3).toFloat()
        }
        val scroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            isFillViewport = false
            addView(toolbar)
        }
        val barParams = LayoutParams(-2, -2, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply {
            leftMargin = dp(AssistantNativeTheme.spaceMd)
            rightMargin = dp(AssistantNativeTheme.spaceMd)
            topMargin = dp(AssistantNativeTheme.spaceMd)
        }
        addView(scroll, barParams)
        setOnApplyWindowInsetsListener { _, insets ->
            val top = if (android.os.Build.VERSION.SDK_INT >= 30) {
                insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()).top
            } else @Suppress("DEPRECATION") insets.systemWindowInsetTop
            barParams.topMargin = top + dp(AssistantNativeTheme.spaceMd)
            scroll.layoutParams = barParams
            insets
        }
        fun tool(label: String, action: () -> Unit): TextView {
            return TextView(context).apply {
                text = label
                setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, AssistantNativeTheme.textBody)
                setTextColor(actionColors())
                gravity = Gravity.CENTER
                minWidth = dp(AssistantNativeTheme.minTouchDp)
                minimumHeight = dp(AssistantNativeTheme.minTouchDp)
                setPadding(dp(AssistantNativeTheme.spaceMd), 0, dp(AssistantNativeTheme.spaceMd), 0)
                isFocusable = true
                contentDescription = label
                background = RippleDrawable(
                    ColorStateList.valueOf(AssistantNativeTheme.ripple),
                    AssistantNativeTheme.surface(context, Color.TRANSPARENT, AssistantNativeTheme.radiusMd),
                    null,
                )
                setOnClickListener { action() }
                toolbar.addView(this, LinearLayout.LayoutParams(-2, -2))
            }
        }
        lateinit var region: TextView
        lateinit var full: TextView
        fun select(all: Boolean) {
            canvas.fullScreen = all
            region.isSelected = !all
            full.isSelected = all
            region.setTextColor(if (all) AssistantNativeTheme.textSecondary else AssistantNativeTheme.primary)
            full.setTextColor(if (all) AssistantNativeTheme.primary else AssistantNativeTheme.textSecondary)
            region.paint.isFakeBoldText = !all
            full.paint.isFakeBoldText = all
            region.invalidate(); full.invalidate()
        }
        region = tool("局部") { select(false) }
        full = tool("全屏") { select(true) }
        val long = tool("长截图") {
            // 尚未框选时，长截图默认整屏；已有选区时沿选区采集。
            if (canvas.selection.box == null) canvas.fullScreen = true
            canvas.crop()?.let(onLongCapture)
        }
        long.contentDescription = "长截图，框选后只拼接选区，未框选时使用全屏"
        val done = tool("完成") { canvas.crop()?.let(onConfirm) }
        tool("×") { onCancel() }.contentDescription = "取消截图"
        val hint = TextView(context).apply {
            text = "拖动框选 · 框内移动 · 四角调整"
            setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, AssistantNativeTheme.textMetadata)
            gravity = Gravity.CENTER
            setTextColor(AssistantNativeTheme.onMedia)
            setShadowLayer(dp(2).toFloat(), 0f, 0f, AssistantNativeTheme.shadow)
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        addView(hint, LayoutParams(-1, -2, Gravity.BOTTOM).apply { bottomMargin = dp(56) })
        canvas.onSelectionChanged = {
            done.isEnabled = canvas.crop() != null
            done.setTextColor(if (done.isEnabled) AssistantNativeTheme.primary else AssistantNativeTheme.onDisabled)
            done.alpha = 1f
        }
        done.isEnabled = false
        done.setTextColor(AssistantNativeTheme.onDisabled)
        select(false)
        isFocusableInTouchMode = true
        requestFocus()
    }

    /** 截图工具动作的按压/焦点/禁用状态色。 */
    private fun actionColors(): ColorStateList = ColorStateList(
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

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_UP && (event.keyCode == KeyEvent.KEYCODE_BACK || event.keyCode == KeyEvent.KEYCODE_ESCAPE)) {
            onCancel(); return true
        }
        return super.dispatchKeyEvent(event)
    }
}
