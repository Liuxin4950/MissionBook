import 'dart:async';
import 'dart:math' as math;

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../application/assistant/assistant_controller.dart';
import 'assistant_markdown.dart';
import 'assistant_voice_status.dart';
import 'assistant_avatar.dart';
import 'assistant_scope.dart';
import 'assistant_settings_page.dart';

/// 业务页面仅提供身份；助手状态、识别和操作不归业务页面持有。
class AssistantEntryScope extends InheritedWidget {
  const AssistantEntryScope({
    super.key,
    required this.openNode,
    required super.child,
  });
  final void Function(String) openNode;
  static AssistantEntryScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AssistantEntryScope>();
  @override
  bool updateShouldNotify(AssistantEntryScope oldWidget) =>
      openNode != oldWidget.openNode;
}

class AssistantSurface extends StatefulWidget {
  const AssistantSurface({
    super.key,
    required this.child,
    this.missionId,
    this.goalId,
  });
  final Widget child;
  final String? missionId;
  final String? goalId;
  @override
  State<AssistantSurface> createState() => _AssistantSurfaceState();
}

class _AssistantSurfaceState extends State<AssistantSurface> {
  final _entry = GlobalKey<AssistantLauncherState>();
  @override
  Widget build(BuildContext context) {
    if (AssistantScope.maybeOf(context) == null) return widget.child;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AssistantEntryScope(
      openNode: (id) => _entry.currentState?.openNodeMenu(id),
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 76 + bottom),
              child: widget.child,
            ),
            Positioned(
              bottom: 12 + bottom,
              left: 0,
              right: 0,
              child: Center(
                child: AssistantLauncher(
                  key: _entry,
                  missionId: widget.missionId,
                  goalId: widget.goalId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AssistantLauncher extends StatefulWidget {
  const AssistantLauncher({
    super.key,
    this.missionId,
    this.goalId,
    this.nodeId,
    this.navigationRailWidth,
  });
  final String? missionId;
  final String? goalId;
  final String? nodeId;
  final double? navigationRailWidth;

  @override
  State<AssistantLauncher> createState() => AssistantLauncherState();
}

class AssistantLauncherState extends State<AssistantLauncher> {
  String? _selectedNodeId;

  void openNodeMenu(String id) {
    _selectedNodeId = id;
    _showMenu();
  }

  void resetContext() {
    _selectedNodeId = null;
    if (_recording) {
      unawaited(_scope?.voice.cancel());
      _recording = false;
    }
    _hide();
  }

  final _link = LayerLink();
  final _target = GlobalKey();
  final _portal = OverlayPortalController();
  bool _menu = false;
  bool _bubble = false;
  bool _opening = false;
  bool _recording = false;
  String? _bubbleSession;
  UserMessage? _sentMessage;
  bool _transitioning = false;
  int? _hover;
  AssistantScope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AssistantScope.of(context);
    if (_scope?.controller != scope.controller) {
      _scope?.controller.removeListener(_changed);
      scope.controller.addListener(_changed);
    }
    if (_scope?.voice != scope.voice) {
      _scope?.voice.removeListener(_changed);
      scope.voice.addListener(_changed);
    }
    _scope = scope;
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _prepare() async {
    final controller = _scope!.controller;
    await controller.initialize();
    final nodeId = _selectedNodeId ?? widget.nodeId;
    if (nodeId != null) {
      await controller.openNodeReference(nodeId);
    } else if (widget.missionId != null) {
      await controller.openMissionReference(widget.missionId!);
    } else if (widget.goalId != null) {
      await controller.openGoalReference(widget.goalId!);
    } else {
      await controller.openGlobalConversation();
    }
  }

  void _showMenu() {
    if (_opening || _transitioning) return;
    if (_bubble) {
      unawaited(_closeBubble());
      return;
    }
    setState(() {
      _menu = true;
      _hover = null;
    });
    _portal.show();
  }

  void _hide() {
    setState(() {
      _menu = false;
      _bubble = false;
      _hover = null;
    });
    _portal.hide();
  }

  Rect _safeBounds(BuildContext context) {
    final media = MediaQuery.of(context);
    return Rect.fromLTRB(
      media.padding.left + 12,
      media.padding.top + 12,
      media.size.width - media.padding.right - 12,
      media.size.height -
          math.max(media.viewInsets.bottom, media.padding.bottom) -
          12,
    );
  }

  Rect _anchor() {
    final box = _target.currentContext?.findRenderObject() as RenderBox?;
    return (box?.localToGlobal(Offset.zero) ?? Offset.zero) &
        (box?.size ?? const Size(56, 56));
  }

  List<Rect> _choices(BuildContext context) {
    final anchor = _anchor();
    final bounds = _safeBounds(context);
    final rail = widget.navigationRailWidth;
    final groupLeft =
        (rail == null
                ? anchor.center.dx - 80
                : rail + MediaQuery.paddingOf(context).left + 12)
            .clamp(bounds.left, math.max(bounds.left, bounds.right - 160));
    final top = (rail == null ? anchor.top - 92 : anchor.center.dy - 32).clamp(
      bounds.top,
      math.max(bounds.top, bounds.bottom - 64),
    );
    return [
      for (var index = 0; index < 2; index++)
        Rect.fromLTWH(
          (groupLeft + index * 96).toDouble(),
          top.toDouble(),
          64,
          64,
        ),
    ];
  }

  void _move(Offset position) {
    int? selected;
    final choices = _choices(context);
    for (var index = 0; index < choices.length; index++) {
      if ((position - choices[index].center).distance <= 36) selected = index;
    }
    if (_hover != selected) setState(() => _hover = selected);
  }

  Future<void> _select(int mode) async {
    if (_opening) return;
    _opening = true;
    try {
      await _prepare().timeout(const Duration(seconds: 5));
      _selectedNodeId = null;
      if (!mounted) return;
      _menu = false;
      _opening = false;
      _bubbleSession = _scope!.controller.currentSessionId;
      _sentMessage = null;
      if (mode == 0) {
        await _expand();
      } else {
        setState(() {
          _bubble = true;
          _recording = true;
        });
        _portal.show();
        unawaited(_scope!.voice.start());
      }
    } catch (error) {
      if (mounted) {
        _hide();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      _opening = false;
      if (mounted) setState(() {});
    }
  }

  void _preserveVoiceDraft() {
    final text = _scope!.voice.text.trim();
    if (!_recording || text.isEmpty) return;
    final controller = _scope!.controller;
    final existing = controller.draft.trimRight();
    controller.draft = existing.isEmpty ? text : '$existing\n$text';
  }

  Future<void> _closeBubble() async {
    if (_transitioning) return;
    _transitioning = true;
    _preserveVoiceDraft();
    _recording = false;
    _hide();
    await _scope!.voice.cancel();
    _transitioning = false;
  }

  Future<void> _expand() async {
    if (_transitioning) return;
    _transitioning = true;
    _preserveVoiceDraft();
    if (_recording) await _scope!.voice.cancel();
    _recording = false;
    if (!mounted) return;
    _hide();
    _transitioning = false;
    await showAssistantConversation(context);
  }

  Future<void> _sendVoice() async {
    final scope = _scope!;
    if (_transitioning ||
        !_recording ||
        scope.voice.busy ||
        scope.voice.listening ||
        scope.controller.isBusy) {
      return;
    }
    final text = scope.voice.text.trim();
    if (text.isEmpty) return;
    if (scope.controller.currentSessionId != _bubbleSession) {
      await _closeBubble();
      return;
    }
    if (!scope.controller.hasCredential) {
      await _expand();
      return;
    }
    FocusScope.of(context).unfocus();
    final message = UserMessage(text: text);
    setState(() {
      _recording = false;
      _sentMessage = message;
    });
    await scope.controller.sendMessage(message);
    if (mounted &&
        _bubble &&
        _sentMessage == message &&
        !scope.controller.transcript.any((item) => item.id == message.id)) {
      setState(() => _recording = true);
    }
  }

  @override
  void dispose() {
    _scope?.controller.removeListener(_changed);
    _scope?.voice.removeListener(_changed);
    if (_recording) unawaited(_scope?.voice.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope!;
    final controller = scope.controller;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final choices = _choices(context);
        final bounds = _safeBounds(context);
        final anchor = _anchor();
        return Stack(
          children: [
            if (_menu)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _hide,
                  behavior: HitTestBehavior.opaque,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            if (_menu)
              for (var index = 0; index < choices.length; index++)
                Positioned.fromRect(
                  rect: choices[index],
                  child: _modeBubble(index),
                ),
            if (_bubble && controller.currentSessionId == _bubbleSession)
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: _AssistantBubbleLayout(
                    anchor: anchor,
                    bounds: bounds,
                    railWidth: widget.navigationRailWidth,
                  ),
                  child: Material(
                    key: const Key('assistant-voice-bubble'),
                    elevation: 4,
                    shadowColor: Colors.black26,
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: _bubbleContent(),
                  ),
                ),
              ),
          ],
        );
      },
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _showMenu();
              return null;
            },
          ),
        },
        child: CompositedTransformTarget(
          link: _link,
          child: Semantics(
            label: 'AI 助手，长按后滑动选择文字或语音',
            excludeSemantics: true,
            button: true,
            onTap: _showMenu,
            child: GestureDetector(
              key: _target,
              onTap: _showMenu,
              onLongPressStart: (_) => _showMenu(),
              onLongPressMoveUpdate: (details) => _move(details.globalPosition),
              onLongPressEnd: (_) {
                final choice = _hover;
                if (choice != null) {
                  unawaited(_select(choice));
                }
              },
              child: Tooltip(
                triggerMode: TooltipTriggerMode.manual,
                message: '长按选择文字或语音',
                child: Container(
                  key: const Key('assistant-launcher'),
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _opening
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          scope.voice.listening && _recording
                              ? Icons.mic_rounded
                              : controller.isRunning
                              ? Icons.auto_awesome
                              : assistantAvatarIcon(controller.persona.avatar),
                          color: Colors.white,
                          size: 26,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeBubble(int index) => Semantics(
    button: true,
    label: index == 0 ? '文字对话' : '语音输入',
    child: Material(
      color: _hover == index ? AppColors.primarySoft : AppColors.card,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _select(index),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                index == 0 ? Icons.keyboard_outlined : Icons.mic_none,
                color: AppColors.primary,
                size: 22,
              ),
              Text(
                index == 0 ? '文字' : '语音',
                style: const TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _bubbleContent() {
    final controller = _scope!.controller;
    final voice = _scope!.voice;
    final transcript = controller.transcript;
    final start = transcript.indexWhere(
      (message) => message.id == _sentMessage?.id,
    );
    // 只读取本次发送以后的消息与操作，不能用整个会话的最后一条回复。
    final messages = start < 0
        ? <AssistantMessage>[]
        : transcript
              .skip(start + 1)
              .takeWhile((m) => m is! UserMessage)
              .whereType<AssistantMessage>()
              .toList();
    final callIds = messages
        .expand((m) => m.toolCalls)
        .map((c) => c.id)
        .toSet();
    final operations = controller.operations
        .where((o) => callIds.contains(o.callId))
        .toList();
    final waiting = operations.any(
      (o) => o.status == AssistantOperationStatus.waitingConfirmation,
    );
    final reply = messages
        .where((m) => m.text.trim().isNotEmpty)
        .map((m) => m.text)
        .join('\n\n');
    final streaming = start >= 0 && controller.activity.isRunning
        ? controller.activity.text
        : '';
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(
            children: [
              Icon(
                _recording
                    ? Icons.mic_none_rounded
                    : assistantAvatarIcon(controller.persona.avatar),
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _recording ? '语音输入' : controller.persona.name,
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: '展开同一对话',
                onPressed: _transitioning ? null : _expand,
                icon: const Icon(Icons.open_in_full, size: 18),
              ),
              IconButton(
                tooltip: '收起气泡',
                onPressed: _closeBubble,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            key: const Key('assistant-bubble-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_recording) ...[
                  AssistantVoiceStatus(voice: voice),
                  const SizedBox(height: 12),
                  if (voice.text.isNotEmpty ||
                      (!voice.busy && !voice.listening && voice.error == null))
                    AssistantVoiceDraft(voice: voice)
                  else if (voice.error == null)
                    Text(
                      voice.starting
                          ? '正在准备，请稍候。'
                          : voice.stopping
                          ? '录音已结束，识别完成后可以修改文字。'
                          : '说完后点击“结束录音”，检查文字后再发送。',
                      style: text.bodyMedium,
                    ),
                  if (voice.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      voice.error!,
                      style: text.bodyMedium?.copyWith(color: AppColors.error),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          await _closeBubble();
                          if (!mounted) return;
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AssistantSettingsPage(controller: controller),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.settings_voice_outlined,
                          size: 18,
                        ),
                        label: const Text('语音设置'),
                      ),
                    ),
                  ],
                  if (controller.errorMessage != null)
                    Text(
                      controller.errorMessage!,
                      style: text.bodySmall?.copyWith(color: AppColors.error),
                    ),
                ] else ...[
                  if (_sentMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '你说',
                            style: text.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _sentMessage!.text,
                            key: const Key('assistant-bubble-request'),
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (reply.isNotEmpty) AssistantMarkdown(text: reply),
                  if (streaming.isNotEmpty && streaming != reply) ...[
                    if (reply.isNotEmpty) const SizedBox(height: 8),
                    AssistantMarkdown(text: streaming),
                  ],
                  if (operations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('assistant-bubble-operations'),
                      onPressed: _expand,
                      icon: Icon(
                        waiting
                            ? Icons.fact_check_outlined
                            : Icons.receipt_long_outlined,
                        size: 18,
                      ),
                      label: Text(waiting ? '查看并确认操作' : '查看操作结果'),
                    ),
                  ],
                  if (controller.isRunning)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          if (!waiting)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          if (!waiting) const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              waiting ? '等待你确认，本次操作尚未执行' : '正在回复…',
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (controller.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      controller.errorMessage!,
                      style: text.bodyMedium?.copyWith(color: AppColors.error),
                    ),
                  ] else if (!controller.isRunning &&
                      reply.isEmpty &&
                      operations.isEmpty)
                    Text('本轮已结束，可展开对话查看详情。', style: text.bodyMedium),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (_recording) ...[
                TextButton(
                  onPressed: _transitioning ? null : _expand,
                  child: const Text('改用文字'),
                ),
                if (voice.listening)
                  FilledButton.icon(
                    key: const Key('assistant-voice-stop'),
                    onPressed: voice.stop,
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('结束录音'),
                  )
                else if (voice.busy)
                  TextButton(onPressed: voice.cancel, child: const Text('取消识别'))
                else ...[
                  IconButton.outlined(
                    tooltip: '重试语音',
                    onPressed: voice.start,
                    icon: const Icon(Icons.mic_none_rounded),
                  ),
                  FilledButton.icon(
                    key: const Key('assistant-voice-send'),
                    onPressed:
                        voice.text.trim().isEmpty ||
                            controller.isBusy ||
                            _transitioning
                        ? null
                        : _sendVoice,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    label: const Text('发送'),
                  ),
                ],
              ] else ...[
                TextButton(onPressed: _expand, child: const Text('展开对话')),
                if (controller.isRunning)
                  FilledButton.tonal(
                    onPressed: controller.stop,
                    child: const Text('停止回复'),
                  )
                else
                  FilledButton.tonal(
                    onPressed: controller.isBusy
                        ? null
                        : () {
                            setState(() => _recording = true);
                            unawaited(voice.start());
                          },
                    child: const Text('继续说'),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AssistantBubbleLayout extends SingleChildLayoutDelegate {
  _AssistantBubbleLayout({
    required this.anchor,
    required this.bounds,
    this.railWidth,
  });
  final Rect anchor;
  final Rect bounds;
  final double? railWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: math.min(400, bounds.width),
        maxWidth: math.min(400, bounds.width),
        maxHeight: math.max(0, math.min(560, bounds.height - 8)),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = railWidth == null
        ? anchor.center.dx - childSize.width / 2
        : bounds.left + railWidth!;
    final above = anchor.top - 12 - childSize.height;
    final top = railWidth == null
        ? above
        : anchor.center.dy - childSize.height / 2;
    return Offset(
      left.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - childSize.width),
      ),
      top.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_AssistantBubbleLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      bounds != oldDelegate.bounds ||
      railWidth != oldDelegate.railWidth;
}
