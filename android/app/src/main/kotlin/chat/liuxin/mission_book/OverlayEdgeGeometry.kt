package chat.liuxin.mission_book

/** 仅决定手势几何；可见性与系统 Window 仍由悬浮服务持有。 */
internal object OverlayEdgeGeometry {
    fun nearEdge(x: Int, screenWidth: Int, bubbleWidth: Int, threshold: Int): Boolean {
        val maximum = (screenWidth - bubbleWidth).coerceAtLeast(0)
        return x <= threshold || x >= maximum - threshold
    }
    fun inwardDistance(left: Boolean, dx: Int): Int = if (left) dx else -dx
    fun revealedX(left: Boolean, screenWidth: Int, bubbleWidth: Int, gap: Int): Int =
        (if (left) gap else screenWidth - bubbleWidth - gap).coerceIn(0, (screenWidth - bubbleWidth).coerceAtLeast(0))
}
