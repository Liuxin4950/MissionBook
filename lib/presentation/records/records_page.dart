import '../../application/errors/user_error_message.dart';
import '../../domain/entities/analysis_scope.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:uuid/uuid.dart';
import '../../application/records/record_service.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/evidence.dart';
import '../missions/evidence/evidence_camera_panel.dart';
import '../missions/evidence/evidence_image_loader.dart';
import '../widgets/adaptive_columns.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_dropdown_form_field.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_settings_row.dart';
import '../widgets/app_segmented_control.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_top_bar.dart';
import 'record_scope.dart';
import 'analysis_panel.dart';

part 'record_editor.dart';
part 'record_association_picker.dart';
part 'record_detail.dart';
part 'record_entries.dart';

/// 各页面共用同一记录列表、编辑器和关联选择器。
class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    this.goalId,
    this.nodeId,
    this.missionId,
    this.date,
    this.capture = false,
  });
  final String? goalId, nodeId, missionId, date;
  final bool capture;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  Future<Map<String, Object?>>? _data;
  StreamSubscription<void>? _changes;
  int _offset = 0;
  bool _initialized = false;
  RecordService get service => RecordScope.maybeOf(context)!.service;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
      _changes = service.missions.changes.listen((_) {
        if (mounted) _load();
      });
      if (widget.capture) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _create(capture: true),
        );
      }
    }
  }

  void _load() {
    setState(() {
      _data = service.queryRecords(
        goalId: widget.goalId,
        nodeId: widget.nodeId,
        missionId: widget.missionId,
        date: widget.date,
        offset: _offset,
      );
    });
  }

  Future<void> _create({bool capture = false}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RecordEditor(
          capture: capture,
          goalId: widget.goalId,
          nodeId: widget.nodeId,
          missionId: widget.missionId,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _delete(Map<String, Object?> item) async {
    if (item['mission_id'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已作为任务材料的记录不能删除，请在任务材料中追加修正')),
      );
      return;
    }
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: '删除这条记录？',
      message: '删除后将无法在记录中查看。',
      confirmText: '删除',
    );
    if (!confirmed || !mounted) return;
    try {
      await service.delete(item['id'] as String);
      if (mounted) {
        if (_offset > 0) {
          _offset = 0;
        }
        _load();
      }
    } catch (error, stack) {
      debugPrint('删除记录失败：$error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
      }
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      title: '记录',
      actions: [
        IconButton(
          tooltip: '拍照记录',
          onPressed: () => _create(capture: true),
          icon: const Icon(Icons.photo_camera_outlined),
        ),
        IconButton(
          tooltip: '添加记录',
          onPressed: _create,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, Object?>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: AppEmptyState(
              title: '记录读取失败',
              details: const Text('请检查设备存储后重试。'),
              actions: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final items = data['items'] as List<Map<String, Object?>>;
        return ListView(
          padding: const EdgeInsets.all(AppLayout.spaceLg),
          children: [
            if (items.isEmpty)
              AppEmptyState(
                title: '还没有记录',
                details: const Text('可以拍照或写下文字。'),
                actions: FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('添加记录'),
                ),
              ),
            for (final item in items)
              _SwipeRecord(
                key: ValueKey<String>(item['id'] as String),
                onDelete: () => _delete(item),
                child: Card(
                  child: ListTile(
                    leading: item['type'] == 'IMAGE'
                        ? _RecordThumbnail(
                            storageKey:
                                item['attachment_storage_key'] as String,
                            name:
                                item['attachment_file_name'] as String? ??
                                '记录图片',
                            service: service,
                          )
                        : const Icon(Icons.notes),
                    title: Text(
                      (item['content'] as String?)?.isNotEmpty == true
                          ? item['content'] as String
                          : item['attachment_file_name'] as String? ?? '记录',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${DateTime.fromMillisecondsSinceEpoch(item['occurred_at'] as int).toLocal()}\n${_analysisLabel(item['analysis'])}',
                    ),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => RecordDetail(id: item['id'] as String),
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _offset == 0
                      ? null
                      : () {
                          _offset = (_offset - 20).clamp(0, 1 << 30);
                          _load();
                        },
                  child: const Text('上一页'),
                ),
                Text('共 ${data['total']} 条'),
                TextButton(
                  onPressed: data['nextOffset'] == null
                      ? null
                      : () {
                          _offset = data['nextOffset'] as int;
                          _load();
                        },
                  child: const Text('下一页'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

/// 左滑露出删除操作，点击后再确认。
/// 缩略图持有自己的读取结果；列表重建不重复读文件，失败可原位重试。
class _RecordThumbnail extends StatelessWidget {
  const _RecordThumbnail({
    required this.storageKey,
    required this.name,
    required this.service,
  });
  final String storageKey;
  final String name;
  final RecordService service;
  static const _imageSize = 64.0; // 缩略内容尺寸，与顶栏及按钮尺寸无关。

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: _imageSize,
    child: _RecordImage(
      service: service,
      storageKey: storageKey,
      name: name,
      width: _imageSize,
      height: _imageSize,
      compact: true,
    ),
  );
}

class _SwipeRecord extends StatefulWidget {
  const _SwipeRecord({super.key, required this.child, required this.onDelete});
  final Widget child;
  final VoidCallback onDelete;
  @override
  State<_SwipeRecord> createState() => _SwipeRecordState();
}

class _SwipeRecordState extends State<_SwipeRecord> {
  double _offset = 0;
  @override
  Widget build(BuildContext context) => Semantics(
    customSemanticsActions: {
      const CustomSemanticsAction(label: '删除记录'): widget.onDelete,
    },
    child: ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 80,
                height: double.infinity,
                child: ExcludeSemantics(
                  excluding: _offset == 0,
                  child: TextButton(
                    onPressed: widget.onDelete,
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.errorContainer,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Icon(Icons.delete_outline), Text('删除')],
                    ),
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (d) =>
                setState(() => _offset = (_offset + d.delta.dx).clamp(-80, 0)),
            onHorizontalDragEnd: (_) =>
                setState(() => _offset = _offset < -35 ? -80 : 0),
            child: Transform.translate(
              offset: Offset(_offset, 0),
              child: widget.child,
            ),
          ),
        ],
      ),
    ),
  );
}

String _analysisLabel(Object? value) {
  final a = value as Map<String, Object?>?;
  return switch (a?['state']) {
    'ready' => a?['stale'] == true ? '摘要待更新' : '已生成内容摘要',
    'failed' => '分析失败，可重试',
    'blocked' => '分析需配置模型能力',
    'running' => '正在分析',
    'pending' => '待分析',
    _ => '尚未分析',
  };
}
