# Agent 基座验证记录

日期：2026-10-29；Windows、Dart 3.13.5；目录 `E:\working\mission_book\packages\agent_core`。本轮对已提交的首版基座继续加固，Harness 参考基线 `f3803c9697`。结论限于 [FOUNDATION](FOUNDATION.md) 的独立包范围。

## 最终自动验证

- `dart analyze`：无问题。
- `dart format --output=none --set-exit-if-changed lib bin example test`：52 个 Dart 文件，无格式变化。
- `dart test --reporter expanded`：**111/111 通过，退出码 0**。首版历史基线为 81 项，本轮增加并调整协议、恢复、工具和视觉用例。
- `dart run example/foundation_demo.dart`：退出码 0；估算 3341 → 235，12 条原始消息、5 条当前上下文；工具只执行一次，关闭重开后继续，分支保留 14 条消息。
- `dart compile js example/foundation_demo.dart -o .dart_tool/agent-core-checks/foundation_demo.js`：退出码 0；证明纯核心可编译 JavaScript，不是浏览器实跑验收。

| 场景 | 对应证据 |
| --- | --- |
| 业务拒绝、只读失败、写入后取消、工具不返回 | `foundation_hardening_test.dart`；业务失败可继续，未知写入必须核对，期限结束不会假称未执行。 |
| 预算、摘要与原文 | `context_compaction_test.dart`、加固测试；触发线与硬预算分开，完整工具组和最新输入保留，摘要失败不覆盖原投影。 |
| 图片与模型限额 | `vision_test.dart`；图片头、数量/尺寸/大小、双协议编码、文件上传查询删除、跨供应商保护、输出上限不可绕过。 |
| 流式与重试 | `model_streaming_test.dart`、加固测试；UTF-8、交错参数、重复相同 id、缺 function 的首帧、严格结束、Retry-After、心跳与凭据等待总超时。 |
| 用量、空正文、界面快照 | 加固测试；失败尝试不漏掉已报告用量，缓存计入总输入但不重复相加；只返回思考可保存并重开继续；晚订阅可读已生成文字。 |
| 存储与版本 | `file_session_store_test.dart`、`session_runtime_test.dart`；零字节初始化、只读/分页、跨块大记录、大小限制、关闭与追加顺序、跨 isolate/进程锁、半截尾、完整坏行及未来记录。 |
| 中断与副作用 | 真实子进程在写出副作用后 `exit(73)`；重开获得未知结果，阻止重放，核对后继续。落盘故障覆盖工具执行前、结果后及收尾。 |
| 去重与分支 | 加固测试；同一请求规格只保存一次；导入不嵌套整个日志；fork 工具边界、配置恢复、未来诊断与未知业务记录分别处理。 |

## 真实 DeepSeek 验证

有效凭据只用于临时测试进程，不写入源码、配置、会话或本记录。请求只发送合成资料、测试图和本机时间。先前 401 属于凭据问题；本轮已用新的有效凭据取得成功结果。

### 图片

`example/foundation_vision_live.dart` 生成白底黑字 `AGENT 42` 的 PNG，上传到 Files API，验证文件引用；结束时确认删除本次测试文件。四项均完整回答，退出码 0。

| 协议 | 思考 | 实际识别 | 当次输出 tokens |
| --- | --- | --- | --- |
| Messages | off | AGENT 42 | 4 |
| Messages | low | AGENT 42 | 112 |
| Chat Completions | off | AGENT 42 | 4 |
| Chat Completions | low | AGENT 42 | 132 |

图像验证支持“能识别并完成请求”的结论，不用于比较协议成本。

### 自动压缩、流式思考和工具往返

运行 `foundation_live_smoke.dart` 及 `--thinking`；每项均摘要一次，再以两次主请求、一次时间工具完成回答，准确包含 `杉木-42`。脚本同时断言原文仍可读取、最新要求原样保留。

| 模式 / 协议 | 估算压缩前 → 后 | 时间与结果 |
| --- | --- | --- |
| off / Messages | 9078 → 573 | 09:49:42，PASS |
| off / Chat Completions | 9102 → 665 | 09:49:48，PASS |
| low / Messages | 9091 → 649 | 09:49:58，PASS，有思考和文字增量 |
| low / Chat Completions | 9111 → 684 | 约 09:50，PASS，有思考和文字增量 |

最后核对发现缓存统计差异，相同合成输入直接查询得到：Chat 总输入 **4409**，Messages 为 `input_tokens=185` 加 `cache_read_input_tokens=4224`。修复后 `TokenUsage.inputTokens` 统一包含普通输入、缓存读和缓存写；`cachedInputTokens` 是其中命中缓存的部分。

补修后再次执行 `--thinking`：Messages **9091 → 582**，总输入/输出 **6933/321**；Chat **9111 → 991**，**7530/640**，均 PASS、两步主请求、一次工具、一次摘要、退出码 0。总量包含摘要请求，摘要措辞和缓存变化会影响后续计数。统计规则参照 [Messages 缓存说明](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)，并与 DeepSeek 实际响应核对。

## 真实终端交互

`foundation_generation_live.dart` 另验证纯思考历史后的继续请求和 Chat JSON 对象输出：首次复现 Chat 空 assistant 消息导致 400；发送时省略不可回传的空内容后，两协议均 PASS，JSON 的 `ok=true` 校验通过，退出码 0。原始思考仍留在会话记录中。

通过 `run.ps1 --demo` 构建并运行原生 bundle，现场执行 `/status`、`/thinking low`、`/output 65536`、时间查询、`/rename`、`/history`、`/exit`。新进程以原会话编号重开，显示 1 Mi 上下文、64 Ki 输出和低思考，历史工具结果仍在；最终源码变动后自动重建，时间查询成功，退出码 0。

终端采用清晰角色、简短完成信息、可选颜色与等待动画，完整配置留在 `/status`。`dart build cli` 将 SQLite 原生资产放进 bundle，启动器会一起保留。

## 审查意见的处理边界

- 修复已复现的业务拒绝停摆、字节预算、视觉摘要、取消误判、工具增量兼容、Retry-After、无总期限、初始化孤儿、跨 isolate 锁、用量、活动快照和日志重复问题。
- 保留执行前落盘、未知写入硬拦、真实 socket 取消、尾片段隔离和原始事实不改写；核对另有结构化 `resolvedOutcomes`。
- SSE 没有终止空行的最后一帧仍不交付；这是 [SSE 规范](https://html.spec.whatwg.org/multipage/server-sent-events.html#event-stream-interpretation) 的要求，不把不完整流当成功。
- 记录级版本与可忽略诊断已实现；未知业务事实仍拒绝读取。新日志不承诺旧版程序可读。
- 存储已有分页、体积上限和请求规格去重，活跃会话仍重建完整状态；没有宣称无限日志、手机内存或帧率已经验收。

## 未包含的验收

其他供应商真实请求、Android/iOS 实机、App Drift 与备份、安全凭据存储、业务工具及权限界面、任务总结和目标记忆仍属后续工作。没有修改 App 业务代码或数据库，没有新增用户独立实现/掌握证据。本记录随本轮基座代码一并提交；未推送远端。
