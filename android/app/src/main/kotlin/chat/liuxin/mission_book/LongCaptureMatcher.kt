package chat.liuxin.mission_book

import kotlin.math.abs

internal object LongCaptureMatcher {
    data class Join(val shift: Int, val bottom: Int)

    fun match(previous: IntArray, next: IntArray, width: Int, height: Int): Join {
        require(previous.size == width * height && next.size == previous.size)
        fun distance(a: Int, b: Int): Int =
            abs((a shr 16 and 255) - (b shr 16 and 255)) +
                abs((a shr 8 and 255) - (b shr 8 and 255)) + abs((a and 255) - (b and 255))
        fun sameRow(y: Int): Boolean = (0 until width).count {
            distance(previous[y * width + it], next[y * width + it]) < 18
        } >= width * 0.95
        var top = 0
        while (top < height / 3 && sameRow(top)) top++
        var bottom = 0
        while (bottom < height / 3 && sameRow(height - bottom - 1)) bottom++
        val changed = previous.indices.count { distance(previous[it], next[it]) > 18 }
        require(changed > previous.size / 100) { "画面没有变化，请先向下滚动再采集" }
        val contentHeight = height - top - bottom
        val scores = DoubleArray(contentHeight * 4 / 5 + 1) { Double.POSITIVE_INFINITY }
        for (shift in 1 until scores.size) {
            val overlap = contentHeight - shift
            var total = 0L
            var samples = 0
            for (row in 0 until 24) {
                val y = top + row * (overlap - 1) / 23
                for (x in 0 until width) {
                    total += distance(previous[(y + shift) * width + x], next[y * width + x])
                    samples++
                }
            }
            scores[shift] = total.toDouble() / samples
        }
        val best = scores.indices.minBy { scores[it] }
        val alternative = scores.indices.filter { abs(it - best) > 4 }.minOfOrNull { scores[it] }
            ?: Double.POSITIVE_INFINITY
        require(scores[best] < 12 && alternative > scores[best] + 1) {
            "无法可靠拼接，请少滚动一些并保留上一屏的部分内容"
        }
        return Join(best, bottom)
    }
}
