import 'package:flutter/material.dart';

import '../../../application/goals/goal_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../widgets/app_top_bar.dart';
import 'goal_import_section.dart';

/// 独立导入工作区，列表不再混入文件输入和校验表单。
class GoalImportPage extends StatefulWidget {
  const GoalImportPage({super.key, required this.service});
  final GoalService service;

  @override
  State<GoalImportPage> createState() => _GoalImportPageState();
}

class _GoalImportPageState extends State<GoalImportPage> {
  final _section = GlobalKey<GoalImportSectionState>();
  bool _leaving = false;
  bool _allowPop = false;

  Future<void> _back() async {
    if (_leaving) return;
    _leaving = true;
    try {
      if (!await (_section.currentState?.prepareToCollapse() ??
              Future.value(true)) ||
          !mounted) {
        return;
      }
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } finally {
      _leaving = false;
    }
  }

  void _imported(String id) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(id);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope<String>(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: AppTopBar(title: '导入目标与计划', onBack: _back),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: AppLayout.pagePadding(context),
              child: GoalImportSection(
                key: _section,
                service: widget.service,
                onImported: _imported,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
