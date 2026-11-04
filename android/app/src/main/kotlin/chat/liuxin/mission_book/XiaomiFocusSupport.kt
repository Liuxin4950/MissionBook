package chat.liuxin.mission_book

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings

/** 系统能力和应用授权分别查询；耗时的 Provider 调用由调用者放在后台线程。 */
data class XiaomiFocusSupport(
    val islandSupported: Boolean?,
    val focusPermission: Boolean?,
    val configured: Boolean,
) {
    val enabled: Boolean get() = islandSupported == true && focusPermission == true && configured

    companion object {
        fun read(context: Context): XiaomiFocusSupport {
            val meta = context.packageManager.getApplicationInfo(
                context.packageName, PackageManager.GET_META_DATA
            ).metaData
            val configured = !meta?.get("com.xiaomi.xms.APP_ID")?.toString().isNullOrBlank()
            val protocol = Settings.System.getInt(context.contentResolver, "notification_focus_protocol", 0)
            val supported: Boolean? = if (protocol < 3) false else try {
                Class.forName("android.os.SystemProperties")
                    .getDeclaredMethod("getBoolean", String::class.java, Boolean::class.javaPrimitiveType)
                    .invoke(null, "persist.sys.feature.island", false) as Boolean
            } catch (_: Exception) { null }
            val permission: Boolean? = if (protocol == 0) false else try {
                context.contentResolver.call(
                    Uri.parse("content://miui.statusbar.notification.public"),
                    "canShowFocus", null,
                    Bundle().apply { putString("package", context.packageName) }
                )?.getBoolean("canShowFocus", false)
            } catch (_: Exception) { null }
            return XiaomiFocusSupport(supported, permission, configured)
        }
    }
}
