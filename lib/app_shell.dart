import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() {
    return _AppShellState();
  }
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  static const List<String> _titles = [
    '今天',
    '目标',
    '历史',
    '我的',
  ];
  static const List<Widget> _pages = [
    Center(child: Text('今天页面')),
    Center(child: Text('目标页面')),
    Center(child: Text('历史页面')),
    Center(child: Text('我的页面')),
  ];
  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildNavigationBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectPage,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.today_outlined),
          label: '今天',
        ),
        NavigationDestination(
          icon: Icon(Icons.flag_outlined),
          label: '目标',
        ),
        NavigationDestination(
          icon: Icon(Icons.history),
          label: '历史',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: '我的',
        ),
      ],
    );
  }
}
