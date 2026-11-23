import 'dart:async';
import 'dart:typed_data';

/// 悬浮录音的识别方式。票据开始后固定，不因中途修改设置而切换。
enum AssistantVoiceMode {
  offline('离线语音'),
  remote('录音转写服务');

  const AssistantVoiceMode(this.label);

  /// 原生录音面板直接展示的名称，不根据本地路径或 Key 猜测。
  final String label;
}

/// 契约冻结的中文可展示原因；原生直接显示，不自行拼接地址或凭据。
abstract final class AssistantVoiceMessages {
  static const offlineModelMissing = '离线语音模型未安装，请先在语音设置中下载';
  static const offlineModelInvalid = '离线语音模型已损坏，请重新下载';
  static const offlineModelInitFailed = '离线语音模型未能加载，请重试或改用文字';
  static const remoteConfigMissing = '录音转写服务未配置，请先完成语音设置';
  static const remoteConfigInvalid = '录音转写服务配置无效，请检查语音设置';
  static const workspaceUnavailable = '助手正在准备，请稍后重试';
  static const busy = '语音正在使用中，请稍后重试';

  static const ticketInvalid = '语音会话已失效，请重新开始录音';
  static const draftChanged = '原草稿已失效，请重新开始语音';
  static const emptyAudio = '录音为空或长度超出限制，请重新录音';
  static const remoteRequestFailed = '录音转写服务请求失败，请检查服务地址、模型或网络';
  static const remoteAuthFailed = '录音转写服务拒绝访问，请检查独立转写 API Key';
  static const transcribeTimeout = '语音识别超时，请重试或改用文字';
  static const noSpeech = '没有识别到清晰语音，请重试或改用文字';
  static const cancelled = '已取消录音';
  static const failed = '语音识别失败，请重试或改用文字';
}

/// 一次识别的非敏感失败：错误码供原生判断状态，文案供直接展示。
class AssistantVoiceFailure implements Exception {
  const AssistantVoiceFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AssistantVoiceFailure($code)';
}

/// 契约上限：16 kHz 单声道 PCM16，最多 30 秒，偶数长度。
const minVoicePcmBytes = 3200;
const maxVoicePcmBytes = 960000;

bool isValidVoicePcm(Uint8List pcm) =>
    pcm.length >= minVoicePcmBytes &&
    pcm.length <= maxVoicePcmBytes &&
    !pcm.length.isOdd;

/// 预检成功后固化的本轮后端；凭据与客户端只留在 Dart 内存。
abstract interface class PreparedAssistantVoice {
  AssistantVoiceMode get mode;

  /// 识别本轮 PCM；失败时抛出 [AssistantVoiceFailure]。
  Future<String> transcribe(Uint8List pcm16);

  /// 取消可取消的网络资源；本地 worker 的迟到结果由调用方丢弃。幂等。
  Future<void> cancel();
}

/// 语音后端预检结果：成功携带已固定的后端，失败只携带非敏感原因。
class VoicePreflight {
  const VoicePreflight.ready({
    required this.mode,
    required PreparedAssistantVoice this.prepared,
  }) : failure = null;

  const VoicePreflight.failed({
    required this.mode,
    required AssistantVoiceFailure this.failure,
  }) : prepared = null;

  final AssistantVoiceMode mode;
  final AssistantVoiceFailure? failure;
  final PreparedAssistantVoice? prepared;

  bool get ready => failure == null && prepared != null;
}

/// 录音前预检/准备入口；不下载、不上传音频、不申请麦克风。
abstract interface class AssistantVoiceSpeech {
  Future<VoicePreflight> preflight();
}

/// 一次悬浮录音票据；只存在于 Dart 内存，不向原生暴露服务配置或凭据。
class _VoiceTicket {
  _VoiceTicket({
    required this.ticket,
    required this.draftKey,
    required this.mode,
    required this.generation,
    required this.prepared,
  });

  final String ticket;
  final String draftKey;
  final AssistantVoiceMode mode;
  final int generation;
  final PreparedAssistantVoice prepared;
  bool consumed = false;
  bool cancelled = false;
}

/// 把 beginVoice / voice / cancelVoice 的票据状态机从通道分发中拆出，
/// 便于在不接触原生与真实模型的情况下验证幂等、迟到结果和模式固定。
class AssistantVoiceChannel {
  AssistantVoiceChannel({
    required AssistantVoiceSpeech? speech,
    required Future<void> Function() prepare,
    required bool Function() isCurrent,
    required String Function() draftKey,
    required String Function(String key) draftFor,
    required void Function(String key, String text) saveDraft,
    required bool Function(String key) canWrite,
    required this.generation,
  }) : _speech = speech,
       _prepare = prepare,
       _isCurrent = isCurrent,
       _draftKey = draftKey,
       _draftFor = draftFor,
       _saveDraft = saveDraft,
       _canWrite = canWrite;

  static const workspaceUnavailableFailure = AssistantVoiceFailure(
    'workspaceUnavailable',
    AssistantVoiceMessages.workspaceUnavailable,
  );
  static const busyFailure = AssistantVoiceFailure(
    'busy',
    AssistantVoiceMessages.busy,
  );

  final AssistantVoiceSpeech? _speech;
  final Future<void> Function() _prepare;
  final bool Function() _isCurrent;
  final String Function() _draftKey;
  final String Function(String key) _draftFor;
  final void Function(String key, String text) _saveDraft;
  final bool Function(String key) _canWrite;
  final int generation;

  _VoiceTicket? _ticket;
  bool _preparing = false;
  String? _preparingTicket;
  bool _prepareCancelled = false;
  AssistantVoiceMode? _lastMode;

  bool get ticketActive => _ticket != null || _preparing;

  /// 工作区代次已被拒时仍按契约返回结构，不把异常抛给原生。
  Map<String, Object?> beginUnavailable({
    AssistantVoiceMode mode = AssistantVoiceMode.offline,
  }) => _beginFailure(mode, workspaceUnavailableFailure);

  Map<String, Object?> voiceUnavailable() =>
      _voiceFailure(workspaceUnavailableFailure);

  /// 准备并固定本轮草稿、模式与后端；失败不抛异常。
  Future<Map<String, Object?>> begin(String ticket) async {
    final active = _ticket;
    if (_preparing || active != null) {
      return _beginFailure(
        active?.mode ?? _lastMode ?? AssistantVoiceMode.offline,
        busyFailure,
      );
    }
    final speech = _speech;
    if (speech == null) {
      return beginUnavailable(mode: _lastMode ?? AssistantVoiceMode.offline);
    }
    _preparing = true;
    _preparingTicket = ticket;
    _prepareCancelled = false;
    try {
      try {
        await _prepare();
      } catch (_) {
        return beginUnavailable(mode: _lastMode ?? AssistantVoiceMode.offline);
      }
      if (!_isCurrent() || _prepareCancelled) {
        return beginUnavailable(mode: _lastMode ?? AssistantVoiceMode.offline);
      }
      final boundDraft = _draftKey();
      final VoicePreflight preflight;
      try {
        preflight = await speech.preflight();
      } catch (_) {
        return beginUnavailable(mode: _lastMode ?? AssistantVoiceMode.offline);
      }
      _lastMode = preflight.mode;
      final prepared = preflight.prepared;
      final failure = preflight.failure;
      if (!_isCurrent() || _prepareCancelled) {
        await prepared?.cancel();
        return beginUnavailable(mode: preflight.mode);
      }
      if (failure != null || prepared == null) {
        return _beginFailure(
          preflight.mode,
          failure ??
              const AssistantVoiceFailure(
                'offlineModelInitFailed',
                AssistantVoiceMessages.offlineModelInitFailed,
              ),
        );
      }
      // 预检可能较慢；期间切换会话则本轮身份已不再可靠，不能把文字写回旧草稿。
      if (_draftKey() != boundDraft) {
        await prepared.cancel();
        return beginUnavailable(mode: preflight.mode);
      }
      final session = _VoiceTicket(
        ticket: ticket,
        draftKey: boundDraft,
        mode: preflight.mode,
        generation: generation,
        prepared: prepared,
      );
      _ticket = session;
      return _beginReady(session);
    } finally {
      _preparing = false;
      _preparingTicket = null;
      _prepareCancelled = false;
    }
  }

  /// 使用本轮固定的后端识别，并只追加到票据绑定的草稿。重复提交返回 ticketInvalid。
  Future<Map<String, Object?>> voice(String ticket, Uint8List pcm) async {
    final session = _ticket;
    if (session == null ||
        session.ticket != ticket ||
        session.generation != generation ||
        session.consumed) {
      return _voiceFailure(
        const AssistantVoiceFailure(
          'ticketInvalid',
          AssistantVoiceMessages.ticketInvalid,
        ),
      );
    }
    if (!_isCurrent()) {
      _ticket = null;
      await _cancelPrepared(session);
      return voiceUnavailable();
    }
    if (!_canWrite(session.draftKey)) {
      _ticket = null;
      await _cancelPrepared(session);
      return _voiceFailure(
        const AssistantVoiceFailure(
          'draftChanged',
          AssistantVoiceMessages.draftChanged,
        ),
      );
    }
    if (!isValidVoicePcm(pcm)) {
      _ticket = null;
      await _cancelPrepared(session);
      return _voiceFailure(
        const AssistantVoiceFailure(
          'emptyAudio',
          AssistantVoiceMessages.emptyAudio,
        ),
      );
    }
    // 先占位再识别：并发或重复的第二次提交只能得到 ticketInvalid。
    session.consumed = true;
    try {
      final text = (await session.prepared.transcribe(pcm)).trim();
      if (session.cancelled || !identical(_ticket, session)) {
        return _voiceFailure(
          const AssistantVoiceFailure(
            'cancelled',
            AssistantVoiceMessages.cancelled,
          ),
        );
      }
      if (!_isCurrent()) return voiceUnavailable();
      if (!_canWrite(session.draftKey)) {
        return _voiceFailure(
          const AssistantVoiceFailure(
            'draftChanged',
            AssistantVoiceMessages.draftChanged,
          ),
        );
      }
      if (text.isEmpty) {
        return _voiceFailure(
          const AssistantVoiceFailure(
            'noSpeech',
            AssistantVoiceMessages.noSpeech,
          ),
        );
      }
      final prior = _draftFor(session.draftKey);
      _saveDraft(session.draftKey, prior.isEmpty ? text : '$prior\n$text');
      return {'accepted': true, 'draftKey': session.draftKey};
    } on AssistantVoiceFailure catch (failure) {
      return _voiceFailure(failure);
    } catch (_) {
      return _voiceFailure(
        const AssistantVoiceFailure('failed', AssistantVoiceMessages.failed),
      );
    } finally {
      if (identical(_ticket, session)) _ticket = null;
    }
  }

  /// 使票据失效并取消可取消的网络资源；票据不存在也返回成功（幂等）。
  Future<void> cancel(String ticket) async {
    final session = _ticket;
    if (session != null && session.ticket == ticket) {
      session.cancelled = true;
      session.consumed = true;
      _ticket = null;
      await _cancelPrepared(session);
    }
    if (_preparing && _preparingTicket == ticket) {
      _prepareCancelled = true;
    }
  }

  /// 工作区 detach/重建：本实例的所有票据作废，迟到结果不再写入任何草稿。
  Future<void> release() async {
    _prepareCancelled = true;
    final session = _ticket;
    _ticket = null;
    if (session != null) {
      session.cancelled = true;
      await _cancelPrepared(session);
    }
  }

  Future<void> _cancelPrepared(_VoiceTicket session) async {
    try {
      await session.prepared.cancel();
    } catch (_) {
      // 取消本身是清理动作；失败不能反过来影响原生关闭窗口。
    }
  }

  Map<String, Object?> _beginReady(_VoiceTicket session) => {
    'ready': true,
    'mode': session.mode.name,
    'draftKey': session.draftKey,
    'label': session.mode.label,
  };

  Map<String, Object?> _beginFailure(
    AssistantVoiceMode mode,
    AssistantVoiceFailure failure,
  ) => {
    'ready': false,
    'mode': mode.name,
    'errorCode': failure.code,
    'message': failure.message,
  };

  Map<String, Object?> _voiceFailure(AssistantVoiceFailure failure) => {
    'accepted': false,
    'errorCode': failure.code,
    'message': failure.message,
  };
}
