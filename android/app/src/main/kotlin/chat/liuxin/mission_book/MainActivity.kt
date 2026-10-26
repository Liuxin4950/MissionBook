package chat.liuxin.mission_book

import android.app.AlarmManager
import android.app.NotificationManager
import android.os.Build
import android.provider.Settings
import android.app.Activity
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
 * Android 只实现 Mission Book 当前需要的 openFile。
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
    // ContentProvider 读取和副本写入都可能很慢，交给后台线程，避免阻塞 Flutter 界面。
    private val fileCopyExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PlannedAlarm.attach(flutterEngine, applicationContext)
        fileCopyExecutor.execute { fileSelectorCacheRoot().deleteRecursively() }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mission_book/device")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "capabilities" -> {
                            val info = packageManager.getPackageInfo(packageName, 0)
                            val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                            result.success(mapOf(
                                "version" to "${info.versionName} ($code)",
                                "notifications" to getSystemService(NotificationManager::class.java).areNotificationsEnabled(),
                                "exactAlarms" to (Build.VERSION.SDK_INT < 31 || getSystemService(AlarmManager::class.java).canScheduleExactAlarms()),
                            ))
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
        PlannedAlarm.detachPrimary()
        super.cleanUpFlutterEngine(flutterEngine)
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
        pendingFileLimit = if (mimeTypes.contains("application/json")) MAX_GOAL_JSON_BYTES else MAX_ATTACHMENT_BYTES
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
                            if (maxBytes == MAX_GOAL_JSON_BYTES) "目标 JSON 不能超过 2 MiB。" else "每个附件不能超过 20 MiB。"
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
        const val MAX_GOAL_JSON_BYTES = 2L * 1024L * 1024L
        const val FILE_SELECTOR_CHANNEL = "plugins.flutter.io/file_selector"
        const val OPEN_FILE_REQUEST_CODE = 43021
        const val SAVE_BACKUP_REQUEST_CODE = 43022
    }
}
