import 'dart:typed_data';

/// 我的页面只依赖备份操作，不直接访问数据库或平台文件。
abstract interface class BackupExporter {
  Future<Uint8List> create();
}
