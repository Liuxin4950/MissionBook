import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text(label, style: theme.textTheme.titleSmall)),
        const SizedBox(height: 8),
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
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
      ],
    );
  }
}
