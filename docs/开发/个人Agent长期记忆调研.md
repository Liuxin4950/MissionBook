# 个人 Agent 长期记忆调研

> 原调研日期：2026-11-13。范围：主流个人 Agent / 记忆框架的公开一手资料，以及 MissionBook 记忆链路的源码、依赖与环境核验。本文保留重构前调研与后续状态更新；外部调研结论、工作树实现和验收结果分别理解，不代表整套重构已经完成。
>
> 2026-11-13 阶段交接：按用户要求暂停继续扩展和修复，将当前有限实现提交同步，供用户在自己的电脑接续开发；完整重构未最终验收。第 2–4 节是原调研资料，本次不重新检索外部项目；第 6 节的 file:line 是重构前历史证据，不是当前行号，第 7.1–7.4 节是当时环境/实验快照。第 5.3、7.5、8–9 节说明当前结构与交接边界；不得把历史计数当作最终通过。现行路径、交接验证和剩余事项见[长期记忆](../架构/前端/助手与总结/长期记忆.md#阶段交接验证与接续开发)，调整原因见[变更记录](../教学/变更记录.md)。

## 0. 结论摘要

1. **身份核实**：用户所说的 “OpenClaw” 确认为 `openclaw/openclaw`（多个来源称其前身为 Clawdbot/Moltbot）；“harmes agent” 未检索到同名项目，最接近且几乎可以确定指的是 Nous Research 的 **Hermes Agent**，本文按 Hermes Agent 调研并明确标注替代关系。
2. **主流设计没有统一“分层表”**：真正稳定复用的只有四件事——**常驻核心（小而精）+ 可检索的长期存储 + 明确的写入/更新策略 + 用户可见可改**。OpenClaw、Hermes、Letta、Claude Code 都采用“常驻核心 + 按需检索”的两段式；Mem0、Zep 走“抽取 + 更新/失效”的服务化路线；Generative Agents、A-MEM、MemoryOS 提供了反思、链接、热度分层等研究思路，但都不是可直接照搬的移动端工程方案。
3. **MissionBook 的主要问题不在“缺表/缺向量库”**：重构前 `MemoryEntries` 已具备来源、确定性、冲突键、过期、墓碑和用户更正保护；真正导致“鸡肋”的是 **注入与话题无关、目标级记忆不进入核心、检索无排序、冲突时静默覆盖、写入路径窄、抽取只看单条用户消息**。该条是重构前判断，现行结构见第 8 节。
4. **不建议第一轮就上向量库/设备端 embedding**：当前没有文本 embedding 依赖与模型资产；在单用户、本地 SQLite、强事务与备份版本校验的约束下，引入向量存储会同时增加包体、迁移、备份和评测成本，收益尚未被数据证明。Hermes 官方为 FTS5，OpenClaw 未配置 embedding 时默认也是关键词检索；本轮延后与两个参考对象的默认形态一致，不是能力妥协。
5. **FTS5 可用，但不能直接解决中文检索**：随包的 SQLite 3.54.1 已启用 FTS5；但默认 `unicode61` 对无空格中文只匹配整段，`trigram` 只支持 ≥3 字子串。中文优先的产品必须保留 `LIKE` 回退或做预分词，不能只用 FTS5 替换。
6. **调研时的最大工程风险是 schema/备份兼容**：当时 `schemaVersion=16` 且升级即拒绝，备份恢复也要求版本完全一致。后续用户撤回“保留历史数据”的前提，P1 已直接升级到 17 并重做备份（见 7.5）；旧库仍显式拒绝，不写迁移链或兼容层。

## 1. 方法与可信度

- 一手资料优先：官方文档、GitHub 源码/README、论文原文。
- 每个对象尽量回答：分层与数据模型、写入触发、检索、注入与预算、更新/去重/冲突/遗忘、用户可见与可编辑、存储与隐私、已知失败模式。
- 可信度标记：
  - **高**：直接读到官方文档/源码/论文正文。
  - **中**：官方页面可检索到摘要但正文抓取失败（如 OpenAI Help 403），或更名历史只有多个二手来源一致。
  - **低**：仅社区文章，本文只用于补充批评视角，不作为机制结论。
- 所有链接均为实际检索结果；“访问日期”指本次调研读取日期。未给出发布日期的官方文档，以访问日期标注。

## 2. 逐对象分析

### 2.1 OpenClaw

**身份核实（中高）**：官方仓库为 `openclaw/openclaw`，MIT，定位是运行在用户自己机器上的开源个人 AI 助手。官方 README 只写“状态、记忆和凭据留在用户硬件”，未提更名；Mem0 博客（2026-02-06）与 Milvus 指南（2026-02-10）等多个来源一致称其前身为 Clawdbot/Moltbot，故更名细节标为中等可信度。

**机制（高，官方 docs.openclaw.ai）**：

**检索前提（2026-11-13 核对官方原文，可信度高；官方页未标发布日期）**：
- `https://docs.openclaw.ai/concepts/memory-builtin` 原文：**“Without an embedding provider, only keyword search is available.”** 同一页说明关键词检索走 **SQLite FTS5（BM25 scoring）或 PostgreSQL native full text**。
- `https://docs.openclaw.ai/concepts/memory-search` 说明向量检索是可选能力：显式设置 `memory.search.provider: 'none'` 可只走关键词；provider 失败时也会回退。只有配置 embedding provider 后才出现 BM25 + 向量的混合检索。
- 因此不能把“混合 BM25 + 向量”写成 OpenClaw 的默认形态；embedding provider 不是必需项。

| 维度 | 事实 |
| --- | --- |
| 记忆分层 | `USER.md`（稳定偏好，小）、`MEMORY.md`（长期事实，小）、每日笔记 `YYYY-MM-DD.md`（情景/流水，大）、会话 transcript、可选 `DREAMS.md`。核心是“小而常驻的 curated 层 + 大而按需检索的 episodic 层”。 |
| 写入触发 | 会话产生每日笔记；Agent 或 dreaming 写 `MEMORY.md/USER.md`；压缩前有 silent flush；dreaming 在后台把强短期信号提升为长期记忆。 |
| 检索 | `memory_search` / `memory_get`；分块时把标题附加到正文。**默认/未配置 embedding provider 时为关键词检索：SQLite FTS5（BM25 评分）或 PostgreSQL 原生全文**；只有配置 embedding provider 后才启用 BM25 + 向量混合。最大 4,096 UTF-16 单元、128 terms、200 hits、700 字符片段；`maxResults` 默认 6；30 天 recency 半衰期 + importance 乘子；MMR lambda 0.7；索引默认 SQLite，也支持 PostgreSQL/LanceDB/Honcho。 |
| 注入/预算 | `USER.md`/`MEMORY.md` 在会话开始时注入；每日笔记在 `/new`/reset 时注入；超出 bootstrap 预算会截断。每日笔记和 transcript **不会自动注入**，只能通过检索工具访问。 |
| 更新/冲突/遗忘 | dreaming 有 Light/REM/Deep 三阶段，按 relevance 0.30、frequency 0.24、query diversity 0.15、recency 0.15、consolidation 0.10、conceptual richness 0.06 评分，并要求过 minScore/minRecallCount/minUniqueQueries；安全阀 `maxPriorEntryLossFraction=0.25`、`maxPromotedSnippetTokens=160`。`memory reset` 清派生索引但保留文件和会话；`forget` 删文本与向量。 |
| 用户可见/可编辑 | 记忆是 Markdown 文件，可直接编辑；CLI 有 `memory status/search/index/reset`；Settings 可 Import Memory；另有 memory-wiki 插件把记忆编译成 wiki。 |
| 存储/隐私 | 本地优先，状态/记忆/凭据在用户硬件；但支持多种索引后端，使用远程 embedding 时内容会离开本机。 |
| 已知失败/批评 | 持久记忆是 prompt injection 的放大器：恶意内容一旦写入 `MEMORY.md`，后续会话会反复带入（promptfoo 安全库、安全厂商分析，2026）。官方用 provenance 门控降低风险：只有来源可信的 curated 内容可自动注入，未审内容只能显式检索。 |

**可借鉴**：
- “常驻 curated 层 vs 按需 episodic 层”的两段式，比强行建四层表更实用。
- provenance 门控：**只有用户明确陈述/可确认来源进入核心**，观察、网页、文件内容只进检索层。
- recency + importance + 多样性（MMR）的组合，比单一时间排序更接近“当前有用”。
- 后台 consolidation（dreaming）的思路，但要缩成移动端可承受的单一任务。

**不可借鉴/需改造**：
- Markdown 文件 + 多索引后端不适合 MissionBook 的强事务/SQLite/备份模型。
- 只有配置 embedding provider 后才需要向量索引；provider/model/prefix 变更需重建索引、本地索引串行，移动端成本高。未配置时只走关键词检索，不能把它描述成默认依赖向量。
- 定时 dreaming 在 Android 后台受限制，不能假设夜间稳定运行。
- 自动注入每日笔记会放大上下文噪音；MissionBook 应保持“任务事实从任务/记录读取”，不复制时间线。

### 2.2 Hermes Agent（对 “harmes agent” 的替代）

**身份核实（高）**：Nous Research 官方站点 `hermes-agent.nousresearch.com` 与仓库 `NousResearch/hermes-agent` 均存在，定位是“会随使用成长的个人 Agent”，MIT。检索 “Harmes agent” 没有找到同名项目；下文均指 Hermes Agent，不能把 “Hermes” 模型家族与 Hermes Agent 混为一谈。

**机制（高，官方 memory 文档 + 仓库源码路径 + issue）**：

| 维度 | 事实 |
| --- | --- |
| 记忆分层 | 官方文档明确“bounded, curated memory persists across sessions”：`MEMORY.md` 上限 2,200 字符，`USER.md` 上限 1,375 字符；仓库另有 FTS5 检索 + LLM 摘要来维护用户模型；技能（skills）是程序性经验的独立载体。社区所称“三层”不是本文的一手结论。 |
| 写入触发 | 通过 `memory` 工具写入；Agent 自主决定写入；会话开始时记忆被冻结（frozen at session start），避免同轮内被改写。 |
| 检索 | SQLite 全文检索（仓库 README 称 FTS5），对历史/笔记做检索；核心两文件不需要检索，直接注入。 |
| 注入/预算 | 两个文件合计约 3,575 字符（约 1,300 tokens，按第三方换算）；每次会话注入。超过上限的写入会显式失败，而不是静默驱逐旧事实（官方 feature 页；GitHub issue #16831 也确认 2,200 字符是硬编码并请求可配置）。 |
| 更新/冲突/遗忘 | 自动去重；没有 decay；通过 memory 工具替换/删除；CLI 可编辑。 |
| 用户可见/可编辑 | 文件可直接查看/编辑，CLI 可改；有配套桌面端。 |
| 存储/隐私 | 本地文件 + 本地 SQLite；模型调用仍会把注入内容发给模型提供方。 |
| 已知失败/批评 | 硬上限导致“写不进去”；无衰减导致旧偏好长期占位；只有 FTS5 关键词检索，中文无空格场景同样受 tokenizer 限制；会话冻结意味着长会话内新记忆不可见。 |

**可借鉴**：
- 硬上限 + 显式失败，比“悄悄截断/悄悄丢旧事实”更可解释；MissionBook 可把上限做成可配置并返回明确回执。
- 核心文件小、检索层大；核心只放稳定偏好/约束。
- 写入走显式工具，便于审计。

**不可借鉴/需改造**：
- “会话开始冻结”不适合 MissionBook 的长会话/跨轮目标推进；应允许本轮新记忆在下一轮可见。
- 无 decay 不满足用户对“遗忘/过期”的诉求；MissionBook 已有 `expiresAt`，应保留并扩展到观察类。
- 纯 FTS5 对中文不友好（见第 7 节实测）。

### 2.3 Letta（MemGPT）

**机制（高，官方文档/博客；论文 2023-10-12）**：

| 维度 | 事实 |
| --- | --- |
| 分层 | Core memory blocks（label/value/limit，始终在上下文）+ Recall memory（历史对话检索）+ Archival memory（外部向量库，长期事实/知识）。MemGPT 论文把它描述为 OS 式虚拟上下文管理：主上下文 + 外部上下文，通过分页和中断在两者间搬运。 |
| 写入 | Agent 通过工具/API 编辑 core block；通过 `archival_memory_insert` 写入 archival；sleep-time agent 可在后台异步整理记忆。 |
| 检索 | Core 不需要检索（常驻）；archival 是向量库，按语义搜索；recall 检索对话历史。 |
| 注入/预算 | Core blocks 始终进入上下文，受每块 limit 限制；archival 只能按需工具查询，不能常驻。 |
| 更新/冲突 | Block 更新是**整体替换 value**；官方明确警告并发写会导致数据丢失。没有内建的通用冲突消解器，依赖 Agent/应用层。 |
| 用户可见/可编辑 | 可通过 API/SDK 读写 block；面向开发者的平台，不是消费级 UI。 |
| 存储/隐私 | 服务端/数据库 + 向量存储；可自托管，但默认是平台化组件。 |
| 已知失败/批评 | 整体替换 + 并发写丢失（官方警告）；向量检索成本；Agent 自主管理记忆可能改错/丢内容；平台抽象重，移动端嵌入成本高。 |

**可借鉴**：
- “常驻核心块 vs 外部检索”是最清晰的心智模型；MissionBook 可用“核心注入块 + `getMemory` 检索”对应。
- 核心块有硬 limit，防止无限膨胀。
- 后台 sleep-time 整理的方向，对应“会话后 consolidation”。

**不可借鉴**：
- 整体替换 block、并发写丢失的语义不能用于 MissionBook 的强事务记忆；必须用行级更新 + 版本校验。
- 向量库/平台依赖不适合本地单用户 App。

### 2.4 Mem0

**机制（高，论文 2025-04-28；官方仓库）**：

| 维度 | 事实 |
| --- | --- |
| 分层/模型 | 短期对话 + 长期记忆；长期默认向量存储，Mem0g 增加图存储。不是“四层认知表”，而是“抽取出的记忆条目 + 向量/图索引”。 |
| 写入 | 两阶段：Extraction（LLM 从对话抽候选事实）→ Update（用向量相似度决定 ADD / UPDATE / DELETE / NOOP）。 |
| 检索 | 语义向量检索；图版本可做实体/关系检索。 |
| 注入/预算 | 由调用方把检索结果拼入 prompt；框架本身不规定固定 token 预算。 |
| 更新/冲突 | 核心贡献就是显式四操作；比“字符串相等去重”更强，但依赖 LLM 判断。 |
| 用户可见/可编辑 | 提供 API/平台；用户可见性取决于接入方。 |
| 存储/隐私 | 向量库（可云端/自托管）+ 可选图库；抽取与更新通常要调用 LLM。 |
| 已知失败/批评 | 每次写入的 LLM 抽取/更新有成本与延迟；论文自述图记忆在多跳场景反而可能变差；LOCOMO 等基准存在厂商争议（见第 4 节）；向量库运维与 embedding 版本迁移成本。 |

**可借鉴**：
- 把“写入”从“插入一条”提升为 **ADD/UPDATE/DELETE/NOOP 决策**；MissionBook 可以在本地用确定性规则实现，不必每次调 LLM。
- 抽取与更新分离，便于审计。

**不可借鉴**：
- 每次写入都调 LLM 做冲突判断，移动端成本/延迟不可接受。
- 向量库/图库依赖不符合“本地 SQLite、无云端向量库”。

### 2.5 Zep / Graphiti

**机制（高，论文 2025-01-20；Graphiti 开源）**：

| 维度 | 事实 |
| --- | --- |
| 分层/模型 | 时间知识图谱：episode 子图（原始事件）、semantic entity 子图（实体/事实）、community 子图（社区摘要）；边带 bi-temporal：有效时间（t_valid/t_invalid）+ 摄入时间。 |
| 写入 | 从 episode 抽取实体/关系；新事实使旧边 **invalid** 而不是删除；保留历史。 |
| 检索 | 混合：cosine 向量 + BM25 + 图 BFS；按时间/相关性组合。 |
| 注入/预算 | 返回相关子图/事实给调用方；由应用拼 prompt。 |
| 更新/冲突 | 时间失效 + 边失效是核心；比“覆盖”更能表达“曾经为真，现在不为真”。 |
| 用户可见/可编辑 | 平台/服务；图数据库可查，但消费级编辑弱。 |
| 存储/隐私 | 图数据库 + 向量/全文索引；通常是服务化部署。 |
| 已知失败/批评 | 摄取/实体消解成本高；图 schema 与维护复杂；DMR/LongMemEval 成绩与 Mem0 存在公开争议；对单用户小数据可能过度设计。 |

**可借鉴**：
- **时间有效性**：记忆不是只有“有/无”，还有“何时为真、何时被取代”。MissionBook 可用现有的 `updatedAt/expiresAt` + 一个“被取代”标记表达，不必上图。
- 失效而非物理删除，和现有墓碑思路一致。

**不可借鉴**：
- 图数据库、实体/社区抽取、混合检索服务，对本地单用户 App 过重。

### 2.6 LangMem（LangChain）

**机制（高，官方概念文档 + 2025-02-18 发布博客）**：

| 维度 | 事实 |
| --- | --- |
| 分层 | Semantic（事实）、Episodic（经历）、Procedural（行为/规则）。 |
| 写入 | Hot path（对话中实时写，低延迟要求）vs Background（对话后异步写，延迟不敏感）。提供 memory manager 工具做抽取/更新。 |
| 检索 | 按 namespace/key 组织文档，语义检索；namespace 用于隔离用户/租户。 |
| 注入/预算 | 检索结果由应用拼 prompt；框架不强制预算。 |
| 更新/冲突 | 依赖 memory manager 的 prompt/策略；没有像 Mem0 那样固定的四操作协议。 |
| 用户可见/可编辑 | SDK/开发者接口；产品层需自建。 |
| 存储/隐私 | 可接 LangGraph store/向量库；取决于部署。 |
| 已知失败/批评 | 热路径写入增加延迟；后台写入可能陈旧；记忆质量高度依赖抽取/更新 prompt；namespace 增加抽象复杂度。 |

**可借鉴**：
- “热路径显式写 + 后台整理”二分，对应 MissionBook 的 `saveMemory` + 异步抽取。
- semantic/episodic/procedural 作为**概念分类**，不必落成三张表；任务/记录/分析已经承载 episodic 事实，技能/规则可由提示词/设置承载。

**不可借鉴**：
- 为三类记忆建独立存储/namespace，和项目“最小结构”冲突。

### 2.7 ChatGPT Memory

**机制（中：官方页面抓取返回 403，以下依据官方搜索结果摘要与官方公告标题；不能视为逐字引用）**：

| 维度 | 事实 |
| --- | --- |
| 分层 | “Saved memories”（用户显式要求记住，或行为可用时自动保存的细节）+ “Reference chat history”（参考历史对话）。 |
| 写入 | 用户显式要求；或在支持的行为下自动保存。 |
| 检索/注入 | 平台自动决定是否引用；用户可关闭 “reference saved memories” 或 “reference chat history”。 |
| 更新/冲突/遗忘 | 用户可在 Settings 查看、编辑、删除 saved memories；有 Memory summary/Manage 等控制。 |
| 用户可见/可编辑 | 较高：可见列表 + 开关；但自动保存的判定不透明。 |
| 存储/隐私 | 云端账户数据；跨设备同步。 |
| 已知失败/批评 | 自动保存不透明、错误/陈旧记忆、隐私与“被记住不想被记住的内容”；用户难以知道某条回答到底用了哪条记忆。 |

**可借鉴**：
- 用户可见、可编辑、可关闭是长期记忆的底线；MissionBook 的“AI 日记本”方向正确。
- 把“显式保存”和“自动参考历史”分开控制。

**不可借鉴**：
- 云端黑盒自动保存；MissionBook 应保持本地、可解释、可回执。

### 2.8 Claude Code 的 CLAUDE.md / auto memory

**机制（高，官方文档 code.claude.com/docs/en/memory，访问 2026-11-13）**：

| 维度 | 事实 |
| --- | --- |
| 分层 | 托管/用户（`~/.claude/`）/项目（`./` 或 `.claude/`）/本地（`.local.md`）；子目录文件在访问对应路径时按需加载。 |
| 写入 | 用户编辑 CLAUDE.md；auto memory 会在纠正/偏好出现时自动写入 `~/.claude/projects/<project>/memory/MEMORY.md`。 |
| 检索/注入 | 启动时加载上层文件；子目录按需；auto memory 每个会话只加载前 200 行或 25KB。 |
| 预算/限制 | 建议 CLAUDE.md <200 行以减少上下文噪音；>4MB 文件跳过；`@path` 导入递归最多 4 跳，工作目录外导入需批准。 |
| 更新/冲突 | 后加载的文件优先；没有自动冲突消解，靠层级/优先级。 |
| 用户可见/可编辑 | `/memory` 查看/编辑/开关 auto memory；`/context all` 检查实际加载。 |
| 存储/隐私 | 本地文件，但会作为上下文发给模型；外部导入有安全审批。 |
| 已知失败/批评 | 上下文噪音/规则冲突；auto memory 容量小；文件过期；层级优先级可能不符合直觉。 |

**可借鉴**：
- 分层作用域（全局/项目/目录）对应 MissionBook 的全局记忆/目标记忆/任务相关记忆。
- 明确的大小上限与“按需加载”。
- 用户可直接编辑、可检查“实际加载了什么”。

**不可借鉴**：
- 文件层级/路径 glob 不适用于移动端数据模型；auto memory 的 200 行限制是 token 预算的粗粒度替代。

### 2.9 Cursor Rules

**机制（高，官方文档 cursor.com/docs/context/rules，访问 2026-11-13）**：

| 维度 | 事实 |
| --- | --- |
| 分层 | Project rules（`.mdc`）、User rules、Team rules、`AGENTS.md`；支持嵌套 AGENTS.md。 |
| 写入 | 用户/团队手写规则；不是自动抽取。 |
| 检索/注入 | 四种激活：`alwaysApply`、按 glob 自动附加、由 description 让 Agent 自选、手动 `@` 引用。 |
| 预算/限制 | 建议规则 <500 行；嵌套规则按目录生效。 |
| 更新/冲突 | 无自动冲突消解；规则过多/相互矛盾会降低效果。 |
| 用户可见/可编辑 | 高：纯文本、可版本控制。 |
| 存储/隐私 | 本地/仓库文件，随上下文发给模型。 |
| 已知失败/批评 | 规则膨胀、always-apply 占上下文、Agent 自选可能漏规则、跨工具规则重复。 |

**可借鉴**：
- “always / 自动附加 / 手动检索”三种激活模式，可映射为：核心记忆常驻、目标/关键词自动附加、长尾记忆按需 `getMemory`。
- 规则要少而精，避免“记忆越多越好”。

**不可借鉴**：
- 文件/glob 规则体系对单用户 App 过重。

### 2.10 Generative Agents（Stanford）

**机制（高，论文 2023-04-07）**：

| 维度 | 事实 |
| --- | --- |
| 分层 | Memory stream：自然语言记录 + 时间戳 + 最近访问时间；没有数据库分层，靠检索和反思组织。 |
| 写入 | 观察/对话/行动写入 stream；定期 reflection 生成更高层记忆。 |
| 检索 | score = recency + importance + relevance；recency 衰减因子 0.995；importance 1–10；relevance 用 embedding cosine。 |
| 注入/预算 | 检索 top-k 记忆进入 prompt；论文未给移动端 token 预算。 |
| 反思 | 当未反思记忆的 importance 之和 >150 时触发 reflection，生成洞察并重新入库。 |
| 更新/冲突 | 以追加为主，反思产生新条目；没有强冲突消解。 |
| 用户可见/可编辑 | 研究沙盒，无消费级编辑 UI。 |
| 存储/隐私 | 本地模拟环境；25 个 Agent 的 Smallville 沙盒。 |
| 已知失败/批评 | 幻觉式 embellishment、过度正式的语言、检索失败；规模小、可复现性有限。 |

**可借鉴**：
- recency/importance/relevance 三因子是低成本、可解释的排序骨架；适合在 Dart 里实现。
- reflection 的“重要性累积到阈值再整理”可作为后台 consolidation 的触发条件。

**不可借鉴**：
- 0.995 的快速衰减不适合长期偏好；importance 每条用 LLM 打分成本高；沙盒结论不能直接外推到移动端个人助手。

### 2.11 A-MEM

**机制（高，论文 2025-02-17）**：

| 维度 | 事实 |
| --- | --- |
| 分层/模型 | Zettelkasten 式笔记：content、keywords、tags、context、links；笔记之间动态链接。 |
| 写入 | LLM 构建笔记，并生成链接；memory evolution 会随新笔记调整旧笔记的上下文/链接。 |
| 检索 | 向量/余弦相似度检索，结合链接结构。 |
| 注入/预算 | 检索结果拼 prompt；论文未规定移动端预算。 |
| 更新/冲突 | 通过链接与演化表达关系，不是覆盖；但依赖 LLM 判断。 |
| 用户可见/可编辑 | 研究原型；可视化/编辑有限。 |
| 存储/隐私 | 向量库 + 笔记结构；研究环境。 |
| 已知失败/批评 | 每条笔记的链接/演化都要 LLM 调用，成本高；图漂移/链接噪声；评测主要在 LoCoMo 对话数据，生产证据有限。 |

**可借鉴**：
- “相关记忆互相链接”能帮助解释“为什么一起被召回”；MissionBook 若要做，可先用确定性的 `conflictKey/goalId` 关系，不必每条调 LLM。

**不可借鉴**：
- LLM 自动建链/演化对本地写入成本和可解释性都不友好。

### 2.12 MemoryOS

**机制（高，论文 2025-05-30）**：

| 维度 | 事实 |
| --- | --- |
| 分层 | Short-term（STM）、mid-term（MTM）、long-term personal memory（LPM）。 |
| 写入/更新 | 新对话进 STM；按 heat（访问/交互/recency）在 MTM/LPM 间更新；MTM 用分段页组织。 |
| 检索 | 查询所有层，按相关性与热度组合。 |
| 注入/预算 | 检索结果拼 prompt；框架未规定移动端预算。 |
| 更新/冲突 | 热度驱动的淘汰/提升；不是语义冲突消解。 |
| 用户可见/可编辑 | 研究原型。 |
| 存储/隐私 | 研究环境；需要维护多层结构。 |
| 已知失败/批评 | 热度参数/分页策略需要调参；多层维护复杂；评测集中在 GVD/LoCoMo，生产证据有限。 |

**可借鉴**：
- “使用频率/热度”可作为排序因子；原调研基线没有 usage。当前重构已有 `memory_usage` 写入与排序路径，完整统计测试及收益评估仍待最终验收，不能沿用“目前没有”的表述。
- 分层不是目的，稳定核心 + 可检索长尾才是目的。

**不可借鉴**：
- 三套存储层 + 分页组织，对单用户移动端是过度设计。

## 3. 横向对比

| 对象 | 核心形态 | 写入 | 检索 | 注入 | 冲突/遗忘 | 用户控制 | 主要风险 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| OpenClaw | curated 文件 + episodic 文件 | Agent/dreaming/压缩前 flush | 默认关键词（SQLite FTS5/Postgres）；配置 embedding 后 BM25+向量+MMR | 核心启动注入，长尾检索 | 后台 consolidation；forget 删文本/向量 | 文件/CLI/导入 | 注入持久化、配置向量后的索引成本、后台调度 |
| Hermes | 两个小文件 + FTS5 历史 | memory 工具 | FTS5 关键词 | 每次会话注入，冻结 | 自动去重、无 decay | 文件/CLI | 硬上限、无衰减、中文检索 |
| Letta | core blocks + recall + archival | Agent 工具/API/后台 | 向量/历史检索 | core 常驻 | block 整体替换、并发丢失 | SDK/API | 覆盖丢内容、向量成本 |
| Mem0 | 抽取条目 + 向量/图 | LLM 抽取 + ADD/UPDATE/DELETE/NOOP | 语义/图 | 应用拼 prompt | 四操作 | API/平台 | LLM 成本、基准争议、图多跳 |
| Zep | 时间知识图谱 | episode 抽取、边失效 | 向量+BM25+图 | 子图拼 prompt | 双时间、失效不删 | 平台/图查询 | 摄取成本、实体消解、复杂度 |
| LangMem | semantic/episodic/procedural | 热路径/后台 | namespace + 语义 | 应用拼 prompt | 依赖 manager 策略 | SDK | 延迟/陈旧、prompt 质量 |
| ChatGPT | saved memories + history | 显式/自动 | 平台内部 | 平台自动 | 用户查看/编辑/删除 | 设置开关 | 黑盒、隐私、错误记忆 |
| Claude Code | 分层 CLAUDE.md + auto memory | 用户编辑/自动笔记 | 启动加载/按需 | 文件注入，200 行/25KB | 优先级，无自动消解 | `/memory` | 上下文噪音、规则冲突 |
| Cursor | 规则文件 | 用户/团队手写 | 激活模式 | always/自动/自选/手动 | 无自动消解 | 高 | 规则膨胀、漏规则 |
| Generative Agents | memory stream | 观察/反思 | recency+importance+relevance | top-k | 追加/反思 | 研究沙盒 | 幻觉、检索失败、小规模 |
| A-MEM | Zettelkasten 笔记 | LLM 建笔记/链接/演化 | 余弦+链接 | top-k | 链接/演化 | 研究原型 | LLM 成本、图漂移 |
| MemoryOS | STM/MTM/LPM | 热度驱动 | 全层检索 | 检索拼 prompt | 热度淘汰 | 研究原型 | 调参、复杂度、证据有限 |

## 4. 批评与反面视角

1. **基准不可复现/厂商争议**：Zep 博客《Lies, damn lies, statistics: Is Mem0 really SOTA in agent memory?》（2025-05-06）质疑 Mem0 对 Zep 的评测；Mem0 在 Zep 的 `zep-papers` issue #5（2025-05-07）回应并要求修正。双方都既是参赛者又是裁判。LOCOMO/LongMemEval/DMR 是对话/记忆检索基准，不等于“移动端个人助手的长期记忆质量”；不能直接拿宣称分数做设计依据。
2. **记忆污染**：AgentPoison（NeurIPS 2024，arXiv 2407.12784）证明少量污染记忆/知识库即可对 RAG Agent 植入后门；OpenClaw 的 `MEMORY.md` 也被安全分析指出是持久 prompt injection 的放大器。任何“自动把外部内容写进核心”的设计都必须有来源门控。
3. **覆盖丢内容**：Letta 官方明确警告 block 更新是整体替换、并发写会丢数据；这与 MissionBook 的行级事务/乐观锁语义相反。任何“整块重写记忆”的方案都应避免。
4. **硬上限的副作用**：Hermes 2,200/1,375 字符上限导致超限写入失败（官方 feature 页 + issue #16831）；“有界”是优点，但必须有可见失败、可配置上限和用户清理入口。
5. **上下文噪音**：Claude Code 官方建议 CLAUDE.md <200 行；auto memory 每会话只加载 200 行/25KB。记忆不是越多越好，注入预算和“按需检索”比“全量塞入”更重要。
6. **向量维护成本（仅在配置 embedding 后）**：OpenClaw 在配置 embedding provider 后，provider/model/prefix 变更需重建索引；本地索引串行；Mem0/Zep 需要向量库/图库与 embedding 版本管理。未配置时只走关键词检索，不产生这些成本；对单用户移动端，是否引入是独立取舍。
7. **研究原型的规模外推**：Generative Agents 是 25 个 Agent 的沙盒；A-MEM/MemoryOS 主要在 LoCoMo/GVD 上评测。它们的机制可借鉴，但不能把实验数字当成生产保证。

## 5. 对 MissionBook 的适配判断

### 5.1 约束

- Android 个人 App，Flutter + Drift/SQLite；单用户；本地数据。
- 无云端向量库；模型是远程 API（DeepSeek 等），注入内容会发给模型提供方。
- 强事务、操作回执、乐观锁、三档权限、备份/恢复版本校验。
- 任务/记录/分析是事实来源；记忆不能复制一套可写时间线。
- 中文优先，中文检索不能假设空格分词。

### 5.2 可借鉴 / 不可借鉴

| 来源 | 可借鉴 | 不可借鉴/改造 |
| --- | --- | --- |
| OpenClaw | curated vs episodic 两段式；provenance 门控；recency+importance+MMR；后台 consolidation；默认关键词检索的轻量形态 | Markdown/多索引后端；配置 embedding 后的额外 provider/索引维护；夜间 dreaming |
| Hermes | 小而硬上限的核心；显式写入；去重；可见失败 | 会话冻结；无 decay；纯 FTS5 |
| Letta | core 常驻 + archival 检索；硬 limit；后台整理 | block 整体替换；并发丢失；向量平台 |
| Mem0 | ADD/UPDATE/DELETE/NOOP 的显式更新语义 | 每次写入调 LLM；向量/图库 |
| Zep | 时间有效性/失效而非删除 | 图数据库/实体消解/服务化 |
| LangMem | 热路径写 + 后台整理；三类记忆作为概念 | 三套 namespace/存储 |
| ChatGPT | 用户可见/可编辑/可关闭；显式与自动分开 | 云端黑盒自动保存 |
| Claude Code | 作用域层级；大小上限；按需加载；可检查 | 文件路径/glob 体系 |
| Cursor | always/自动/手动三种激活 | 规则文件体系 |
| Generative Agents | recency+importance+relevance；反思阈值 | 快速衰减；逐条 LLM 打分；沙盒外推 |
| A-MEM | 相关记忆链接/演化 | 每条 LLM 建链 |
| MemoryOS | 使用热度作为排序因子 | 三层存储/分页维护 |

### 5.3 落点（早期建议，已被后续完整重构取代）

> 本节原建议“不新增分层表、用既有字段表达核心/目标/观察”的增量方案，已被用户后来“完整重构、所有结构可改”的裁定取代，**不再是现行设计**。现行实现以[长期记忆](../架构/前端/助手与总结/长期记忆.md)为准；本节只保留为历史决策记录。

当前真实结构（`schemaVersion=18`，`lib/data/local/tables/memory_tables.dart`）：

- `MemoryItems`：独立 `layer` 列表达 **identity / semantic / episodic / procedural / observation** 五层；`certainty` 三态 **stated / inferred / unverified**；`importance` 1–100；`topicId`、`sourceKind/sourceRef`、`goalId`、时间、墓碑与用户更正字段。
- `MemoryTopics` + `MemoryTopicAliases`：主题与别名消解，取代旧 `conflictKey` 字符串相等；`MemoryVersions` 追加式保存 before/after 版本历史；`AppSettings` 保存记忆抽取开关并随备份恢复。
- 旧 `memory_entries` 与 `conflictKey` 已删除；备份改为 formatVersion 2（`database.json` + schema 指纹）。
- `episodic` 与 `procedural` 已有派生表、反思动作、通用 save 新增/更正/换层同步与读取路径；`memory_usage` 已接 recall/inject 记录、节流、关闭排空及完整评分，相关定向测试已有实跑。FTS5 与 embedding 仍未引入。

## 6. 现状事实核验（重构前基线，file:line）

### 6.1 5 条“鸡肋”候选逐条判定

| # | 假设 | 判定 | 证据与影响 |
| --- | --- | --- | --- |
| 1 | 核心上下文只有全局 stated 前 10 条/2000 字符、按更新时间排序、与话题无关；目标级记忆不进核心 | **成立** | `coreMemory()` 的 SQL 明确 `goal_id IS NULL AND certainty='stated'`，`ORDER BY user_edited DESC, updated_at DESC, id LIMIT 10`；JSON 长度 >2000 即停止（`drift_memory_repository.dart:543-565`）。注入在每次 `sendMessage` 追加一条 `mission_book_memory` 上下文（`assistant_sessions.dart:271-276`），不是按当前话题检索。目标级记忆完全不进核心。附加问题：字符预算不是 token 预算；每次发送都追加一份，长会话会重复/被压缩摘要。 |
| 2 | 检索只有 LIKE，无语义召回、无重要度/使用频次/时间衰减加权 | **成立（“检索不到”需限定）** | `queryMemory` 只有 `content LIKE %kw% OR id=kw`，排序 `user_edited DESC, updated_at DESC`（`drift_memory_repository.dart:291-328`）。没有语义、没有 usage/importance/decay；`MemoryEntries` 也没有这些字段（`record_analysis_tables.dart:101-115`）。但 LIKE 对中文子串是有效的，小数据量下不是“搜不到”，而是“无排序、全表扫描、随规模退化”；没有源码证据证明当前已出现性能故障。 |
| 3 | 无记忆分层、无反思汇总与遗忘衰减，冲突靠 conflictKey 字符串相等，易漏合并或误合并 | **成立** | 表字段没有 layer/importance/access 统计；没有 reflection/consolidation 任务，只有逐条用户消息抽取（`analysis_triggers.dart:77-84`、`analysis_service.dart:187-194`）。冲突判断是归一化 `conflict_key` 字符串相等或正文完全相同（`drift_memory_repository.dart:459-501`）；命中后直接覆盖目标条目的 content/kind/source/certainty/expiresAt，不保留旧值。误合并风险来自宽泛 conflictKey，漏合并来自同义不同键；跨目标/全局用 `goal_id IS ?` 隔离。另：`docs/架构/前端/助手与总结/总览.md:187` 说“冲突时保留原有事实，新条目作为未验证观察”，与当前代码不符，属于过时文档。 |
| 4 | AI 侧 saveMemory 不能写 observation、certainty 只能 stated，观察类记忆只能靠异步抽取，写入路径窄 | **部分成立，需修正** | AI 工具 `saveMemory` 的 kind enum 只有 preference/fact/constraint，certainty enum 只有 stated（`context_tools.dart:387-407`）；异步抽取也只接受 preference/fact/constraint 且 certainty 必须 stated（`drift_analysis_store.dart:441-449`、`analysis_service.dart:189`）。因此 observation **既不能由 AI 写，也不能由异步抽取写**，只能由用户在“AI 日记本”编辑器手动创建（`memory_page.dart:525-545`，kind observation → certainty unverified）。所以“写入路径窄”成立，但“观察类只能靠异步抽取”不成立；实际是“只能靠用户手动”。 |
| 5 | 记忆与任务事实/时间线割裂，助手难以把长期偏好与当前目标进展结合 | **部分成立** | `MemoryEntries` 只有 `goalId` 外键，没有 missionId/recordId；source 是字符串（`record_analysis_tables.dart:101-115`）。核心注入只有记忆 JSON，任务事实要靠 `getMission/getGoal/getRecord` 另行查询（`assistant_prompt.dart:17-31`）。助手理论上可以在一次回答里组合工具结果，但没有“当前目标 brief = 任务事实 + 目标记忆”的自动装配；目标级记忆又不进核心，所以实际很容易只看到全局偏好。属于架构性割裂，不是绝对不可组合。 |

### 6.2 额外必须查清的点

- **coreMemory 的生产调用点**：只有 `assistant_sessions.dart:274` 一处（`_controller._memory.core()`），在每次 `sendMessage` 内调用；测试中另有 `record_context_test.dart`、`context_settings_page_test.dart`、`record_context_flow_test.dart` 的直接调用。
- **注入位置与分层**：系统提示词只定义记忆行为（`assistant_prompt.dart:33-37`）；每轮先注入 `mission_book_context`（当前时间/引用目标，`assistant_sessions.dart:267-270`，内容见 `:545-562`），再注入 `mission_book_memory`（`:271-276`），然后才是用户消息。记忆不是 system prompt 的一部分，也不是持久核心块；它是普通上下文消息。
- **预算计算**：`coreMemory` 用 `jsonEncode(v).length` 累加，上限 2000 字符、最多 10 条（`drift_memory_repository.dart:548-564`）；单条 content 上限 1000 字符（`_saveMemory`，`:408-413`）。不是 token 估算，也未与整体上下文预算联动。
- **上下文压缩**：`ContextPolicy` 默认 `triggerRatio=0.8`、`targetRatio=0.5`、`headroomTokens=512`、`keepRecentMessages=6`、`summaryMaxTokens=1024`、`maxSummaryCalls=3`（`packages/agent_core/lib/src/models/configuration.dart:220-249`）。记忆上下文消息和其他消息一样可被摘要，不会被固定保留；因此“每轮追加一份”在压缩后可能只剩摘要中的二手描述。
- **抽取触发与失败重试**：`assistant_session_records` 每插入一条 user `message_added`，触发器就排一个 `memory` job，target 为 `sessionId:sequence`（`analysis_triggers.dart:77-84`）。`AnalysisService` 在 claim 时把 `memory` 始终并入 automatic scopes（`analysis_service.dart:176-181`），所以即使关闭 mission/node/goal 自动总结，记忆抽取仍会自动跑（除非偏好读取失败导致空集合）。抽取只读这一条用户消息（`drift_analysis_store.dart:63-82`），最多 5 条，quote 必须是原文子串（`:441-449`）；失败按 `30 * 2^attempts` 秒退避、最多 5 次（`:365-390`），页面用 `requestManual(memory)` 重试（`memory_page.dart:105-128`）。
- **memory_page 交互与三步原则**：页面提供搜索、包含过期过滤、分页、编辑/新增弹层、忘记确认、抽取重试（`memory_page.dart:43-128`、`:130-195`、`:496-693`）；没有目标筛选、没有层级/使用次数展示、没有“哪些会进入核心”的提示。所有按钮都接到 `MemoryService`/`AnalysisService`，未发现假数据或空回调。当前路径是 设置 → AI 日记本 → 编辑弹层 → 保存（忘记另有确认弹窗）；重构时不要新增中间页，否则会破坏三步原则。

## 7. 依赖与环境核验

### 7.1 工具与版本（实跑）

- `flutter --version`：Flutter 3.47.4 stable，Dart 3.13.3（2026-09-10 构建）。
- `flutter analyze`：`No issues found! (ran in 6.2s)`。
- `flutter test test/data/assistant/memory_selection_recovery_test.dart`：`All tests passed!`（仅一条最小记忆清理恢复测试；未跑全量）。
- 依赖：`drift 2.34.0`、`drift_flutter ^0.3.1`、`sqlite3 3.8.0`（`pubspec.yaml:22-23,47`）；`sqlite3_flutter_libs 0.6.0+eol` 是 `0.6.0` 起的空壳包，实际 SQLite 由 `sqlite3` v3 的 native assets 提供。

### 7.2 FTS5 是否可用

- `sqlite3 3.8.0` 的编译默认 defines 含 `SQLITE_ENABLE_FTS5`、`SQLITE_ENABLE_RTREE`、`SQLITE_ENABLE_MATH_FUNCTIONS`（`~/.pub-cache/hosted/pub.flutter-io.cn/sqlite3-3.8.0/lib/src/hook/compile/description.dart:576` 起）。
- 实际构建产物 `build/native_assets/linux/libsqlite3.so`：`sqlite3_libversion()=3.54.1`，`sqlite3_compileoption_used('ENABLE_FTS5')=1`；用 ctypes 执行 `CREATE VIRTUAL TABLE t USING fts5(a)`、插入、`MATCH` 查询返回 rc=0。
- Android arm64 产物 `build/app/intermediates/flutter/release/native_assets/jniLibs/lib/arm64-v8a/libsqlite3.so` 含 `fts5` 模块错误字符串与 `3.54.1` 版本串；Web 的 `web/sqlite3.wasm` 也含 fts5 字符串。
- 结论：**无需新增依赖即可使用 FTS5**；但 Android 真机未实际执行，只能算构建产物证据。

### 7.3 中文检索实测（关键）

用随包 SQLite 3.54.1 对同一句 `我喜欢上午学习` 做 FTS5 查询：

| 表配置 | 查询 | 命中 |
| --- | --- | --- |
| 默认 `unicode61` | `上午学习` | 0 |
| 默认 `unicode61` | `我喜欢上午学习`（整段） | 1 |
| `trigram` | `上午学`（3 字） | 1 |
| `trigram` | `上午`（2 字） | 0 |
| `trigram` | `喜欢`（2 字） | 0 |

含义：默认 tokenizer 把无空格中文整段当一个 token，用户搜两个字的词会失败；`trigram` 支持 ≥3 字子串，但 2 字词失败。现有 `LIKE %kw%` 反而对任意中文子串有效。**因此不能用 FTS5 直接替换 LIKE**；若引入 FTS5，必须 `trigram` + LIKE 回退（或做中文预分词/双字索引），并覆盖 2 字查询测试。

### 7.4 设备端 embedding

- `pubspec.yaml` 只有 `sherpa_onnx 1.13.8`，用于离线语音（`local_speech_backend_base.dart:3`、`sherpa_speech_engine.dart:5`）；没有文本 embedding 模型、没有 ONNX/TFLite 文本编码器、没有向量索引依赖，`assets/models/` 下只有语音模型。
- 结论：**当前没有现成的设备端文本 embedding 能力**。若要上，需要新增模型资产（包体/下载）、推理运行时、向量存储/暴力扫描、中文评测与隐私说明；不建议在本轮重构中作为前置条件。
- **两个参考对象的默认形态同样不依赖向量**：Hermes Agent 官方 memory 文档是 SQLite 全文检索（https://hermes-agent.nousresearch.com/docs/user-guide/features/memory ，仓库 README 明确 FTS5：https://github.com/nousresearch/hermes-agent ；访问 2026-11-13）；OpenClaw builtin 在未配置 embedding provider 时只有关键词检索（官方原文见 §2.1）。因此本轮不做 embedding 与两个参考对象的默认形态一致，不是 MissionBook 独有的能力妥协。
- **延后不等于永久不做**：先用别名登记、主题归并、确定性加权检索跑中文评测；若同义召回仍低于验收门槛，且目标机验证模型资产/内存/延迟可接受，再单独立项评估 embedding。本轮不引入模型资产、不预建空向量接口、不建同义词词典工程。

### 7.5 schema/迁移/备份（P1 后的事实）

> 本节原先基于“必须保留旧数据、不能改 schema”的前提；用户已撤回该前提（开发阶段不做历史兼容），P1 已直接升级到 schemaVersion 17。

- 当前 `schemaVersion=18`，`beforeOpen` 继续在 `hadUpgrade` 时显式拒绝，旧库政策不变；不写迁移链或兼容层。
- 备份已改为 formatVersion 2：`database.json` 行数据 + manifest 结构指纹；恢复只接受同版本、同指纹、同表列集合，不执行备份包提供的 SQL/DDL。应用自身仍执行参数化 INSERT、清空当前表和触发器停用/重建 DDL，不能说“完全不执行 SQL”。指纹基于版本、表列及索引/触发器名称，不是 SQL 定义全文哈希。旧格式备份直接拒绝。
- [current_schema_test.dart](../../test/data/local/current_schema_test.dart) 当前断言 **25 张表**，不是此前 P1 阶段的 22 表；记忆主体、主题/别名、版本、情节、流程、usage 与 app_settings 均在当前结构中。结构测试已纳入本次交接全量，当前唯一失败为独立的性能门槛。
- FTS5 仍未引入；若后续引入，虚拟表不在 `allTables`，导出无需过滤，但恢复后需同事务重建索引，并同步更新备份文档与测试。

## 8. 最终设计与已撤回建议

原建议 1–5 建立在“不改 schema、不做抽取开关、不建主题表、只用 conflictKey”的旧前提上，均已被最终设计取代：

- **分层**：独立 `layer` 表达五层；情节/流程派生结构、反思写入与通用 save 同步已有，observation 固定 unverified。
- **主题**：主题/别名表取代 conflictKey 字符串相等；S6-A 显式登记别名后的召回有历史证据，不等于原 S6 通用同义能力。
- **写入**：四态 + 追加式版本，冲突保留原事实；所有 AI save certainty 均校验 basis 引用当前用户原话。请求 id、resultId、keptId 分开，entityId 不保证恒为实际结果条目；14 字段版本常量共用，usage 不改更正快照。
- **注入**：装配含稳定、目标、话题、情节、流程和未验证块及 brief；最终序列化 JSON（含 brief/结构开销）估算 ≤800 tokens、stable 含全局 identity+semantic、全局/当前目标隔离已有实现与专项测试。供给块每轮替换；旧摘要、连续安全摘要及 getMemory 结果失效已有阶段实现，完整忘记传播尚待验收。
- **抽取开关**：`app_settings` 保存、触发器与自动任务领取同时受控；设置读取失败保留最近值，初始默认开启，迟到模型结果在发布前再检查，随备份恢复。
- **检索**：确定性加权（相关性、确认程度、层级、重要度、目标亲和、90 天衰减）；FTS 与 embedding 仍待数据证明，本轮不建空接口。

### 8.1 S6-A / S6-B 的能力边界

- **S6-A（显式登记别名）**：调用方在写入时登记“晨跑”“早上跑步”等别名，主题归并后由装配器/检索查别名召回；当前实现与评测已覆盖，S6-A 通过。
- **S6-B（无别名的同义场景）**：脚本基线历史失败；本次真实 DeepSeek B 场景通过，但只含上下文断言，不证明回答采纳，更不能证明通用同义消解。当前没有向量或通用同义消解器，不能把单次通过写成该能力已实现。
- 原调研中的关键词/FTS5 对比只说明字面检索自身的边界，不能代替对外部 Agent 模型改写、工具调用或完整产品行为的评测。MissionBook 的具体能力必须分别用登记别名、无别名、实际送达与真实回答断言验证。
- 改善路径是**别名登记 + 主题归并 + 装配器查别名**（已按该路径实施），不是上向量或建同义词词典；本轮不做 embedding 的裁定与两个参考对象的默认形态一致。不得用 S6-A 的通过冒充原 S6 场景通过。

## 9. 阶段交接验证与接续开发

2026-11-13 用户要求暂时保留有限实现，更新文档后完整提交推送，转到自己的电脑继续开发。相关在途成员任务已停止；交接版包含已写入的生产代码与测试，不表示原完整重构目标全部完成。

| 验证 | 交接实跑结果 | 边界 |
| --- | --- | --- |
| Flutter 静态分析 | 0 issue | 新测试编译错误和旧连接空正文断言已修正 |
| Flutter 全量 | 1036 通过、45 跳过、1 失败 | 唯一失败是混合 5k 性能，退出码 1 |
| 模型预算与生命周期专项 | 40 通过 | 脚本模型，不证明供应商真实效果 |
| agent_core | 静态分析 0 issue；140 通过、1 跳过 | 跳过项需要真实模型凭据 |
| 显式启用的压缩专项 | 9 通过 | 手动/自动/连续压缩、旧摘要、查询后遗忘与重开；脚本模型 |
| 混合 5k 装配 | 本次全量 p95 6.280 ms；此前单并发 5.181 ms | 均超过严格小于 5 ms 的门槛，保留失败 |
| 历史真实 DeepSeek | 工具 1 通过；adoption 6 通过、1 失败 | semantic 注入修复后未重跑最终树，不能改写为通过 |

接续先处理混合 5k 性能与跨连接缓存失效验证，再完善 saveMemory 等工具结果/衍生摘要失效、超长单节点和通用工具输出预算；之后重跑真实 DeepSeek 和 Android 真机交互。FTS5、embedding 和通用同义消解仍未实现。实现边界、完整命令、历史结果与优先级统一维护在[长期记忆交接](../架构/前端/助手与总结/长期记忆.md#阶段交接验证与接续开发)，本报告不另行推算计数。

S1/S8 的脚本结果只证明送达，S4 证明标注与分块，S5 证明特定投影断言；不能升级成模型效果结论。脚本 S6-A 历史通过、S6-B 历史失败保留为不同场景的基线，不能写成原 S6 或 9 项全过。完整重构、真实模型最终采纳和目标设备验收均未标记通过。

用户体验以现有页面为准：“助手设置 → AI 日记本”检查层级、目标范围（含全局）、来源和别名；“助手设置 → 自动总结 → 自动整理对话记忆”即时切换；聊天预算圆环打开“上下文与用量 → 压缩早期对话”；日记本忘记需确认；“数据备份”先校验预览再替换。列表筛选目标不会让手动新增继承目标，新增目前为全局、更正保留原 goalId。完整待验收步骤见[用户体验路径](../架构/前端/助手与总结/长期记忆.md#用户体验与待验收路径)。

原调研未找到名为“Harmes”的同名项目，仍按 Hermes Agent 标注替代关系；本轮未补新外部调研。
