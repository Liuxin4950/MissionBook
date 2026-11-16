package chat.liuxin.mission_book

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View

/** 直接遮罩已定格的当前画面；拖选、移动、拖角调整共用一套坐标。 */
internal class CaptureSelectionView(context: Context, private val image: Bitmap) : View(context) {
    val selection = CaptureSelection()
    var onSelectionChanged: (() -> Unit)? = null
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val density = resources.displayMetrics.density
    var fullScreen = false
        set(value) { field = value; if (value) selection.full() else selection.clear(); changed() }

    init {
        isFocusable = true
        contentDescription = "截图选区，拖动框选，框内移动，四角调整。可用顶部全屏按钮选择全部画面。"
    }
    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        selection.bounds(w.toFloat(), h.toFloat())
        if (fullScreen) selection.full()
    }
    fun crop(): Rect? {
        if (!selection.valid(24 * density)) return null
        val b = selection.box ?: return null
        return Rect(
            (b.left * image.width / width).toInt().coerceIn(0, image.width - 1),
            (b.top * image.height / height).toInt().coerceIn(0, image.height - 1),
            (b.right * image.width / width).toInt().coerceIn(1, image.width),
            (b.bottom * image.height / height).toInt().coerceIn(1, image.height),
        )
    }
    private fun changed() { invalidate(); onSelectionChanged?.invoke() }
    override fun onDraw(canvas: Canvas) {
        canvas.drawBitmap(image, null, Rect(0, 0, width, height), paint.apply { color = Color.WHITE; style = Paint.Style.FILL })
        val b = selection.box
        paint.color = 0x660E1B14
        if (b == null) canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        else {
            canvas.drawRect(0f, 0f, width.toFloat(), b.top, paint)
            canvas.drawRect(0f, b.top, b.left, b.bottom, paint)
            canvas.drawRect(b.right, b.top, width.toFloat(), b.bottom, paint)
            canvas.drawRect(0f, b.bottom, width.toFloat(), height.toFloat(), paint)
            paint.color = 0xFF78AC8B.toInt()
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 2 * density
            canvas.drawRect(RectF(b.left, b.top, b.right, b.bottom), paint)
            paint.style = Paint.Style.FILL
            for (point in arrayOf(b.left to b.top, b.right to b.top, b.right to b.bottom, b.left to b.bottom)) {
                canvas.drawCircle(point.first, point.second, 5 * density, paint)
            }
        }
    }
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (fullScreen) return true
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> selection.begin(event.x, event.y, 24 * density)
            MotionEvent.ACTION_MOVE -> selection.drag(event.x, event.y)
            MotionEvent.ACTION_UP -> { selection.drag(event.x, event.y); performClick() }
            MotionEvent.ACTION_CANCEL -> selection.cancel()
            else -> return true
        }
        changed()
        return true
    }
    override fun performClick(): Boolean { super.performClick(); return true }
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_ESCAPE) { selection.clear(); changed(); return true }
        return super.onKeyDown(keyCode, event)
    }
}
