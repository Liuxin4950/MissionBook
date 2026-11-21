package chat.liuxin.mission_book

/** 可用区域和头像均用同一屏幕坐标；先选与头像不相交的区域，再测量面板。 */
internal object OverlayPanelPlacement {
    data class Box(val left: Int, val top: Int, val right: Int, val bottom: Int) {
        val width get() = (right - left).coerceAtLeast(0)
        val height get() = (bottom - top).coerceAtLeast(0)
    }

    data class Slot(val x: Int, val width: Int, val top: Int, val bottom: Int, val anchorY: Int, val above: Boolean) {
        val height get() = bottom - top
        fun y(measured: Int): Int = (if (above) bottom - measured else anchorY)
            .coerceIn(top, (bottom - measured).coerceAtLeast(top))
    }

    fun choose(safe: Box, ball: Box, preferred: Int, minimum: Int, gap: Int): Slot? {
        if (safe.width == 0 || safe.height == 0) return null
        val left = ball.left - gap - safe.left
        val right = safe.right - ball.right - gap
        val width = minOf(preferred, safe.width)
        val x = (if (ball.left + ball.right >= safe.left + safe.right) ball.right - width else ball.left)
            .coerceIn(safe.left, safe.right - width)
        val upperEnd = (ball.top - gap).coerceIn(safe.top, safe.bottom)
        val lowerStart = (ball.bottom + gap).coerceIn(safe.top, safe.bottom)
        val upper = upperEnd - safe.top
        val lower = safe.bottom - lowerStart
        val side = maxOf(left, right)
        if (side >= minimum || (side > 0 && maxOf(upper, lower) < gap * 8)) {
            val w = minOf(side, width)
            val sideX = if (left >= right) ball.left - gap - w else ball.right + gap
            return Slot(sideX.coerceIn(safe.left, safe.right - w), w, safe.top, safe.bottom, ball.top, false)
        }
        return when {
            lower >= upper && lower > 0 -> Slot(x, width, lowerStart, safe.bottom, lowerStart, false)
            upper > 0 -> Slot(x, width, safe.top, upperEnd, upperEnd, true)
            else -> null
        }
    }
}
