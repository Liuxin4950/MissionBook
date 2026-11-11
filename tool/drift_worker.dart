import 'package:drift/wasm.dart';

// 使用项目锁定的 drift/sqlite3 依赖编译 Worker，确保它与应用及 WASM 接口匹配。
// 编译命令见 docs/开发/Web浏览器预览.md；生成结果放入 web/drift_worker.js。
void main() {
  WasmDatabase.workerMainForOpen();
}
