import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/assistant/assistant_voice_ticket.dart';

class FakePreparedVoice implements PreparedAssistantVoice {
  FakePreparedVoice(this.mode, {this.result = '明天复习布局', this.error});

  @override
  final AssistantVoiceMode mode;
  final List<Uint8List> calls = [];
  int cancels = 0;
  String result;
  AssistantVoiceFailure? error;
  Completer<String>? gate;

  @override
  Future<String> transcribe(Uint8List pcm16) async {
    calls.add(pcm16);
    if (error != null) throw error!;
    final waiting = gate;
    if (waiting != null) return waiting.future;
    return result;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

class FakeVoiceSpeech implements AssistantVoiceSpeech {
  FakeVoiceSpeech(this.preflightResult);

  VoicePreflight preflightResult;
  int preflightCalls = 0;
  Completer<void>? gate;

  @override
  Future<VoicePreflight> preflight() async {
    preflightCalls++;
    final waiting = gate;
    if (waiting != null) await waiting.future;
    return preflightResult;
  }
}

class FakeDraftHost {
  String key = 'draft:global';
  final drafts = <String, String>{};
  bool current = true;
  bool writable = true;
  Object? prepareError;
  Completer<void>? prepareGate;
  int prepares = 0;

  Future<void> prepare() async {
    prepares++;
    final waiting = prepareGate;
    if (waiting != null) await waiting.future;
    final failure = prepareError;
    if (failure != null) throw failure;
  }

  String draftFor(String key) => drafts[key] ?? '';

  void saveDraft(String key, String text) => drafts[key] = text;

  bool canWrite(String key) => writable && key == this.key;
}

void main() {
  late FakeDraftHost host;
  late FakeVoiceSpeech speech;
  late FakePreparedVoice prepared;

  setUp(() {
    host = FakeDraftHost();
    prepared = FakePreparedVoice(AssistantVoiceMode.offline);
    speech = FakeVoiceSpeech(
      VoicePreflight.ready(
        mode: AssistantVoiceMode.offline,
        prepared: prepared,
      ),
    );
  });

  AssistantVoiceChannel channel() => AssistantVoiceChannel(
    speech: speech,
    generation: 7,
    prepare: host.prepare,
    isCurrent: () => host.current,
    draftKey: () => host.key,
    draftFor: host.draftFor,
    saveDraft: host.saveDraft,
    canWrite: host.canWrite,
  );

  final pcm = Uint8List(3200);

  test('beginVoice 固定草稿与离线模式，voice 只追加文字且不重复提交', () async {
    host.key = 'draft:mission:1';
    host.drafts[host.key] = '已有文字';
    final voice = channel();

    final ready = await voice.begin('t1');
    expect(ready, {
      'ready': true,
      'mode': 'offline',
      'draftKey': 'draft:mission:1',
      'label': '离线语音',
    });
    expect(speech.preflightCalls, 1);
    expect(host.prepares, 1);

    final accepted = await voice.voice('t1', pcm);
    expect(accepted, {'accepted': true, 'draftKey': 'draft:mission:1'});
    expect(host.drafts[host.key], '已有文字\n明天复习布局');
    expect(prepared.calls, hasLength(1));

    final duplicate = await voice.voice('t1', pcm);
    expect(duplicate['accepted'], false);
    expect(duplicate['errorCode'], 'ticketInvalid');
    expect(host.drafts[host.key], '已有文字\n明天复习布局');
  });

  test('已有票据或正在准备时 beginVoice 返回 busy，不覆盖当前票据', () async {
    host.prepareGate = Completer<void>();
    final voice = channel();
    final first = voice.begin('t1');
    await pumpEventQueue();

    final duringPrepare = await voice.begin('t2');
    expect(duringPrepare['ready'], false);
    expect(duringPrepare['errorCode'], 'busy');
    expect(duringPrepare['message'], AssistantVoiceMessages.busy);

    host.prepareGate!.complete();
    expect((await first)['ready'], true);

    final afterReady = await voice.begin('t3');
    expect(afterReady['errorCode'], 'busy');
    expect(speech.preflightCalls, 1);

    await voice.cancel('t1');
    expect((await voice.begin('t4'))['ready'], true);
  });

  test('本轮模式固定：预检后改设置不切换后端', () async {
    final remote = FakePreparedVoice(AssistantVoiceMode.remote);
    final voice = channel();
    expect((await voice.begin('t1'))['mode'], 'offline');

    speech.preflightResult = VoicePreflight.ready(
      mode: AssistantVoiceMode.remote,
      prepared: remote,
    );
    final accepted = await voice.voice('t1', pcm);
    expect(accepted['accepted'], true);
    expect(prepared.calls, hasLength(1));
    expect(remote.calls, isEmpty);
  });

  test('远程票据返回远程模式与标签，识别成功后只追加原草稿', () async {
    final remote = FakePreparedVoice(AssistantVoiceMode.remote);
    speech = FakeVoiceSpeech(
      VoicePreflight.ready(mode: AssistantVoiceMode.remote, prepared: remote),
    );
    final voice = channel();
    final ready = await voice.begin('t1');
    expect(ready['ready'], true);
    expect(ready['mode'], 'remote');
    expect(ready['label'], '录音转写服务');

    expect((await voice.voice('t1', pcm))['accepted'], true);
    expect(host.drafts[host.key], '明天复习布局');
  });

  test('并发 voice 只允许第一次产生文字，第二次立即 ticketInvalid', () async {
    prepared.gate = Completer<String>();
    final voice = channel();
    await voice.begin('t1');

    final first = voice.voice('t1', pcm);
    await pumpEventQueue();
    final second = await voice.voice('t1', pcm);
    expect(second['accepted'], false);
    expect(second['errorCode'], 'ticketInvalid');

    prepared.gate!.complete('并发后只写一次');
    expect((await first)['accepted'], true);
    expect(host.drafts[host.key], '并发后只写一次');
    expect(prepared.calls, hasLength(1));
  });

  test('取消幂等，取消后 voice 返回 ticketInvalid，可重新开始新一轮', () async {
    final voice = channel();
    await voice.begin('t1');

    await voice.cancel('t1');
    await voice.cancel('t1');
    expect(prepared.cancels, 1);

    final afterCancel = await voice.voice('t1', pcm);
    expect(afterCancel['accepted'], false);
    expect(afterCancel['errorCode'], 'ticketInvalid');
    expect(host.drafts, isEmpty);

    final next = FakePreparedVoice(AssistantVoiceMode.offline);
    speech.preflightResult = VoicePreflight.ready(
      mode: AssistantVoiceMode.offline,
      prepared: next,
    );
    expect((await voice.begin('t2'))['ready'], true);
    expect((await voice.voice('t2', pcm))['accepted'], true);
    expect(host.drafts[host.key], '明天复习布局');
  });

  test('detach/工作区失效后的迟到结果被丢弃，不写任何草稿', () async {
    prepared.gate = Completer<String>();
    final voice = channel();
    await voice.begin('t1');
    final pending = voice.voice('t1', pcm);
    await pumpEventQueue();
    expect(prepared.calls, hasLength(1));

    await voice.release();
    prepared.gate!.complete('迟到文字');
    final late = await pending;
    expect(late['accepted'], false);
    expect(late['errorCode'], 'cancelled');
    expect(host.drafts, isEmpty);
    expect(prepared.cancels, 1);
  });

  test('取消进行中的识别返回 cancelled，不写部分结果', () async {
    prepared.gate = Completer<String>();
    final voice = channel();
    await voice.begin('t1');
    final pending = voice.voice('t1', pcm);
    await pumpEventQueue();

    await voice.cancel('t1');
    prepared.gate!.complete('迟到文字');
    final result = await pending;
    expect(result['accepted'], false);
    expect(result['errorCode'], 'cancelled');
    expect(result['message'], AssistantVoiceMessages.cancelled);
    expect(host.drafts, isEmpty);
  });

  test('工作区未就绪、prepare 抛错或预检期间切换会话都返回 workspaceUnavailable', () async {
    host.current = false;
    final offline = channel();
    expect(await offline.begin('t1'), {
      'ready': false,
      'mode': 'offline',
      'errorCode': 'workspaceUnavailable',
      'message': AssistantVoiceMessages.workspaceUnavailable,
    });
    expect(speech.preflightCalls, 0);

    host.current = true;
    host.prepareError = StateError('工作区重建');
    expect((await channel().begin('t1'))['errorCode'], 'workspaceUnavailable');
    expect(speech.preflightCalls, 0);

    host.prepareError = null;
    speech.gate = Completer<void>();
    final switching = channel();
    final begin = switching.begin('t1');
    await pumpEventQueue();
    host.key = 'draft:mission:2';
    speech.gate!.complete();
    final result = await begin;
    expect(result['errorCode'], 'workspaceUnavailable');
    // 预检完成后已切换会话，刚得到的后端被立即释放，不留下无主资源。
    expect(prepared.cancels, 1);
  });

  test('绑定草稿失效返回 draftChanged 并清理票据', () async {
    final voice = channel();
    await voice.begin('t1');
    host.writable = false;

    final changed = await voice.voice('t1', pcm);
    expect(changed['accepted'], false);
    expect(changed['errorCode'], 'draftChanged');
    expect(host.drafts, isEmpty);

    host.writable = true;
    expect((await voice.voice('t1', pcm))['errorCode'], 'ticketInvalid');
  });

  test('空音频返回 emptyAudio，不调用识别后端', () async {
    final voice = channel();
    await voice.begin('t1');

    final empty = await voice.voice('t1', Uint8List(2));
    expect(empty['accepted'], false);
    expect(empty['errorCode'], 'emptyAudio');
    expect(prepared.calls, isEmpty);
    expect(host.drafts, isEmpty);
  });

  test('识别失败按错误码返回并清理票据', () async {
    prepared.error = const AssistantVoiceFailure(
      'remoteAuthFailed',
      AssistantVoiceMessages.remoteAuthFailed,
    );
    final voice = channel();
    await voice.begin('t1');

    final failed = await voice.voice('t1', pcm);
    expect(failed['accepted'], false);
    expect(failed['errorCode'], 'remoteAuthFailed');
    expect(failed['message'], AssistantVoiceMessages.remoteAuthFailed);
    expect((await voice.voice('t1', pcm))['errorCode'], 'ticketInvalid');
  });

  test('预检失败返回契约错误码与文案，失败后不残留 busy', () async {
    speech.preflightResult = const VoicePreflight.failed(
      mode: AssistantVoiceMode.offline,
      failure: AssistantVoiceFailure(
        'offlineModelMissing',
        AssistantVoiceMessages.offlineModelMissing,
      ),
    );
    final voice = channel();
    final missing = await voice.begin('t1');
    expect(missing, {
      'ready': false,
      'mode': 'offline',
      'errorCode': 'offlineModelMissing',
      'message': AssistantVoiceMessages.offlineModelMissing,
    });
    expect(voice.ticketActive, isFalse);

    speech.preflightResult = VoicePreflight.ready(
      mode: AssistantVoiceMode.offline,
      prepared: prepared,
    );
    expect((await voice.begin('t2'))['ready'], true);
  });
}
