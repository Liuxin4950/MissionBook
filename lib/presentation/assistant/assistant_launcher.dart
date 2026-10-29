import 'dart:async';
import 'dart:math' as math;

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import 'assistant_operation_card.dart';
import 'assistant_scope.dart';

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
    if (_opening) return;
    if (_bubble) {
      if (_recording) unawaited(_scope!.voice.cancel());
      _recording = false;
      _hide();
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

  Future<void> _expand() async {
    String? draft;
    if (_recording) {
      await _scope!.voice.stop();
      draft = _scope!.voice.text;
      _recording = false;
    }
    if (!mounted) return;
    _hide();
    await showAssistantConversation(context, initialText: draft);
  }

  Future<void> _sendVoice() async {
    final scope = _scope!;
    await scope.voice.stop();
    if (!mounted) return;
    final text = scope.voice.text.trim();
    if (text.isEmpty) return;
    if (scope.controller.currentSessionId != _bubbleSession) {
      _hide();
      return;
    }
    if (!scope.controller.hasCredential) {
      await _expand();
      return;
    }
    setState(() => _recording = false);
    await scope.controller.send(text);
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
                      child: _bubbleContent(),
                    ),
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
                              : Icons.auto_awesome_outlined,
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
    final operation = controller.operations
        .where((item) => item.isWrite)
        .lastOrNull;
    final reply = controller.transcript
        .whereType<AssistantMessage>()
        .where((item) => item.text.trim().isNotEmpty)
        .lastOrNull
        ?.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (_recording) ...[
              Icon(
                voice.listening ? Icons.mic_rounded : Icons.circle,
                size: voice.listening ? 18 : 8,
                color: voice.error == null
                    ? AppColors.primary
                    : AppColors.error,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                _recording
                    ? (voice.starting
                          ? '正在准备语音…'
                          : voice.stopping
                          ? '正在结束录音…'
                          : voice.listening
                          ? '正在听…'
                          : voice.error != null
                          ? '语音暂不可用'
                          : '准备发送')
                    : controller.isRunning
                    ? '助手处理中…'
                    : '助手',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            IconButton(
              tooltip: '展开同一对话',
              onPressed: _expand,
              icon: const Icon(Icons.open_in_full, size: 18),
            ),
            IconButton(
              tooltip: '收起气泡',
              onPressed: () {
                if (_recording) {
                  unawaited(voice.cancel());
                  _recording = false;
                }
                _hide();
              },
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
        if (_recording) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 8, 20),
            child: Semantics(
              liveRegion: !voice.listening,
              child: Text(
                voice.text.isNotEmpty
                    ? voice.text
                    : voice.error ??
                          (voice.starting
                              ? '正在连接系统语音服务…'
                              : voice.listening
                              ? '说说你想调整什么…'
                              : '没有听清，可以再说一次'),
                key: const Key('assistant-voice-transcript'),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: voice.error != null && voice.text.isEmpty
                      ? AppColors.error
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (voice.error != null && voice.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                voice.error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          Row(
            children: [
              IconButton(
                tooltip: '改用文字',
                onPressed: _expand,
                icon: const Icon(Icons.keyboard_outlined),
              ),
              const Spacer(),
              IconButton.outlined(
                tooltip: voice.busy
                    ? '取消准备'
                    : voice.listening
                    ? '结束录音'
                    : '重试语音',
                onPressed: voice.busy
                    ? voice.cancel
                    : voice.listening
                    ? voice.stop
                    : () async {
                        await voice.cancel();
                        await voice.start();
                      },
                icon: Icon(
                  voice.busy || voice.listening
                      ? Icons.stop_rounded
                      : Icons.mic_none_rounded,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  foregroundColor: AppColors.onPrimary,
                  iconColor: AppColors.onPrimary,
                  backgroundColor: AppColors.primary,
                  disabledForegroundColor: AppColors.onDisabled,
                  disabledBackgroundColor: AppColors.disabled,
                ),
                key: const Key('assistant-voice-send'),
                onPressed:
                    voice.text.trim().isEmpty || voice.busy || controller.isBusy
                    ? null
                    : _sendVoice,
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                label: const Text('发送'),
              ),
            ],
          ),
        ] else ...[
          if (controller.lastUserInput != null)
            Text(
              controller.lastUserInput!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (operation != null)
            AssistantOperationCard(
              controller: controller,
              operation: operation,
              onOpenReference: (_, _) => _expand(),
            ),
          if (controller.activity.text.isNotEmpty || reply != null)
            Text(
              controller.activity.text.isNotEmpty
                  ? controller.activity.text
                  : reply!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          if (controller.errorMessage != null)
            Text(
              controller.errorMessage!,
              style: const TextStyle(color: AppColors.error),
            ),
          Wrap(
            spacing: 8,
            children: [
              if (controller.isRunning)
                TextButton(onPressed: controller.stop, child: const Text('停止')),
              TextButton(onPressed: _expand, child: const Text('展开对话')),
              if (!controller.isRunning)
                TextButton(
                  onPressed: () async {
                    setState(() => _recording = true);
                    await voice.start();
                  },
                  child: const Text('继续说'),
                ),
            ],
          ),
        ],
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
        minWidth: math.min(360, bounds.width),
        maxWidth: math.min(360, bounds.width),
        maxHeight: math.max(0, math.min(480, bounds.height * .72)),
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
