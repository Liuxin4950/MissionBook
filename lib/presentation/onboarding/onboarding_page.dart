import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/colors.dart';

/// 首次体验只介绍产品的核心路径，不在用户还没有上下文时申请系统权限。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinish});

  /// 返回 true 表示引导状态已经成功持久化，页面才会交给主工作区。
  final Future<bool> Function() onFinish;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  var _page = 0;
  var _saving = false;
  String? _error;

  static const _steps = <_OnboardingStepData>[
    _OnboardingStepData(
      eyebrow: '第一步 · 今天',
      title: '先从今天开始，不必先学会一切',
      description: '今天页把安排、执行和待补材料放在一起。选一个下一步，开始一次真实行动。',
      asset: 'assets/illustrations/day-plan.png',
      imageLabel: '一本打开的日程本和书签',
    ),
    _OnboardingStepData(
      eyebrow: '第二步 · 目标',
      title: '把目标写成可以走的路径',
      description: '目标可以拆成节点，再变成任务；每一次完成都能留下记录和材料，而不是只留下一个愿望。',
      asset: 'assets/illustrations/goal-path.png',
      imageLabel: '从书页上向上延伸的目标路径',
    ),
    _OnboardingStepData(
      eyebrow: '第三步 · 助手',
      title: '需要时，让助手帮你整理',
      description: '文字、语音、拍照和截屏都可以进入同一条会话。先保留草稿，再决定是否发送或写回任务。',
      asset: 'assets/illustrations/assistant-notebook.png',
      imageLabel: '带有便签和助手符号的笔记本',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final completed = await widget.onFinish();
    if (!mounted) return;
    if (completed) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    setState(() {
      _saving = false;
      _error = '引导状态暂时没有保存成功，请重试。';
    });
  }

  void _next() {
    if (_page == _steps.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: AppMotion.resolve(context, AppMotion.navigation),
      curve: AppMotion.curve,
    );
  }

  void _skip() => _finish();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? AppLayout.space3Xl : AppLayout.spaceLg,
                        AppLayout.spaceMd,
                        wide ? AppLayout.space3Xl : AppLayout.spaceLg,
                        AppLayout.spaceSm,
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/branding/mission_book_logo_v4.png',
                            width: 28,
                            height: 28,
                            semanticLabel: 'MissionBook 标识',
                          ),
                          const SizedBox(width: AppLayout.spaceSm),
                          Text('MissionBook', style: AppTypography.itemTitle),
                          const Spacer(),
                          TextButton(
                            key: const Key('onboarding-skip'),
                            onPressed: _saving ? null : _skip,
                            child: const Text('跳过'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        key: const Key('onboarding-pages'),
                        controller: _pageController,
                        itemCount: _steps.length,
                        onPageChanged: (value) {
                          if (mounted) setState(() => _page = value);
                        },
                        itemBuilder: (context, index) => _StepView(
                          data: _steps[index],
                          wide: wide,
                          reduceMotion: reduceMotion,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? AppLayout.space3Xl : AppLayout.spaceLg,
                        AppLayout.spaceSm,
                        wide ? AppLayout.space3Xl : AppLayout.spaceLg,
                        AppLayout.spaceLg,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (
                                var index = 0;
                                index < _steps.length;
                                index++
                              )
                                AnimatedContainer(
                                  key: Key('onboarding-indicator-$index'),
                                  duration: AppMotion.resolve(
                                    context,
                                    AppMotion.quick,
                                  ),
                                  curve: AppMotion.curve,
                                  width: index == _page ? 24 : 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: AppLayout.spaceXs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index == _page
                                        ? AppColors.primary
                                        : AppColors.hairline,
                                    borderRadius: BorderRadius.circular(
                                      AppLayout.radiusPill,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppLayout.spaceSm),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppLayout.spaceMd),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const Key('onboarding-next'),
                              onPressed: _saving ? null : _next,
                              child: _saving
                                  ? const SizedBox(
                                      width: AppLayout.iconMd,
                                      height: AppLayout.iconMd,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.onPrimary,
                                      ),
                                    )
                                  : Text(
                                      _page == _steps.length - 1
                                          ? '开始使用'
                                          : '下一步',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingStepData {
  const _OnboardingStepData({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.asset,
    required this.imageLabel,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String asset;
  final String imageLabel;
}

class _StepView extends StatelessWidget {
  const _StepView({
    required this.data,
    required this.wide,
    required this.reduceMotion,
  });

  final _OnboardingStepData data;
  final bool wide;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final image = _OnboardingImage(
      asset: data.asset,
      label: data.imageLabel,
      reduceMotion: reduceMotion,
    );
    final words = Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? AppLayout.space3Xl : AppLayout.spaceLg,
        wide ? AppLayout.space3Xl : AppLayout.spaceXl,
        wide ? AppLayout.space3Xl : AppLayout.spaceLg,
        wide ? AppLayout.space3Xl : AppLayout.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            data.eyebrow,
            style: text.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppLayout.spaceMd),
          Text(data.title, style: text.headlineSmall),
          const SizedBox(height: AppLayout.spaceMd),
          Text(data.description, style: text.bodyLarge),
        ],
      ),
    );
    final content = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 10, child: image),
              Expanded(flex: 9, child: words),
            ],
          )
        : Column(
            children: [
              Expanded(flex: 6, child: image),
              Expanded(flex: 5, child: words),
            ],
          );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? AppLayout.space3Xl : AppLayout.spaceSm,
        vertical: AppLayout.spaceSm,
      ),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}

class _OnboardingImage extends StatelessWidget {
  const _OnboardingImage({
    required this.asset,
    required this.label,
    required this.reduceMotion,
  });

  final String asset;
  final String label;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final duration = reduceMotion ? Duration.zero : AppMotion.entrance;
    return Semantics(
      image: true,
      label: label,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .94, end: 1),
        duration: duration,
        curve: AppMotion.curve,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: ColoredBox(
          color: AppColors.accentSoft,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppLayout.spaceXl),
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                cacheWidth: 960,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
