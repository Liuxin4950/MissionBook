package chat.liuxin.mission_book

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** 屏幕像素坐标的可移动矩形；与 Bitmap / View 分离，以验证边界与裁剪坐标。 */
internal class CaptureSelection {
    data class Box(val left: Float, val top: Float, val right: Float, val bottom: Float) {
        val width get() = right - left
        val height get() = bottom - top
    }
    var box: Box? = null
        private set
    private var original: Box? = null
    private var startX = 0f
    private var startY = 0f
    private var mode = 0
    private var width = 0f
    private var height = 0f

    fun bounds(width: Float, height: Float) {
        this.width = width
        this.height = height
        box = box?.let { Box(it.left.coerceIn(0f, width), it.top.coerceIn(0f, height), it.right.coerceIn(0f, width), it.bottom.coerceIn(0f, height)) }
    }
    fun clear() { box = null }
    fun full() { box = Box(0f, 0f, width, height) }
    fun begin(x: Float, y: Float, handle: Float) {
        startX = x.coerceIn(0f, width)
        startY = y.coerceIn(0f, height)
        original = box
        val b = box
        mode = when {
            b == null -> 0
            abs(x - b.left) < handle && abs(y - b.top) < handle -> 1
            abs(x - b.right) < handle && abs(y - b.top) < handle -> 2
            abs(x - b.right) < handle && abs(y - b.bottom) < handle -> 3
            abs(x - b.left) < handle && abs(y - b.bottom) < handle -> 4
            x in b.left..b.right && y in b.top..b.bottom -> 5
            else -> 0
        }
        if (mode == 0) box = Box(startX, startY, startX, startY)
    }
    fun drag(x: Float, y: Float) {
        val px = x.coerceIn(0f, width)
        val py = y.coerceIn(0f, height)
        val b = original
        box = if (mode == 5 && b != null) {
            val dx = (px - startX).coerceIn(-b.left, width - b.right)
            val dy = (py - startY).coerceIn(-b.top, height - b.bottom)
            Box(b.left + dx, b.top + dy, b.right + dx, b.bottom + dy)
        } else {
            val anchorX = when (mode) { 1, 4 -> b!!.right; 2, 3 -> b!!.left; else -> startX }
            val anchorY = when (mode) { 1, 2 -> b!!.bottom; 3, 4 -> b!!.top; else -> startY }
            Box(min(anchorX, px), min(anchorY, py), max(anchorX, px), max(anchorY, py))
        }
    }
    fun cancel() { box = original }
    fun valid(minimum: Float) = box?.let { it.width >= minimum && it.height >= minimum } == true
}
