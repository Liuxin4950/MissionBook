import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mission_book/application/assistant/assistant_settings.dart';
import 'package:mission_book/data/assistant/configured_assistant_speech.dart';
import 'package:mission_book/data/speech/pcm_utils.dart';

void main() {
  const settings = AssistantSpeechSettings(
    useTranscription: true,
    endpoint: 'https://speech.example.invalid/v1/audio/transcriptions',
    model: 'speech-test',
  );
  test('录音以正确 WAV 和独立凭据送到配置的转写服务，得到中文', () async {
    final wav = pcmToWav(Uint8List.fromList([0, 0, 12, 0]));
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(ByteData.sublistView(wav).getUint32(24, Endian.little), 16000);
    final client = MockClient((request) async {
      expect(request.url.toString(), settings.endpoint);
      expect(request.headers['Authorization'], 'Bearer fake-voice-key');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(latin1.decode(request.bodyBytes), contains('speech.wav'));
      expect(latin1.decode(request.bodyBytes), contains('speech-test'));
      return http.Response(
        jsonEncode({'text': '明天复习布局'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    expect(
      await transcribeAudio(client, settings, 'fake-voice-key', wav),
      '明天复习布局',
    );
    client.close();
  });
  test('认证失败和系统网络失败保留真实原因，错误不能当转写文字', () async {
    final client = MockClient(
      (request) async => http.Response('private provider body', 401),
    );
    await expectLater(
      transcribeAudio(client, settings, 'fake', Uint8List(48)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('401'),
        ),
      ),
    );
    client.close();
  });
  test('纯标点或空白不算有效语音', () {
    expect(hasRecognizedSpeech('。'), isFalse);
    expect(hasRecognizedSpeech(' … ！？ '), isFalse);
    expect(hasRecognizedSpeech('明天复习布局'), isTrue);
  });
  test('录音 PCM16 转为 [-1,1] 浮点采样', () {
    final samples = pcm16ToFloat32(
      Uint8List.fromList([0x00, 0x00, 0xff, 0x7f, 0x00, 0x80]),
    );
    expect(samples, hasLength(3));
    expect(samples[0], 0);
    expect(samples[1], closeTo(32767 / 32768, 1e-6));
    expect(samples[2], -1);
  });
}
