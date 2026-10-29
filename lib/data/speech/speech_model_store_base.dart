/// 已安装模型的文件位置。
class SpeechModelPaths {
  const SpeechModelPaths({
    required this.directory,
    required this.model,
    required this.tokens,
  });

  final String directory;
  final String model;
  final String tokens;
}

/// 离线语音模型的安装与查找；实现按平台条件导入。
abstract interface class SpeechModelStore {
  bool get supported;
  int get downloadBytes;
  Future<SpeechModelPaths?> findInstalled();
  // 只检查已有模型；不得由录音或预热触发下载。
  Future<SpeechModelPaths> ensureInstalled();
  Future<SpeechModelPaths> download({
    required void Function(int received, int total) onProgress,
  });
  void cancelDownload();
}

class SpeechModelDownloadCancelled implements Exception {
  const SpeechModelDownloadCancelled();
}

/// 固定版本的文件清单；下载地址、长度和摘要必须一起更新。
class SpeechModelFile {
  const SpeechModelFile(this.name, this.bytes, this.sha256, this.url);
  final String name;
  final int bytes;
  final String sha256;
  final String url;
}

const _source =
    'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/2365baeacb507f821a0c8120fcee3d484dba7a07';
const senseVoiceFiles = [
  SpeechModelFile(
    'model.int8.onnx',
    239233841,
    'c71f0ce00bec95b07744e116345e33d8cbbe08cef896382cf907bf4b51a2cd51',
    '$_source/model.int8.onnx',
  ),
  SpeechModelFile(
    'tokens.txt',
    315894,
    'f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc',
    '$_source/tokens.txt',
  ),
];
