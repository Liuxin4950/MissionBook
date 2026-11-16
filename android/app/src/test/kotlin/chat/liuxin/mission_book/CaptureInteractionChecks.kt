package chat.liuxin.mission_book

/** 用 JVM 运行的纯几何回归；不冒充 Android View / MediaProjection 设备验收。 */
fun main() {
    val s = CaptureSelection()
    s.bounds(1000f, 800f)
    check(!s.valid(24f))
    s.begin(700f, 600f, 24f)
    s.drag(100f, 120f)
    check(s.box == CaptureSelection.Box(100f, 120f, 700f, 600f))
    check(s.valid(24f))
    // 框内拖移保持宽高，到屏幕边界停止。
    s.begin(300f, 300f, 24f)
    s.drag(1100f, 900f)
    check(s.box == CaptureSelection.Box(400f, 320f, 1000f, 800f))
    s.cancel()
    check(s.box == CaptureSelection.Box(100f, 120f, 700f, 600f))
    // 四角逐一调整，允许反向越过锚点。
    val corners = listOf(100f to 120f, 700f to 120f, 700f to 600f, 100f to 600f)
    for ((x, y) in corners) {
        s.begin(x, y, 24f)
        s.drag(350f, 360f)
        check(s.valid(24f))
        s.cancel()
        check(s.box == CaptureSelection.Box(100f, 120f, 700f, 600f))
    }
    // 框外重新拉选、裁边、过小区域和全屏。
    s.begin(5f, 5f, 24f); s.drag(-100f, -100f)
    check(!s.valid(24f))
    s.clear(); s.begin(200f, 100f, 24f); s.drag(1500f, 900f)
    check(s.box == CaptureSelection.Box(200f, 100f, 1000f, 800f))
    s.full(); check(s.box == CaptureSelection.Box(0f, 0f, 1000f, 800f))
    s.bounds(600f, 400f); check(s.box == CaptureSelection.Box(0f, 0f, 600f, 400f))
    check(OverlayEdgeGeometry.nearEdge(0, 1000, 56, 12))
    check(OverlayEdgeGeometry.nearEdge(934, 1000, 56, 12))
    check(!OverlayEdgeGeometry.nearEdge(400, 1000, 56, 12))
    check(OverlayEdgeGeometry.inwardDistance(true, 30) == 30)
    check(OverlayEdgeGeometry.inwardDistance(false, -30) == 30)
    check(OverlayEdgeGeometry.inwardDistance(false, 30) < 0)
    check(OverlayEdgeGeometry.revealedX(true, 1000, 56, 16) == 16)
    check(OverlayEdgeGeometry.revealedX(false, 600, 56, 16) == 528)
    check(OverlayEdgeGeometry.revealedX(false, 40, 56, 16) == 0)
    println("Capture interaction geometry checks passed")
}
