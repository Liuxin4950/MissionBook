import 'dart:typed_data';

/// 把录音插件的 16-bit little-endian PCM 转成 SenseVoice 需要的 [-1, 1] 浮点采样。
Float32List pcm16ToFloat32(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final samples = Float32List(bytes.length ~/ 2);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return samples;
}
