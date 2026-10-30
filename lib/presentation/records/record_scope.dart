import '../../application/memory/memory_service.dart';
import '../../application/web/web_service.dart';
import 'package:flutter/material.dart';
import '../../application/records/record_service.dart';
import '../../application/analysis/analysis_service.dart';

class RecordScope extends InheritedWidget {
  const RecordScope({
    super.key,
    required this.service,
    required this.analysis,
    this.memory,
    this.web,
    required super.child,
  });
  final RecordService service;
  final MemoryService? memory;
  final AnalysisService analysis;
  final WebService? web;
  static RecordScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RecordScope>();
  @override
  bool updateShouldNotify(RecordScope oldWidget) =>
      service != oldWidget.service ||
      analysis != oldWidget.analysis ||
      memory != oldWidget.memory ||
      web != oldWidget.web;
}
