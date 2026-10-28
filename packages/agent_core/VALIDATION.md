# Agent 基座验证记录

日期：2026-10-28。环境：Windows、Dart 3.13.5；工作目录 `E:\working\mission_book\packages\agent_core`。Harness 参考基线 `f3803c9697`。

本次验收对应 [FOUNDATION.md](FOUNDATION.md) 的独立基座范围。以下记录来自当前源码与实际运行，App 集成不包含在结论中。

## 逐项证据

| 要求 | 实现位置 | 当前证据 |
| --- | --- | --- |
| 消息与工具 | `message.dart`、`tool.dart`、`agent_loop.dart` | `agent_loop_test.dart` 验证参数、逐次授权、顺序执行、多步多工具、重复编号、已知失败、未知结果、取消保留成功结果。`session_runtime_test.dart` 验证来源及未知结果核对。 |
| 模型配置 | `models/configuration.dart`、`model_registry.dart`、`io/configuration_file.dart` | `model_configuration_test.dart` 验证双协议、多配置引用、JSON 往返、参数和地址校验；文件测试实际保存、覆盖保存、读取；CLI 实际加载样例并切换模型。 |
| 通信与流式 | `http_agent_model.dart`、`wire_codec.dart`、`stream_decoder.dart`、`sse_reader.dart`、`request_runner.dart` | 完整响应与流式测试覆盖 UTF-8 逐字节、思考签名、交错工具参数、结束标记、截断、使用量、有限重试、退避取消、响应头和已开始流的取消/超时。真实 DeepSeek 两种协议在思考关闭和 low 模式下均完成工具往返。 |
| 自动压缩 | `context/context_compactor.dart` | 9 项专项测试覆盖原文与最新输入保留、完整工具组、手动/关闭自动、取消/失败/无效摘要、超大单元、分块和调用上限；模拟模型溢出后恢复，已完成工具执行计数仍为 1。真实 API 自动摘要后准确回答测试项目代号，原文和最新要求仍在。 |
| 会话 | `sessions/agent_runtime.dart`、`session_state.dart` | 多轮、关闭重开、配置变更、上下文注入、压缩投影、导入导出、分支/分支再分支、中断继续、并发拒绝均有测试；损坏导入序号和请求上下文被拒绝。CLI 实际执行新建、列出、打开失败后继续、模型切换、导入导出和分支。 |
| 存储与恢复 | `sessions/session_store.dart`、`io/file_session_store.dart` | 真实文件重开恢复原文和摘要；未完成尾片段隔离；完整坏行和未知版本不被修改；同进程与独立进程写锁。测试子进程在写出真实副作用后 `exit(73)`，重开得到 `outcome_unknown`，阻止自动执行，核对后继续且副作用没有重复。 |
| 可观察性与持久化边界 | `agent_event.dart`、Runtime `_observe()` | 模型尝试、文字/思考/参数、工具、压缩与终态可订阅；摘要增量有独立 purpose。故障注入覆盖执行开始保存失败、工具结果保存失败、取消收尾保存失败，验证保存失败时停止及保留进程内真实结果。 |
| 可运行与可读 | `bin/agent.dart`、`example/`、`README.md` | 离线完整演示通过；CLI 帮助与配置样例可用，真实 CLI 一次运行并在新进程重开继续通过；README 按同一次调用讲解。纯核心完整演示编译 JavaScript 成功。 |
| 回归与验收 | `test/`、真实验证入口 | 全部 **81/81** 自动测试通过，静态分析无问题，42 个 Dart 文件格式检查无变化；真实网络与原生文件证据见下。 |

## 实际执行

```powershell
dart analyze
dart test --reporter expanded
dart format --output=none --set-exit-if-changed lib bin example test
dart run example/foundation_demo.dart
dart compile js example/foundation_demo.dart -o .dart_tool/agent-core-checks/foundation_demo.js
dart run bin/agent.dart --help
```

以上命令退出码均为 0。离线演示压缩预算估算 3951 → 683，保留 12 条原文而当前上下文为 5 条；时间工具执行一次、模型请求两步，关闭重开后继续并创建 14 条消息的分支。

CLI 配置和管理命令检查采用独立 `.agent-data/cli-smoke-*` 目录：切换到 `deepseek-chat`，尝试打开不存在会话后原会话仍可导出；导入、分支和新建后列出 4 个会话，导出格式为 `agent_core_export`，退出码 0。

## 真实 DeepSeek 验证

沿用用户明确授权的 Key，仅设置测试子进程环境，结束后恢复；不写入项目配置或会话。请求只包含示例内合成背景和本机时间，不读取 MissionBook 数据。

运行 `dart run example/foundation_live_smoke.dart` 与 `--thinking`：

| 模式与协议 | 自动压缩前 → 后（本地估算） | 完整主请求 / 工具执行 | 结果 |
| --- | --- | --- | --- |
| 关闭思考 · Messages | 9554 → 2133 | 2 / 1 | 15:12:43，准确回答杉木-42 和本机时间 |
| 关闭思考 · Chat Completions | 9613 → 1875 | 2 / 1 | 15:12:48，准确回答杉木-42 和本机时间 |
| low 思考 · Messages | 9586 → 1772 | 2 / 1 | 对话文字增量 28、思考增量 31，准确回答代号和时间 |
| low 思考 · Chat Completions | 9637 → 2080 | 2 / 1 | 对话文字增量 33、思考增量 7，准确回答代号和 15:14:38 |

四项每次均自动调用摘要模型一次，最终 `completed`；验证入口同时断言原文可读取、最新用户要求原样保留和工具只执行一次。模型返回标识均为 `deepseek-flash`，两个程序退出码均为 0。计数属于本次响应，后续模型措辞、摘要长度和增量数量可能变化。

另通过真实命令行验证跨进程持久对话：第一次查询得到 `2026-10-28 15:22:50`、UTC 偏移 +480 分钟，2 步 / 2 次尝试；程序退出后以原会话编号启动新进程，要求根据上次结果回答偏移，1 步回答 +480 分钟，没有再次执行工具，两次都 `completed`、退出码 0。

早期非流式 `example/deepseek_demo.dart` 在 14:15:54 的真实时间工具验证保留为历史证据，见应用[学习进度](../../docs/教学/学习进度.md)。

## 结论适用范围

- 默认预算估算是保守 UTF-8 字节估算，非精确 tokenizer。单个不可拆分超大输入会明确失败；摘要的语义质量仍应通过原始记录核对。
- 未获得完整响应的失败尝试可能缺少用量，`usage` 不是完整账单。网络重试只针对请求，不能保证供应商没有计费。
- 已验证的网络供应商是 DeepSeek；其他兼容服务需各自测试。图片输入有协议表示能力，本轮未验证供应商视觉理解。
- 文件持久化和跨进程锁在 Windows 验证；JavaScript 编译只证明纯核心编译兼容性，不是浏览器运行或 Web 持久化验收。
- 没有接入 MissionBook UI、业务服务、任务总结或目标记忆；没有 Android/iOS 设备验收，也没有新增用户独立实现或掌握证据。
- 本次未提交或推送 Git。业务代码与数据库结构未改变。
