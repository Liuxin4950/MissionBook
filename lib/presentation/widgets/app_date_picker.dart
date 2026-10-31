import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/app_layout.dart';
import 'adaptive_sheet.dart';

/// 在手机使用底部弹层，较宽窗口使用居中对话框；确认后才返回日期。
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime currentDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required String title,
}) => showAdaptiveSheet<DateTime>(
  context: context,
  backgroundColor: AppColors.card,
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      bottom: AppLayout.windowClassOf(sheetContext) == WindowClass.compact
          ? MediaQuery.viewInsetsOf(sheetContext).bottom +
                MediaQuery.paddingOf(sheetContext).bottom
          : 0,
    ),
    child: _DatePickerContent(
      initialDate: initialDate,
      currentDate: currentDate,
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
    ),
  ),
);

/// 统一限制日历宽度并取整，避免宽屏间距过大及长日期范围的滚动精度问题。
class AppCalendar extends StatelessWidget {
  const AppCalendar({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
    this.currentDate,
  });
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? currentDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: constraints.maxWidth.clamp(0.0, 420.0).floorToDouble(),
        child: CalendarDatePicker(
          initialDate: initialDate,
          currentDate: currentDate,
          firstDate: firstDate,
          lastDate: lastDate,
          onDateChanged: onDateChanged,
        ),
      ),
    ),
  );
}

class _DatePickerContent extends StatefulWidget {
  const _DatePickerContent({
    required this.initialDate,
    required this.currentDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });
  final DateTime initialDate, currentDate, firstDate, lastDate;
  final String title;
  @override
  State<_DatePickerContent> createState() => _DatePickerContentState();
}

class _DatePickerContentState extends State<_DatePickerContent> {
  late DateTime _selected = DateUtils.dateOnly(widget.initialDate);
  late final _input = TextEditingController();
  int _calendarRevision = 0;
  bool _typing = false;
  String? _inputError;

  bool _allowed(DateTime date) =>
      !date.isBefore(DateUtils.dateOnly(widget.firstDate)) &&
      !date.isAfter(DateUtils.dateOnly(widget.lastDate));

  void _choose(DateTime date) {
    setState(() {
      _selected = DateUtils.dateOnly(date);
      _calendarRevision++; // 快捷选择也同步切换日历所在月份。
    });
  }

  void _confirm() {
    if (_typing) {
      final match = RegExp(
        r'^(\d{1,4})-(\d{1,2})-(\d{1,2})$',
      ).firstMatch(_input.text.trim());
      DateTime? date;
      if (match != null) {
        final year = int.parse(match[1]!);
        final month = int.parse(match[2]!);
        final day = int.parse(match[3]!);
        final candidate = DateTime(year, month, day);
        if (candidate.year == year &&
            candidate.month == month &&
            candidate.day == day &&
            _allowed(candidate)) {
          date = candidate;
        }
      }
      if (date == null) {
        setState(() => _inputError = '请输入范围内的有效日期，例如 2026-10-27');
        return;
      }
      Navigator.pop(context, date);
      return;
    }
    Navigator.pop(context, _selected);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = DateUtils.dateOnly(widget.currentDate);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight:
            (MediaQuery.sizeOf(context).height -
                (AppLayout.windowClassOf(context) == WindowClass.compact
                    ? MediaQuery.viewInsetsOf(context).bottom
                    : 0)) *
            .85,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppLayout.spaceXl,
          AppLayout.spaceXl,
          AppLayout.spaceXl,
          AppLayout.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.title, style: text.titleLarge),
                    const SizedBox(height: AppLayout.spaceSm),
                    Text(
                      '${_selected.year}年${_selected.month}月${_selected.day}日',
                      key: const Key('app-date-selected'),
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: AppLayout.spaceMd),
                    Wrap(
                      spacing: AppLayout.spaceSm,
                      runSpacing: AppLayout.spaceXs,
                      children: [
                        OutlinedButton(
                          key: const Key('app-date-today'),
                          onPressed: _allowed(today)
                              ? () {
                                  setState(() => _typing = false);
                                  _choose(today);
                                }
                              : null,
                          child: const Text('今天'),
                        ),
                        OutlinedButton(
                          key: const Key('app-date-tomorrow'),
                          onPressed: _allowed(tomorrow)
                              ? () {
                                  setState(() => _typing = false);
                                  _choose(tomorrow);
                                }
                              : null,
                          child: const Text('明天'),
                        ),
                        TextButton.icon(
                          key: const Key('app-date-input-toggle'),
                          onPressed: () => setState(() {
                            _typing = !_typing;
                            _inputError = null;
                            _input.text =
                                '${_selected.year.toString().padLeft(4, '0')}-${_selected.month.toString().padLeft(2, '0')}-${_selected.day.toString().padLeft(2, '0')}';
                          }),
                          icon: Icon(
                            _typing
                                ? Icons.calendar_month_outlined
                                : Icons.edit_outlined,
                            size: AppLayout.iconSm,
                          ),
                          label: Text(_typing ? '选择日历' : '输入日期'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceXs),
                    if (_typing)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppLayout.spaceLg,
                        ),
                        child: TextField(
                          key: const Key('app-date-input'),
                          controller: _input,
                          keyboardType: TextInputType.datetime,
                          decoration: InputDecoration(
                            labelText: '日期（年-月-日）',
                            errorText: _inputError,
                          ),
                          onSubmitted: (_) => _confirm(),
                        ),
                      )
                    else
                      AppCalendar(
                        key: ValueKey(_calendarRevision),
                        initialDate: _selected,
                        currentDate: today,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        onDateChanged: (date) =>
                            setState(() => _selected = date),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppLayout.spaceSm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppLayout.spaceSm,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  key: const Key('app-date-confirm'),
                  onPressed: _confirm,
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
