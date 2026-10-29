# agent_core

MissionBook 的独立 Dart Agent 基座。保留多供应商配置，当前优先适配 DeepSeek Flash；支持 Messages 和 Chat Completions 两种协议。基座管理模型循环、工具、上下文和会话，App 提供业务服务、权限策略和自己的存储适配。

当前实现与验收见 [FOUNDATION.md](FOUNDATION.md)、[VALIDATION.md](VALIDATION.md)。沿一次调用读代码，先看 [阅读路线](阅读路线.md)。

## 启动

在 PowerShell 中：

```powershell
cd E:\working\mission_book\packages\agent_core
.\run.ps1 --demo
```

演示使用脚本模型，不消耗 API；查询时间仍执行真实设备工具。启动器第一次构建原生程序，以后直接运行；源码变动后自动重建。也可以继续使用 `dart run bin/agent.dart`。

连接真实模型：

```powershell
$env:DEEPSEEK_API_KEY = '你的APIKey'
.\run.ps1
```

凭据只在当前终端环境中提供，不写入源码或模型配置。这里不自动加载 `.env`。正常启动默认使用 DeepSeek Flash 的 Chat Completions 协议；旧会话保存的 Messages 配置仍可打开。

```powershell
.\run.ps1 --prompt '请查当前时间'
.\run.ps1 --image 'E:\资料\截图.png' --prompt '识别图片中的文字'
.\run.ps1 --session 会话完整编号
.\run.ps1 --config agent.config.json
```

`--no-color` 关闭颜色；输出重定向时自动使用普通文本。运行中 Ctrl+C 取消当前操作，空闲时退出。默认日志目录是 `.agent-data/`，可通过 `--sessions 路径` 改变。

## 常用命令

| 命令 | 用途 |
| --- | --- |
| `/image "路径" [问题]` | 读取本地图片；也接受公开图片链接 |
| `/thinking off/low/high/max` | 调整当前会话思考强度，实际输入用空格，如 `/thinking low` |
| `/output 65536` | 调整输出预算，不能超过模型硬上限或上下文窗口 |
| `/format text`、`/format json` | 普通回答或 JSON 对象；JSON 模式使用 Chat 协议 |
| `/models`、`/model 编号` | 查看、切换命名配置；摘要模型用 `/summary-model 编号` |
| `/compact`、`/resume` | 整理旧上下文、继续中断轮次 |
| `/new`、`/list`、`/open 编号` | 管理会话；打开时支持唯一编号前缀 |
| `/rename 名称`、`/fork` | 改名、创建分支 |
| `/history`、`/status` | 原始对话、完整编号与当前配置 |
| `/export 路径`、`/import 路径` | 完整会话导出、导入为新会话 |
| `/delete 编号` | 删除已关闭的本地会话 |
| `/help`、`/exit` | 查看帮助、保存退出 |

## 模型配置：能力上限与输出预算分开

DeepSeek Flash 官方当前上下文为 **1,048,576 tokens**，单次最大输出为 **393,216 tokens**。上下文包含输入和输出；本包日常默认输出预算为 **8,192**，思考默认关闭。可以提高输出预算或开启思考，较大的输出预算会减少可用输入空间。[官方模型元数据](https://api-docs.deepseek.com/api/list-models/)、[生成参数](https://api-docs.deepseek.com/api/create-chat-completion/)

复制 [配置样例](example/agent.config.example.json) 后修改：

```powershell
Copy-Item example/agent.config.example.json agent.config.json
.\run.ps1 --config agent.config.json
```

| 字段 | 意义 |
| --- | --- |
| `id` | 本地配置编号，`/model` 使用它 |
| `provider`、`model` | 供应商标识、请求的模型名称 |
| `endpoint`、`protocol` | 完整接口地址、`messages` 或 `chatCompletions` |
| `credentialKey` | 凭据标识；CLI 读同名环境变量，App 可映射安全存储 |
| `contextWindowTokens` | 该模型的输入加输出窗口 |
| `outputTokenLimit` | 供应商允许的输出硬上限；未知时可省略 |
| `maxOutputTokens` | 日常请求输出预算 |
| `supportsImages` | 当前配置是否允许视觉输入 |
| `reasoningEffort`、`temperature` | 思考强度、可选温度；具体效果取决于供应商 |
| `requestTimeoutMs` | 等待凭据、响应头或下一段数据的空闲上限 |
| `totalRequestTimeoutMs` | 一次请求的总时长，包含凭据等待和心跳 |
| `retry` | 有限重试；本地退避上限不会缩短服务器的 Retry-After |
| `maxRunDurationMs` | 一轮操作总时长，默认 15 分钟 |
| `context` | 压缩触发比例、保留消息、摘要输出和摘要调用上限 |

其他供应商分别填写自己的限额，不能统一设为 1M。旧配置未填写预算时仍保留 64,000/2,048 的兼容默认值；旧 `credentialEnvironment` 字段仍可读，新配置使用 `credentialKey`。目前实际供应商验收范围见验证记录，兼容协议不代表每家服务的所有扩展都已验证。

## 图片

`ImageInput.fromBytes` 识别实际图片格式和尺寸，支持 JPEG、PNG、GIF、WebP。`ImageBlock` 支持链接、内联图片和云端文件引用；Chat 协议支持 `auto/low/high/original` detail。Messages 按原图发送，detail 选择由 Chat 协议提供。

DeepSeek 单张内联图片最多 32 MiB，文件引用最多 64 MiB，请求体最多 48 MiB，最多 600 张。15 张及以上时单边限制降为 4096 像素，否则为 8192；已知尺寸和大小在发送前校验，远程链接的实际内容由服务端核验。[官方视觉说明](https://api-docs.deepseek.com/guides/vision/)

CLI 连接官方 DeepSeek 时，先用 `DeepSeekFilesClient` 上传本地图片，随后保存和复用文件编号。默认保留云端文件，SDK 也可显式指定 1 小时至 30 天有效期，支持查询、分页和删除。删除本地会话不会自动删除云端图片。[官方 Files API](https://api-docs.deepseek.com/guides/files_api/)

其他兼容服务使用链接或内联图片。文件引用只能交回所属供应商；切换到无法读取现有图片的配置会明确拒绝。会话导出中的文件引用不包含原图，App 接入时应把原图纳入已有材料备份。

## 循环、工具与取消

`AgentSession.send()` 接收输入，`AgentLoop` 请求模型，工具返回结果后再请求模型，直到完成、达到上限或失败。授权回调由宿主提供；执行工具前必须先保存 `tool_execution_started`。

- 正常成功返回 `ToolOutput.success`。
- 已知业务失败返回 `ToolOutput.failure`；明确保证没有提交或已经回滚时，也可抛 `ToolRejected`。
- `readOnly: true` 只用于确实无副作用的工具，其异常可以正常回传。
- 写工具的未知异常、开始后无法确认结果的取消或超时，进入 `outcome_unknown`，阻止继续。
- 已经提交的工具应返回真实结果。普通取消会等待协作结果；整轮期限到达仍未返回时，写工具需要核对，不能自动重放。

`ToolContext.idempotencyKey` 组合会话编号和调用编号。App 应把它稳定映射到业务命令身份，并复用同一事务和幂等校验。基座不能代替业务数据库判断是否提交。

核对后调用 `resolveToolOutcome(callId, actual, source: ...)`。原始未知事实保留，当前 `unknownOutcomes` 会清除，结构化的实际结果可从 `resolvedOutcomes` 读取。

## 上下文与用量

默认 `ApproximateTokenEstimator` 按字符估算并留余量，图片单独计算；DeepSeek 每图采用官方 1024-token 上界，其他配置采用可替换的保守估算。它不是精确 tokenizer；宿主可注入 `TokenEstimator`。[官方 token 说明](https://api-docs.deepseek.com/quick_start/token_usage/)

自动压缩保留近期完整工具组和最新用户输入。摘要模型接收原生消息与视觉块，base64 不会被转成普通文字。摘要模型无法接收某图时，使用带原消息编号的明确占位说明。较大的历史分块摘要，按组累计预算；图片的数量和传输大小也参与分块。

触发线决定何时尝试整理，硬预算决定能否发出请求。摘要缩小且低于硬预算即可接受；很短的手动压缩可能直接返回无需整理。原始对话始终保留。

用量汇总包括成功、失败尝试中已经报告的用量及摘要请求。断流可能丢失服务端尚未报告的计数，`usageIncomplete` 会说明这点；汇总不是完整账单。

`inputTokens` 统一表示含缓存的全部输入；`cachedInputTokens` 是其中的缓存命中部分，不再相加。模型只返回思考、没有正文时，会保存已返回内容和用量并报告未完成，可以用 `/resume` 继续。

## 会话存储与 App 接入

`SessionStore` 提供异步分页、创建、只读打开和删除；不携带文件尾字节等专属字段。`recordCount` 获取数量，`await readRecords(start: ..., limit: ...)` 读取记录，`await export()` 导出。重命名属于 `AgentSession.rename()`。

`MemorySessionStore` 用于测试或临时会话。`FileSessionStore` 保存带校验的 JSONL，逐条 flush；先写临时文件再发布导入，流式扫描建立偏移索引，分页解码。系统提示和工具定义按请求规格去重；导入和分支不再把整段历史嵌入一条记录。默认单记录 64 MiB、单日志 256 MiB，达到限额明确停止，原记录保留，可由宿主调整并导出归档。

文件写租约采用 SQLite 的跨连接锁管理，避免普通 POSIX 文件锁的跨 isolate 语义差异。会话数据仍为 JSONL。原生打包使用 `dart build cli`，必须保留 bundle 中的动态库；`run.ps1` 已负责这一步。

完整坏行和未知业务记录会拒绝读取，避免丢失事实；只有明确标为 `ignorable` 的未来诊断记录可跳过。已确认的未完成尾片段会隔离，零字节初始化文件可以重新创建。旧格式的日志、种子导入和配置保留读取兼容；新写入格式不保证旧版程序可读。

界面订阅 `session.changes` 后读取 `session.activity`，重新进入页面时也先读快照。运行中已经收到的文字和思考不会因重新订阅而丢失；正式消息仍来自 `transcript`。长会话的活跃状态目前仍会重建到内存，分页存储不等于已实现 App 的历史列表虚拟化。

MissionBook 后续还需实现 Drift 适配、业务工具、权限界面、安全凭据存储和备份接入；本轮不新增业务数据库表。

## 验证

```powershell
dart analyze
dart test --reporter expanded
dart run example/foundation_demo.dart
dart compile js example/foundation_demo.dart -o .dart_tool/agent-core-checks/foundation_demo.js
```

有有效凭据后，使用合成背景与合成图片验证真实 API：

```powershell
dart run example/foundation_live_smoke.dart
dart run example/foundation_live_smoke.dart --thinking
dart run example/foundation_vision_live.dart
dart run example/foundation_generation_live.dart
```

视觉脚本仅上传自己生成的测试图，并在结束时删除本次云端文件。它不会读取个人材料。
