/// 记忆抽取开关；与自动总结分层独立，读取失败时由调用方回退为开启。
abstract interface class MemorySettingsStore {
  Future<bool> extractionEnabled();
  Future<void> saveExtractionEnabled(bool enabled);
}
