package chat.liuxin.mission_book

import kotlin.random.Random
import kotlin.math.abs

fun main() {
    val width = 64
    val height = 800
    val random = Random(42)
    val document = IntArray(width * height * 3) { random.nextInt(0x1000000) }
    fun frame(offset: Int, bars: Boolean = false) = IntArray(width * height) { index ->
        val y = index / width
        if (bars && (y < 60 || y >= height - 40)) 0x778899
        else document[(offset + y) * width + index % width]
    }
    val first = frame(0)
    val second = frame(310)
    val join = LongCaptureMatcher.match(first, second, width, height)
    check(abs(join.shift - 310) <= 1) { "Incorrect overlap: $join" }
    val fixed = LongCaptureMatcher.match(frame(0, true), frame(310, true), width, height)
    check(abs(fixed.shift - 310) <= 1 && fixed.bottom == 40) { "Incorrect fixed bars: $fixed" }
    check(runCatching { LongCaptureMatcher.match(first, first, width, height) }.isFailure)
    check(runCatching { LongCaptureMatcher.match(first, frame(900), width, height) }.isFailure)
    check(runCatching {
        LongCaptureMatcher.match(IntArray(width * height), IntArray(width * height) { 0xffffff }, width, height)
    }.isFailure)
    println("5 long capture matcher regressions passed")
}
