import 'local_speech_backend_base.dart';
import 'speech_model_store_base.dart';
import 'local_speech_backend_stub.dart'
    if (dart.library.io) 'local_speech_backend_io.dart'
    as platform;

export 'local_speech_backend_base.dart';

LocalSpeechBackend createLocalSpeechBackend({SpeechModelStore? modelStore}) =>
    platform.createLocalSpeechBackend(modelStore: modelStore);
