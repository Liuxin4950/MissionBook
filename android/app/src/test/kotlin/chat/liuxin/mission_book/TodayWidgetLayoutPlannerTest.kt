package chat.liuxin.mission_book

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 纯布局规划器的 JVM 回归：容量、rowLimit 夹取、字段开关、时间降级、字体缩放与三槽切换。
 *
 * 字体度量用可控近似（`1dp = 1px`，字宽 `0.6 × sp`，行高 `1.4 × sp`），
 * 因此断言的是规划器的取舍逻辑，不冒充 Android 文本测量或 Launcher 真机效果。
 */
class TodayWidgetLayoutPlannerTest {
    private class FakeMetrics(
        private val fontScale: Float = 1f,
        private val nonlinear: Boolean = false,
        private val charWidthRatio: Float = 0.6f,
        private val lineHeightRatio: Float = 1.4f,
    ) : WidgetTextMetrics {
        fun sizePx(sizeSp: Int): Float {
            val scaled = sizeSp * fontScale
            // 近似 Android 14 的非线性字体缩放：大字号增长放缓。
            val shaped = if (nonlinear && scaled > 20f) 20f + (scaled - 20f) * 0.6f else scaled
            return shaped
        }

        override fun textWidthPx(text: String, sizeSp: Int): Float =
            text.length * sizePx(sizeSp) * charWidthRatio

        override fun lineHeightPx(sizeSp: Int): Float = sizePx(sizeSp) * lineHeightRatio
    }

    private fun labels() = WidgetLabels(
        title = "今日任务",
        date = "11月23日",
        waiting = "等待同步，点按打开",
        empty = "今日暂无任务",
        open = "点按查看今日任务",
        untitled = "未命名任务",
        flexible = "自选时间",
        more = { count -> "另有 $count 项 ›" },
        count = { count -> "+$count" },
        timeRange = { start, end -> "$start–$end" },
        metaJoin = { time, status -> "$time · $status" },
    )

    private fun item(
        index: Int,
        title: String = "任务$index",
        start: String? = "08:00",
        end: String? = "09:40",
        status: String? = "待开始",
        current: Boolean = false,
    ) = WidgetItem(
        id = "m$index",
        title = title,
        startText = start,
        endText = end,
        statusText = status,
        flexibleTime = start == null,
        currentSlot = current,
        progressText = if (current) "计划进度 62%" else null,
    )

    private fun items(count: Int) = (1..count).map { item(it) }

    private fun plan(
        sizeClass: WidgetSizeClass,
        widthPx: Int,
        heightPx: Int,
        items: List<WidgetItem>,
        total: Int = items.size,
        appearance: TodayWidgetAppearance = TodayWidgetAppearance(),
        metrics: WidgetTextMetrics = FakeMetrics(),
        state: WidgetSnapshotState = WidgetSnapshotState.DATA,
        theme: String = WidgetPlan.THEME_LIGHT,
    ): WidgetPlan = TodayWidgetLayoutPlanner.plan(
        WidgetPlanRequest(
            sizeClass = sizeClass,
            widthPx = widthPx,
            heightPx = heightPx,
            density = 1f,
            textMetrics = metrics,
            appearance = appearance,
            state = state,
            items = items,
            total = total,
            labels = labels(),
            theme = theme,
        ),
    )

    @Test
    fun `location gets a separate line and reserves height in all sizes`() {
        for (size in WidgetSizeClass.entries) {
            val ordinary = items(1)
            val location = "第二教学楼 A203 ".repeat(20)
            val located = ordinary.map { it.copy(locationText = location) }
            val without = plan(size, 600, 500, ordinary)
            val with = plan(size, 600, 500, located)
            assertEquals(WidgetPlan.ROW_LAYOUT_STACKED, with.rowLayout)
            assertEquals(location, with.rows.single().location)
            assertTrue(with.rows.single().contentDescription.contains(location))
            assertTrue(with.metrics.rowHeightPx > without.metrics.rowHeightPx)
            val hidden = plan(size, 600, 500, located,
                appearance = TodayWidgetAppearance(showDetails = false))
            assertNull(hidden.rows.single().location)
            val locationOnly = plan(size, 600, 500, located,
                appearance = TodayWidgetAppearance(showStatus = false, timeMode = TodayWidgetAppearance.TIME_NONE))
            assertEquals(location, locationOnly.rows.single().location)
            assertFalse(locationOnly.rows.single().showTime)
            assertFalse(locationOnly.rows.single().showStatus)
        }
    }

    @Test
    fun `small shows one focus row and head count only when it fits`() {
        val result = plan(WidgetSizeClass.SMALL, 109, 109, items(1), total = 6)
        assertEquals(1, result.rows.size)
        assertEquals(2, result.rows.first().titleMaxLines)
        // 小号题头放不下「+5」，就不显示计数，也不能盖住标题或日期。
        assertNull(result.header.count)
        assertEquals(WidgetPlan.FOOTER_NONE, result.footer.kind)
        assertFalse(result.footer.visible)
        assertEquals(WidgetPlan.OVERFLOW_TIGHT, result.overflow)
        assertEquals(59, result.metrics.rowHeightPx)
    }

    @Test
    fun `small without hidden items has no count and no overflow`() {
        val result = plan(WidgetSizeClass.SMALL, 109, 109, items(1), total = 1)
        assertEquals(1, result.rows.size)
        assertNull(result.header.count)
        assertEquals(WidgetPlan.FOOTER_NONE, result.footer.kind)
        assertEquals(WidgetPlan.OVERFLOW_NONE, result.overflow)
        assertEquals(WidgetPlan.EMPTY_NONE, result.empty)
    }

    @Test
    fun `medium stacks one row with a more footer and bumps touch height to 48dp`() {
        val result = plan(WidgetSizeClass.MEDIUM, 220, 109, items(5), total = 5)
        assertEquals(WidgetPlan.ROW_LAYOUT_STACKED, result.rowLayout)
        assertEquals(1, result.rows.size)
        assertEquals(WidgetPlan.FOOTER_MORE, result.footer.kind)
        assertTrue(result.footer.visible)
        assertEquals("另有 4 项 ›", result.footer.text)
        assertEquals(WidgetPlan.OVERFLOW_TIGHT, result.overflow)
        // 尾部与行数都不变时才补到 48dp 触控高。
        assertEquals(48, result.metrics.rowHeightPx)
    }

    @Test
    fun `large clamps rows by capacity and moves the count to the header`() {
        val result = plan(WidgetSizeClass.LARGE, 220, 220, items(5), total = 6)
        assertEquals(WidgetPlan.ROW_LAYOUT_STACKED, result.rowLayout)
        assertEquals(4, result.rows.size)
        assertEquals(WidgetPlan.FOOTER_HEADER_COUNT, result.footer.kind)
        assertFalse(result.footer.visible)
        assertEquals("+2", result.header.count)
        assertEquals(WidgetPlan.OVERFLOW_TIGHT, result.overflow)
        // 补到 48dp 会减少行数，因此保持 42dp。
        assertEquals(42, result.metrics.rowHeightPx)
    }

    @Test
    fun `two rows fit when the header count replaces the footer`() {
        val result = plan(WidgetSizeClass.MEDIUM, 220, 140, items(5), total = 6)
        assertEquals(2, result.rows.size)
        assertEquals(WidgetPlan.FOOTER_HEADER_COUNT, result.footer.kind)
        assertEquals("+4", result.header.count)
        assertEquals(WidgetPlan.OVERFLOW_TIGHT, result.overflow)
        // 换成头部计数后仍能保住两行，于是把触控高补到 48dp。
        assertEquals(48, result.metrics.rowHeightPx)
    }

    @Test
    fun `header only fallback keeps an entry when not even one row fits`() {
        val result = plan(WidgetSizeClass.MEDIUM, 220, 60, items(5), total = 5)
        assertTrue(result.rows.isEmpty())
        assertEquals(WidgetPlan.OVERFLOW_HEADER_ONLY, result.overflow)
        assertEquals(WidgetPlan.EMPTY_NONE, result.empty)
        assertTrue(result.header.visible)
        assertFalse(result.footer.visible)
    }

    @Test
    fun `wide slot uses triSlot and five rows with a more footer`() {
        val result = plan(WidgetSizeClass.LARGE, 240, 260, items(6), total = 6)
        assertEquals(WidgetPlan.ROW_LAYOUT_WIDE, result.rowLayout)
        assertEquals(5, result.rows.size)
        assertEquals(WidgetPlan.FOOTER_MORE, result.footer.kind)
        assertEquals("另有 1 项 ›", result.footer.text)
        assertEquals(32, result.metrics.rowHeightPx)
        assertEquals(1, result.rows.first().titleMaxLines)
        assertEquals("08:00–09:40", result.rows.first().time)
    }

    @Test
    fun `220dp narrow slot stays stacked`() {
        val result = plan(WidgetSizeClass.MEDIUM, 220, 109, items(5), total = 5)
        assertEquals(WidgetPlan.ROW_LAYOUT_STACKED, result.rowLayout)
        assertTrue(result.rows.first().showTime)
        assertTrue(result.rows.first().showStatus)
    }

    @Test
    fun `long title at the same width falls back to stacked`() {
        val long = (1..5).map { item(it, title = "品牌与营销管理实务课程设计与实践总结报告汇编") }
        val result = plan(WidgetSizeClass.LARGE, 240, 220, long, total = 5)
        assertEquals(WidgetPlan.ROW_LAYOUT_STACKED, result.rowLayout)
    }

    @Test
    fun `large font scale degrades range to start time and reduces rows`() {
        val metrics = FakeMetrics(fontScale = 2f)
        val large = plan(WidgetSizeClass.LARGE, 240, 220, items(6), total = 6, metrics = metrics)
        assertEquals(WidgetPlan.ROW_LAYOUT_WIDE, large.rowLayout)
        assertEquals("08:00", large.rows.first().time)
        // 题头也按真实字高增长，因此大字下只剩三行。
        assertEquals(3, large.rows.size)

        val normal = plan(WidgetSizeClass.LARGE, 240, 220, items(6), total = 6)
        assertEquals(5, normal.rows.size)
        assertTrue(large.metrics.rowHeightPx > normal.metrics.rowHeightPx)
    }

    @Test
    fun `font scale 1 dot 3 no longer fits the footer`() {
        val result = plan(
            WidgetSizeClass.MEDIUM, 220, 109, items(5), total = 5,
            metrics = FakeMetrics(fontScale = 1.3f),
        )
        assertEquals(1, result.rows.size)
        assertEquals(WidgetPlan.FOOTER_HEADER_COUNT, result.footer.kind)
        assertEquals("+4", result.header.count)
    }

    @Test
    fun `nonlinear font scaling measures smaller than linear scaling`() {
        val linear = plan(
            WidgetSizeClass.LARGE, 240, 220, items(6), total = 6,
            metrics = FakeMetrics(fontScale = 2f),
        )
        val nonlinear = plan(
            WidgetSizeClass.LARGE, 240, 220, items(6), total = 6,
            metrics = FakeMetrics(fontScale = 2f, nonlinear = true),
        )
        assertEquals(39, nonlinear.metrics.rowHeightPx)
        assertTrue(nonlinear.metrics.rowHeightPx < linear.metrics.rowHeightPx)
    }

    @Test
    fun `row limit clamps even when capacity allows more`() {
        val appearance = TodayWidgetAppearance(rowLimit = 2)
        val result = plan(
            WidgetSizeClass.LARGE, 240, 300, items(6), total = 6, appearance = appearance,
        )
        assertEquals(2, result.rows.size)
        assertEquals(WidgetPlan.FOOTER_MORE, result.footer.kind)
        assertEquals("另有 4 项 ›", result.footer.text)
    }

    @Test
    fun `show details false keeps only the task name and gains rows`() {
        val appearance = TodayWidgetAppearance(showDetails = false)
        val result = plan(
            WidgetSizeClass.LARGE, 240, 220, items(6), total = 6, appearance = appearance,
        )
        assertEquals(WidgetPlan.ROW_LAYOUT_STACKED, result.rowLayout)
        assertEquals(5, result.rows.size)
        assertTrue(result.rows.all { !it.showTime && !it.showStatus })
        assertTrue(result.rows.all { it.time == null && it.status == null })
        assertEquals("+1", result.header.count)
    }

    @Test
    fun `time mode none hides time but keeps status`() {
        val appearance = TodayWidgetAppearance(timeMode = TodayWidgetAppearance.TIME_NONE)
        val result = plan(
            WidgetSizeClass.LARGE, 240, 220, items(3), total = 3, appearance = appearance,
        )
        assertEquals(WidgetPlan.ROW_LAYOUT_WIDE, result.rowLayout)
        assertTrue(result.rows.all { it.time == null && !it.showTime })
        assertTrue(result.rows.all { it.status == "待开始" && it.showStatus })
    }

    @Test
    fun `flexible time shows the flexible label instead of a fake time`() {
        val flexible = listOf(item(1, start = null, end = null), item(2))
        val result = plan(WidgetSizeClass.LARGE, 240, 220, flexible, total = 2)
        assertEquals("自选时间", result.rows.first().time)
        assertTrue(result.rows.first().showTime)
    }

    @Test
    fun `time degrades before the status and is kept when status is hidden`() {
        val metrics = FakeMetrics(fontScale = 6f)
        val withStatus = plan(
            WidgetSizeClass.MEDIUM, 220, 400, items(1), total = 1, metrics = metrics,
        )
        // 范围与开始时间都放不下时优先保留阶段，时间整槽隐藏。
        assertTrue(withStatus.rows.first().time == null)
        assertTrue(withStatus.rows.first().showStatus)

        val withoutStatus = plan(
            WidgetSizeClass.MEDIUM, 220, 400, items(1), total = 1, metrics = metrics,
            appearance = TodayWidgetAppearance(showStatus = false),
        )
        // 阶段关闭时不能把辅助信息清空，保留开始时间。
        assertEquals("08:00", withoutStatus.rows.first().time)
        assertTrue(withoutStatus.rows.first().showTime)
    }

    @Test
    fun `footer counts use the day total not the row limit`() {
        val result = plan(WidgetSizeClass.LARGE, 220, 220, items(5), total = 9)
        assertEquals(4, result.rows.size)
        assertEquals("+5", result.header.count)
    }

    @Test
    fun `show more false hides the count but keeps the overflow state`() {
        val appearance = TodayWidgetAppearance(showMore = false)
        val result = plan(
            WidgetSizeClass.MEDIUM, 220, 109, items(5), total = 5, appearance = appearance,
        )
        assertEquals(WidgetPlan.FOOTER_NONE, result.footer.kind)
        assertNull(result.header.count)
        assertEquals(WidgetPlan.OVERFLOW_TIGHT, result.overflow)
    }

    @Test
    fun `show date false clears the date slot`() {
        val appearance = TodayWidgetAppearance(showDate = false)
        val result = plan(
            WidgetSizeClass.MEDIUM, 220, 109, items(2), total = 2, appearance = appearance,
        )
        assertEquals("", result.header.right)
        assertTrue(result.header.visible)
    }

    @Test
    fun `waiting and empty snapshots are different empty states`() {
        val waiting = plan(
            WidgetSizeClass.MEDIUM, 220, 109, emptyList(),
            state = WidgetSnapshotState.WAITING, total = 0,
        )
        assertEquals(WidgetPlan.EMPTY_WAITING, waiting.empty)
        assertTrue(waiting.rows.isEmpty())
        assertEquals(WidgetPlan.OVERFLOW_NONE, waiting.overflow)

        val empty = plan(
            WidgetSizeClass.MEDIUM, 220, 109, emptyList(),
            state = WidgetSnapshotState.EMPTY, total = 0,
        )
        assertEquals(WidgetPlan.EMPTY_EMPTY, empty.empty)
        assertEquals(WidgetPlan.OVERFLOW_NONE, empty.overflow)

        val snapshotWithoutRows = plan(WidgetSizeClass.MEDIUM, 220, 109, emptyList(), total = 0)
        assertEquals(WidgetPlan.EMPTY_EMPTY, snapshotWithoutRows.empty)
    }

    @Test
    fun `styles drive spine and divider visibility`() {
        val paper = plan(WidgetSizeClass.MEDIUM, 220, 109, items(2), appearance = TodayWidgetAppearance())
        assertFalse(paper.spineVisible)
        assertTrue(paper.dividerVisible)

        val index = plan(
            WidgetSizeClass.MEDIUM, 220, 109, items(2),
            appearance = TodayWidgetAppearance(style = TodayWidgetAppearance.STYLE_INDEX),
        )
        assertTrue(index.spineVisible)
        assertFalse(index.dividerVisible)

        val minimalSmall = plan(
            WidgetSizeClass.SMALL, 109, 109, items(1),
            appearance = TodayWidgetAppearance(style = TodayWidgetAppearance.STYLE_MINIMAL),
        )
        assertFalse(minimalSmall.spineVisible)

        val paperSmall = plan(WidgetSizeClass.SMALL, 109, 109, items(1))
        // 契约 2.4：只有 index 有书脊，paper 小号也只留分隔线。
        assertFalse(paperSmall.spineVisible)
        assertTrue(paperSmall.dividerVisible)
    }

    @Test
    fun `colors follow the resolved theme`() {
        val light = plan(WidgetSizeClass.MEDIUM, 220, 109, items(2))
        val dark = plan(
            WidgetSizeClass.MEDIUM, 220, 109, items(2), theme = WidgetPlan.THEME_DARK,
        )
        assertEquals(0xFFFFFFFF.toInt(), light.colors.content)
        assertEquals(0xFF202C24.toInt(), dark.colors.content)
        assertEquals(0xFF244D3D.toInt(), light.colors.spine)
        assertEquals(0xFFA7C9B3.toInt(), dark.colors.spine)
    }

    @Test
    fun `current slot row carries the planned progress text`() {
        val result = plan(
            WidgetSizeClass.LARGE, 240, 260, listOf(item(1, status = "进行中", current = true)), total = 1,
        )
        assertEquals("计划进度 62%", result.rows.first().progress)
        assertTrue(result.rows.first().currentSlot)
    }

    @Test
    fun `preview payload matches the frozen dto keys and values`() {
        val plan = plan(WidgetSizeClass.MEDIUM, 220, 109, items(5), total = 5)
        val payload = TodayWidgetPreviewPayload.build(
            plan = plan,
            sizeClass = WidgetSizeClass.MEDIUM,
            sizeSource = "reference",
            widthDp = 220,
            heightDp = 109,
        )
        assertEquals(
            setOf(
                "version", "sizeClass", "sizeSource", "widthDp", "heightDp", "theme", "style",
                "colors", "metrics", "header", "rows", "footer", "empty", "overflow",
                "rowLayout", "spineVisible", "dividerVisible", "sample",
            ),
            payload.keys,
        )
        assertEquals(2, payload["version"])
        assertEquals("medium", payload["sizeClass"])
        assertEquals("reference", payload["sizeSource"])
        assertEquals(220, payload["widthDp"])
        assertEquals(109, payload["heightDp"])
        assertEquals("light", payload["theme"])
        assertEquals("paper", payload["style"])
        assertEquals("stacked", payload["rowLayout"])
        assertEquals(false, payload["spineVisible"])
        assertEquals(true, payload["dividerVisible"])
        assertEquals(true, payload["sample"])

        @Suppress("UNCHECKED_CAST")
        val colors = payload["colors"] as Map<String, Any?>
        assertEquals(
            setOf(
                "surface", "content", "rowSurface", "spine", "primaryText",
                "secondaryText", "accent", "warn", "hairline",
            ),
            colors.keys,
        )
        // 预览的 surface 就是原生根面实际使用的颜色角色。
        assertEquals(0xFFF7F8F5.toInt(), colors["surface"])
        assertEquals(0xFFFFFFFF.toInt(), colors["content"])

        @Suppress("UNCHECKED_CAST")
        val metrics = payload["metrics"] as Map<String, Any?>
        assertEquals(
            setOf(
                "horizontalPadding", "verticalPadding", "rowPadding", "rowGap", "radius",
                "headerSp", "taskSp", "metaSp", "headerHeight", "footerHeight", "rowHeight",
            ),
            metrics.keys,
        )

        @Suppress("UNCHECKED_CAST")
        val rows = payload["rows"] as List<Map<String, Any?>>
        assertEquals(
            setOf("time", "title", "location", "status", "showTime", "showStatus", "titleMaxLines", "progress", "currentSlot"),
            rows.first().keys,
        )
        @Suppress("UNCHECKED_CAST")
        val footer = payload["footer"] as Map<String, Any?>
        assertEquals(setOf("visible", "kind", "text"), footer.keys)
        @Suppress("UNCHECKED_CAST")
        val header = payload["header"] as Map<String, Any?>
        assertEquals(setOf("visible", "left", "right", "count"), header.keys)
    }

    @Test
    fun `preview payload reports wide layout and index spine`() {
        val plan = plan(
            WidgetSizeClass.LARGE, 240, 260, items(6), total = 6,
            appearance = TodayWidgetAppearance(style = TodayWidgetAppearance.STYLE_INDEX),
        )
        val payload = TodayWidgetPreviewPayload.build(
            plan = plan,
            sizeClass = WidgetSizeClass.LARGE,
            sizeSource = "widget",
            widthDp = 250,
            heightDp = 270,
        )
        assertEquals("wide", payload["rowLayout"])
        assertEquals(true, payload["spineVisible"])
        assertEquals(false, payload["dividerVisible"])
        assertEquals("widget", payload["sizeSource"])
    }

    @Test
    fun `timeline style exposes current node and no divider`() {
        val result = plan(
            WidgetSizeClass.LARGE, 240, 260, listOf(
                item(1, current = true), item(2), item(3),
            ), total = 3,
            appearance = TodayWidgetAppearance(style = TodayWidgetAppearance.STYLE_TIMELINE),
        )
        assertTrue(result.spineVisible)
        assertFalse(result.dividerVisible)
        assertTrue(result.rows.first().currentSlot)
        assertFalse(result.rows[1].currentSlot)
        val payload = TodayWidgetPreviewPayload.build(
            plan = result, sizeClass = WidgetSizeClass.LARGE,
            sizeSource = "reference", widthDp = 220, heightDp = 220,
        )
        @Suppress("UNCHECKED_CAST")
        val rows = payload["rows"] as List<Map<String, Any?>>
        assertEquals(true, rows.first()["currentSlot"])
    }

    @Test
    fun `accessibility summary keeps the full title and enabled details`() {
        val result = plan(WidgetSizeClass.LARGE, 240, 260, items(1), total = 1)
        assertEquals("任务1, 08:00–09:40, 待开始", result.rows.first().contentDescription)
    }
}
