part of 'sherpa_speech_engine.dart';

/// 主线程与离线识别 worker 之间的消息；不携带识别器或 FFI 资源。
class SpeechModelInitRequest {
  const SpeechModelInitRequest(this.id, this.model, this.tokens);
  final int id;
  final String model;
  final String tokens;
}

class SpeechTranscribeRequest {
  const SpeechTranscribeRequest(this.id, this.samples);
  final int id;
  final Float32List samples;
}

class SpeechWorkerDisposeRequest {
  const SpeechWorkerDisposeRequest(this.id);
  final int id;
}

sealed class SpeechWorkerResponse {
  const SpeechWorkerResponse(this.id);
  final int id;
}

class SpeechModelReady extends SpeechWorkerResponse {
  const SpeechModelReady(super.id);
}

class SpeechTextResult extends SpeechWorkerResponse {
  const SpeechTextResult(super.id, this.text);
  final String text;
}

class SpeechWorkerFailure extends SpeechWorkerResponse {
  const SpeechWorkerFailure(super.id, this.message);
  final String message;
}
