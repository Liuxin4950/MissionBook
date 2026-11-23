package chat.liuxin.mission_book

import android.animation.ValueAnimator
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.util.TypedValue
import android.widget.TextView
import org.json.JSONObject
import java.io.File

/**
 * 悬浮助手所有 App 自绘表面的唯一语义令牌来源。
 *
 * 悬浮快捷动作、聊天面板、截图工具栏/长截图控制条、录音与识别面板、主动通知都在这里取色、
 * 取间距和圆角，避免各文件散落硬编码。值对应 Flutter 的 `AppColors`/`AppTypography`/`AppLayout`；
 * 原生取不到全局主题，因此集中复制一份并只在这一个文件里维护。
 *
 * 说明：本文件由集成者冻结。各工作包需要新的组合 helper 时，在自己的文件里用这些常量拼装，
 * 不要并行修改本文件；确实必须扩展令牌时先通知集成者。
 */
internal object AssistantNativeTheme {
    // 颜色：与 lib/core/theme/colors.dart 的语义角色一一对应。
    const val pageBackground = 0xFFF7F8F5.toInt()
    const val cardSurface = 0xFFFFFFFF.toInt()
    const val surfaceMuted = 0xFFF0F2EE.toInt()
    const val primary = 0xFF244D3D.toInt()
    const val primarySoft = 0xFFEEF2EC.toInt()
    const val primaryPressed = 0xFF1B3B2F.toInt()
    const val accent = 0xFFD9F28B.toInt()
    const val accentSoft = 0xFFF1F6E6.toInt()
    const val onPrimary = 0xFFFFFFFF.toInt()
    const val textPrimary = 0xFF282E2A.toInt()
    const val textSecondary = 0xFF626A64.toInt()
    const val hairline = 0xFFE0E5DD.toInt()
    const val outline = 0xFF626A64.toInt()
    const val disabled = 0xFFE4E7DF.toInt()
    const val onDisabled = 0xFF5E675F.toInt()
    const val error = 0xFFA35448.toInt()
    const val errorSoft = 0xFFF8EAE6.toInt()
    const val warning = 0xFF805D28.toInt()
    const val warningSoft = 0xFFF4EBDD.toInt()
    const val shadow = 0x33000000
    // 截图预览的媒体画布保持黑色，不随主题改白；其上控制条用暖白与森林绿。
    const val mediaBackground = 0xFF000000.toInt()
    const val onMedia = 0xFFFFFFFF.toInt()
    /** 轻按压/焦点反馈的默认水波纹，与快捷动作原有效果一致。 */
    const val ripple = 0x33244D3D

    // 字号（sp）：对应 AppTypography 的 itemTitle/metadata/readingBody/dialogTitle/pageTitle。
    const val textCaption = 11f
    const val textMetadata = 12f
    const val textBody = 14f
    const val textTitle = 16f
    const val textSection = 20f

    // 间距（dp）：对应 AppLayout 的 spaceXs..spaceXl。
    const val spaceXs = 4
    const val spaceSm = 8
    const val spaceMd = 12
    const val spaceLg = 16
    const val spaceXl = 24

    // 圆角（dp）：对应 AppLayout radiusSm..radiusXxl。
    const val radiusSm = 8f
    const val radiusMd = 12f
    const val radiusLg = 16f
    const val radiusXl = 20f
    const val radiusXxl = 24f

    /** 普通触控下限；外观令牌不另立更小的点击标准。 */
    const val minTouchDp = 48

    fun dp(context: Context, value: Int): Int =
        (value * context.resources.displayMetrics.density + .5f).toInt()

    fun dpFloat(context: Context, value: Int): Float =
        value * context.resources.displayMetrics.density

    /** 纯色圆角面，用于面板、行底和按钮底；圆角按 dp 传入并在内部换算 px。 */
    fun surface(
        context: Context,
        color: Int,
        radiusDp: Float = radiusLg,
        strokeColor: Int? = null,
        strokeDp: Float = 0f,
    ): GradientDrawable {
        val density = context.resources.displayMetrics.density
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(color)
            cornerRadius = radiusDp * density
            if (strokeColor != null && strokeDp > 0f) {
                setStroke((strokeDp * density).toInt().coerceAtLeast(1), strokeColor)
            }
        }
    }

    /** 可点表面：底色 + 水波纹；内容形状与 [surface] 使用同一圆角基准。 */
    fun clickableSurface(
        context: Context,
        color: Int,
        radiusDp: Float,
        rippleColor: Int = ripple,
    ): RippleDrawable = RippleDrawable(
        ColorStateList.valueOf(rippleColor),
        surface(context, color, radiusDp),
        null,
    )

    /** 统一设置 TextView 的字号与颜色，避免各面板各自换算。 */
    fun text(
        view: TextView,
        sp: Float,
        color: Int = textPrimary,
        bold: Boolean = false,
        maxLines: Int = Int.MAX_VALUE,
    ) {
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        view.setTextColor(color)
        view.maxLines = maxLines
        view.includeFontPadding = false
        if (bold) view.typeface = android.graphics.Typeface.DEFAULT_BOLD
    }

    /**
     * 与页面动效偏好同源：读取 Flutter 保存的 `page_motion.txt`（兼容旧枚举文本），
     * `reduced` 返回 0，`full` 或系统允许动画时返回 180ms。
     * 原生无法读取 Flutter 主题，因此只按已保存偏好与系统动画开关判定。
     */
    fun motionDuration(context: Context): Long {
        val preference = runCatching {
            val saved = File(context.filesDir, "page_motion.txt").takeIf { it.exists() }
                ?.readText()?.trim().orEmpty()
            if (saved.startsWith("{")) JSONObject(saved).optString("preference") else saved
        }.getOrDefault("system")
        if (preference == "reduced") return 0L
        val systemEnabled = Build.VERSION.SDK_INT < 26 || ValueAnimator.areAnimatorsEnabled()
        return if (preference == "full" || systemEnabled) 180L else 0L
    }
}
