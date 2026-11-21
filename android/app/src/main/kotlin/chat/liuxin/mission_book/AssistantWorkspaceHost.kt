package chat.liuxin.mission_book

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** 主界面和 Android 助手在一个进程内租用同一个 FlutterEngine。 */
internal object AssistantWorkspaceHost {
    private val handler = Handler(Looper.getMainLooper())
    private val clients = mutableSetOf<Any>()
    private var engine: FlutterEngine? = null
    private var bridge: MethodChannel? = null
    private var lifecycle: MethodChannel? = null
    private var closing = false
    var generation: Int? = null
        private set
    var onState: ((Map<*, *>) -> Unit)? = null
    var onReady: (() -> Unit)? = null
    var onUnavailable: (() -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    fun acquire(context: Context, owner: Any): FlutterEngine {
        val app = context.applicationContext
        clients.add(owner)
        handler.removeCallbacks(idle)
        engine?.let { return it }
        val created = FlutterEngine(context.applicationContext)
        engine = created
        lifecycle = MethodChannel(created.dartExecutor.binaryMessenger, "mission_book/workspace_lifecycle")
        bridge = MethodChannel(created.dartExecutor.binaryMessenger, "mission_book/assistant_workspace").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (engine !== created) { result.success(null); return@setMethodCallHandler }
                when (call.method) {
                    "ready" -> if (!closing) {
                        generation = call.arguments as? Int
                        if (generation != null) onReady?.invoke()
                    }
                    "unavailable" -> if (generation == call.arguments) {
                        generation = null
                        onUnavailable?.invoke()
                    }
                    "state" -> (call.arguments as? Map<*, *>)?.let {
                        if (it["generation"] == generation) onState?.invoke(it)
                    }
                    "error" -> if (!closing) (call.arguments as? String)?.let { onError?.invoke(it) }
                    "verifyObservation" -> {
                        val data = call.arguments as? Map<*, *>
                        if (data == null || data["generation"] != generation) result.success(false)
                        else AssistantUsageMonitorService.verify(app, data) { valid ->
                            result.success(valid && data["generation"] == generation)
                        }
                        return@setMethodCallHandler
                    }
                    "currentUse" -> {
                        if (closing || call.arguments != generation) result.success(null)
                        else AssistantUsageMonitorService.currentUse(app) { use ->
                            result.success(use.takeIf { !closing && call.arguments == generation })
                        }
                        return@setMethodCallHandler
                    }
                    "resetObservation" -> if (call.arguments == generation) {
                        AssistantUsageMonitorService.configure(app, mapOf("enabled" to false))
                    }
                    else -> { result.notImplemented(); return@setMethodCallHandler }
                }
                result.success(null)
            }
        }
        created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return created
    }

    fun release(owner: Any) {
        clients.remove(owner)
        if (clients.isEmpty()) {
            handler.removeCallbacks(idle)
            handler.postDelayed(idle, 900)
        }
    }

    private val idle = Runnable {
        val owner = engine ?: return@Runnable
        if (clients.isNotEmpty() || closing) return@Runnable
        closing = true
        generation = null
        onUnavailable?.invoke()
        lifecycle?.invokeMethod("close", null, object : MethodChannel.Result {
            override fun success(result: Any?) = finishedClose(owner)
            override fun error(code: String, message: String?, details: Any?) = finishedClose(owner)
            override fun notImplemented() = finishedClose(owner)
        })
    }

    private fun finishedClose(owner: FlutterEngine) {
        if (engine !== owner) return
        closing = false
        if (clients.isNotEmpty()) {
            lifecycle?.invokeMethod("open", null)
        } else {
            generation = null
            bridge?.setMethodCallHandler(null)
            bridge = null
            lifecycle = null
            engine = null
            // 不在 MethodChannel 当前回调栈内销毁引擎。
            handler.post { owner.destroy() }
        }
    }

    fun call(method: String, data: Map<String, Any?> = emptyMap(),
             failure: (String) -> Unit = { onError?.invoke(it) }, success: (Any?) -> Unit = {}) {
        val channel = bridge
        val revision = generation
        if (channel == null || revision == null || closing) {
            failure("助手正在准备，请稍后重试")
            return
        }
        channel.invokeMethod(method, data + ("generation" to revision), object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (channel === bridge && revision == generation) success(result)
            }
            override fun error(code: String, message: String?, details: Any?) {
                if (channel === bridge && revision == generation) failure(message ?: "助手操作失败")
            }
            override fun notImplemented() = error("missing", "助手尚未准备好", null)
        })
    }
}
