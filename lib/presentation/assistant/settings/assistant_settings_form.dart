import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/assistant/assistant_controller.dart';
import '../../../application/errors/user_error_message.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/page_footer_bar.dart';

/// 等设置加载后再建立表单，避免默认值覆盖设备已保存配置。
class AssistantSettingsLoader extends StatefulWidget {
  const AssistantSettingsLoader({
    super.key,
    required this.controller,
    required this.title,
    required this.builder,
  });
  final AssistantController controller;
  final String title;
  final WidgetBuilder builder;
  @override
  State<AssistantSettingsLoader> createState() =>
      _AssistantSettingsLoaderState();
}

class _AssistantSettingsLoaderState extends State<AssistantSettingsLoader> {
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.controller.initialize();
      if (!widget.controller.initialized) {
        throw StateError(widget.controller.errorMessage ?? '设置加载失败');
      }
    } catch (error) {
      if (mounted) _error = userErrorMessage(error, fallback: '设置加载失败，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == null) return widget.builder(context);
    return Scaffold(
      appBar: AppTopBar(title: widget.title),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
      ),
    );
  }
}

/// 独立设置页共用返回草稿保护、阅读限宽、反馈和底部保存。
class AssistantSettingsForm extends StatefulWidget {
  const AssistantSettingsForm({
    super.key,
    required this.title,
    required this.changed,
    required this.busy,
    required this.child,
    this.error,
    this.message,
    this.onSave,
  });
  final String title;
  final bool changed, busy;
  final String? error, message;
  final VoidCallback? onSave;
  final Widget child;
  @override
  State<AssistantSettingsForm> createState() => _AssistantSettingsFormState();
}

class _AssistantSettingsFormState extends State<AssistantSettingsForm> {
  bool _allowPop = false, _asking = false;
  Future<void> _back() async {
    if (widget.busy || _asking) return;
    _asking = true;
    final leave =
        !widget.changed ||
        await AppConfirmDialog.show(
          context: context,
          title: '放弃${widget.title}修改？',
          message: '尚未保存的修改会丢失。',
          cancelText: '继续编辑',
          confirmText: '放弃修改',
        );
    _asking = false;
    if (!mounted || !leave) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _allowPop || (!widget.busy && !widget.changed),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_back());
    },
    child: Scaffold(
      appBar: AppTopBar(
        title: widget.title,
        canGoBack: !widget.busy,
        onBack: _back,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
            child: ListView(
              padding: AppLayout.pagePadding(context),
              children: [widget.child],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: PageFooterBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.error != null || widget.message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppLayout.spaceSm),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      widget.error ?? widget.message!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: widget.error != null
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              FilledButton(
                key: const Key('assistant-save-settings'),
                onPressed: widget.busy ? null : widget.onSave,
                child: Text(widget.busy ? '正在处理…' : '保存设置'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
