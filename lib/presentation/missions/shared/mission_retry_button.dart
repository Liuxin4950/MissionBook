import 'package:mission_book/core/theme/app_layout.dart';
import 'package:flutter/material.dart';
import '../../widgets/detail_pane.dart';

import '../../../application/missions/mission_service.dart';
import '../../../domain/entities/mission_detail.dart';
import '../form/mission_form_page.dart';

/// 明确保存后才新建，返回仍停在来源记录；旧任务始终保持终态。
class MissionRetryButton extends StatefulWidget {
  const MissionRetryButton({
    super.key,
    required this.source,
    required this.service,
  });
  final MissionDetail source;
  final MissionService service;
  @override
  State<MissionRetryButton> createState() => _MissionRetryButtonState();
}

class _MissionRetryButtonState extends State<MissionRetryButton> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final saved = await openDetailPane<bool>(
        context,
        label: '再次尝试',
        builder: (_) => MissionFormPage.retry(
          missionService: widget.service,
          source: widget.source,
        ),
      );
      if (mounted && saved == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已创建新的尝试，可在对应日期查看')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton(
    key: const Key('mission-retry'),
    onPressed: _opening ? null : _open,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(AppLayout.actionMinHeight),
      shape: const StadiumBorder(),
    ),
    child: const Text('再次尝试'),
  );
}
