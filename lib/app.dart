import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'app_shell.dart';
// 定义根wight,将UI逻辑与main分离
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
