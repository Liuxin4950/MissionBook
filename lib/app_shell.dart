import 'package:flutter/material.dart';
import 'presentation/today/today_page.dart';
import 'application/missions/mission_service.dart';
import 'core/theme/colors.dart';

/// 管理四个顶层导航入口，并保留各页状态、转交共享业务对象。
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.missionService});
  // App 传入共享的任务业务对象；本层只转交给今天页，不执行业务方法。
  final MissionService missionService;

  @override
  State<AppShell> createState() {
    return _AppShellState();
  }
}

class _AppShellState extends State<AppShell> {
  // 索引
  int _selectedIndex = 0;

  // 路由变更方法
  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 主要渲染内容
  @override
  Widget build(BuildContext context) {
    // 通过 widget 读取 App 传入的服务引用；重建页面时不重新创建服务。
    final pages = <Widget>[
      TodayPage(missionService: widget.missionService),
      Center(child: Text('目标页面')),
      Center(child: Text('历史页面')),
      Center(child: Text('我的页面')),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var index = 0; index < pages.length; index++)
            TickerMode(
              enabled: index == _selectedIndex,
              child: pages[index],
            ), // 只在选中时才启动动画
        ],
      ),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  // 导航仍由 _selectedIndex 控制；这里只将标准横条改成当前稿的白色胶囊。
  Widget _buildNavigationBar() {
    final margin = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 24.0;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(margin, 8, margin, 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 792),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: AppColors.card,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _navigationItem(
                      0,
                      '今天',
                      Icons.home_outlined,
                      Icons.home_rounded,
                    ),
                    _navigationItem(
                      1,
                      '目标',
                      Icons.track_changes_outlined,
                      Icons.track_changes,
                    ),
                    _navigationItem(
                      2,
                      '历史',
                      Icons.schedule_outlined,
                      Icons.schedule,
                    ),
                    _navigationItem(
                      3,
                      '我的',
                      Icons.person_outline,
                      Icons.person,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 四个目的地共用同一排版；点击仍交给已有 _selectPage 切换 IndexedStack。
  Widget _navigationItem(
    int index,
    String label,
    IconData icon,
    IconData selectedIcon,
  ) {
    final selected = index == _selectedIndex;
    final foreground = selected ? AppColors.accent : AppColors.textSecondary;

    // 触屏和读屏都调用同一个入口，使用当前导航项的 index 切换页面。
    void selectPage() {
      _selectPage(index);
    }

    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        enabled: true,
        // 替换子节点语义后，需要在这里同时提供标签和实际点击动作。
        excludeSemantics: true,
        onTap: selectPage,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: selectPage,
            customBorder: const StadiumBorder(),
            child: Ink(
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: selected ? AppColors.primary : AppColors.card,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? selectedIcon : icon,
                      size: 22,
                      color: foreground,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
