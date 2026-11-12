import 'package:flutter/material.dart';

import '../../application/backup/backup_service.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_section_header.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/page_footer_bar.dart';

/// 导出前选择要带走的本机资源。业务数据与材料原件是恢复必需的整体，
/// 恢复器要求两者完全对应，因此不参与勾选。
class BackupScopePage extends StatefulWidget {
  const BackupScopePage({super.key, this.initial = defaultBackupResources});

  final Set<BackupResource> initial;

  @override
  State<BackupScopePage> createState() => _BackupScopePageState();
}

class _BackupScopePageState extends State<BackupScopePage> {
  late final Set<BackupResource> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AppTopBar(title: '选择导出范围'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.maxPageWidth,
                  ),
                  child: ListView(
                    padding: AppLayout.pagePadding(context),
                    children: [
                      AppSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppSectionHeader('始终包含'),
                            const SizedBox(height: AppLayout.spaceSm),
                            Text(
                              '任务、目标、记录、正式材料原件、长期记忆与已保存的助手会话。',
                              style: text.bodyLarge,
                            ),
                            const SizedBox(height: AppLayout.spaceXs),
                            Text(
                              '恢复要求数据库快照与材料原件完全对应，这两部分不能单独取消。',
                              style: text.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppLayout.spaceLg),
                      AppSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppSectionHeader('可选本机资源'),
                            for (final resource in BackupResource.values)
                              SwitchListTile(
                                key: Key('backup-scope-${resource.name}'),
                                contentPadding: EdgeInsets.zero,
                                title: Text(resource.label),
                                subtitle: Text(resource.description),
                                value: _selected.contains(resource),
                                onChanged: (value) => setState(() {
                                  if (value) {
                                    _selected.add(resource);
                                  } else {
                                    _selected.remove(resource);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                      if (_selected.contains(BackupResource.speechModel)) ...[
                        const SizedBox(height: AppLayout.spaceMd),
                        Text(
                          '已勾选离线语音模型：备份包增加约 228 MiB，导出与恢复都会明显变慢；本机未安装时不会写入模型文件。',
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            PageFooterBar(
              child: FilledButton(
                key: const Key('backup-scope-confirm'),
                onPressed: () => Navigator.of(context).pop({..._selected}),
                child: const Text('按此范围导出'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}