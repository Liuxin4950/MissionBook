package chat.liuxin.mission_book

import android.app.AlarmManager
import android.app.NotificationManager
import android.os.Build
import android.provider.Settings
import android.app.Activity
import android.os.Bundle
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Android 系统桥：文件选择、备份保存、版本与通知能力查询。
 *
 * 系统 ACTION_OPEN_DOCUMENT 负责授权；选中的外部 Uri 会先复制到应用 cache，
 * Flutter 随后再复制到正式的 Evidence 私有目录。这样既不申请存储权限，也不
 * 长期依赖 ContentProvider 的临时授权。
 */
class MainActivity : FlutterActivity() {
    private var pendingBackupResult: MethodChannel.Result? = null
    private var pendingBackupFile: File? = null
    private var pendingFileResult: MethodChannel.Result? = null
    private var pendingFileLimit = MAX_ATTACHMENT_BYTES
    private var pendingOverlayResult: MethodChannel.Result? = null
    private var pendingAssistantOpen = false
    private var pendingCapturePath: String? = null
    private var assistantOverlayChannel: MethodChannel? = null
    // ContentProvider 读取、能力查询和文件写入交给后台线程，避免阻塞 Flutter 界面。
    private val fileCopyExecutor = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingAssistantOpen = intent?.getBooleanExtra(EXTRA_OPEN_ASSISTANT, false) == true
        pendingCapturePath = intent?.getStringExtra(EXTRA_CAPTURE_PATH)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PlannedAlarm.attach(flutterEngine, applicationContext)
        assistantOverlayChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ASSISTANT_OVERLAY_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumePendingOpen" -> {
                        val pending = pendingAssistantOpen
                        pendingAssistantOpen = false
                        result.success(pending)
                    }
                    "consumePendingCapture" -> consumePendingCapture(result)
                    else -> result.notImplemented()
                }
            }
        }
        fileCopyExecutor.execute { fileSelectorCacheRoot().deleteRecursively() }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mission_book/device")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "capabilities" -> {
                            fileCopyExecutor.execute {
                                try {
                                    val info = packageManager.getPackageInfo(packageName, 0)
                                    val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                                    val manager = getSystemService(NotificationManager::class.java)
                                    val channelEnabled = if (Build.VERSION.SDK_INT >= 26)
                                        manager.getNotificationChannel("mission_execution_v2")?.let { it.importance != NotificationManager.IMPORTANCE_NONE }
                                        else true
                                    val focus = XiaomiFocusSupport.read(applicationContext)
                                    val value = mapOf(
                                        "version" to "${info.versionName} ($code)",
                                        "notifications" to manager.areNotificationsEnabled(),
                                        "exactAlarms" to (Build.VERSION.SDK_INT < 31 || getSystemService(AlarmManager::class.java).canScheduleExactAlarms()),
                                        "executionNotifications" to channelEnabled,
                                        "islandSupported" to focus.islandSupported,
                                        "focusPermission" to focus.focusPermission,
                                        "focusConfigured" to focus.configured,
                                    )
                                    runOnUiThread { result.success(value) }
                                } catch (error: Exception) {
                                    runOnUiThread { result.error("device_operation_failed", error.message, null) }
                                }
                            }
                        }
                        "notificationSettings" -> {
                            val intent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                            startActivity(intent)
                            result.success(null)
                        }
                        "exactAlarmSettings" -> {
                            val intent = if (Build.VERSION.SDK_INT >= 31) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))
                            else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                            startActivity(intent)
                            result.success(null)
                        }
                        "toggleAssistantOverlay" -> toggleAssistantOverlay(result)
                        "saveBackup" -> {
                            check(pendingBackupResult == null) { "已有备份保存窗口" }
                            val source = File(requireNotNull(call.argument<String>("path"))).canonicalFile
                            check(source.path.startsWith(cacheDir.canonicalPath + File.separator) && source.isFile) { "备份缓存文件无效" }
                            pendingBackupFile = source
                            pendingBackupResult = result
                            try {
                                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "application/zip"
                                    putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                                }, SAVE_BACKUP_REQUEST_CODE)
                            } catch (error: Exception) {
                                pendingBackupFile = null
                                pendingBackupResult = null
                                throw error
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("device_operation_failed", error.message, null)
                }
            }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FILE_SELECTOR_CHANNEL,
        ).setMethodCallHandler(::handleFileSelectorCall)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        assistantOverlayChannel?.setMethodCallHandler(null)
        assistantOverlayChannel = null
        PlannedAlarm.detachPrimary()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(EXTRA_OPEN_ASSISTANT, false)) {
            pendingAssistantOpen = true
            assistantOverlayChannel?.invokeMethod("pendingOpen", null)
        }
        intent.getStringExtra(EXTRA_CAPTURE_PATH)?.let { path ->
            pendingCapturePath = path
            assistantOverlayChannel?.invokeMethod("pendingCapture", null)
        }
    }

    private fun consumePendingCapture(result: MethodChannel.Result) {
        val path = pendingCapturePath ?: run { result.success(null); return }
        pendingCapturePath = null
        fileCopyExecutor.execute {
            try {
                val root = File(cacheDir, "assistant_capture").canonicalFile
                val source = File(path).canonicalFile
                check(source.path.startsWith(root.path + File.separator) && source.isFile) { "截屏缓存无效" }
                check(source.length() <= MAX_ASSISTANT_CAPTURE_BYTES) { "截屏文件超出大小限制" }
                val bytes = source.readBytes()
                source.delete()
                runOnUiThread { result.success(bytes) }
            } catch (error: Exception) {
                runOnUiThread { result.error("capture_read_failed", error.message, null) }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (overlayEnabled()) sendOverlayAction(AssistantOverlayService.ACTION_HIDE)
    }

    override fun onPause() {
        if (overlayEnabled() && !capturePending()) {
            sendOverlayAction(AssistantOverlayService.ACTION_SHOW)
        }
        super.onPause()
    }

    private fun toggleAssistantOverlay(result: MethodChannel.Result) {
        if (overlayEnabled()) {
            getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE)
                .edit().putBoolean(AssistantOverlayService.ENABLED_KEY, false).apply()
            stopService(Intent(this, AssistantOverlayService::class.java))
            result.success(false)
            return
        }
        if (!Settings.canDrawOverlays(this)) {
            check(pendingOverlayResult == null) { "已有悬浮窗权限设置正在打开" }
            pendingOverlayResult = result
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            )
            try {
                startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
            } catch (error: Exception) {
                pendingOverlayResult = null
                result.error("overlay_settings_failed", error.message, null)
            }
            return
        }
        enableAssistantOverlay(result)
    }

    private fun enableAssistantOverlay(result: MethodChannel.Result) {
        getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE)
            .edit().putBoolean(AssistantOverlayService.ENABLED_KEY, true).apply()
        try {
            val intent = Intent(this, AssistantOverlayService::class.java)
                .setAction(AssistantOverlayService.ACTION_SHOW)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
            result.success(true)
        } catch (error: Exception) {
            getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE)
                .edit().putBoolean(AssistantOverlayService.ENABLED_KEY, false).apply()
            result.error("overlay_start_failed", error.message, null)
        }
    }

    private fun overlayEnabled(): Boolean =
        getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE)
            .getBoolean(AssistantOverlayService.ENABLED_KEY, false)

    private fun capturePending(): Boolean =
        getSharedPreferences(AssistantOverlayService.PREFS, MODE_PRIVATE)
            .getBoolean(AssistantOverlayService.CAPTURE_PENDING_KEY, false)

    private fun sendOverlayAction(action: String) {
        startService(Intent(this, AssistantOverlayService::class.java).setAction(action))
    }

    private fun handleFileSelectorCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "openFile") {
            result.notImplemented()
            return
        }
        if (pendingFileResult != null) {
            result.error("selection_in_progress", "已有文件选择窗口正在打开。", null)
            return
        }

        val mimeTypes = extractMimeTypes(call)
        pendingFileLimit = when {
            mimeTypes.contains("application/zip") -> MAX_BACKUP_BYTES
            mimeTypes.contains("application/json") -> MAX_GOAL_JSON_BYTES
            else -> MAX_ATTACHMENT_BYTES
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (mimeTypes.size == 1) mimeTypes.single() else "*/*"
            if (mimeTypes.size > 1) {
                putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            }
        }
        pendingFileResult = result
        try {
            startActivityForResult(intent, OPEN_FILE_REQUEST_CODE)
        } catch (error: Exception) {
            pendingFileResult = null
            result.error("open_file_failed", error.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            val result = pendingOverlayResult ?: return
            pendingOverlayResult = null
            if (Settings.canDrawOverlays(this)) enableAssistantOverlay(result)
            else result.success(false)
            return
        }
        if (requestCode == SAVE_BACKUP_REQUEST_CODE) {
            val result = pendingBackupResult ?: return
            val source = pendingBackupFile
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pendingBackupResult = null
                pendingBackupFile = null
                result.success(null)
                return
            }
            val uri = data.data!!
            fileCopyExecutor.execute {
                try {
                    requireNotNull(source).inputStream().use { input ->
                        requireNotNull(contentResolver.openOutputStream(uri, "wt")).use { output ->
                            input.copyTo(output)
                        }
                    }
                    val name = queryDisplayName(uri) ?: uri.toString()
                    runOnUiThread {
                        pendingBackupResult = null
                        pendingBackupFile = null
                        val location = when (uri.authority) {
                            "com.android.providers.downloads.documents" -> "下载"
                            "com.android.externalstorage.documents" -> {
                                val documentId = android.provider.DocumentsContract.getDocumentId(uri)
                                documentId.substringAfter(':', "").substringBeforeLast('/', "")
                            }
                            else -> ""
                        }
                        result.success(if (location.isBlank()) "已保存：$name" else "已保存到 $location\n$name")
                    }
                } catch (error: Exception) {
                    // 本次系统选择器刚创建的目标，失败时尽量回收不完整文件。
                    try { android.provider.DocumentsContract.deleteDocument(contentResolver, uri) } catch (_: Exception) { }
                    runOnUiThread {
                        pendingBackupResult = null
                        pendingBackupFile = null
                        result.error("backup_save_failed", error.message, null)
                    }
                }
            }
            return
        }
        if (requestCode != OPEN_FILE_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingFileResult ?: return
        if (resultCode != Activity.RESULT_OK) {
            pendingFileResult = null
            result.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            pendingFileResult = null
            result.error("empty_selection", "系统没有返回可读取的文件。", null)
            return
        }
        fileCopyExecutor.execute {
            try {
                val selectedPath = copySelectionToCache(uri, pendingFileLimit).absolutePath
                runOnUiThread {
                    pendingFileResult = null
                    result.success(listOf(selectedPath))
                }
            } catch (error: Exception) {
                runOnUiThread {
                    pendingFileResult = null
                    result.error("copy_selection_failed", error.message, null)
                }
            }
        }
    }

    private fun copySelectionToCache(uri: Uri, maxBytes: Long): File {
        val rawName = queryDisplayName(uri) ?: "attachment"
        // ContentProvider 的文件名属于不可信输入：去掉路径片段与控制字符。
        val safeName = rawName
            .replace('\\', '/')
            .substringAfterLast('/')
            .replace(Regex("[\\u0000-\\u001F\\u007F]"), "_")
            .take(180)
            .ifBlank { "attachment" }
        val root = fileSelectorCacheRoot()
        root.deleteRecursively()
        val targetDirectory = File(root, UUID.randomUUID().toString())
        check(targetDirectory.mkdirs() || targetDirectory.isDirectory) {
            "无法创建文件选择缓存目录。"
        }
        val target = File(targetDirectory, safeName)
        try {
            contentResolver.openInputStream(uri).use { input ->
                checkNotNull(input) { "无法读取所选文件。" }
                target.outputStream().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var totalBytes = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        totalBytes += count
                        check(totalBytes <= maxBytes) {
                            when (maxBytes) {
                                MAX_BACKUP_BYTES -> "备份不能超过 256 MiB。"
                                MAX_GOAL_JSON_BYTES -> "目标 JSON 不能超过 32 MiB。"
                                else -> "每个附件不能超过 20 MiB。"
                            }
                        }
                        output.write(buffer, 0, count)
                    }
                }
            }
        } catch (error: Exception) {
            target.delete()
            throw error
        }
        return target
    }

    private fun queryDisplayName(uri: Uri): String? {
        return contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) null else cursor.getString(index)
        }
    }

    private fun extractMimeTypes(call: MethodCall): List<String> {
        val groups = call.argument<List<*>>("acceptedTypeGroups") ?: return emptyList()
        return groups.flatMap { group ->
            val map = group as? Map<*, *> ?: return@flatMap emptyList()
            val values = map["mimeTypes"] as? List<*> ?: return@flatMap emptyList()
            values.filterIsInstance<String>()
        }.distinct()
    }

    private fun fileSelectorCacheRoot(): File =
        File(cacheDir, "mission_book_file_selector")

    override fun onDestroy() {
        fileCopyExecutor.shutdown()
        super.onDestroy()
    }

    private companion object {
        const val MAX_ATTACHMENT_BYTES = 20L * 1024L * 1024L
        const val MAX_BACKUP_BYTES = 256L * 1024L * 1024L
        const val MAX_GOAL_JSON_BYTES = 32L * 1024L * 1024L
        const val FILE_SELECTOR_CHANNEL = "plugins.flutter.io/file_selector"
        const val OPEN_FILE_REQUEST_CODE = 43021
        const val SAVE_BACKUP_REQUEST_CODE = 43022
        const val OVERLAY_PERMISSION_REQUEST_CODE = 43023
        const val ASSISTANT_OVERLAY_CHANNEL = "mission_book/assistant_overlay"
        const val EXTRA_OPEN_ASSISTANT = "assistant_overlay_open"
        const val EXTRA_CAPTURE_PATH = "assistant_capture_path"
        const val MAX_ASSISTANT_CAPTURE_BYTES = 4L * 1024L * 1024L
    }
}
