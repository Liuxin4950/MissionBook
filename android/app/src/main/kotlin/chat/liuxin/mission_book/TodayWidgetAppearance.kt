package chat.liuxin.mission_book

import android.content.Context
import android.os.Build
import android.widget.RemoteViews

/** A device-local appearance choice, independent of the app and today's task cache. */
internal data class TodayWidgetAppearance(val theme: String, val textSize: String) {
    val largeText get() = textSize == LARGE

    fun toMap(): Map<String, String> = mapOf("theme" to theme, "textSize" to textSize)

    private data class Colors(val primary: Int, val secondary: Int, val accent: Int)

    private val explicitColors: Colors?
        get() = when (theme) {
            LIGHT -> Colors(0xFF242741.toInt(), 0xFF4B5174.toInt(), 0xFF414990.toInt())
            DARK -> Colors(0xFFF1F2FF.toInt(), 0xFFCCD0EE.toInt(), 0xFFD2D6FF.toInt())
            else -> null
        }

    fun applyRoot(context: Context, views: RemoteViews) {
        views.setImageViewResource(R.id.today_widget_card_surface, when (theme) {
            LIGHT -> R.drawable.today_widget_background_light
            DARK -> R.drawable.today_widget_background_dark
            else -> R.drawable.today_widget_background
        })
        val colors = explicitColors
        views.textColor(context, R.id.today_widget_title, R.color.today_widget_accent, colors?.accent)
        views.textColor(context, R.id.today_widget_date, R.color.today_widget_accent, colors?.accent)
        views.textColor(context, R.id.today_widget_empty, R.color.today_widget_secondary, colors?.secondary)
        views.textColor(context, R.id.today_widget_more, R.color.today_widget_accent, colors?.accent)
    }

    fun applyRow(context: Context, views: RemoteViews, hasTimeColumn: Boolean) {
        views.setImageViewResource(R.id.today_widget_row_surface, when (theme) {
            LIGHT -> R.drawable.today_widget_row_background_light
            DARK -> R.drawable.today_widget_row_background_dark
            else -> R.drawable.today_widget_row_background
        })
        val colors = explicitColors
        views.textColor(context, R.id.today_widget_row_title, R.color.today_widget_primary, colors?.primary)
        views.textColor(context, R.id.today_widget_row_subtitle, R.color.today_widget_secondary, colors?.secondary)
        if (hasTimeColumn) {
            views.textColor(context, R.id.today_widget_row_time, R.color.today_widget_secondary, colors?.secondary)
            if (colors == null && Build.VERSION.SDK_INT >= 31) {
                views.setColor(R.id.today_widget_row_accent, "setBackgroundColor", R.color.today_widget_accent)
            } else {
                views.setInt(R.id.today_widget_row_accent, "setBackgroundColor", colors?.accent
                    ?: context.getColor(R.color.today_widget_accent))
            }
        }
    }

    // Always set colors, even returning from an explicit theme to System: Launcher can reapply
    // RemoteViews to existing views instead of reinflating them. Android 12+ resolves resources in host.
    private fun RemoteViews.textColor(context: Context, id: Int, resource: Int, explicit: Int?) {
        if (explicit == null && Build.VERSION.SDK_INT >= 31) {
            setColor(id, "setTextColor", resource)
        } else {
            setTextColor(id, explicit ?: context.getColor(resource))
        }
    }

    companion object {
        private const val PREFS = "today_widget_appearance"
        private const val SYSTEM = "system"
        private const val LIGHT = "light"
        private const val DARK = "dark"
        private const val STANDARD = "standard"
        private const val LARGE = "large"
        private val themes = setOf(SYSTEM, LIGHT, DARK)
        private val textSizes = setOf(STANDARD, LARGE)

        fun read(context: Context): TodayWidgetAppearance {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val theme = prefs.getString("theme", SYSTEM)?.takeIf(themes::contains) ?: SYSTEM
            val size = prefs.getString("textSize", STANDARD)?.takeIf(textSizes::contains) ?: STANDARD
            return TodayWidgetAppearance(theme, size)
        }

        fun save(context: Context, values: Map<*, *>) {
            val theme = requireNotNull((values["theme"] as? String)?.takeIf(themes::contains))
            val size = requireNotNull((values["textSize"] as? String)?.takeIf(textSizes::contains))
            check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("theme", theme)
                .putString("textSize", size)
                .commit()) { "无法保存桌面小组件样式" }
        }
    }
}
