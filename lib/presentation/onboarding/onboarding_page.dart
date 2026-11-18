import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/app_typography.dart';
import 'onboarding_scene.dart';

/// 用同一块连续画布介绍今天、目标与助手，只持久化完成标记。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinish});

  /// 保存成功后才离开；重看引导时由调用方关闭当前路由。
  final Future<bool> Function() onFinish;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final _progress = AnimationController(
    vsync: this,
    upperBound: 2,
    duration: AppMotion.storyTransition,
  )..addListener(_updateStep);
  var _page = 0;
  var _destination = 0;
  var _saving = false;
  var _reduceMotion = false;
  var _dragStart = 0.0;
  var _dragDistance = 0.0;
  String? _error;

  static const _steps = [
    (
      label: '今天',
      title: '今天，先走一步',
      description: '安排、开始，都在「今天」。',
      imageLabel: '操作示意：从今天的任务卡片开始一次二十分钟的阅读',
    ),
    (
      label: '目标',
      title: '大目标，拆小一点',
      description: '拆成小任务，知道下一步做什么。',
      imageLabel: '操作示意：读完一本书的目标，沿路径拆成第一章和今天阅读的小任务',
    ),
    (
      label: '助手',
      title: '有想法，交给书栖',
      description: '说说想法，一起理清下一步。',
      imageLabel: '操作示意：把阅读想法交给书栖助手，再整理为可执行的下一步',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion && _progress.isAnimating) {
      _progress.stop();
      _progress.value = _destination.toDouble();
    }
  }

  void _updateStep() {
    final page = _progress.value.round();
    if (page != _page) setState(() => _page = page);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    _progress.stop();
    setState(() {
      _saving = true;
      _error = null;
    });
    bool completed;
    try {
      completed = await widget.onFinish();
    } catch (_) {
      completed = false;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!completed) _error = '暂时没能保存，请再试一次。';
    });
  }

  void _goTo(int page) {
    if (_saving) return;
    _destination = page.clamp(0, _steps.length - 1);
    final target = _destination.toDouble();
    if (_reduceMotion) {
      _progress.value = target;
    } else {
      _progress.animateTo(
        target,
        duration: AppMotion.storyTransition,
        curve: AppMotion.curve,
      );
    }
  }

  void _next() {
    if (_saving || _progress.isAnimating) return;
    if (_page == _steps.length - 1) {
      _finish();
    } else {
      _goTo(_page + 1);
    }
  }

  void _dragUpdate(DragUpdateDetails details, double extent) {
    if (_saving) return;
    _dragDistance += details.delta.dx;
    if (!_reduceMotion) {
      _progress.value = (_dragStart - _dragDistance / extent).clamp(0, 2);
    }
  }

  void _dragEnd(DragEndDetails details, double extent) {
    if (_saving) return;
    final value = (_dragStart - _dragDistance / extent).clamp(0.0, 2.0);
    final velocity = details.primaryVelocity ?? 0;
    final target = velocity.abs() > 250
        ? (velocity < 0 ? value.floor() + 1 : value.ceil() - 1)
        : value.round();
    _goTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _goTo(_page + 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _goTo(_page - 1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(16) / 16;
                    final inlineControls =
                        constraints.maxWidth >= 600 &&
                        constraints.maxHeight >= 560 &&
                        scale < 1.7;
                    return Column(
                      children: [
                        _header(),
                        Expanded(
                          child: _body(
                            context,
                            inlineControls: inlineControls,
                            sideBySide:
                                inlineControls &&
                                constraints.maxWidth >= 960 &&
                                constraints.maxWidth >=
                                    constraints.maxHeight * 1.05,
                          ),
                        ),
                        if (!inlineControls) _footer(context),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
    child: Row(
      children: [
        Image.asset(
          'assets/branding/mission_book_logo_v4.png',
          width: 26,
          height: 26,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: AppLayout.spaceSm),
        const Expanded(child: Text('MissionBook')),
        TextButton(
          key: const Key('onboarding-skip'),
          onPressed: _saving ? null : _finish,
          child: const Text('跳过'),
        ),
      ],
    ),
  );

  Widget _body(
    BuildContext context, {
    required bool inlineControls,
    required bool sideBySide,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final scroll =
            !sideBySide && (constraints.maxHeight < 440 || textScale >= 1.7);
        final scene = Semantics(
          key: const Key('onboarding-artwork'),
          container: true,
          image: true,
          label: _steps[_page].imageLabel,
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => OnboardingScene(
                  progress: _progress.value,
                  expanded: inlineControls,
                ),
              ),
            ),
          ),
        );
        final words = _words(context, sideBySide);
        final Widget content;
        if (sideBySide) {
          content = Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 32, 40),
            child: Row(
              key: const Key('onboarding-two-columns'),
              children: [
                Expanded(
                  flex: 6,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 500,
                        maxHeight: 460,
                      ),
                      child: scene,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        words,
                        const SizedBox(height: 24),
                        _footer(context, inline: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else if (inlineControls) {
          content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 360, child: scene),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: words,
                    ),
                    const SizedBox(height: 20),
                    _footer(context),
                  ],
                ),
              ),
            ),
          );
        } else if (scroll) {
          content = SingleChildScrollView(
            key: const Key('onboarding-scroll'),
            child: Column(
              children: [
                SizedBox(
                  height: math.min(constraints.maxWidth * .94, 330),
                  child: scene,
                ),
                words,
                const SizedBox(height: 16),
              ],
            ),
          );
        } else {
          content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: scene,
                ),
              ),
              words,
              const SizedBox(height: 16),
            ],
          );
        }
        // 整个内容区接收横向手势，短屏仍由内部滚动区处理纵向滚动。
        return GestureDetector(
          key: const Key('onboarding-pages'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _saving
              ? null
              : (_) {
                  _progress.stop();
                  _dragStart = _progress.value;
                  _dragDistance = 0;
                },
          onHorizontalDragUpdate: (details) =>
              _dragUpdate(details, constraints.maxWidth),
          onHorizontalDragEnd: (details) =>
              _dragEnd(details, constraints.maxWidth),
          onHorizontalDragCancel: () => _goTo(_progress.value.round()),
          child: content,
        );
      },
    );
  }

  Widget _words(BuildContext context, bool wide) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 28, vertical: 12),
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => Stack(
          alignment: wide ? Alignment.centerLeft : Alignment.center,
          children: [
            for (var i = 0; i < _steps.length; i++)
              ExcludeSemantics(
                excluding: i != _page,
                child: Opacity(
                  // 文字先退后进，避免过渡中两段文字叠在一起。
                  opacity: (1 - (_progress.value - i).abs() * 2).clamp(0, 1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: wide
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      Text(
                        _steps[i].title,
                        textAlign: wide ? TextAlign.left : TextAlign.center,
                        style: AppTypography.pageTitle,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _steps[i].description,
                        textAlign: wide ? TextAlign.left : TextAlign.center,
                        style: text.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, {bool inline = false}) {
    return Padding(
      padding: inline
          ? const EdgeInsets.symmetric(horizontal: 16)
          : const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == _page,
                        label: '第 ${i + 1} 步，共 3 步',
                        child: TextButton(
                          key: Key('onboarding-indicator-$i'),
                          onPressed: _saving ? null : () => _goTo(i),
                          style: TextButton.styleFrom(
                            foregroundColor: i == _page
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_steps[i].label),
                              const SizedBox(height: 5),
                              AnimatedContainer(
                                duration: AppMotion.resolve(
                                  context,
                                  AppMotion.quick,
                                ),
                                width: i == _page ? 20 : 4,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: i == _page
                                      ? AppColors.primary
                                      : AppColors.hairline,
                                  borderRadius: BorderRadius.circular(
                                    AppLayout.radiusXs,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_page > 0) ...[
                    IconButton.outlined(
                      key: const Key('onboarding-back'),
                      tooltip: '上一步',
                      onPressed: _saving ? null : () => _goTo(_page - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      key: const Key('onboarding-next'),
                      onPressed: _saving ? null : _next,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_page == 2 ? '开始使用' : '下一步'),
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
