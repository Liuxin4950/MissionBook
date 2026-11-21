import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../application/assistant/assistant_attachment.dart';
import '../../application/assistant/assistant_controller.dart';
import '../../application/assistant/assistant_schedule.dart';
import '../../application/assistant/assistant_supervision.dart';
import '../../application/errors/user_error_message.dart';
import 'configured_assistant_speech.dart';

/// 连接原生悬浮窗与同一个助手控制器，不持有另外一份聊天。
class AndroidAssistantBridge {
  AndroidAssistantBridge(this.assistant, {this.speech, this.supervision});

  static const channel = MethodChannel('mission_book/assistant_workspace');
  static AndroidAssistantBridge? _active;
  static int _serial = 0;
  final AssistantController assistant;
  final ConfiguredAssistantSpeech? speech;
  final AssistantSupervision? supervision;
  String? _voiceTicket;
  final int generation = ++_serial;
  final _attachmentIds = Expando<String>();
  final _proposalVersions = Expando<String>();
  ({String id, String draft})? _capture;
  ({String id, Uint8List bytes, String? missionId})? _record;
  Timer? _push;
  bool _watching = false;
  int _watchRevision = 0;
  int _snapshotRevision = 0;
  bool _sending = false;

  bool get _current => identical(_active, this);

  void install() {
    _active?.detach();
    _active = this;
    channel.setMethodCallHandler(_handle);
    assistant.addListener(_changed);
    assistant.liveActivity.addListener(_changed);
    unawaited(_notifyHost('ready'));
  }

  void detach() {
    _capture = null;
    _record = null;
    supervision?.close();
    if (_voiceTicket != null) unawaited(speech?.cancel());
    _voiceTicket = null;
    _watching = false;
    _push?.cancel();
    if (!_current) return;
    _active = null;
    assistant.removeListener(_changed);
    assistant.liveActivity.removeListener(_changed);
    channel.setMethodCallHandler(null);
    unawaited(_notifyHost('unavailable'));
  }

  /// 系统授权与模型选择不跟随备份替换。
  Future<void> resetObservation() async {
    supervision?.invalidate();
    await _notifyHost('resetObservation');
  }

  /// 唯有用户点击保存记录才创建这次交接；取走前不写任何业务事实。
  ({Uint8List bytes, String? missionId})? takeRecord(String id) {
    final request = _record;
    if (!_current || request == null || request.id != id) return null;
    _record = null;
    return (bytes: request.bytes, missionId: request.missionId);
  }

  Future<void> _notifyHost(String name, [Object? data]) async {
    try {
      await channel.invokeMethod<void>(name, data ?? generation);
    } on PlatformException {
      // 已失效的窗口不会影响正常会话。
    } on MissingPluginException {
      // 原生宿主已拆除。
    }
  }

  void _changed() {
    if (!_watching || !_current || _push?.isActive == true) return;
    _push = Timer(const Duration(milliseconds: 140), () {
      if (_watching && _current) unawaited(_notifyHost('state', _snapshot()));
    });
  }

  Future<Object?> _handle(MethodCall call) async {
    final args = call.arguments as Map? ?? const {};
    try {
      if (!_current || args['generation'] != generation) {
        throw StateError('助手工作区已切换，请重试');
      }
      switch (call.method) {
        case 'invalidateObservation':
          supervision?.invalidate();
          return null;
        case 'observation':
          final service = supervision;
          if (service == null) return null;
          await assistant.initialize();
          if (!_current) return null;
          final revision = args['revision'];
          final id = args['observationId'] as String;
          final authorization = {
            'generation': generation,
            'revision': revision,
            'observationId': id,
          };
          final notice = await service.observe(
            (
              id: id,
              label: args['app'] as String,
              seconds: args['seconds'] as int,
            ),
            isCurrent: () async =>
                _current &&
                await channel.invokeMethod<bool>(
                      'verifyObservation',
                      authorization,
                    ) ==
                    true,
          );
          return notice == null || !_current
              ? null
              : {
                  'sessionId': notice.sessionId,
                  'missionId': notice.missionId,
                  'message': notice.message,
                };
        case 'dismissNotice':
          supervision?.dismiss(onlyLater: args['later'] == true);
          return null;
        case 'openNotice':
          final id = args['sessionId'] as String;
          if (assistant.isBusy) throw StateError('请先处理当前会话');
          await assistant.openConversation(id);
          if (!_current) return null;
          return _snapshot();
        case 'watch':
          final revision = ++_watchRevision;
          await assistant.initialize();
          if (!_current) throw StateError('助手正在重建');
          if (revision == _watchRevision) _watching = true;
          return _snapshot();
        case 'unwatch':
          _watchRevision++;
          _watching = false;
          return null;
        case 'beginCapture':
          await assistant.prepareExternalEntry();
          if (!_current || _capture != null) throw StateError('助手尚不能开始新的截图');
          final ticket = (id: const Uuid().v4(), draft: assistant.draftKey);
          _capture = ticket;
          return ticket.id;
        case 'capture':
          final ticket = _capture;
          if (ticket == null || args['ticket'] != ticket.id) return false;
          _capture = null;
          if (args['bytes'] case final Uint8List bytes) {
            assistant.addCapturedAttachment(
              AssistantAttachment.fromBytes('截图-${ticket.id}.jpg', bytes),
              target: ticket.draft,
            );
          }
          return true;
        case 'cancelVoice':
          if (_voiceTicket == args['ticket']) {
            _voiceTicket = null;
            await speech?.cancel();
          }
          return null;
        case 'voice':
          final key = args['key'] as String;
          if (key != assistant.draftKey ||
              _voiceTicket != null ||
              speech == null) {
            throw StateError('会话已变化或语音正在转写');
          }
          final ticket = args['ticket'] as String;
          _voiceTicket = ticket;
          try {
            final result = await speech!.transcribePcm(
              args['pcm'] as Uint8List,
            );
            if (!_current || _voiceTicket != ticket || result.isEmpty) {
              return false;
            }
            final prior = assistant.draftFor(key);
            assistant.saveDraft(
              key,
              prior.isEmpty ? result : [prior, result].join('\n'),
            );
            _changed();
            return true;
          } finally {
            if (_voiceTicket == ticket) _voiceTicket = null;
          }
      }
      if (args['key'] != assistant.draftKey) throw StateError('会话已切换，请重新打开');
      switch (call.method) {
        case 'draft':
          if (args['previous'] != assistant.draft) {
            throw StateError('草稿已在另一处修改');
          }
          assistant.draft = args['text'] as String;
          return true;
        case 'image':
        case 'stageRecord':
        case 'removeImage':
          final files = assistant.attachmentsFor(null);
          final index = files.indexWhere((file) => _id(file) == args['image']);
          if (index < 0) throw StateError('图片已移除');
          if (call.method == 'image') return files[index].bytes;
          if (call.method == 'stageRecord') {
            final id = const Uuid().v4();
            final reference = assistant.reference;
            _record = (
              id: id,
              bytes: files[index].bytes,
              missionId: reference?.type == AssistantReferenceType.mission
                  ? reference?.id
                  : null,
            );
            return id;
          }
          assistant.saveAttachments(null, [...files]..removeAt(index));
          return _snapshot();
        case 'send':
          if (assistant.isBusy || _sending) throw StateError('请先结束当前操作');
          final text = assistant.draft.trim();
          final files = assistant.attachmentsFor(null);
          if (text.isEmpty && files.isEmpty) throw StateError('请输入内容或添加图片');
          if (!assistant.supportsImages && files.any((file) => file.isImage)) {
            throw StateError('当前模型不支持图片，请在会话中切换模型');
          }
          final message = UserMessage.withContent(
            content: [
              if (text.isNotEmpty) TextBlock(text: text),
              for (final file in files) file.block,
            ],
          );
          final key = assistant.draftKey;
          final original = assistant.draft;
          assistant.saveDraft(key, '');
          assistant.saveAttachments(key, []);
          _sending = true;
          unawaited(_send(message, key, original, files));
          return _snapshot();
        case 'confirm':
        case 'reject':
        case 'checkOutcome':
          final id = args['operation'] as String;
          if (call.method == 'confirm') {
            final operation = assistant.operations
                .where((item) => item.callId == id)
                .firstOrNull;
            if (operation == null ||
                _operation(operation)['confirmable'] != true) {
              throw StateError('请在完整会话核对该提案');
            }
            if (args['version'] != _version(operation)) {
              throw StateError('提案已更新，请重新查看');
            }
            final error = assistant.confirmProposal(id);
            if (error != null) throw StateError(error);
          } else if (call.method == 'reject') {
            assistant.cancelProposal(id);
          } else {
            await assistant.resolveUnknownOutcome(id);
          }
          return _snapshot();
        case 'stop':
          assistant.stop();
          return _snapshot();
      }
      throw MissingPluginException(call.method);
    } on MissingPluginException {
      rethrow;
    } catch (error) {
      throw PlatformException(
        code: 'assistant_request',
        message: userErrorMessage(error, fallback: '助手操作失败，请重试'),
      );
    }
  }

  Future<void> _send(
    UserMessage message,
    String key,
    String text,
    List<AssistantAttachment> files,
  ) async {
    try {
      await assistant.sendMessage(
        message,
        confirmWrites: true,
        readCurrentUse: _readCurrentUse,
      );
    } catch (_) {
      if (_current) await _notifyHost('error', '消息未能发送，请查看会话');
    } finally {
      // 与主聊天一致：只恢复没有写入会话的本次输入，不覆盖后来编辑的草稿。
      if (_current && !assistant.transcript.any((m) => m.id == message.id)) {
        if (assistant.draftFor(key).isEmpty &&
            assistant.attachmentsFor(key).isEmpty) {
          assistant.saveDraft(key, text);
          assistant.saveAttachments(key, files);
        } else {
          assistant.retainUnsentDraft(key, AssistantUnsentDraft(text, files));
        }
      }
      _sending = false;
      _changed();
    }
  }

  Future<({String app, int seconds})?> _readCurrentUse() async {
    try {
      final use = await channel
          .invokeMapMethod<String, Object?>('currentUse', generation)
          .timeout(const Duration(milliseconds: 700));
      if (!_current || use == null) return null;
      final app = use['app'];
      final seconds = use['seconds'];
      if (app is! String ||
          app.trim().isEmpty ||
          seconds is! int ||
          seconds < 0) {
        return null;
      }
      return (app: _short(app, 80), seconds: seconds);
    } on TimeoutException {
      return null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  String _id(AssistantAttachment file) =>
      _attachmentIds[file] ??= const Uuid().v4();
  String _version(AssistantOperation item) =>
      _proposalVersions[item.input] ??= const Uuid().v4();

  Map<String, Object?> _snapshot() {
    final activity = assistant.activity;
    final recent = assistant.transcript.reversed
        .where(
          (message) =>
              (message is UserMessage || message is AssistantMessage) &&
              (message.text.isNotEmpty ||
                  message.content.any((block) => block is ImageBlock)),
        )
        .take(8)
        .toList()
        .reversed;
    return {
      'generation': generation,
      'revision': ++_snapshotRevision,
      'key': assistant.draftKey,
      'title': assistant.sessionTitle,
      'name': assistant.persona.name,
      'draft': assistant.draft,
      'images': [
        for (final file in assistant.attachmentsFor(null))
          if (file.isImage) {'id': _id(file), 'name': file.name},
      ],
      'messages': [
        for (final message in recent)
          {
            'id': message.id,
            'user': message is UserMessage,
            'text': _short(message.text, 2600),
            'images': message.content.whereType<ImageBlock>().length,
          },
      ],
      // 正文缓冲在请求结束后仍保留。只有当前请求在流式输出时才展示它；
      // 完成、重试间隙和工具阶段由已保存消息接管，不按文字内容去重。
      'partial': assistant.isRunning && activity.modelRequestRunning
          ? _short(activity.text, 2600)
          : '',
      'busy': assistant.isBusy || _sending,
      'running': assistant.isRunning,
      'operations': [
        for (final item in assistant.operations.reversed.take(8))
          if (item.status != AssistantOperationStatus.running || item.isWrite)
            _operation(item),
      ],
      'error': assistant.errorMessage,
    };
  }

  Map<String, Object?> _operation(AssistantOperation item) {
    final rows = item.toolName == 'planMissions'
        ? AssistantScheduleService.rows(item.input)
        : [item.input];
    final preview = rows
        .take(6)
        .map(
          (row) => [
            row['title'] ??
                item.planOriginals[row['itemId']]?.mission.title ??
                item.targetTitle,
            row['scheduledDate'],
            _slotLabel(row),
          ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
        )
        .where((s) => s.isNotEmpty)
        .join('\n');
    final compact =
        item.toolName == 'planMissions' &&
        rows.length <= 6 &&
        rows.isNotEmpty &&
        item.planPreviewReady &&
        !item.planChecking &&
        item.planConflicts.isEmpty &&
        item.planPreviewError == null;
    return {
      'id': item.callId,
      'label': switch (item.toolName) {
        'getSchedule' => '查看日程',
        'planMissions' => '安排日程',
        _ => item.targetTitle ?? (item.isWrite ? '修改操作' : '读取资料'),
      },
      'version': _version(item),
      'writes': item.isWrite,
      'preview': _short(preview, 900),
      'status': item.status.name,
      'confirmable':
          item.status == AssistantOperationStatus.waitingConfirmation &&
          (!item.isWrite || compact),
      'detail':
          item.planPreviewError ??
          item.error ??
          (item.planConflicts.isEmpty
              ? null
              : _short(
                  item.planConflicts
                      .take(3)
                      .map((item) => item.message)
                      .join('\n'),
                  260,
                )),
      'missionId': _savedMission(item),
    };
  }

  String? _slotLabel(Map<String, Object?> row) {
    final start = row['fixedStartLocal'];
    final duration = row['plannedMinutes'] ?? row['plannedDurationMinutes'];
    if (duration is! int) return start as String?;
    if (start is! String) return '自选 · $duration 分钟';
    final parts = start.split(':').map(int.tryParse).toList();
    if (parts.length != 2 || parts[0] == null || parts[1] == null) {
      return '$start · $duration 分钟';
    }
    final end = parts[0]! * 60 + parts[1]! + duration;
    String digits(int value) => value.toString().padLeft(2, '0');
    final late = end >= 1440 ? '次日 ' : '';
    return '$start 至 $late${digits(end ~/ 60 % 24)}:${digits(end % 60)}';
  }

  String? _savedMission(AssistantOperation item) {
    if (item.status != AssistantOperationStatus.succeeded || !item.isWrite) {
      return null;
    }
    try {
      final decoded = jsonDecode(item.output ?? '');
      if (decoded is! Map) return null;
      final result = decoded['result'];
      final data = result is Map ? result : decoded;
      if (data['missionId'] case final String id) return id;
      final items = data['items'];
      if (items is List && items.length == 1 && items.first is Map) {
        if ((items.first as Map)['missionId'] case final String id) return id;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String _short(String value, int limit) => value.runes.length <= limit
      ? value
      : '${String.fromCharCodes(value.runes.take(limit))}…';
}
