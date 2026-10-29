import 'speech_model_store_base.dart';
import 'speech_model_store_stub.dart'
    if (dart.library.io) 'speech_model_store_io.dart'
    as platform;

export 'speech_model_store_base.dart';

SpeechModelStore createSpeechModelStore() => platform.createSpeechModelStore();
