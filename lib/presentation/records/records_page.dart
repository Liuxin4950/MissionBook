import '../../domain/entities/saved_record.dart';
import '../../domain/entities/record_draft.dart';
import '../../application/errors/user_error_message.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:uuid/uuid.dart';
import '../../application/records/record_service.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../attachments/photo_capture_panel.dart';
import '../attachments/attachment_image_loader.dart';
import '../assistant/assistant_launcher.dart';
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
  Future<RecordPage>? _data;
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
      _changes = service.changes.listen((_) {
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
      _data = service.readRecords(
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

  Future<void> _delete(SavedRecord item) async {
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: '删除这条记录？',
      message: '删除后将无法在记录中查看，任务中已经提交的材料仍会保留。',
      confirmText: '删除',
    );
    if (!confirmed || !mounted) return;
    try {
      await service.delete(item.id);
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
  Widget build(BuildContext context) => AssistantSurface(
    missionId: widget.missionId,
    goalId: widget.goalId,
    nodeId: widget.nodeId,
    child: Scaffold(
      appBar: AppTopBar(
        title: widget.missionId != null
            ? '材料来源记录'
            : widget.nodeId != null
            ? '节点记录'
            : widget.goalId != null
            ? '目标记录'
            : '记录',
        maxContentWidth: AppLayout.formMaxWidth,
        actions: [
          IconButton(
            tooltip: '拍照记录',
            onPressed: () => _create(capture: true),
            icon: const Icon(Icons.photo_camera_outlined),
          ),
          IconButton(
            tooltip: '添加记录',
            onPressed: _create,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
            child: LayoutBuilder(
              builder: (context, box) => FutureBuilder<RecordPage>(
                future: _data,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return SingleChildScrollView(
                      padding: AppLayout.pagePadding(context),
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
                  if (data.items.isEmpty) {
                    return SingleChildScrollView(
                      padding: AppLayout.pagePadding(context),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (box.maxHeight - AppLayout.space3Xl).clamp(
                            0,
                            double.infinity,
                          ),
                        ),
                        child: AppEmptyState(
                          title: '还没有记录',
                          details: const Text('拍下值得留下的瞬间，或写下一段想法。'),
                          actions: FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('添加记录'),
                          ),
                        ),
                      ),
                    );
                  }
                  final padding = AppLayout.horizontalPadding(context);
                  final wide =
                      box.maxWidth - padding * 2 >=
                      680 * MediaQuery.textScalerOf(context).scale(1);
                  Widget tile(SavedRecord item) => _SwipeRecord(
                    key: ValueKey<String>(item.id),
                    onDelete: () => _delete(item),
                    child: _RecordTile(
                      item: item,
                      service: service,
                      onDelete: () => _delete(item),
                      onOpen: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => RecordDetail(id: item.id),
                        ),
                      ),
                    ),
                  );
                  return ListView(
                    padding: AppLayout.pagePadding(context),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppLayout.spaceLg,
                        ),
                        child: Text(
                          '共 ${data.total} 条记录',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      for (
                        var index = 0;
                        index < data.items.length;
                        index += wide ? 2 : 1
                      )
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppLayout.spaceMd,
                          ),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: tile(data.items[index])),
                                    const SizedBox(width: AppLayout.spaceLg),
                                    Expanded(
                                      child: index + 1 < data.items.length
                                          ? tile(data.items[index + 1])
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                )
                              : tile(data.items[index]),
                        ),
                      if (_offset > 0 || data.nextOffset != null)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: AppLayout.spaceMd,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _offset == 0
                                  ? null
                                  : () {
                                      _offset = (_offset - 20).clamp(
                                        0,
                                        1 << 30,
                                      );
                                      _load();
                                    },
                              child: const Text('上一页'),
                            ),
                            Text('第 ${_offset ~/ 20 + 1} 页'),
                            TextButton(
                              onPressed: data.nextOffset == null
                                  ? null
                                  : () {
                                      _offset = data.nextOffset!;
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
            ),
          ),
        ),
      ),
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

/// 列表突出内容、发生时间和归属；摘要在详情查看，不铺开模型配置状态。
class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.item,
    required this.service,
    required this.onOpen,
    required this.onDelete,
  });
  final SavedRecord item;
  final RecordService service;
  final VoidCallback onOpen, onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final local = item.occurredAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final date =
        '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppLayout.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    item.type == ContentType.image
                        ? Icons.photo_outlined
                        : item.type == ContentType.file
                        ? Icons.attach_file
                        : Icons.notes_rounded,
                    size: AppLayout.iconMd,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppLayout.spaceSm),
                  Expanded(child: Text(date, style: text.bodySmall)),
                  PopupMenuButton<String>(
                    tooltip: '记录操作',
                    onSelected: (_) => onDelete(),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'delete', child: Text('删除记录')),
                    ],
                    icon: const Icon(Icons.more_horiz, size: AppLayout.iconMd),
                  ),
                ],
              ),
              if (item.type == ContentType.image) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _RecordThumbnail(
                    storageKey: item.attachmentStorageKey!,
                    name: item.attachmentFileName ?? '记录图片',
                    service: service,
                  ),
                ),
                const SizedBox(height: AppLayout.spaceMd),
              ],
              Text(
                item.content?.isNotEmpty == true
                    ? item.content!
                    : item.attachmentFileName ?? '记录',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: text.bodyLarge,
              ),
              if (item.goalTitle != null) ...[
                const SizedBox(height: AppLayout.spaceMd),
                Text(
                  '${item.goalTitle}${item.nodeTitle == null ? '' : ' / ${item.nodeTitle}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
