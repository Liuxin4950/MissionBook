import 'package:flutter/widgets.dart';

/// 可见内容在失去输入焦点时也继续刷新，真正隐藏或挂起后才停止。
bool isAppVisible(AppLifecycleState? state) =>
    state == null ||
    state == AppLifecycleState.resumed ||
    state == AppLifecycleState.inactive;
