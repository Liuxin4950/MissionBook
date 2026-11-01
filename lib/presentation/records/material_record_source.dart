import 'package:flutter/material.dart';
import '../../domain/entities/saved_record.dart';
import 'record_scope.dart';
import 'records_page.dart';

/// 仅展示材料来源的存续状态；材料正文始终来自已提交快照。
class MaterialRecordSource extends StatefulWidget {
  const MaterialRecordSource({super.key, required this.recordId});
  final String recordId;
  @override
  State<MaterialRecordSource> createState() => _MaterialRecordSourceState();
}

class _MaterialRecordSourceState extends State<MaterialRecordSource> {
  Future<RecordPage>? _source;
  void _load() {
    final service = RecordScope.maybeOf(context)?.service;
    if (service != null) {
      setState(() => _source = service.readRecords(id: widget.recordId));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _source ??= RecordScope.maybeOf(
      context,
    )?.service.readRecords(id: widget.recordId);
  }

  @override
  void didUpdateWidget(MaterialRecordSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordId != widget.recordId) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_source == null) return const Text('材料已保留提交时的内容');
    return FutureBuilder<RecordPage>(
      future: _source,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton(onPressed: _load, child: const Text('来源读取失败，重试'));
        }
        if (!snapshot.hasData) return const Text('材料已保留提交时的内容');
        if (snapshot.data!.items.isEmpty) return const Text('来源记录已删除，提交材料仍保留');
        return TextButton(
          onPressed: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => RecordDetail(id: widget.recordId),
              ),
            );
            if (mounted) _load();
          },
          child: const Text('查看来源记录 · 材料保留提交时内容'),
        );
      },
    );
  }
}
