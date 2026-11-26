import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../application/assistant/assistant_settings.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/colors.dart';
import '../shared/assistant_avatar.dart';
import '../shared/assistant_markdown.dart';
import '../shared/assistant_output_scroll.dart';

part 'windows_overlay_chat.dart';

/// Renders the native desktop overlay with the main engine as its sole workspace.
void runWindowsAssistantOverlay() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Windows overlay isolate started');
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _WindowsOverlay(),
    ),
  );
}

const _channel = MethodChannel('mission_book/windows_overlay');
typedef _Fields = Map<Object?, Object?>;

_Fields _fields(Object? value) => value is Map ? Map.of(value) : {};
List<_Fields> _items(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) Map.of(item),
      ]
    : [];
String _text(_Fields fields, String key) => fields[key] as String? ?? '';
int _number(_Fields fields, String key) => fields[key] as int? ?? 0;

class _WindowsOverlay extends StatefulWidget {
  const _WindowsOverlay();

  @override
  State<_WindowsOverlay> createState() => _WindowsOverlayState();
}

class _WindowsOverlayState extends State<_WindowsOverlay> {
  // 与 Windows 原生边缘把手的逻辑高度对齐。
  static const _edgeHandleHeight = 42.0;

  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  _Fields _layout = {};
  _Fields _snapshot = {};
  _Fields _persona = {};
  _Fields _notice = {};
  String _motion = 'system';
  String _syncedDraft = '';
  String? _error;
  bool _working = false;
  bool _dragged = false;
  bool _followOutput = true;
  bool _hasNewOutput = false;
  bool _showJumpToLatest = false;
  String _outputVersion = '';
  final _readingPositions =
      <
        String,
        ({double offset, bool follow, bool hasNewOutput, String outputVersion})
      >{};
  bool _focusAfterLayout = false;
  bool _draftConflict = false;
  Timer? _draftTimer;
  Future<void>? _draftSaving;
  ({_Fields item, Uint8List bytes})? _preview;
  String get _key => _text(_snapshot, 'key');
  bool get _busy => _snapshot['busy'] == true;
  bool get _running => _snapshot['running'] == true;
  List<_Fields> get _images => _items(_snapshot['images']);
  bool get _hasChat =>
      _items(_layout['parts']).any((part) => part['id'] == 'chat');

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_receive);
    unawaited(_announce());
  }

  /// 原生宿主在创建窗口后才安装通道处理器；首条 ready 若早到会被丢弃。
  /// 收到成功回执才停止，避免悬浮球因一次握手失败永久不显示。
  Future<void> _announce() async {
    for (var attempt = 0; attempt < 50 && mounted; attempt++) {
      try {
        await _channel.invokeMethod<void>('ready');
        return;
      } on PlatformException {
        // 宿主尚未就绪，短暂等待后重试。
      } on MissingPluginException {
        // 宿主引擎仍在装配。
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _draftTimer?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _receive(MethodCall call) async {
    if (!mounted) return;
    final data = _fields(call.arguments);
    switch (call.method) {
      case 'layout':
        setState(() {
          _layout = data;
          if (!_hasChat) _preview = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_call('painted'));
          if (_hasChat) _restoreOutputPosition();
          if (_hasChat && _focusAfterLayout) {
            _focusAfterLayout = false;
            _inputFocus.requestFocus();
          }
        });
      case 'state':
        _acceptState(data);
      case 'persona':
        setState(() => _persona = data);
      case 'motion':
        setState(() => _motion = call.arguments as String? ?? 'system');
      case 'notice':
        setState(() => _notice = data);
      case 'error':
        setState(() => _error = call.arguments as String?);
      case 'reset':
        _draftTimer?.cancel();
        _readingPositions.clear();
        _outputVersion = '';
        _followOutput = true;
        _hasNewOutput = false;
        _showJumpToLatest = false;
        setState(() {
          _snapshot = {};
          _preview = null;
          _notice = {};
          _error = null;
          _syncedDraft = '';
          _draftConflict = false;
          _input.clear();
        });
    }
  }

  void _acceptState(_Fields data, {bool replaceDraft = false}) {
    if (!mounted || data['key'] is! String) return;
    if (_snapshot['generation'] == data['generation'] &&
        _number(data, 'revision') < _number(_snapshot, 'revision')) {
      return;
    }
    final changed =
        _key != data['key'] || _snapshot['generation'] != data['generation'];
    final outputVersion = _outputVersionFor(data);
    final reading = changed ? _readingPositions[_text(data, 'key')] : null;
    if (changed && _key.isNotEmpty && _scroll.hasClients) {
      _readingPositions[_key] = (
        offset: _scroll.offset,
        follow: _followOutput,
        hasNewOutput: _hasNewOutput,
        outputVersion: _outputVersion,
      );
    }
    var followOutput = changed ? reading?.follow ?? true : _followOutput;
    var hasNewOutput = changed ? reading?.hasNewOutput ?? false : _hasNewOutput;
    if (!followOutput &&
        ((changed &&
                reading != null &&
                reading.outputVersion != outputVersion) ||
            (!changed && _outputVersion != outputVersion))) {
      hasNewOutput = true;
    }
    final draft = _text(data, 'draft');
    setState(() {
      _snapshot = data;
      _followOutput = followOutput;
      _hasNewOutput = hasNewOutput;
      _showJumpToLatest = AssistantOutputScroll.shouldShowJumpToLatest(
        following: followOutput,
        hasNewOutput: hasNewOutput,
      );
      if (changed) {
        _draftTimer?.cancel();
        _preview = null;
        _error = null;
        _draftConflict = false;
      }
      if (changed || replaceDraft || _input.text == _syncedDraft) {
        if (_input.text != draft) {
          _input.value = TextEditingValue(
            text: draft,
            selection: TextSelection.collapsed(offset: draft.length),
          );
        }
        _draftConflict = false;
      } else if (draft != _syncedDraft &&
          draft != _input.text &&
          _draftSaving == null) {
        _draftConflict = true;
      }
      _syncedDraft = draft;
    });
    _outputVersion = outputVersion;
    if (_key.isNotEmpty) {
      final savedOffset = _readingPositions[_key]?.offset ?? 0;
      _readingPositions[_key] = (
        offset: changed
            ? reading?.offset ?? 0
            : _scroll.hasClients
            ? _scroll.offset
            : savedOffset,
        follow: _followOutput,
        hasNewOutput: _hasNewOutput,
        outputVersion: _outputVersion,
      );
    }
    if (changed || _followOutput) _restoreOutputPosition();
  }

  String _outputVersionFor(_Fields data) {
    final messages = _items(data['messages'])
        .map((message) {
          final text = _text(message, 'text');
          return '${_text(message, 'id')}:${message['user']}:${text.length}:${text.hashCode}:${_number(message, 'images')}';
        })
        .join('|');
    final operations = _items(data['operations'])
        .map((operation) {
          final preview = _text(operation, 'preview');
          final detail = _text(operation, 'detail');
          return '${_text(operation, 'id')}:${_text(operation, 'status')}:${preview.length}:${preview.hashCode}:${detail.length}:${detail.hashCode}';
        })
        .join('|');
    final partial = _text(data, 'partial');
    final error = _text(data, 'error');
    return '$messages/$operations/${partial.length}:${partial.hashCode}/${error.length}:${error.hashCode}';
  }

  void _restoreOutputPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasChat || !_scroll.hasClients) return;
      final reading = _readingPositions[_key];
      final double? target = _followOutput
          ? _scroll.position.minScrollExtent
          : reading == null
          ? null
          : reading.offset
                .clamp(
                  _scroll.position.minScrollExtent,
                  _scroll.position.maxScrollExtent,
                )
                .toDouble();
      if (target != null && (_scroll.offset - target).abs() > 0.5) {
        _scroll.jumpTo(target);
      }
    });
  }

  void _jumpToLatest() {
    if (!mounted) return;
    setState(() {
      _followOutput = true;
      _hasNewOutput = false;
      _showJumpToLatest = false;
    });
    if (_key.isNotEmpty) {
      _readingPositions[_key] = (
        offset: _scroll.hasClients ? _scroll.position.minScrollExtent : 0,
        follow: true,
        hasNewOutput: false,
        outputVersion: _outputVersion,
      );
    }
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.minScrollExtent,
        duration: AppMotion.quick,
        curve: AppMotion.curve,
      );
    }
  }

  Future<void> _call(String name, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(name, args);
    } on PlatformException catch (error) {
      if (mounted && error.code != 'overlay_inactive') {
        setState(() => _error = error.message ?? '桌面悬浮球操作未完成');
      }
    }
  }

  Future<Object?> _workspace(
    String method, [
    Map<String, Object?> data = const {},
  ]) => _channel.invokeMethod<Object?>('workspace', {
    'method': method,
    'args': {'key': _key, ...data},
  });

  void _showPreview(({_Fields item, Uint8List bytes})? preview) {
    if (mounted && _hasChat) setState(() => _preview = preview);
  }

  void _setError(String message) {
    if (mounted) setState(() => _error = message);
  }

  void _edited(String _) {
    setState(() {});
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 150), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (_draftSaving case final pending?) await pending;
    if (!mounted ||
        _key.isEmpty ||
        _input.text == _syncedDraft ||
        _draftConflict) {
      return;
    }
    final key = _key;
    final text = _input.text;
    final previous = _syncedDraft;
    final write = () async {
      try {
        final response = await _workspace('draft', {
          'previous': previous,
          'text': text,
        });
        if (!mounted || _key != key) return;
        if (response is Map) {
          _acceptState(_fields(response));
        } else {
          _syncedDraft = text;
        }
      } on PlatformException catch (error) {
        if (mounted && _key == key) {
          setState(() {
            _draftConflict = true;
            _error = error.message;
          });
        }
      }
    }();
    _draftSaving = write;
    await write;
    if (identical(_draftSaving, write)) _draftSaving = null;
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? '助手操作未完成');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _action(String method, [Map<String, Object?> args = const {}]) =>
      _perform(() async {
        _acceptState(_fields(await _workspace(method, args)));
      });

  Future<void> _mode(String mode, {bool focus = false}) async {
    _focusAfterLayout = focus;
    if (mode != 'chat') _startVoiceWhenReady = false;
    if (mode != 'chat') {
      _draftTimer?.cancel();
      await _saveDraft();
      if (!mounted) return;
      _inputFocus.unfocus();
    }
    await _call('mode', {'value': mode, 'focus': focus});
  }

  Future<void> _openMain({String? missionId, String? recordId}) async {
    await _saveDraft();
    if (mounted) {
      await _call('openMain', {'missionId': missionId, 'recordId': recordId});
    }
  }

  Future<void> _openVoice() async {
    await _mode('chat');
    // Wait for the first workspace snapshot before addressing its draft.
    if (!mounted) return;
    if (_key.isEmpty || _snapshot['compact'] == true) {
      _startVoiceWhenReady = true;
    } else {
      await _startVoice();
    }
  }

  bool _startVoiceWhenReady = false;
  Future<void> _startVoice() => _perform(() async {
    _inputFocus.unfocus();
    await _saveDraft();
    if (!mounted) return;
    _acceptState(_fields(await _workspace('voiceStart')));
  });

  Future<void> _capture() async {
    await _saveDraft();
    if (mounted) await _call('capture');
  }

  Future<void> _openNotice() => _perform(() async {
    final id = _text(_notice, 'sessionId');
    if (id.isEmpty) return;
    await _saveDraft();
    if (!mounted) return;
    _acceptState(_fields(await _workspace('openNotice', {'sessionId': id})));
    await _mode('chat', focus: true);
  });

  Widget _part(String id) => switch (id) {
    'ball' => _ball(),
    'badge' => _badge(),
    'handle' => _handle(),
    'chat' => _WindowsOverlayChat(host: this),
    'notice' => _noticeCard(),
    'text' => _tool(
      '文字',
      Icons.chat_bubble_outline_rounded,
      () => _mode('chat', focus: true),
      0,
    ),
    'voice' => _tool('语音', Icons.mic_none_rounded, _openVoice, 1),
    'capture' => _tool('截图', Icons.screenshot_monitor_outlined, _capture, 2),
    'more' => _tool('更多', Icons.more_horiz_rounded, () => _mode('more'), 3),
    'main' => _tool('会话', Icons.open_in_new_rounded, () => _openMain(), 0),
    'usage' => _tool(
      '感知',
      Icons.explore_outlined,
      () => _call('usage'),
      1,
      selected: _layout['usage'] == true,
      tooltip: _layout['usage'] == true ? '关闭应用感知' : '开启应用感知',
    ),
    'close' => _tool(
      '关闭',
      Icons.close_rounded,
      () => _call('closeOverlay'),
      2,
      tooltip: '关闭悬浮球',
    ),
    'back' => _tool('返回', Icons.arrow_back_rounded, () => _mode('tools'), 3),
    _ => const SizedBox.shrink(),
  };

  Widget _avatar(double size) {
    final avatar = _text(_persona, 'avatar');
    return AssistantPersonaAvatar(
      avatar: AssistantAvatar.values.firstWhere(
        (item) => item.name == avatar,
        orElse: () => AssistantAvatar.spark,
      ),
      customAvatarBase64: _persona['customAvatarBase64'] as String?,
      color: AppColors.onPrimary,
      size: size,
    );
  }

  Widget _ball() => MouseRegion(
    cursor: SystemMouseCursors.grab,
    child: GestureDetector(
      onPanDown: (_) {
        _dragged = false;
        unawaited(_call('dragStart'));
      },
      onPanUpdate: (_) {
        _dragged = true;
        unawaited(_call('dragMove'));
      },
      onPanEnd: (_) => unawaited(_call('dragEnd')),
      onPanCancel: () {
        if (_dragged) unawaited(_call('dragEnd', {'cancel': true}));
      },
      child: Material(
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        color: AppColors.primary,
        child: Semantics(
          label: '书祺助手，拖动到侧边收起',
          button: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _mode(
              _items(_layout['parts']).any(
                    (part) =>
                        part['id'] == 'text' ||
                        part['id'] == 'main' ||
                        part['id'] == 'chat',
                  )
                  ? 'closed'
                  : 'tools',
            ),
            child: LayoutBuilder(
              builder: (_, box) => _avatar(box.biggest.shortestSide),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _badge() => Material(
    color: AppColors.primarySoft,
    borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
    child: InkWell(
      onTap: () => _mode('chat', focus: true),
      child: Semantics(
        label: '${_images.length} 张待发送图片',
        button: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppMetrics.spaceXs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.image_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  '${_images.length}',
                  style: AppTypography.calendarLabel.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _handle() => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Semantics(
      label: '展开书祺悬浮球',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _call('reveal'),
        onHorizontalDragStart: (_) => unawaited(_call('dragStart')),
        onHorizontalDragUpdate: (_) => unawaited(_call('dragMove')),
        onHorizontalDragEnd: (_) => unawaited(_call('dragEnd')),
        child: Align(
          alignment: _layout['dock'] == -1
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: Container(
            width: AppMetrics.spaceXs,
            height: _edgeHandleHeight,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppMetrics.radiusXs),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _tool(
    String label,
    IconData icon,
    VoidCallback open,
    int index, {
    bool selected = false,
    String? tooltip,
  }) => Builder(
    builder: (context) {
      final duration = AppMotion.resolve(context, AppMotion.quick);
      return Material(
        color: selected ? AppColors.primarySoft : AppColors.card,
        shape: const CircleBorder(side: BorderSide(color: AppColors.hairline)),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          label: tooltip ?? label,
          button: true,
          selected: selected,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: open,
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: duration == Duration.zero ? 1.0 : 0.0,
                end: 1,
              ),
              duration: duration == Duration.zero
                  ? duration
                  : duration + Duration(milliseconds: 24 * index),
              curve: AppMotion.curve,
              builder: (_, value, child) => Transform.scale(
                scale: .62 + value * .38,
                child: Opacity(opacity: value, child: child),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(AppMetrics.spaceXs),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: AppColors.primary,
                          size: AppMetrics.iconMd,
                        ),
                        Text(
                          label,
                          style: AppTypography.calendarLabel.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _noticeCard() => Material(
    color: AppColors.card,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.spaceMd,
        vertical: AppMetrics.spaceXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _text(_notice, 'message'),
                style: AppTypography.itemTitle,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _working
                    ? null
                    : () => _action('dismissNotice', {'later': true}),
                child: const Text('稍后'),
              ),
              TextButton(
                onPressed: _working ? null : _openNotice,
                child: const Text('回复'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduced =
        _motion == 'reduced' ||
        (_motion == 'system' && media.disableAnimations);
    if (_hasChat &&
        _startVoiceWhenReady &&
        _key.isNotEmpty &&
        _snapshot['compact'] != true) {
      _startVoiceWhenReady = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hasChat) unawaited(_startVoice());
      });
    }
    return MediaQuery(
      data: media.copyWith(disableAnimations: reduced),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_preview != null) {
              setState(() => _preview = null);
            } else {
              unawaited(_mode('closed'));
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            // Flutter paints the control surfaces; Win32 clips the space between them.
            backgroundColor: _number(_layout, 'dock') == 0
                ? AppColors.card
                : Colors.transparent,
            body: LayoutBuilder(
              builder: (context, box) {
                final nativeWidth = _number(_layout, 'w');
                final nativeHeight = _number(_layout, 'h');
                if (nativeWidth <= 0 || nativeHeight <= 0) {
                  return const SizedBox.shrink();
                }
                final xScale = box.maxWidth / nativeWidth;
                final yScale = box.maxHeight / nativeHeight;
                return Stack(
                  children: [
                    for (final part in _items(_layout['parts']))
                      Positioned(
                        key: ValueKey(_text(part, 'id')),
                        left: _number(part, 'x') * xScale,
                        top: _number(part, 'y') * yScale,
                        width: _number(part, 'w') * xScale,
                        height: _number(part, 'h') * yScale,
                        child: _part(_text(part, 'id')),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
