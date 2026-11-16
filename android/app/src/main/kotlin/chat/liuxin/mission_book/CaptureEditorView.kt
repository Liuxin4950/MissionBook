package chat.liuxin.mission_book

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.view.KeyEvent
import android.view.WindowInsets
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView

/** 顶部单行工具栏；窄屏 / 大字号可横向滚动，不挤压截图画布。 */
internal class CaptureEditorView(
    context: Context,
    image: Bitmap,
    onConfirm: (android.graphics.Rect) -> Unit,
    onLongCapture: (android.graphics.Rect) -> Unit,
    private val onCancel: () -> Unit,
) : FrameLayout(context) {
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private val canvas = CaptureSelectionView(context, image)
    init {
        addView(canvas, LayoutParams(-1, -1))
        val toolbar = LinearLayout(context).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(6), dp(4), dp(6), dp(4))
            background = GradientDrawable().apply {
                setColor(0xFFF7F8F5.toInt()); cornerRadius = dp(16).toFloat()
                setStroke(dp(1), 0xFFE0E7DF.toInt())
            }
            elevation = dp(3).toFloat()
        }
        val scroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            isFillViewport = false
            addView(toolbar)
        }
        val barParams = LayoutParams(-2, -2, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply {
            leftMargin = dp(12); rightMargin = dp(12); topMargin = dp(12)
        }
        addView(scroll, barParams)
        setOnApplyWindowInsetsListener { _, insets ->
            val top = if (android.os.Build.VERSION.SDK_INT >= 30) {
                insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()).top
            } else @Suppress("DEPRECATION") insets.systemWindowInsetTop
            barParams.topMargin = top + dp(12)
            scroll.layoutParams = barParams
            insets
        }
        fun tool(label: String, action: () -> Unit): TextView {
            return TextView(context).apply {
                text = label
                textSize = 13f
                setTextColor(0xFF244D3D.toInt())
                gravity = Gravity.CENTER
                minWidth = dp(48)
                minimumHeight = dp(48)
                setPadding(dp(12), 0, dp(12), 0)
                isFocusable = true
                contentDescription = label
                background = RippleDrawable(ColorStateList.valueOf(0x22244D3D), GradientDrawable().apply {
                    setColor(Color.TRANSPARENT); cornerRadius = dp(12).toFloat()
                }, null)
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
            region.setTextColor(if (all) 0xFF748077.toInt() else 0xFF244D3D.toInt())
            full.setTextColor(if (all) 0xFF244D3D.toInt() else 0xFF748077.toInt())
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
            textSize = 12f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setShadowLayer(dp(2).toFloat(), 0f, 0f, 0x88000000.toInt())
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        addView(hint, LayoutParams(-1, -2, Gravity.BOTTOM).apply { bottomMargin = dp(56) })
        canvas.onSelectionChanged = {
            done.isEnabled = canvas.crop() != null
            done.alpha = if (done.isEnabled) 1f else .4f
        }
        done.isEnabled = false
        done.alpha = .4f
        select(false)
        isFocusableInTouchMode = true
        requestFocus()
    }
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_UP && (event.keyCode == KeyEvent.KEYCODE_BACK || event.keyCode == KeyEvent.KEYCODE_ESCAPE)) {
            onCancel(); return true
        }
        return super.dispatchKeyEvent(event)
    }
}
