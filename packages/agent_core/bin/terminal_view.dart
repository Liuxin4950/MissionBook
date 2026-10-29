import 'dart:async';
import 'dart:io';

import 'package:agent_core/agent_core.dart';

/// 终端展示只负责文字、颜色与等待提示，模型和命令逻辑留在 AgentCli。
final class TerminalView {
  TerminalView({bool color = true})
    : color =
          color &&
          stdout.hasTerminal &&
          stdout.supportsAnsiEscapes &&
          !Platform.environment.containsKey('NO_COLOR');

  final bool color;
  Timer? _spinner;
  final _waiting = Stopwatch();
  bool _hasText = false;
  bool _answerStarted = false;
  int _frame = 0;

  String _paint(String text, String code) =>
      color ? '\x1b[${code}m$text\x1b[0m' : text;
  void line(String text) {
    stopWaiting();
    stdout.writeln(text);
  }

  void note(String text) => line(_paint('  $text', '90'));
  void success(String text) => line(_paint('  ✓ $text', '32'));
  void error(String text) => line(_paint('  ! $text', '31'));

  void welcome(AgentSession session, {bool demo = false}) {
    line('');
    line(_paint('  MISSIONBOOK', '1;36'));
    line('  Agent  ·  ${demo ? '离线演示' : session.modelProfile.model}');
    note(
      '${tokens(session.modelProfile.contextWindowTokens)} 上下文  ·  输出预算 ${tokens(session.outputTokens)}  ·  思考${thinking(session.reasoningEffort)}',
    );
    line('');
    note('直接输入问题。/help 命令  ·  /image 看图  ·  Ctrl+C 取消或退出');
    note(
      '会话 ${session.id.substring(0, session.id.length.clamp(0, 8))}  ·  ${session.title}',
    );
  }

  void prompt() {
    stopWaiting();
    stdout.write(_paint('\n你 › ', '1;32'));
  }

  void startWaiting(String message) {
    stopWaiting();
    _waiting.reset();
    _waiting.start();
    if (!color) return;
    _spinner = Timer.periodic(const Duration(milliseconds: 100), (_) {
      const frames = ['·  ', '·· ', '···'];
      stdout.write(
        '\r\x1b[2K${_paint('  ${frames[_frame++ % frames.length]} $message  ${_waiting.elapsed.inSeconds}s', '90')}',
      );
    });
  }

  void stopWaiting() {
    if (_spinner != null) {
      _spinner!.cancel();
      _spinner = null;
      stdout.write('\r\x1b[2K');
    }
    _waiting.stop();
  }

  void observe(AgentEvent event) {
    switch (event) {
      case ModelAttemptStarted():
        if (event.request.purpose != ModelRequestPurpose.conversation) {
          startWaiting('整理上下文');
          return;
        }
        _hasText = false;
        _answerStarted = false;
        startWaiting('等待回答');
      case ModelStreamUpdated():
        if (event.purpose != ModelRequestPurpose.conversation) return;
        if (event.update case ModelTextDelta(:final text)) writeAnswer(text);
        if (event.update is ModelThinkingDelta &&
            !_hasText &&
            _spinner == null) {
          startWaiting('思考中');
        }
      case ToolExecutionStarted():
        if (_hasText) stdout.writeln();
        note(
          '↳ ${event.call.name == 'get_current_time' ? '查询设备时间' : event.call.name}',
        );
      case ContextCompacted():
        note(
          '上下文已整理  ${tokens(event.compaction.beforeTokens)} → ${tokens(event.compaction.afterTokens)}（估算）',
        );
      case ModelAttemptFailed():
        if (_hasText) stdout.writeln();
        if (event.willRetry) {
          note('连接中断，${event.delay.inSeconds} 秒后重试；上段未完成回答未进入正式记录');
        }
      default:
        break;
    }
  }

  void writeAnswer(String text) {
    stopWaiting();
    if (!_answerStarted) {
      stdout.writeln(_paint('\n助理', '1;36'));
      _answerStarted = true;
    }
    stdout.write(text);
    _hasText = true;
  }

  void result(AgentRunResult result, Duration duration) {
    stopWaiting();
    if (!_hasText && result.answer != null) writeAnswer(result.answer!);
    if (_hasText) stdout.writeln();
    final status = switch (result.reason) {
      AgentStopReason.completed => '完成',
      AgentStopReason.cancelled => '已取消',
      AgentStopReason.maxTokens => '达到输出预算，可 /resume 继续',
      AgentStopReason.maxSteps => '达到步骤上限，可 /resume 继续',
      AgentStopReason.refused => '模型拒绝回答',
      AgentStopReason.interrupted => '运行中断',
      AgentStopReason.failed => '未完成',
    };
    note(
      '$status  ·  ${(duration.inMilliseconds / 1000).toStringAsFixed(1)} 秒  ·  输入 ${tokens(result.usage.inputTokens)} / 输出 ${tokens(result.usage.outputTokens)}${result.usageIncomplete ? '（含未完整报告的尝试）' : ''}',
    );
    if (result.failure != null) error(result.failure!.message);
    _hasText = false;
    _answerStarted = false;
  }

  void help() {
    line('');
    line(_paint('  对话', '1'));
    note('/image 路径 [问题]        识别本地图片或图片链接；有空格的路径加引号');
    note('/thinking off|low|high|max 切换思考强度');
    note('/output 数量              设置本次会话的输出预算');
    note('/format text|json         普通回答或 JSON 对象（Chat 协议）');
    note('/compact  /resume         整理上下文、继续中断的回答');
    line(_paint('\n  模型与会话', '1'));
    note('/models  /model 编号      查看、切换供应商模型配置');
    note('/summary-model 编号       选择摘要模型');
    note('/new  /list  /open 编号    新建、列出、打开会话（编号可用唯一前缀）');
    note('/rename 名称  /fork       重命名、创建分支');
    note('/history  /status         查看对话、完整配置与用量信息');
    note('/export 路径  /import 路径 导出、导入会话');
    note('/delete 会话编号          删除已关闭的本地会话');
    note('/exit                     保存并退出');
  }

  void close() {
    stopWaiting();
  }
}

String thinking(ReasoningEffort effort) => switch (effort) {
  ReasoningEffort.off => '关闭',
  ReasoningEffort.low => '低',
  ReasoningEffort.high => '高',
  ReasoningEffort.max => '最高',
};

String tokens(int count) {
  if (count >= 1048576 && count % 1048576 == 0) return '${count ~/ 1048576} Mi';
  if (count >= 1024 && count % 1024 == 0) return '${count ~/ 1024} Ki';
  return count.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]},',
  );
}
