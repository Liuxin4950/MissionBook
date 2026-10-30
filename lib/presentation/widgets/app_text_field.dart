import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_layout.dart';

/// 目标与节点表单沿用任务表单的外置标签、输入字号和柔和底色。
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.readOnly = false,
    this.minLines = 1,
    this.maxLines = 3,
    this.autofocus = false,
    this.textInputAction,
    this.validator,
    this.inputFormatters,
  });
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool readOnly;
  final int minLines;
  final int maxLines;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text(label, style: theme.textTheme.titleSmall)),
        const SizedBox(height: AppLayout.spaceSm),
        Semantics(
          label: label,
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            minLines: minLines,
            maxLines: maxLines,
            autofocus: autofocus,
            textInputAction: textInputAction,
            validator: validator,
            inputFormatters: inputFormatters,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
      ],
    );
  }
}
