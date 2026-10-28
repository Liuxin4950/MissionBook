# 参考项目与许可

本包使用 Dart 独立实现 Agent 基座，设计参考本地 DeepSeek Harness 基线 `f3803c9697`（2026-10-28 核对）。保留其 MIT 许可文本，便于后续分发时追溯参考来源。

| Harness 源码 | 本包对应职责 |
| --- | --- |
| `packages/core/agent-loop/src/agent.ts` | 请求模型、顺序执行工具、回传结果、驱动下一步 |
| `docs/architecture.md`、`packages/core/session` | 日志持有模型可见事实，重建会话 |
| `packages/compaction/compaction-basic` | 自动/手动压缩、完整工具组边界、保留近期上下文 |
| `packages/session/session-persistence`、JSONL provider | 单写入者、追加记录和中断恢复 |
| `packages/llm/llm/src/retry-policy.ts` | 有限重试和退避 |
| `packages/llm/llm-deepseek` | 协议转换、流式拼接、完整结束判定 |

运行依赖由 pub 管理：`args`、`crypto`、`http`、`json_schema`、`uuid`；实际版本见 `pubspec.lock`，各依赖自己的 LICENSE 随其发布包提供。本文件不改变这些依赖的许可。包没有复制 Harness 的 Node 依赖或插件运行时。

来源：[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)。以下为该基线仓库 `LICENSE`：

```text
MIT License

Copyright (c) 2026 DeepSeek

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
