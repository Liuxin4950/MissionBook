import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../shared/mission_execution_display.dart';
import '../../../core/theme/app_layout.dart';

/// 暂停前可选填原因；取消返回 null，留空确认返回空字符串。
class ExecutionPauseDialog extends StatefulWidget {
  const ExecutionPauseDialog({super.key});

  static Future<String?> show(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => const ExecutionPauseDialog(),
  );

  @override
  State<ExecutionPauseDialog> createState() => _ExecutionPauseDialogState();
}

class _ExecutionPauseDialogState extends State<ExecutionPauseDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.card,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(AppLayout.spaceXxl),
    constraints: const BoxConstraints(maxWidth: 360),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppLayout.spaceXxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('暂停任务', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppLayout.spaceMd),
          const Text('需要记录暂停原因吗？可选填，确认后暂停计时。'),
          const SizedBox(height: AppLayout.spaceLg),
          TextField(
            key: const Key('pause-reason'),
            controller: _reason,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '暂停原因（选填）'),
          ),
          const SizedBox(height: AppLayout.spaceXxl),
          MissionActionPair(
            primary: OutlinedButton(
              key: const Key('pause-cancel'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('继续专注', textAlign: TextAlign.center),
            ),
            secondary: FilledButton(
              key: const Key('pause-confirm'),
              onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
              child: const Text('确认暂停', textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 空间足够时并排，窄屏或大字体时纵向；按钮按内容增高，不截断中文。
class MissionActionPair extends StatelessWidget {
  const MissionActionPair({
    super.key,
    required this.primary,
    required this.secondary,
  });
  final Widget primary;
  final Widget secondary;
  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(0, AppLayout.actionMinHeight),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusLg),
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppLayout.spaceLg,
          vertical: AppLayout.spaceMd,
        ),
      ),
    );
    return FilledButtonTheme(
      data: FilledButtonThemeData(style: style),
      child: OutlinedButtonTheme(
        data: OutlinedButtonThemeData(style: style),
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            if (box.maxWidth < 300 * scale) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  primary,
                  const SizedBox(height: AppLayout.spaceSm),
                  secondary,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: primary),
                const SizedBox(width: AppLayout.spaceMd),
                Expanded(child: secondary),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ExecutionFocusRing extends StatelessWidget {
  const ExecutionFocusRing({
    super.key,
    required this.focus,
    required this.budgetMinutes,
    this.paused = false,
  });
  final Duration focus;
  final int budgetMinutes;
  final bool paused; // 使用已保存的阶段显示暂停，不从计时进度猜测状态。
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = math.min(box.maxWidth, 300.0);
      final progress =
          (focus.inMilliseconds /
                  Duration(minutes: budgetMinutes).inMilliseconds)
              .clamp(0.0, 1.0);
      return Center(
        child: Semantics(
          label: '专注时长 ${executionDuration(focus)}',
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              key: const Key('execution-ring'),
              painter: _FocusPainter(progress),
              child: Center(
                child: SizedBox(
                  width: size * .72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        paused ? '已暂停' : '正在专注',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppLayout.spaceSm),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          focusDuration(focus),
                          key: const Key('execution-focus'),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                      const SizedBox(height: AppLayout.spaceSm),
                      // 将数值和单位作为整体换行，双倍字号下不留下单独的“钟”。
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            '当前额度',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '$budgetMinutes 分钟',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _FocusPainter extends CustomPainter {
  const _FocusPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, paint..color = AppColors.hairline);
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(_FocusPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
