# 测试与 CI 质量门禁

来源：[Flutter testing overview](https://docs.flutter.dev/testing/overview) · [Widget test intro](https://docs.flutter.dev/cookbook/testing/widget/introduction) · [Integration tests](https://docs.flutter.dev/testing/integration-tests) · [Dart analyzer](https://dart.dev/tools/analysis) · [Dart format](https://dart.dev/tools/dart-format)

## 分层保证（非替代关系）

| 层级 | 发现的问题 | 不能证明 |
| --- | --- | --- |
| `dart format` | 风格漂移 | 类型正确或领域正确 |
| `flutter analyze` | 诊断、类型与 lint | 业务事务原子性、重启行为 |
| Unit | 纯逻辑、验证、投影、时区转换 | DB 并发唯一性 |
| Widget | UI 结构、交互、局部 semantics | 真机通知、文件沙盒等平台能力 |
| DB/迁移 | 约束、并发、事务、旧数据兼容 | Android 和 Windows 的实际系统行为 |
| Integration / real device | 主要闭环/系统协作 | 形式上的所有可能行为正确 |

## 建议质量门禁顺序

1. 安装/确认锁定 Flutter SDK 版本；检查 `pubspec.yaml` 和 `pubspec.lock`。
2. `flutter pub get`。
3. `dart format --output=none --set-exit-if-changed .`。
4. `flutter analyze --fatal-infos`（若当前 Flutter CLI 支持；否则用 `flutter analyze` 并基于退出码判定）。
5. `flutter test`。
6. **项目实际存在的**迁移测试、真实 SQLite 事务测试和压力/并发测试，显式运行；不存在则列为缺口，不能宣称覆盖。
7. 在连接的 Android/Windows 测试目标上执行 integration test；确保平台插件、通知和权限的验收记录可追踪。

`flutter test integration_test` 的运行能力取决于目标平台、集成测试配置及可用设备；不能假设通用无头 CI 有设备。

## 单测边界必测

- null、空字符串、字符串 trim、非法 enum、时钟回拨、负整数分钟、过大附件、循环 GoalNode。
- 所有允许与拒绝的事件状态跃迁、重复点击与并发写入。
- `END` 分流矩阵（self/optional/required、completed/not_completed）。
- Focus 与时钟暂停区间、原计划/当前额度/实际超时区分。
- 到期材料提交/截止补算的交错顺序、单笔事务成功与失败回滚。
- 迁移前后所有历史事件、证据修正链、关系和绝对时间不变。

## 覆盖率原则

高代码覆盖率不能证明状态机穷举。对业务不变量采用表驱动/性质测试与负路径测试；先识别**未覆盖的危险业务语义**而不是凑百分比。不可静默跳过失败测试。

## 自动化资源

- `assets/analysis_options.yaml`：官方 `flutter_lints` 基线 + 更严格类型检查。
- `scripts/check_quality.py`：跨平台可复用门禁启动器。
- `assets/flutter_quality.yml`：可复制到 `.github/workflows/` 的 CI 模板。

## Pull Request Checklist

- [ ] 变更与目标 SDK 兼容，新增语法注明最低版本。
- [ ] 领域名、单位和时区语义明确。
- [ ] 错误路径、空值、异常与幂等规则具体。
- [ ] 数据仅在明确的写入边界改变；事务测试覆盖并发。
- [ ] Widget 生命周期与订阅释放正常，async context 合法。
- [ ] 交互控制读屏命名准确，Android/Windows 实测计划明确。
- [ ] Formatter、analyzer、unit/widget/DB/migration/integration 测试结果分别报告。
- [ ] 无 `ignore_for_file` 大范围掩盖问题、无静默修正外部输入、无伪造测试结果。
