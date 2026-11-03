import 'dart:typed_data';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'backup_archive.dart';

Future<Uint8List?> pickBackupFile() async {
  final file = await FileSelectorPlatform.instance.openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'MissionBook 完整备份',
        extensions: ['zip'],
        mimeTypes: ['application/zip'],
      ),
    ],
    confirmButtonText: '校验备份',
  );
  if (file == null) return null;
  if (!file.name.toLowerCase().endsWith('.zip') ||
      await file.length() > maxBackupBytes) {
    throw const FormatException('请选择不超过 256 MiB 的 ZIP 备份');
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (builder.length + chunk.length > maxBackupBytes) {
      throw const FormatException('备份超过 256 MiB');
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}
