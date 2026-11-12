import 'dart:typed_data';

import '../../application/backup/backup_service.dart';

/// 备份包内本机资源的固定入口名；归档白名单与恢复共用同一份常量。
const localResourcesEntry = 'local-resources.json';
const speechEntryPrefix = 'speech/';

/// 收集与写回数据库之外的本机资源。备份服务只认相对路径和字节，
/// 不认识安全存储、偏好文件或模型目录。
abstract interface class LocalResourceStore {
  /// 按勾选类别收集；未勾选或本机不存在的类别不出现在结果里。
  Future<Map<String, Uint8List>> collect(Set<BackupResource> resources);

  /// 写回包内实际存在的类别；包里没有的类别保持当前设备值。
  Future<void> apply(Map<String, Uint8List> files);

  /// 已安装并通过校验的离线语音模型体积；未安装为 0。
  Future<int> installedSpeechBytes();
}