import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/errors/user_error_message.dart';
import 'package:mission_book/domain/entities/evidence.dart';

void main() {
  const fallback = '保存未完成，请重试';
  test('业务冲突和输入错误保留中文原因，不暴露 Dart 前缀', () {
    expect(
      userErrorMessage(const EvidenceConflict('记录已变化，请刷新'), fallback: fallback),
      '记录已变化，请刷新',
    );
    expect(
      userErrorMessage(ArgumentError('计划时长必须大于 0 分钟'), fallback: fallback),
      '计划时长必须大于 0 分钟',
    );
  });
  test('平台详情、地址、路径和凭据不会进入用户错误提示', () {
    for (final error in [
      StateError('读取失败 https://example.invalid/private'),
      StateError(r'读取失败 C:\private\config.json'),
      StateError('连接失败 apiKey=secret-value'),
      StateError('连接失败 sk-sensitive-credential'),
      Exception('provider body secret'),
    ]) {
      expect(userErrorMessage(error, fallback: fallback), fallback);
    }
  });
}
