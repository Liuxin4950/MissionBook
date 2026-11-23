package chat.liuxin.mission_book

import android.content.Context
import android.util.AtomicFile
import java.io.File

/**
 * 桌面小组件外观 v2（设备级，一套值作用于这台设备上的所有小、中、大组件）。
 *
 * 冻结契约见 `docs/设计/小组件外观契约v2.md`。本文件刻意分三层，让取值域、JSON 解析、
 * 迁移与损坏恢复都能在 JVM 单测里验证：
 * 1. [TodayWidgetAppearance] / [TodayWidgetAppearanceJson] / [FlatJson] /
 *    [TodayWidgetAppearanceResolver] 是纯 Kotlin，不引用任何 Android 类型。
 * 2. [TodayWidgetAppearanceStore] 只负责 Android IO：`AtomicFile` 读写本机文件、
 *    读取旧 `SharedPreferences` 作为一次性迁移来源。
 *
 * 原生是默认值、取值域、持久化和最终回执的权威；Dart 侧只做同结构的编辑草稿。
 */
internal data class TodayWidgetAppearance(
    val version: Int = VERSION,
    val style: String = STYLE_PAPER,
    val theme: String = THEME_SYSTEM,
    val headerSp: Int = DEFAULT_HEADER_SP,
    val taskSp: Int = DEFAULT_TASK_SP,
    val metaSp: Int = DEFAULT_META_SP,
    val horizontalPaddingDp: Int = DEFAULT_HORIZONTAL_PADDING_DP,
    val verticalPaddingDp: Int = DEFAULT_VERTICAL_PADDING_DP,
    val rowPaddingDp: Int = DEFAULT_ROW_PADDING_DP,
    val rowGapDp: Int = DEFAULT_ROW_GAP_DP,
    val radiusDp: Int = DEFAULT_RADIUS_DP,
    val showDetails: Boolean = true,
    val timeMode: String = TIME_RANGE,
    val showStatus: Boolean = true,
    val showDate: Boolean = true,
    val showMore: Boolean = true,
    val rowLimit: Int = DEFAULT_ROW_LIMIT,
) {
    init {
        // 任何构造路径（含 data class copy、fromMap、迁移）都走同一份取值域。
        require(version == VERSION) { "version 只支持 $VERSION，收到 $version" }
        require(style in STYLES) { "style 取值非法：$style" }
        require(theme in THEMES) { "theme 取值非法：$theme" }
        require(timeMode in TIME_MODES) { "timeMode 取值非法：$timeMode" }
        require(headerSp in HEADER_SP_RANGE) { "headerSp 超出 $HEADER_SP_RANGE：$headerSp" }
        require(taskSp in TASK_SP_RANGE) { "taskSp 超出 $TASK_SP_RANGE：$taskSp" }
        require(metaSp in META_SP_RANGE) { "metaSp 超出 $META_SP_RANGE：$metaSp" }
        require(horizontalPaddingDp in HORIZONTAL_PADDING_RANGE) {
            "horizontalPaddingDp 超出 $HORIZONTAL_PADDING_RANGE：$horizontalPaddingDp"
        }
        require(verticalPaddingDp in VERTICAL_PADDING_RANGE) {
            "verticalPaddingDp 超出 $VERTICAL_PADDING_RANGE：$verticalPaddingDp"
        }
        require(rowPaddingDp in ROW_PADDING_RANGE) {
            "rowPaddingDp 超出 $ROW_PADDING_RANGE：$rowPaddingDp"
        }
        require(rowGapDp in ROW_GAP_RANGE) { "rowGapDp 超出 $ROW_GAP_RANGE：$rowGapDp" }
        require(radiusDp in RADIUS_OPTIONS) { "radiusDp 只能取 $RADIUS_OPTIONS：$radiusDp" }
        require(rowLimit in ROW_LIMIT_RANGE) { "rowLimit 超出 $ROW_LIMIT_RANGE：$rowLimit" }
    }

    /** 通道回执与文件共用同一份键集合，顺序稳定便于对拍。 */
    fun toMap(): Map<String, Any> = linkedMapOf(
        "version" to version,
        "style" to style,
        "theme" to theme,
        "headerSp" to headerSp,
        "taskSp" to taskSp,
        "metaSp" to metaSp,
        "horizontalPaddingDp" to horizontalPaddingDp,
        "verticalPaddingDp" to verticalPaddingDp,
        "rowPaddingDp" to rowPaddingDp,
        "rowGapDp" to rowGapDp,
        "radiusDp" to radiusDp,
        "showDetails" to showDetails,
        "timeMode" to timeMode,
        "showStatus" to showStatus,
        "showDate" to showDate,
        "showMore" to showMore,
        "rowLimit" to rowLimit,
    )

    val isRangeTime get() = timeMode == TIME_RANGE
    val isStartTime get() = timeMode == TIME_START
    val isTimeHidden get() = timeMode == TIME_NONE

    companion object {
        const val VERSION = 2

        const val STYLE_PAPER = "paper"
        const val STYLE_INDEX = "index"
        const val STYLE_MINIMAL = "minimal"
        const val STYLE_TIMELINE = "timeline"

        const val THEME_SYSTEM = "system"
        const val THEME_LIGHT = "light"
        const val THEME_DARK = "dark"

        const val TIME_NONE = "none"
        const val TIME_START = "start"
        const val TIME_RANGE = "range"

        val STYLES = linkedSetOf(STYLE_PAPER, STYLE_INDEX, STYLE_MINIMAL, STYLE_TIMELINE)
        val THEMES = linkedSetOf(THEME_SYSTEM, THEME_LIGHT, THEME_DARK)
        val TIME_MODES = linkedSetOf(TIME_NONE, TIME_START, TIME_RANGE)

        val HEADER_SP_RANGE = 11..17
        val TASK_SP_RANGE = 11..20
        val META_SP_RANGE = 10..16
        val HORIZONTAL_PADDING_RANGE = 8..16
        val VERTICAL_PADDING_RANGE = 4..12
        val ROW_PADDING_RANGE = 3..9
        val ROW_GAP_RANGE = 0..8
        val RADIUS_OPTIONS = linkedSetOf(8, 12, 16)
        val ROW_LIMIT_RANGE = 1..5

        const val DEFAULT_HEADER_SP = 12
        const val DEFAULT_TASK_SP = 12
        const val DEFAULT_META_SP = 11
        const val DEFAULT_HORIZONTAL_PADDING_DP = 10
        const val DEFAULT_VERTICAL_PADDING_DP = 6
        const val DEFAULT_ROW_PADDING_DP = 4
        const val DEFAULT_ROW_GAP_DP = 4
        const val DEFAULT_RADIUS_DP = 16
        const val DEFAULT_ROW_LIMIT = 5

        /** 只读默认值；与 [TodayWidgetAppearance] 全默认构造等价。 */
        val defaults: TodayWidgetAppearance get() = TodayWidgetAppearance()

        /**
         * 通道/文件入参归一化：缺失键补默认，未知枚举、非整数、越界、`version` 缺失或 `version≠2`
         * 整体拒绝。
         *
         * 抛 [IllegalArgumentException]，由通道映射成 `invalidAppearance`；未知键被忽略，
         * 只认本契约的 17 个键，避免旧版本或多写的键影响外观判定。
         */
        fun fromMap(values: Map<*, *>): TodayWidgetAppearance = TodayWidgetAppearance(
            version = requiredVersion(values),
            style = stringValue(values, "style", STYLE_PAPER, STYLES),
            theme = stringValue(values, "theme", THEME_SYSTEM, THEMES),
            headerSp = intValue(values, "headerSp", DEFAULT_HEADER_SP, HEADER_SP_RANGE),
            taskSp = intValue(values, "taskSp", DEFAULT_TASK_SP, TASK_SP_RANGE),
            metaSp = intValue(values, "metaSp", DEFAULT_META_SP, META_SP_RANGE),
            horizontalPaddingDp = intValue(
                values, "horizontalPaddingDp", DEFAULT_HORIZONTAL_PADDING_DP, HORIZONTAL_PADDING_RANGE,
            ),
            verticalPaddingDp = intValue(
                values, "verticalPaddingDp", DEFAULT_VERTICAL_PADDING_DP, VERTICAL_PADDING_RANGE,
            ),
            rowPaddingDp = intValue(values, "rowPaddingDp", DEFAULT_ROW_PADDING_DP, ROW_PADDING_RANGE),
            rowGapDp = intValue(values, "rowGapDp", DEFAULT_ROW_GAP_DP, ROW_GAP_RANGE),
            radiusDp = intValue(values, "radiusDp", DEFAULT_RADIUS_DP, RADIUS_OPTIONS),
            showDetails = boolValue(values, "showDetails", true),
            timeMode = stringValue(values, "timeMode", TIME_RANGE, TIME_MODES),
            showStatus = boolValue(values, "showStatus", true),
            showDate = boolValue(values, "showDate", true),
            showMore = boolValue(values, "showMore", true),
            rowLimit = intValue(values, "rowLimit", DEFAULT_ROW_LIMIT, ROW_LIMIT_RANGE),
        )

        /** 契约第 1 节：`version` 缺失或非 2 都视为无效，不静默补成 2。 */
        private fun requiredVersion(values: Map<*, *>): Int {
            require(values.containsKey("version") && values["version"] != null) { "version 缺失" }
            return intValue(values, "version", VERSION, VERSION..VERSION)
        }

        private fun stringValue(
            values: Map<*, *>,
            key: String,
            default: String,
            allowed: Set<String>,
        ): String {
            val raw = values[key] ?: return default
            require(raw is String) { "$key 必须是字符串" }
            require(raw in allowed) { "$key 取值非法：$raw" }
            return raw
        }

        private fun intValue(values: Map<*, *>, key: String, default: Int, range: IntRange): Int {
            val raw = values[key] ?: return default
            require(raw is Number) { "$key 必须是整数" }
            val asDouble = raw.toDouble()
            require(asDouble.isFinite() && asDouble == Math.floor(asDouble)) { "$key 必须是整数" }
            val value = raw.toLong()
            require(value >= range.first && value <= range.last) { "$key 超出 $range：$value" }
            return value.toInt()
        }

        private fun intValue(values: Map<*, *>, key: String, default: Int, allowed: Set<Int>): Int {
            val raw = values[key] ?: return default
            require(raw is Number) { "$key 必须是整数" }
            val asDouble = raw.toDouble()
            require(asDouble.isFinite() && asDouble == Math.floor(asDouble)) { "$key 必须是整数" }
            val value = raw.toLong()
            require(allowed.contains(value.toInt())) { "$key 只能取 $allowed：$value" }
            return value.toInt()
        }

        private fun boolValue(values: Map<*, *>, key: String, default: Boolean): Boolean {
            val raw = values[key] ?: return default
            require(raw is Boolean) { "$key 必须是布尔值" }
            return raw
        }
    }
}

/** v2 外观文件的 UTF-8 JSON 编解码；纯 Kotlin，可在 JVM 单测直接覆盖。 */
internal object TodayWidgetAppearanceJson {
    fun encode(appearance: TodayWidgetAppearance): String = buildString {
        append('{')
        var first = true
        for ((key, value) in appearance.toMap()) {
            if (!first) append(',')
            first = false
            append('"').append(key).append("\":")
            when (value) {
                is String -> append('"').append(escape(value)).append('"')
                is Int -> append(value)
                is Boolean -> append(if (value) "true" else "false")
                else -> throw IllegalArgumentException("不支持的 JSON 值：$value")
            }
        }
        append('}')
    }

    fun decode(text: String): TodayWidgetAppearance {
        val map = FlatJson.parseObject(text)
        return TodayWidgetAppearance.fromMap(map)
    }

    private fun escape(value: String): String = buildString {
        for (char in value) {
            when (char) {
                '"' -> append("\\\"")
                '\\' -> append("\\\\")
                '\n' -> append("\\n")
                '\r' -> append("\\r")
                '\t' -> append("\\t")
                else -> append(char)
            }
        }
    }
}

/**
 * 只解析「扁平对象 + 字符串/整数/布尔/null」的严格 JSON 读取器。
 *
 * 外观文件的 schema 由本应用独占写入，固定为扁平对象；因此这里不接受嵌套对象或数组，
 * 遇到即视为损坏。这样损坏恢复、版本判定等逻辑不依赖 `org.json`，可以在 JVM 单测覆盖。
 */
internal object FlatJson {
    fun parseObject(text: String): Map<String, Any?> {
        val parser = Parser(text)
        val value = parser.readObject()
        parser.skipWhitespace()
        require(parser.atEnd()) { "JSON 尾部有多余内容" }
        return value
    }

    private class Parser(private val text: String) {
        private var index = 0

        fun atEnd(): Boolean = index >= text.length

        fun skipWhitespace() {
            while (index < text.length && text[index].isWhitespace()) index++
        }

        fun readObject(): Map<String, Any?> {
            skipWhitespace()
            expect('{')
            val result = LinkedHashMap<String, Any?>()
            skipWhitespace()
            if (peek() == '}') {
                index++
                return result
            }
            while (true) {
                skipWhitespace()
                val key = readString()
                skipWhitespace()
                expect(':')
                skipWhitespace()
                result[key] = readValue()
                skipWhitespace()
                when (peek()) {
                    ',' -> index++
                    '}' -> {
                        index++
                        return result
                    }
                    else -> throw IllegalArgumentException("JSON 对象缺少逗号或右括号")
                }
            }
        }

        private fun readValue(): Any? = when (val char = peek()) {
            '"' -> readString()
            '{', '[' -> throw IllegalArgumentException("外观文件不支持嵌套结构")
            't' -> readLiteral("true", true)
            'f' -> readLiteral("false", false)
            'n' -> readLiteral("null", null)
            else -> if (char == '-' || char.isDigit()) readNumber() else {
                throw IllegalArgumentException("非法 JSON 值")
            }
        }

        private fun readLiteral(literal: String, value: Any?): Any? {
            require(text.startsWith(literal, index)) { "非法 JSON 字面量" }
            index += literal.length
            return value
        }

        private fun readNumber(): Number {
            val start = index
            if (peek() == '-') index++
            while (index < text.length && text[index].isDigit()) index++
            var isInteger = true
            if (index < text.length && text[index] == '.') {
                isInteger = false
                index++
                while (index < text.length && text[index].isDigit()) index++
            }
            if (index < text.length && (text[index] == 'e' || text[index] == 'E')) {
                isInteger = false
                index++
                if (index < text.length && (text[index] == '+' || text[index] == '-')) index++
                while (index < text.length && text[index].isDigit()) index++
            }
            val raw = text.substring(start, index)
            require(raw.isNotEmpty() && raw != "-") { "非法 JSON 数字" }
            return if (isInteger) raw.toLong() else raw.toDouble()
        }

        private fun readString(): String {
            expect('"')
            val builder = StringBuilder()
            while (true) {
                require(index < text.length) { "JSON 字符串未闭合" }
                when (val char = text[index++]) {
                    '"' -> return builder.toString()
                    '\\' -> {
                        require(index < text.length) { "JSON 转义未完成" }
                        when (val escaped = text[index++]) {
                            '"' -> builder.append('"')
                            '\\' -> builder.append('\\')
                            '/' -> builder.append('/')
                            'b' -> builder.append('\b')
                            'f' -> builder.append('\u000C')
                            'n' -> builder.append('\n')
                            'r' -> builder.append('\r')
                            't' -> builder.append('\t')
                            'u' -> {
                                require(index + 4 <= text.length) { "JSON Unicode 转义不完整" }
                                val hex = text.substring(index, index + 4)
                                index += 4
                                builder.append(hex.toInt(16).toChar())
                            }
                            else -> throw IllegalArgumentException("不支持的 JSON 转义：\\$escaped")
                        }
                    }
                    else -> builder.append(char)
                }
            }
        }

        private fun peek(): Char {
            require(index < text.length) { "JSON 提前结束" }
            return text[index]
        }

        private fun expect(char: Char) {
            require(index < text.length && text[index] == char) { "JSON 期望 '$char'" }
            index++
        }
    }
}

/** 本机 v2 文件的读取结果；区分「没有文件」和「读不出来」。 */
internal sealed class StoredAppearanceFile {
    data object Missing : StoredAppearanceFile()
    data object Unreadable : StoredAppearanceFile()
    data class Text(val value: String) : StoredAppearanceFile()
}

/** 旧 `SharedPreferences("today_widget_appearance")` 的只读快照，仅作一次性迁移来源。 */
internal data class LegacyWidgetAppearance(
    val theme: String?,
    val textSize: String?,
    val readFailed: Boolean,
)

/** 本次外观从哪里来，回执 `source` 字段。 */
internal enum class AppearanceSource(val wire: String) {
    V2("v2"),
    MIGRATED("migrated"),
    DEFAULTS("defaults"),
}

/** 解析后的外观与来源；[writeRequired] 为真时调用方要把合法文件补写回本机。 */
internal data class AppearanceSnapshot(
    val appearance: TodayWidgetAppearance,
    val source: AppearanceSource,
    val recovered: Boolean,
    val writeRequired: Boolean,
)

/**
 * v2 文件与旧偏好的纯决策逻辑：迁移、损坏恢复、未知高版本都不依赖 Android。
 *
 * 规则（契约第 1 节）：
 * - v2 文件有效 → `source=v2`；
 * - v2 文件损坏/取值非法 → 默认值 + `recovered=true` + 重写合法文件；
 * - 文件里 `version>2`（更新的版本写过）→ 只读默认、`recovered=false`、不写；
 * - 没有 v2 文件且旧偏好有值 → 迁移（`theme` 保留，`standard`/`large` 映射字号）并立即写成 v2；
 * - 没有 v2 文件且旧偏好为空 → 默认值，不写文件（`source=defaults`）。
 */
internal object TodayWidgetAppearanceResolver {
    fun resolve(stored: StoredAppearanceFile, legacy: LegacyWidgetAppearance): AppearanceSnapshot {
        val defaults = TodayWidgetAppearance.defaults
        return when (stored) {
            StoredAppearanceFile.Missing -> when {
                legacy.readFailed -> AppearanceSnapshot(defaults, AppearanceSource.DEFAULTS, true, true)
                hasLegacy(legacy) -> AppearanceSnapshot(
                    migrate(legacy), AppearanceSource.MIGRATED, false, true,
                )
                else -> AppearanceSnapshot(defaults, AppearanceSource.DEFAULTS, false, false)
            }
            StoredAppearanceFile.Unreadable ->
                AppearanceSnapshot(defaults, AppearanceSource.DEFAULTS, true, true)
            is StoredAppearanceFile.Text -> {
                val decoded = runCatching { TodayWidgetAppearanceJson.decode(stored.value) }.getOrNull()
                when {
                    decoded != null -> AppearanceSnapshot(decoded, AppearanceSource.V2, false, false)
                    isFutureVersion(stored.value) ->
                        AppearanceSnapshot(defaults, AppearanceSource.DEFAULTS, false, false)
                    else -> AppearanceSnapshot(defaults, AppearanceSource.DEFAULTS, true, true)
                }
            }
        }
    }

    /** 旧 `standard` 回到默认 12/12/11；旧 `large` 映射 15/15/13；`theme` 原样保留。 */
    fun migrate(legacy: LegacyWidgetAppearance): TodayWidgetAppearance {
        val theme = legacy.theme?.takeIf { it in TodayWidgetAppearance.THEMES }
            ?: TodayWidgetAppearance.THEME_SYSTEM
        val (header, task, meta) = when (legacy.textSize) {
            "large" -> Triple(15, 15, 13)
            else -> Triple(
                TodayWidgetAppearance.DEFAULT_HEADER_SP,
                TodayWidgetAppearance.DEFAULT_TASK_SP,
                TodayWidgetAppearance.DEFAULT_META_SP,
            )
        }
        return TodayWidgetAppearance(
            theme = theme,
            headerSp = header,
            taskSp = task,
            metaSp = meta,
        )
    }

    private fun hasLegacy(legacy: LegacyWidgetAppearance): Boolean =
        legacy.theme != null || legacy.textSize != null

    private fun isFutureVersion(text: String): Boolean = runCatching {
        val raw = FlatJson.parseObject(text)["version"] as? Number ?: return@runCatching false
        raw.toLong() > TodayWidgetAppearance.VERSION
    }.getOrDefault(false)
}

/**
 * 设备本地 v2 外观存储：唯一写入点。
 *
 * `AtomicFile(noBackupFilesDir/today-widget-appearance-v2.json)` 保证保存与已提交值切换在同一
 * 边界；进程内按文件修改时间缓存，保存后立即换快照。旧 `SharedPreferences` 只在 v2 文件不存在时读。
 */
internal object TodayWidgetAppearanceStore {
    private const val LEGACY_PREFS = "today_widget_appearance"
    private const val LEGACY_THEME = "theme"
    private const val LEGACY_TEXT_SIZE = "textSize"
    private const val FILE_NAME = "today-widget-appearance-v2.json"
    private const val MAX_BYTES = 64 * 1024
    private val lock = Any()
    private var cached: AppearanceSnapshot? = null
    private var cachedStamp: String? = null

    fun read(context: Context): AppearanceSnapshot {
        val file = file(context)
        val currentStamp = stamp(file)
        synchronized(lock) {
            cached?.let { if (cachedStamp == currentStamp) return it }
        }
        val resolved = TodayWidgetAppearanceResolver.resolve(
            readFile(file), readLegacy(context),
        )
        val snapshot = if (resolved.writeRequired) {
            // 损坏恢复与迁移都要立刻落一份合法文件；写失败仍返回本次结果，但标记 recovered
            // 让设置页知道「本机偏好仍需重建」，下次读取会再试。
            val written = runCatching {
                write(file, TodayWidgetAppearanceJson.encode(resolved.appearance))
            }
            if (written.isFailure) {
                android.util.Log.w("MissionBook", "桌面小组件外观写入失败", written.exceptionOrNull())
                resolved.copy(recovered = true)
            } else {
                resolved
            }
        } else {
            resolved
        }
        synchronized(lock) {
            cached = snapshot
            cachedStamp = stamp(file)
        }
        return snapshot
    }

    /** 校验 → 原子保存；校验失败抛 [IllegalArgumentException]，IO 失败抛原异常。 */
    fun save(context: Context, values: Map<*, *>): TodayWidgetAppearance {
        val appearance = TodayWidgetAppearance.fromMap(values)
        val file = file(context)
        write(file, TodayWidgetAppearanceJson.encode(appearance))
        synchronized(lock) {
            cached = AppearanceSnapshot(appearance, AppearanceSource.V2, false, false)
            cachedStamp = stamp(file)
        }
        return appearance
    }

    private fun file(context: Context) = File(context.noBackupFilesDir, FILE_NAME)

    private fun stamp(file: File): String =
        "${file.exists()}:${file.lastModified()}:${file.length()}"

    private fun readFile(file: File): StoredAppearanceFile {
        val atomic = AtomicFile(file)
        return try {
            val bytes = atomic.readFully()
            require(bytes.size <= MAX_BYTES) { "外观文件过大" }
            StoredAppearanceFile.Text(String(bytes, Charsets.UTF_8))
        } catch (error: java.io.FileNotFoundException) {
            StoredAppearanceFile.Missing
        } catch (error: Exception) {
            StoredAppearanceFile.Unreadable
        }
    }

    private fun write(file: File, text: String) {
        val atomic = AtomicFile(file)
        val output = atomic.startWrite()
        try {
            output.write(text.toByteArray(Charsets.UTF_8))
            atomic.finishWrite(output)
        } catch (error: Exception) {
            atomic.failWrite(output)
            throw error
        }
    }

    private fun readLegacy(context: Context): LegacyWidgetAppearance = try {
        val prefs = context.getSharedPreferences(LEGACY_PREFS, Context.MODE_PRIVATE)
        LegacyWidgetAppearance(
            theme = prefs.getString(LEGACY_THEME, null),
            textSize = prefs.getString(LEGACY_TEXT_SIZE, null),
            readFailed = false,
        )
    } catch (error: Exception) {
        LegacyWidgetAppearance(null, null, true)
    }
}
