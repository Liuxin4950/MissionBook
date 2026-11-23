# Android 悬浮助手与离线语音统一实施计划

> 状态：**已实施**（提交 `8ed87c5`/`68f1a88`；真机与真实模型验收待补，见[学习进度](../教学/学习进度.md)）。编制日期：2026-11-23；原文保留供追溯。本文供多个 AI 按工作包并行实施；实现前仍须检查当时工作树，不能把本文或旧验收记录当作当前代码状态。

## 目标与范围

根据用户提供的悬浮入口、截图后工具面板两张截图，统一 Android 跨应用助手的入口与回退行为，并核清离线语音调用链及录音状态界面。目标是保留一个可拖动/收起的头像悬浮球，点击后使用既有圆形快捷菜单；截图成功或取消后回到截图前应用，并按截图发起时的上下文恢复圆形快捷菜单或原会话，不再弹出单独的矩形工具首页；语音由用户当前选定的识别方式处理，离线模式使用已配置的 SenseVoice，而不是 Android 系统语音识别。

本计划不改业务数据库、聊天会话协议、任务工具权限、MediaProjection 授权方式或现有的手动截图能力。识别文字只回填原助手草稿，不自动发送。用户明确选择“录音转写服务”时仍按其配置发送录音；离线是默认模式，不代表强行覆盖用户已保存的识别方式。

## 已核对的当前事实

| 项目 | 当前实现与证据 |
| --- | --- |
| 悬浮入口 | [AssistantOverlayService.kt](../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantOverlayService.kt) 点击主球显示 [AssistantOverlayQuickMenu.kt](../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantOverlayQuickMenu.kt)，提供文字、语音、截图、更多四个圆形动作；点击文字打开对话窗口。 |
| 矩形工具首页 | 语音动作先经 `openVoice()` 创建 [AssistantOverlayPanel.kt](../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantOverlayPanel.kt)，等待面板加载后才启动录音 Activity。因此语音入口会短暂经过矩形工具首页。 |
| 截图返回 | 截图完成及取消均由 [AssistantCaptureConsentActivity.kt](../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantCaptureConsentActivity.kt) 结束自身并返回原应用；服务回调 [AssistantOverlayService.kt](../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantOverlayService.kt) 的 `reopenAfterCapture()` 会恢复头像并调用 `showPanel()`，所以返回后出现的矩形工具首页是 App 自己重开的，不是 Android 系统面板。 |
| 截图草稿 | [assistant_workspace_bridge.dart](../../lib/data/assistant/assistant_workspace_bridge.dart) 用 capture ticket 绑定截图开始时的助手草稿；成功后把图片加到该草稿，不自动发送。这个身份与交付语义必须保留。 |
| 录音采集 | [AssistantOverlayVoiceActivity.kt](../../android/app/src/main/kotlin/chat/liuxin/mission_book/AssistantOverlayVoiceActivity.kt) 使用 Android `AudioRecord` 采集 16 kHz、单声道、PCM16，最多 30 秒，然后把 PCM 交给 Flutter 工作区。它是麦克风采集 API，不是语音识别 API。 |
| 语音识别 | 本轮源码检索未发现 `SpeechRecognizer`、`RecognizerIntent` 或 `ACTION_RECOGNIZE_SPEECH` 调用。实际识别由 [configured_assistant_speech.dart](../../lib/data/assistant/configured_assistant_speech.dart) 决定：默认 `useTranscription=false` 时走 Android [local_speech_backend_io.dart](../../lib/data/speech/local_speech_backend_io.dart) 与 sherpa-onnx SenseVoice；用户显式选择转写服务后才走独立 HTTP 服务。 |
| 离线模型 | [speech_model_store_io.dart](../../lib/data/speech/speech_model_store_io.dart) 只检查/使用已安装模型；不会自动下载。模型需由用户在助手语音设置主动下载，固定版本、大小与校验值见 [SenseVoice 模型说明](../../assets/models/sensevoice/README.md)。 |
| 当前语音外观 | 录音 Activity 使用半透明无标题系统主题、原生 `Button` 和少量状态文字；尚未形成与助手快捷菜单一致的完整准备、录音、转写、结果与错误状态设计。 |

详细的现行语音边界见[离线语音设计](离线语音.md)；已有悬浮与截图调用图见[平台资源架构](../架构/前端/平台资源/README.md#android-跨应用助手)和[语音截图修复记录](../审查/2026-11-17-语音与截图交互修复.md)。

## 目标交互规格

### 1. 唯一的快捷工具入口

- 常驻入口仍是现有头像球/边缘把手；点按后只展开 `AssistantOverlayQuickMenu` 的圆形动作，不再显示“书祺 + 截图/语音/文字”矩形工具首页。
- 文字动作直接打开可编辑的助手对话窗口。对话窗口仍是实际聊天、附件预览和操作确认界面，不属于工具首页；不能为统一外观而删除这些真实会话能力。
- 语音动作直接进入录音准备流程，不先打开矩形工具首页。结果需要检查时才打开同一助手草稿的对话输入区。
- “更多”继续承载次级动作。截图、更多和对话面板继续避开头像、系统栏、刘海和键盘，并保留 48dp 触控及左右边缘镜像布局。

### 2. 截图结束恢复发起时的悬浮状态

```text
头像悬浮球 → 圆形动作菜单 → 截图
  → Android 系统投影授权 → 局部/全屏编辑（或长截图）
  → ticket 将图片交给截图开始时的助手草稿
  → 关闭授权/编辑 Activity，返回截图前应用
  → 若从圆形动作菜单发起：恢复同一组圆形动作，不显示矩形工具首页
  → 若从已有聊天面板发起：恢复原会话及其输入草稿
```

- 捕获开始时记录来源状态和必要身份（圆形菜单、已有会话及 draftKey、通知等），并与 capture ticket 绑定；结束时按该身份恢复，不依据全局当前菜单猜测，也不对所有情况套用同一面板。
- 圆形菜单启动截图后，成功或取消返回到截图前应用，并重新显示该圆形动作菜单；需要检查图片时用户从“文字/会话”动作进入聊天。若截图是从已有会话面板的附件工具发起，则回到原会话并显示已交付图片。截图回退不自动新建或打开无关会话。
- 成功时，截图继续附着于开始截图时的草稿，即使期间有异步回调，也不能误投到另一个会话；草稿未提交前仍允许查看、移除和继续编辑。
- 用户取消、系统拒绝、编码失败、Activity/投影异常都释放投影和图片资源并恢复对应的悬浮来源状态；不会把工具首页当成失败兜底。真实失败原因用已有错误反馈路径呈现。
- 将截图恢复与主动通知分开：当前 `showNotice()` 在没有聊天窗口时也会借用 `reopenAfterCapture()` 打开面板。实现时拆分截图来源恢复与通知展示，不能因修改截图菜单而丢掉提醒内容、回复/稍后/不再提醒和任务入口。
- 手动截图仍返回截图前应用，不强制启动 `MainActivity`；保留既有 MediaProjection、选择器、长截图限制、缓存确认与 ticket 语义。

### 3. 语音使用配置中的识别后端

- Android 原始录音仍由 App 控制并以 PCM 交给识别后端；不得把 `AudioRecord` 描述为系统语音识别，也不得新增 `SpeechRecognizer`、识别 Intent、厂商语音 UI 或静默系统服务回退。
- 首装/默认模式为离线 SenseVoice。用户已选择离线时，仅使用已验证的本地模型和 sherpa worker；模型缺失、校验失败或初始化失败时明确报错，不转云、不自动下载，也不先申请录音权限再告知缺模型。
- 用户显式配置并选择“录音转写服务”时，沿用独立 endpoint/model/API Key，并在录音前清楚说明录音会离开设备；服务错误时不静默切回本地模型。
- 以一个语音 ticket 固定本轮草稿身份和识别方式。准备、录音、转写、取消和迟到结果均按 ticket 校验；会话/工作区改变或取消后，迟到文字不能覆盖其它草稿。ticket 仅作会话身份，不向 Android 层暴露 API Key。
- 本地模型准备可显示真实的“准备离线模型”忙碌状态；不得把模型初始化伪装成录音进度。离线模型检查/准备不得触发下载。
- 转写成功后，Activity 通过 ticket 和 `draftKey` 通知 `AssistantOverlayService`；服务关闭圆形菜单，在该草稿仍为当前会话时建立/复用 `AssistantOverlayPanel`、加载最新快照后进入对话输入区。不能仅打开一张空白新会话，也不能拿当前 key 猜测替代 ticket 绑定的 key。若期间原草稿已失效，保留明确错误和用户已有状态，不把文字写到其他草稿。转写成功不自动发送。
- 模型缺失、校验或初始化失败时提供可达的“打开语音设置”入口。实现前由集成者核对导航：原生 Activity 没有直接访问 Flutter 语音设置路由的现成契约，须通过现有 App/工作区入口显式交接目标路由；不能只启动主界面后显示含糊提示。此路由应回到助手设置的语音输入页，用户可主动下载模型后返回悬浮语音入口。
- 转写失败不丢失可恢复的录音/草稿状态；重试路径必须明确是重录还是重试现有 PCM。

### 4. 语音状态及视觉适配

以 App 自有录音面板替换仅有系统按钮和状态字的临时窗口。保持当前应用浅色基调：背景 `#F7F8F5`、白色表面、森林绿 `#244D3D`、主文字 `#282E2A`、次文字 `#626A64`、错误 `#A35448`；浅色沿用全局主题，不新增独立配色或宣称支持目前不存在的 App 暗色主题。视觉值最终应尽量映射到现有全局语义 token，原生侧无法直接读取的值须集中定义而非散落硬编码。

需要覆盖以下可区分状态，每一状态都有准确文案、图标/反馈、可访问标签和可用动作：

| 状态 | 呈现与动作 |
| --- | --- |
| 正在准备 | 明示“准备离线模型”或“检查转写服务”；使用不确定进度指示，不显示虚构百分比。 |
| 模型缺失/准备失败 | 解释不能录音的原因；提供“使用文字”和可达的“打开语音设置/下载模型”路径。不得启动麦克风或宣称识别成功。 |
| 麦克风授权 | 说明用途并调用系统权限请求；授权弹窗由 Android 系统控制，应用只负责回到原窗口、显示拒绝/永久拒绝和重试入口。 |
| 正在录音 | 清楚显示录音状态、已录时长/剩余上限（最多 30 秒）、“取消”和“完成”；完成后仅提交转写，不发送消息。 |
| 正在转写 | 停止计时，显示真实处理中状态和可取消动作；无百分比，重复点击有防重。 |
| 转写完成 | 回到原草稿的可编辑输入，展示完整结果；不自动发送。 |
| 失败/取消 | 可读的短中文原因，提供重试、重新录音、使用文字或关闭；取消不写入部分结果，错误不覆盖用户已有草稿。 |

面板尺寸按可用窗口与系统字号自适应；320dp 窄屏、横竖屏、双倍字号、系统栏/刘海、键盘、返回手势均不得裁切文案或主动作。主要触控不少于 48dp；图标不替代按钮语义；TalkBack 可读出识别方式、状态、计时与动作。动效遵循项目“减少动效”偏好，不用动画暗示假的录音/识别进度。

主题适配不是只给录音窗口换色，而是统一检查 Android 悬浮交互中所有 App 自绘表面：圆形快捷动作、更多动作、截图编辑器顶栏/长截图控制条、录音与识别面板、聊天输入/操作面板、主动提醒及失败提示。现有截图预览的黑色媒体画布保留，不把媒体内容改成白底；其上的控制条使用品牌暖白与森林绿。对话正文、头像、消息语义和截图选区行为不因视觉统一而改变。每种组件沿用相同的主次文字、边界、圆角、间距、焦点/按压/禁用/错误状态与减少动效规则，主题 token 集中定义并覆盖高对比度与系统字体缩放；权限对话框、状态栏等系统 UI 由 Android 控制，不要求伪装成 App 自绘界面。

## 工作包与并行边界

开始并行前先冻结下列桥接契约，所有 AI 读取同一份契约和当前工作树；不得各自发明不兼容的 channel method 或 ticket 含义。

| 工作包 | 文件所有权 | 工作内容 | 依赖 |
| --- | --- | --- | --- |
| A. 圆形入口、截图回退与悬浮主题 | `AssistantOverlayService.kt`、`AssistantOverlayQuickMenu.kt`、`AssistantOverlayPanel.kt`、`CaptureEditorView.kt`、`AssistantScreenCaptureService.kt` 中截图控制条，以及共享 `AssistantNativeTheme.kt` 和对应原生状态/几何测试；不改语音 Activity | 移除截图和语音路径中不必要的矩形工具首页；capture ticket 记录来源状态、原会话 draftKey 并按来源恢复；拆开截图恢复与通知展示；统一圆形菜单、聊天面板、截图工具栏/长截图控制条和主动通知的颜色、间距、边界、按压/焦点/禁用状态；保留提醒与会话能力。 | 先对齐 B 的 channel 契约；先提交 `AssistantNativeTheme.kt` 的 token 名称和值，再与 C 并行。 |
| B. 语音后端与 ticket 契约 | `lib/data/assistant/configured_assistant_speech.dart`、`lib/data/assistant/assistant_workspace_bridge.dart`、对应 `test/data/assistant/` 测试 | 新增录音前后端预检/准备；把当前模式、工作区代次和草稿键绑定 ticket；显式回报离线模型缺失、初始化和转写失败；取消/关闭/工作区代次变化时使 ticket 失效。只在用户主动选转写服务时允许远程传音频。 | 先冻结下方 Dart/原生 channel 契约；之后与 A/C 并行。 |
| C. 原生录音界面与主题 | `AssistantOverlayVoiceActivity.kt`、`android/app/src/main/res/values/styles.xml` 与本工作包新增的专属布局/资源；不改 `AssistantOverlayService.kt` | 实现状态化、主题一致、响应式的录音/转写界面；消费 B 的 ticket 契约和 A 的 `AssistantNativeTheme`；麦克风只能在后端预检成功后启动；成功后打开同一草稿的对话输入区。 | B 的桥接契约及 A 的 token 文件冻结后并行。 |
| D. 集成与统一验收 | `MainActivity.kt`、`app_shell.dart` 中仅限语音设置深链/目标路由消费的增量，以及模块文档与课程记录；由一位集成者串行修改，其他包不得并行编辑这些文件 | 集成 A/B/C；设计并接通“打开语音设置”从原生 Activity 到现有助手语音设置页的明确导航和返回路径；处理启动/热恢复时的一次性路由消费；端到端复验；更新平台资源/离线语音现行文档、导航索引、变更记录和学习进度；记录测试、构建及设备验收各自状态。 | A/B/C 合并后；先检查 MainActivity.kt 与 app_shell.dart 的现有工作区改动并保留。 |

`AssistantOverlayService.kt`、`assistant_workspace_bridge.dart`、`AssistantOverlayVoiceActivity.kt` 各只由上述一个工作包拥有。需要跨包改动时先把接口写入契约并由文件所有者集成，避免同时覆盖同一文件。实施者须保留工作区现有未提交改动；本次规划期间发现已有桌面小组件/平板工作区等未提交工作，不能回滚或混入本功能包。

### 建议桥接协议

具体 DTO 命名可遵循当前代码风格调整，但四个语义必须一致：

1. `beginVoice(ticket)`：Dart 准备当前外部助手草稿，读取已保存的语音设置，预检并准备所选后端，绑定 `{ticket, draftKey, routeSnapshot}`；返回可录音/明确失败及可供 UI 显示的非敏感模式状态。不返回凭据。
2. `voice(ticket, pcm)`：验证 ticket 与当前工作区代次，识别完成后仅把文字追加到绑定草稿，返回成功；不自动发送、不切换草稿。
3. `cancelVoice(ticket)`：使本票据失效并取消可取消的录音/网络资源；本地不可中断的迟到结果也必须在接收处丢弃。
4. Activity/宿主关闭、超时、权限拒绝、预检失败及新工作区接管均走明确的终结路径；重复完成/取消幂等，重复提交不能产生两次文本。

悬浮菜单点击语音时直接启动 Activity 并传入 Kotlin 生成的 ticket；Activity 先显示“正在准备”，再向 Dart 请求 `beginVoice`。Dart 成功后固定本轮 `{ticket, draftKey, routeSnapshot}`，Activity 收到 `ready=true` 后才请求麦克风：

```text
AssistantOverlayService → AssistantOverlayVoiceActivity({ticket})
Activity → beginVoice({ticket})
Dart → {ready, mode: offline|remote, message?}
Activity → 系统麦克风授权/AudioRecord（仅 ready=true）
Activity → voice({ticket, pcm})
Dart → {accepted, draftKey} 或可展示的明确错误
Activity → AssistantOverlayService.voiceDone(ticket, draftKey)
取消/Activity 关闭 → cancelVoice({ticket})
```

`routeSnapshot`、服务配置和可选凭据只留在 Dart 进程内存中的票据会话中；切换设置不能改变已开始这一轮的后端。并发 `beginVoice` 需拒绝或串行化，不能取消/覆盖 `AssistantVoiceController` 正在使用的录音会话。`voice` 必须验证当前 ticket、工作区代次及原草稿仍是可写目标；失败和取消清理票据，迟到结果丢弃。远程预检只校验已保存配置及独立凭据，不先上传音频；只有用户按下“完成”后才发送录音。API Key 不得回传 Kotlin。

如果实现者认为必须改变方法或 payload，应先更新本计划的契约段并告知集成者。不得让 Kotlin 直接判断模型目录、读安全存储或持有转写 Key；识别后端选择只归 Dart `ConfiguredAssistantSpeech` 所有。

## 可复制的工作包说明

**A：圆形入口、截图回退与悬浮主题**

```text
只实施本计划工作包 A。先读取 AGENTS.md 和 docs/设计/Android悬浮助手与离线语音统一实施计划.md，检查 git status 并保留所有已有改动。文件所有权：AssistantOverlayService.kt、AssistantOverlayQuickMenu.kt、AssistantOverlayPanel.kt、CaptureEditorView.kt、AssistantScreenCaptureService.kt 的截图控制条、AssistantNativeTheme.kt 及对应原生测试；不要修改 AssistantOverlayVoiceActivity.kt、Dart bridge 或汇总文档。

按 capture ticket 记录的来源状态恢复截图界面：由圆形快捷菜单发起时返回原应用并恢复同一圆形动作菜单；由已有聊天面板发起时恢复对应会话及图片；取消/授权拒绝/捕获失败也恢复原来源，不显示矩形工具首页。将截图恢复与主动通知显示分开，确保回复/稍后/不再提醒/回任务路径不回归。语音入口依计划中的 beginVoice ticket 契约直接启动录音 Activity，不先 showPanel。成功转写后通过 ticket/draftKey 接收 voiceDone 并打开该草稿的对话输入区。统一圆形快捷菜单、聊天面板、截图编辑工具栏/长截图控制条和通知自绘面的语义色、尺寸、间距、焦点、按压、禁用、错误状态，建立集中 token。保留所有截图、会话、通知和草稿行为。添加针对恢复分支/菜单几何的测试。最后报告改动文件、测试命令与真实未验收项，不提交、不撤销用户改动。
```

**B：语音识别后端、预检与 ticket**

```text
只实施本计划工作包 B。先读取 AGENTS.md 和 docs/设计/Android悬浮助手与离线语音统一实施计划.md，检查 git status 并保留所有已有改动。文件所有权：lib/data/assistant/configured_assistant_speech.dart、lib/data/assistant/assistant_workspace_bridge.dart、对应 test/data/assistant/ 及必要的独立新 Dart 测试；不要修改 Android Kotlin、主题资源或汇总文档。

实现并测试契约 beginVoice({ticket})、voice({ticket, pcm})、cancelVoice({ticket})。beginVoice 固定当前草稿、工作区代次、语音模式和服务配置；默认离线时只校验/prepare 已安装 SenseVoice，不申请麦克风、不下载、不访问网络；缺模型/校验/worker 错误以非敏感中文错误返回。显式远程模式只预检设置和独立凭据，不上传录音；voice 在用户完成后才发送。ticket 会话保存在 Dart，设置中途变化不切换本轮后端；重复调用/取消/重建/迟到成功严格隔离，并避免影响共享 AssistantVoiceController。结果只写入该 ticket 对应原草稿，不自动发送。冻结 Kotlin 可消费的精确 payload、错误码和状态映射并通知 A/C。运行定向 Dart 测试和静态分析，不提交、不撤销用户改动。
```

**C：原生录音界面与主题**

```text
只实施本计划工作包 C。先读取 AGENTS.md 和 docs/设计/Android悬浮助手与离线语音统一实施计划.md，检查 git status 并保留所有已有改动。文件所有权：AssistantOverlayVoiceActivity.kt、AssistantCaptureTheme 对应原生主题/布局资源；不要修改 AssistantOverlayService.kt、Dart bridge 或 A 的 AssistantNativeTheme.kt。开始前先向 A 读取 token 文件接口，向 B 读取冻结后的 channel payload，禁止自行设计另一套协议。

将当前半透明临时按钮窗改为符合 MissionBook 暖白/森林绿的状态化录音面板。按 beginVoice 结果决定是否启动 AudioRecord；显示准备、模型缺失、权限拒绝、录音计时/30 秒上限、转写、成功、失败和取消，提供完成/取消/重录/使用文字/返回等真实动作；只有用户完成后才提交 PCM，成功以 ticket + draftKey 通知悬浮服务并回到原草稿输入区，不自动发送。适配 320dp、横竖屏、系统字号、刘海/系统栏、TalkBack、48dp 触控和减少动效；不伪造进度，不把 AudioRecord 当作识别 API。处理 Activity 重建、权限回调、重复按键、返回、onPause/onDestroy、计时器和录音线程释放。添加可测状态/几何逻辑测试；报告 Kotlin 编译与设备验收边界，不提交、不撤销用户改动。
```

**D：集成者（串行）**

```text
只在 A/B/C 独立工作完成后做本计划工作包 D。先读取 AGENTS.md、工作计划和各包交付说明，检查合并前后 git status 与最终 diff；保留原有和并行 AI 的有效改动，不重写他人文件。集成冻结的 beginVoice/voice/cancelVoice 契约、按来源恢复的截图状态、语音成功后开原草稿以及通知独立路径。单独接通模型缺失时前往现有助手语音设置页的原生到 Flutter 路由，并验证返回。检查完整 capture 和 voice 状态机、异常清理、ticket 幂等、模式快照、权限和 worker 释放。运行相关 Dart 测试、flutter analyze、capture/overlay JVM 检查和 Android Kotlin 编译；然后更新现行架构/语音文档、导航、教学变更记录及学习进度。真实模型、网络、APK、目标设备、用户掌握分别标记证据，不以测试或构建替代真机验收。
```

## 实施顺序

1. **基线与契约**：确认 `git status`、Flutter/Android 配置和已有改动；核实 capture ticket 与工作区重建边界；B 先提交方法签名、错误类别和状态映射供 A/C 复用。
2. **并行实现**：B 实现 Dart 预检/绑定与测试；C 依冻结协议完成界面；A 处理圆形入口与截图状态恢复。三个包分别提交可审查 diff，不修改对方文件。
3. **串行集成**：集成者接入服务到 Activity 的启动参数、权限及 finish 回调；处理主动提醒与截图回退分流；检查草稿身份、附件、模型释放和错误反馈。
4. **验证与文档**：先定向测试与 Android Kotlin 编译，再做实际模型/API/设备验收。同步现行语音与平台文档；所有不能实测的项目明确标为待验收，不以编译或截图代替。

## 自动化验收

- **入口/捕获**：点击头像显示同一圆形菜单；点击语音不闪出矩形工具首页；截图成功、取消、权限拒绝、投影失效、编码失败、尺寸旋转、工作区 unavailable 均清理资源并按 capture ticket 恢复发起时的圆形动作菜单或原会话，不弹矩形工具首页。成功图片仍在原 ticket 草稿，其他草稿不受影响。
- **通知不回归**：助手提醒在无聊天窗口时仍能明确显示并可回复/稍后/本次不再；有任务时保留“回到任务”。不能把通知面板错误地改成截图菜单，也不因截图恢复动作清除待提醒状态。
- **识别路由**：默认及显式离线设置使用 LocalSpeechBackend/SenseVoice；模型缺失/摘要校验失败/worker 失败不申请麦克风、不自动下载、不请求 Android 语音识别或远程 API。显式选择远程服务才发送，并在录音前告知数据去向；失败无静默后端切换。
- **会话及并发**：ticket 与草稿/模式绑定；切会话、重复点击、取消、关闭、超时、工作区 detach/recreate 后的迟到成功/异常均不得覆盖错误草稿或产生重复文本；输入已有草稿时不丢失；识别完成不自动发送。
- **语音 UI**：Widget/原生布局状态测试覆盖准备、缺模型、授权拒绝、录音、最长 30 秒自动停止、转写、成功、失败、取消、重试；验证触控面积、可访问标签、无伪造进度及系统字体缩放。
- **回归门禁**：Dart 定向测试、`flutter analyze --no-pub --fatal-infos`、Android `:app:compileReleaseKotlin` 或仓库现行等价编译、截图/边缘菜单 JVM 测试均通过；运行已有 capture 与语音引擎测试。

## 真机验收

在实际 Android 平板/手机上覆盖不同宽高比、左右贴边、横竖屏、系统导航/返回手势、刘海、常规/双倍字号、TalkBack 和系统动画减少。验证截图确认后确实回到原 App；从圆形动作菜单发起时恢复原菜单，从会话面板发起时回到原会话；附件已在发起时的草稿且不会误开其它会话。取消和权限拒绝恢复同样可靠。

离线模式需在目标 ARM64 设备上先安装并验证真实模型，断网录制真人语音，确认识别文本回到原草稿、未触发 Android 系统识别 UI、没有网络请求；记录首轮模型准备耗时、识别耗时、内存及连续使用温升。模型缺失时确认没有麦克风授权弹窗、没有自动下载，并可通过界面导航到语音设置。若单独验收远程模式，应确认录音前告知、请求目标为用户配置的服务且失败没有改走本地/系统服务。

## 风险与边界

- Android 录音 Activity 是由用户显式动作启动；后台启动限制、HyperOS 覆盖窗/投影策略及录音权限表现仍需实体设备验证。
- 本地模型可能较大且准备时间长；等待界面必须真实，缺模型不能静默下载。远程转写会把录音交给第三方，必须沿用独立配置和凭据，不复用聊天 API Key。
- 截图回退、助手主动提醒与用户打开对话虽然复用同一悬浮服务，目的不同；实现时必须分开恢复动作并按 ticket/通知身份验证，不能以“统一面板”破坏通知交互。
- Android 系统麦克风权限弹窗无法套用 App 主题；App 自有录音窗口、状态、错误反馈和返回方式才是本计划的设计范围。
- 自动化通过、Kotlin 编译通过、真实 SenseVoice 识别、远程供应商验证、Android 设备体验和用户掌握是不同证据，分别记录。

## 交接清单

- 实施者先读 `AGENTS.md`、[文档入口](../README.md)、[架构入口](../架构/README.md)、[平台资源架构](../架构/前端/平台资源/README.md)、[助手与总结架构](../架构/前端/助手与总结/总览.md)及[离线语音设计](离线语音.md)，再查看实际源码、`git status` 和当前测试。
- 本文仅描述规划。未实现之前，不得在架构现状、学习进度或验收记录中写成已完成；用户掌握没有复述/独立操作证据时不得标记。
- 本轮未执行 Dart/Android 测试、未构建 APK、未安装或验证目标设备；规划本身不是实现或设备验收。
