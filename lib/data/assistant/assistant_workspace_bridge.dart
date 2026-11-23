import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../application/assistant/assistant_attachment.dart';
import '../../application/assistant/assistant_controller.dart';
import '../../application/assistant/assistant_schedule.dart';
import '../../application/assistant/assistant_speech.dart';
import '../../application/assistant/assistant_supervision.dart';
import '../../application/errors/user_error_message.dart';
import 'assistant_voice_ticket.dart';
import 'configured_assistant_speech.dart';

/// 连接原生悬浮窗与同一个助手控制器，不持有另外一份聊天。
class AssistantWorkspaceBridge {
  AssistantWorkspaceBridge(
    this.assistant, {
    this.speech,
    this.desktopVoice,
    this.supervision,
  }) {
    _voice = AssistantVoiceChannel(
      speech: speech,
      generation: generation,
      prepare: assistant.prepareExternalEntry,
      isCurrent: () => _current,
      draftKey: () => assistant.draftKey,
      draftFor: assistant.draftFor,
      saveDraft: assistant.saveDraft,
      canWrite: _canWriteDraft,
    );
  }

  static const channel = MethodChannel('mission_book/assistant_workspace');
  static AssistantWorkspaceBridge? _active;
  static int _serial = 0;
  final AssistantController assistant;
  final ConfiguredAssistantSpeech? speech;
  final AssistantVoiceController? desktopVoice;
  late final AssistantVoiceChannel _voice;
  String? _desktopVoiceDraft;
  int _desktopVoiceRevision = 0;
  bool get desktopVoiceActive => _desktopVoiceDraft != null;

  final AssistantSupervision? supervision;
  final int generation = ++_serial;
  final _attachmentIds = Expando<String>();
  final _proposalVersions = Expando<String>();
  ({String id, String draft})? _capture;
  ({String id, Uint8List bytes, String? missionId})? _record;
  Timer? _push;
  bool _watching = false;
  bool _compact = false;
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
    desktopVoice?.addListener(_changed);
    if (desktopVoice != null) assistant.draftChanges.addListener(_changed);
    unawaited(_notifyHost('ready'));
  }

  void detach() {
    _capture = null;
    _record = null;
    supervision?.close();
    // 只释放本桥接的悬浮票据；不取消 AssistantVoiceController 正在使用的录音会话。
    unawaited(_voice.release());
    if (desktopVoiceActive) unawaited(_cancelDesktopVoice());
    _watching = false;
    _push?.cancel();
    if (!_current) return;
    _active = null;
    assistant.removeListener(_changed);
    assistant.liveActivity.removeListener(_changed);
    desktopVoice?.removeListener(_changed);
    if (desktopVoice != null) assistant.draftChanges.removeListener(_changed);
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
    if (_desktopVoiceDraft != null &&
        _desktopVoiceDraft != assistant.draftKey) {
      unawaited(_cancelDesktopVoice());
    }
    if (!_watching || !_current || _push?.isActive == true) return;
    _push = Timer(const Duration(milliseconds: 140), () {
      if (_watching && _current) {
        unawaited(_notifyHost('state', _snapshot(compact: _compact)));
      }
    });
  }

  Future<Object?> _handle(MethodCall call) async {
    final args = call.arguments as Map? ?? const {};
    if (call.method == 'beginVoice' ||
        call.method == 'voice' ||
        call.method == 'cancelVoice') {
      // 语音方法由 Dart 返回结构化结果，代次不符也不能抛异常给原生。
      if (!_current || args['generation'] != generation) {
        return switch (call.method) {
          'beginVoice' => _voice.beginUnavailable(),
          'voice' => _voice.voiceUnavailable(),
          _ => null,
        };
      }
      final ticket = args['ticket'] is String ? args['ticket'] as String : '';
      switch (call.method) {
        case 'beginVoice':
          return _voice.begin(ticket);
        case 'voice':
          final pcm = args['pcm'];
          final result = await _voice.voice(
            ticket,
            pcm is Uint8List ? pcm : Uint8List(0),
          );
          if (result['accepted'] == true) _changed();
          return result;
        default:
          // cancelVoice 幂等：票据不存在、已终结或工作区已切换都返回成功。
          await _voice.cancel(ticket);
          return null;
      }
    }
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
          final compact = desktopVoice != null && args['compact'] == true;
          if (revision == _watchRevision) {
            _watching = true;
            _compact = compact;
          }
          return _snapshot(compact: compact);
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
        case 'voiceCancel':
          if (desktopVoiceActive) await _cancelDesktopVoice();
          return null;
      }
      if (args['key'] != assistant.draftKey) throw StateError('会话已切换，请重新打开');
      switch (call.method) {
        case 'draft':
          if (args['previous'] != assistant.draft) {
            throw StateError('草稿已在另一处修改');
          }
          assistant.draft = args['text'] as String;
          return desktopVoice == null ? true : _snapshot(compact: _compact);
        case 'newSession':
          if (desktopVoice == null || assistant.isBusy) {
            throw StateError('请先结束当前操作');
          }
          await assistant.startNewSession();
          return _snapshot(compact: false);
        case 'voiceStart':
          final voice = desktopVoice;
          if (voice == null ||
              desktopVoiceActive ||
              voice.busy ||
              voice.listening ||
              assistant.isBusy) {
            throw StateError('麦克风或会话正在使用');
          }
          _desktopVoiceDraft = assistant.draftKey;
          _desktopVoiceRevision++;
          unawaited(voice.start());
          return _snapshot(compact: false);
        case 'voiceFinish':
          final voice = desktopVoice;
          final key = _desktopVoiceDraft;
          if (voice == null || key == null || key != assistant.draftKey) {
            throw StateError('录音对应的会话已切换');
          }
          final revision = _desktopVoiceRevision;
          await voice.stop();
          if (!_current || revision != _desktopVoiceRevision) return null;
          final response = {'text': voice.text, 'error': voice.error};
          await _cancelDesktopVoice();
          return response;
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
          return _snapshot(compact: false);
        case 'send':
          if (assistant.isBusy || _sending || desktopVoiceActive) {
            throw StateError('请先结束当前操作');
          }
          if (desktopVoice != null && args.containsKey('text')) {
            if (args['previous'] != assistant.draft) {
              throw StateError('草稿已在另一处修改');
            }
            assistant.draft = args['text'] as String;
          }
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
          return _snapshot(compact: false);
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

  /// 与 AssistantController 的草稿写入边界一致：当前草稿、未提交的对象草稿和
  /// 仍存在的会话可写；已删除会话的旧编号不能再被迟到文字复活。
  bool _canWriteDraft(String key) =>
      key == assistant.draftKey ||
      key.startsWith('draft:') ||
      assistant.conversations.any((conversation) => conversation.id == key);

  Future<void> _cancelDesktopVoice() async {
    _desktopVoiceDraft = null;
    _desktopVoiceRevision++;
    await desktopVoice?.cancel();
    _changed();
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
        foregroundPlatform: desktopVoice != null ? 'Windows' : 'Android',
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

  Map<String, Object?> _snapshot({bool compact = false}) {
    final activity = assistant.activity;
    final recent = (compact ? const <AgentMessage>[] : assistant.transcript)
        .reversed
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
      if (desktopVoice != null) 'compact': compact,
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
      'partial': !compact && assistant.isRunning && activity.modelRequestRunning
          ? _short(activity.text, 2600)
          : '',
      'busy': assistant.isBusy || _sending,
      'running': assistant.isRunning,
      if (desktopVoice != null) ...{
        'canUseImages': assistant.supportsImages,
        'voice': desktopVoiceActive
            ? {
                'starting': desktopVoice!.starting,
                'listening': desktopVoice!.listening,
                'busy': desktopVoice!.busy,
                'error': desktopVoice!.error,
                'seconds': desktopVoice!.elapsedSeconds,
              }
            : null,
      },
      'operations': [
        if (!compact)
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
