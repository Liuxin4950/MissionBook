import 'package:flutter/material.dart';
import 'presentation/today/today_page.dart';
import 'application/create_mission.dart';

//页面聚合状态控制页面
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.createMission});
  // 业务对象
  final CreateMission createMission;

  @override
  State<AppShell> createState() {
    return _AppShellState();
  }
}

class _AppShellState extends State<AppShell> {
  // 索引
  int _selectedIndex = 0;
  // 核心页面聚合列表
  static const List<Widget> _pages = [
    TodayPage(),
    Center(child: Text('目标页面')),
    Center(child: Text('历史页面')),
    Center(child: Text('我的页面')),
  ];
  // 路由变更方法
  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 主要渲染内容
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: Text("MissionBook"),
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  // 底部导航模块
  Widget _buildNavigationBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectPage,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.today_outlined), label: '今天'),
        NavigationDestination(icon: Icon(Icons.flag_outlined), label: '目标'),
        NavigationDestination(icon: Icon(Icons.history), label: '历史'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
      ],
    );
  }
}
