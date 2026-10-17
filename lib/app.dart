import 'package:flutter/material.dart';

// 定义根wight,将UI逻辑与main分离
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("Book")),
        body: const Center(child: Text("test")),
      ),
    );
  }
}
