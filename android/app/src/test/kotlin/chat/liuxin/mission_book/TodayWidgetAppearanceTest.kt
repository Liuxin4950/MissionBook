package chat.liuxin.mission_book

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * 外观 v2 的纯逻辑回归：默认值、取值域拒绝、JSON 往返、v1 迁移与损坏恢复。
 *
 * 这里不碰 Android `Context`/`AtomicFile`（那部分只在真机/宿主验证），只覆盖
 * 契约第 1 节的取值域、迁移映射与恢复决策。
 */
class TodayWidgetAppearanceTest {
    private fun assertInvalid(block: () -> Unit) {
        try {
            block()
        } catch (error: IllegalArgumentException) {
            return
        }
        fail("Expected IllegalArgumentException")
    }

    @Test
    fun `defaults follow the frozen contract`() {
        val defaults = TodayWidgetAppearance.defaults
        assertEquals(2, defaults.version)
        assertEquals("paper", defaults.style)
        assertEquals("system", defaults.theme)
        assertEquals(12, defaults.headerSp)
        assertEquals(12, defaults.taskSp)
        assertEquals(11, defaults.metaSp)
        assertEquals(10, defaults.horizontalPaddingDp)
        assertEquals(6, defaults.verticalPaddingDp)
        assertEquals(4, defaults.rowPaddingDp)
        assertEquals(4, defaults.rowGapDp)
        assertEquals(16, defaults.radiusDp)
        assertTrue(defaults.showDetails)
        assertEquals("range", defaults.timeMode)
        assertTrue(defaults.showStatus)
        assertTrue(defaults.showDate)
        assertTrue(defaults.showMore)
        assertEquals(5, defaults.rowLimit)
        assertEquals(17, defaults.toMap().size)
        assertEquals(2, defaults.toMap()["version"])
    }

    @Test
    fun `fromMap fills missing keys with defaults`() {
        val appearance = TodayWidgetAppearance.fromMap(mapOf("version" to 2, "theme" to "dark"))
        assertEquals("dark", appearance.theme)
        assertEquals("paper", appearance.style)
        assertEquals(12, appearance.headerSp)
        assertEquals(5, appearance.rowLimit)
    }

    @Test
    fun `fromMap rejects a missing version`() {
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("theme" to "dark")) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to null, "theme" to "dark")) }
        assertInvalid { TodayWidgetAppearance.fromMap(emptyMap<String, Any?>()) }
    }

    @Test
    fun `fromMap accepts a complete round trip`() {
        val appearance = TodayWidgetAppearance(
            style = TodayWidgetAppearance.STYLE_INDEX,
            theme = TodayWidgetAppearance.THEME_DARK,
            headerSp = 15,
            taskSp = 16,
            metaSp = 13,
            horizontalPaddingDp = 14,
            verticalPaddingDp = 10,
            rowPaddingDp = 7,
            rowGapDp = 6,
            radiusDp = 8,
            showDetails = false,
            timeMode = TodayWidgetAppearance.TIME_START,
            showStatus = false,
            showDate = false,
            showMore = false,
            rowLimit = 2,
        )
        assertEquals(appearance, TodayWidgetAppearance.fromMap(appearance.toMap()))
    }

    @Test
    fun `unknown enum values are rejected`() {
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "style" to "neon")) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "theme" to "sepia")) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "timeMode" to "week")) }
    }

    @Test
    fun `out of range numbers are rejected`() {
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "headerSp" to 10)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "headerSp" to 18)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "taskSp" to 21)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "metaSp" to 9)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "horizontalPaddingDp" to 17)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "verticalPaddingDp" to 3)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "rowPaddingDp" to 2)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "rowGapDp" to 9)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "rowLimit" to 0)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "rowLimit" to 6)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "radiusDp" to 10)) }
        // 积分值仍然接受（JSON 数字可能被解成 Long），小数与字符串一律拒绝。
        assertEquals(13, TodayWidgetAppearance.fromMap(mapOf("version" to 2, "headerSp" to 13L)).headerSp)
        assertEquals(13, TodayWidgetAppearance.fromMap(mapOf("version" to 2, "headerSp" to 13.0)).headerSp)
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "headerSp" to 12.5)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "headerSp" to "12")) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 2, "showDate" to 1)) }
    }

    @Test
    fun `version other than two is rejected`() {
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 1)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to 3)) }
        assertInvalid { TodayWidgetAppearance.fromMap(mapOf("version" to "2")) }
    }

    @Test
    fun `copy keeps other fields and validates`() {
        val appearance = TodayWidgetAppearance.defaults
        val updated = appearance.copy(taskSp = 15, radiusDp = 8)
        assertEquals(15, updated.taskSp)
        assertEquals(8, updated.radiusDp)
        assertEquals(12, appearance.taskSp)
        assertEquals(16, appearance.radiusDp)
        assertInvalid { updated.copy(radiusDp = 10) }
    }

    @Test
    fun `json round trip preserves every field`() {
        val appearance = TodayWidgetAppearance(
            style = TodayWidgetAppearance.STYLE_MINIMAL,
            theme = TodayWidgetAppearance.THEME_LIGHT,
            headerSp = 17,
            taskSp = 20,
            metaSp = 16,
            horizontalPaddingDp = 16,
            verticalPaddingDp = 12,
            rowPaddingDp = 9,
            rowGapDp = 8,
            radiusDp = 12,
            showDetails = false,
            timeMode = TodayWidgetAppearance.TIME_NONE,
            showStatus = false,
            showDate = false,
            showMore = false,
            rowLimit = 1,
        )
        val text = TodayWidgetAppearanceJson.encode(appearance)
        assertEquals(appearance, TodayWidgetAppearanceJson.decode(text))
        assertTrue(text.startsWith("{") && text.endsWith("}"))
    }

    @Test
    fun `resolver migrates v1 standard`() {
        val snapshot = TodayWidgetAppearanceResolver.resolve(
            StoredAppearanceFile.Missing,
            LegacyWidgetAppearance(theme = "dark", textSize = "standard", readFailed = false),
        )
        assertEquals(AppearanceSource.MIGRATED, snapshot.source)
        assertFalse(snapshot.recovered)
        assertTrue(snapshot.writeRequired)
        assertEquals("dark", snapshot.appearance.theme)
        assertEquals(12, snapshot.appearance.headerSp)
        assertEquals(12, snapshot.appearance.taskSp)
        assertEquals(11, snapshot.appearance.metaSp)
    }

    @Test
    fun `resolver migrates v1 large`() {
        val snapshot = TodayWidgetAppearanceResolver.resolve(
            StoredAppearanceFile.Missing,
            LegacyWidgetAppearance(theme = "system", textSize = "large", readFailed = false),
        )
        assertEquals(AppearanceSource.MIGRATED, snapshot.source)
        assertEquals("system", snapshot.appearance.theme)
        assertEquals(15, snapshot.appearance.headerSp)
        assertEquals(15, snapshot.appearance.taskSp)
        assertEquals(13, snapshot.appearance.metaSp)
        assertTrue(snapshot.writeRequired)
    }

    @Test
    fun `resolver sanitizes unknown legacy values`() {
        val snapshot = TodayWidgetAppearanceResolver.resolve(
            StoredAppearanceFile.Missing,
            LegacyWidgetAppearance(theme = "sepia", textSize = "huge", readFailed = false),
        )
        assertEquals(AppearanceSource.MIGRATED, snapshot.source)
        assertEquals("system", snapshot.appearance.theme)
        assertEquals(12, snapshot.appearance.headerSp)
    }

    @Test
    fun `resolver uses defaults when there is no file and no legacy value`() {
        val snapshot = TodayWidgetAppearanceResolver.resolve(
            StoredAppearanceFile.Missing,
            LegacyWidgetAppearance(theme = null, textSize = null, readFailed = false),
        )
        assertEquals(AppearanceSource.DEFAULTS, snapshot.source)
        assertFalse(snapshot.recovered)
        assertFalse(snapshot.writeRequired)
        assertEquals(TodayWidgetAppearance.defaults, snapshot.appearance)
    }

    @Test
    fun `resolver reads a valid v2 file`() {
        val stored = TodayWidgetAppearanceJson.encode(TodayWidgetAppearance(theme = "dark", rowLimit = 2))
        val snapshot = TodayWidgetAppearanceResolver.resolve(
            StoredAppearanceFile.Text(stored),
            LegacyWidgetAppearance(theme = "light", textSize = "large", readFailed = false),
        )
        assertEquals(AppearanceSource.V2, snapshot.source)
        assertFalse(snapshot.recovered)
        assertFalse(snapshot.writeRequired)
        assertEquals("dark", snapshot.appearance.theme)
        assertEquals(2, snapshot.appearance.rowLimit)
        // v2 存在时旧偏好不再作为来源。
        assertEquals(12, snapshot.appearance.headerSp)
    }

    @Test
    fun `resolver recovers from a corrupt file`() {
        for (corrupt in listOf(
            "not json at all",
            "{\"version\":2,",
            "{\"version\":2,\"style\":\"neon\"}",
            "{\"version\":2,\"headerSp\":99}",
            "{\"version\":1,\"theme\":\"dark\"}",
            "{\"theme\":\"dark\",\"style\":\"paper\"}",
            "{\"version\":2,\"style\":{\"nested\":true}}",
        )) {
            val snapshot = TodayWidgetAppearanceResolver.resolve(
                StoredAppearanceFile.Text(corrupt),
                LegacyWidgetAppearance(theme = "dark", textSize = "large", readFailed = false),
            )
            assertEquals("corrupt=$corrupt", AppearanceSource.DEFAULTS, snapshot.source)
            assertTrue("corrupt=$corrupt", snapshot.recovered)
            assertTrue("corrupt=$corrupt", snapshot.writeRequired)
            assertEquals(TodayWidgetAppearance.defaults, snapshot.appearance)
        }
    }

    @Test
    fun `resolver leaves a future version untouched`() {
        val future = "{\"version\":3,\"style\":\"index\",\"theme\":\"dark\"}"
        val snapshot = TodayWidgetAppearanceResolver.resolve(
            StoredAppearanceFile.Text(future),
            LegacyWidgetAppearance(theme = null, textSize = null, readFailed = false),
        )
        assertEquals(AppearanceSource.DEFAULTS, snapshot.source)
        assertFalse(snapshot.recovered)
        assertFalse(snapshot.writeRequired)
        assertEquals(TodayWidgetAppearance.defaults, snapshot.appearance)
    }

    @Test
    fun `resolver rewrites when the file cannot be read`() {
        val snapshot = TodayWidgetAppearanceResolver.resolve(
            StoredAppearanceFile.Unreadable,
            LegacyWidgetAppearance(theme = null, textSize = null, readFailed = false),
        )
        assertEquals(AppearanceSource.DEFAULTS, snapshot.source)
        assertTrue(snapshot.recovered)
        assertTrue(snapshot.writeRequired)
    }

    @Test
    fun `resolver flags a failed legacy read`() {
        val snapshot = TodayWidgetAppearanceResolver.resolve(
            StoredAppearanceFile.Missing,
            LegacyWidgetAppearance(theme = null, textSize = null, readFailed = true),
        )
        assertEquals(AppearanceSource.DEFAULTS, snapshot.source)
        assertTrue(snapshot.recovered)
        assertTrue(snapshot.writeRequired)
    }

    @Test
    fun `flat json rejects nested and non object payloads`() {
        for (text in listOf("[]", "{\"version\":2,\"style\":[1]}", "", "{", "{\"version\":2}extra")) {
            assertInvalid { FlatJson.parseObject(text) }
        }
    }
}
