import 'dart:convert';
import 'dart:typed_data';

import 'package:mission_book/application/backup/backup_service.dart';
import 'package:mission_book/data/backup/local_resources_base.dart';

/// 用内存映射代替安全存储与偏好文件，核对导出勾选与恢复写回。
class FakeLocalResources implements LocalResourceStore {
  Map<String, String> settings = {
    'assistant_credential_DEEPSEEK_API_KEY': 'sk-测试密钥',
  };
  String? profile = '{"name":"本机资料"}';
  Uint8List? model = Uint8List.fromList([7, 7, 7]);
  Set<BackupResource>? requested;
  Map<String, Uint8List>? applied;

  @override
  Future<Map<String, Uint8List>> collect(Set<BackupResource> resources) async {
    requested = resources;
    final sections = <String, Object?>{};
    if (resources.contains(BackupResource.assistantSettings)) {
      sections['assistantSettings'] = settings;
    }
    if (resources.contains(BackupResource.localPreferences)) {
      sections['localProfile'] = profile;
    }
    final files = <String, Uint8List>{};
    if (sections.isNotEmpty) {
      files[localResourcesEntry] = Uint8List.fromList(
        utf8.encode(jsonEncode(sections)),
      );
    }
    if (resources.contains(BackupResource.speechModel) && model != null) {
      files['${speechEntryPrefix}model.int8.onnx'] = model!;
    }
    return files;
  }

  @override
  Future<void> apply(Map<String, Uint8List> files) async => applied = files;

  @override
  Future<int> installedSpeechBytes() async => model?.length ?? 0;
}