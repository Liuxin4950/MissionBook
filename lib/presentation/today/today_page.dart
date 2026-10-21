import 'package:flutter/material.dart';
import '../../application/create_mission.dart';
import '../missions/create_mission_page.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.createMission});
  // 业务对象
  final CreateMission createMission;

  @override
  Widget build(BuildContext context) {
    //运行查找主题
    final theme = Theme.of(context);
    // weekday 组合日期，因为更新频率低所有没有用StatefulWidget
    final today = DateTime.now();
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dateText =
        '${today.month}月${today.day}日 · ${weekdays[today.weekday - 1]}';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header 头部
              Row(
                children: [
                  // 自适应占据
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今天',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            // 设计规范：页面标题字号 28，行高 36。
                            fontSize: 28,
                            height: 36 / 28,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            height: 20 / 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () {
                      // 点击时才创建路由并打开表单，不在 build 中自动打开。
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (context) {
                            // 将今天页已经收到的业务对象继续交给表单。
                            return CreateMissionPage(
                              createMission: createMission,
                            );
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    tooltip: "创建任务",
                    style: IconButton.styleFrom(
                      fixedSize: const Size(48, 48),
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),

              // plan 固定计划任务 （任务列表，纵向排布，激活项放大，类似课表）
              Column(children: []),

              // time 动态计划任务 （任务列表，纵向排布）
              Column(children: []),
              // 其他聚合信息
              Column(children: []),
            ],
          ),
        ],
      ),
    );
  }
}
