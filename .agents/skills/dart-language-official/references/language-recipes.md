# Dart 官方语言主题应用配方（不是形式文法复制）

用途：让 Agent **看得到代表性语法**，不只是读关键字表。每节以 Dart 3 的一般语法为示意；升级与新语法仍以 `dart analyze`、官方各功能页和 `pubspec.yaml` 的 language version 为准。

## 1. 变量、空安全、推断、final 与 const

```dart
String title = 'Read specification';                  // 非空 String。
String? note;                                         // 允许 null。
final trimmed = title.trim();                         // 推断为 String，不再重指向。
const minimumMinutes = 1;                             // 编译期常量。
late final String loadedTitle;                         // 延迟初始化：使用前必须已赋值。
loadedTitle = trimmed;                                 // 只能赋值一次。
final label = note ?? '(none)';                        // null 合并，不更改原值。
```

## 2. List/Set/Map 与控制流元素

```dart
final names = <String>['START', 'PAUSE'];              // 泛型 List。
final types = <String>{'START', 'PAUSE'};              // 显式泛型 Set。
final amounts = <String, int>{'extension': 30};       // 泛型 Map。
final more = <String>['RESUME'];                       // 第二组值。
final all = <String>[...names, ...more];               // 集合展开。
final nonEmpty = <String>[for (final x in all) if (x.isNotEmpty) x]; // for/if collection elements。
```

## 3. 命名参数、函数类型、闭包与 tear-off

```dart
int addMinutes(int original, {required int extension}) { // 命名参数必须提供。
  if (extension <= 0) throw ArgumentError.value(extension, 'extension'); // 输入检查。
  return original + extension;                         // 结果是新额度，不改原始计划。
}

String normalize(String input) => input.trim();        // 单表达式函数。
final String Function(String) normalizer = normalize; // 函数类型和 tear-off。
final list = [' one ', ' two '].map(normalizer).toList(); // Iterable 变换。
```

## 4. switch 表达式、模式与穷举

```dart
enum ExecutionCommand { start, pause, resume, extend, end }

String labelFor(ExecutionCommand value) => switch (value) {
  ExecutionCommand.start => '开始',
  ExecutionCommand.pause => '暂停',
  ExecutionCommand.resume => '继续',
  ExecutionCommand.extend => '延长',
  ExecutionCommand.end => '结束执行',
};

bool isValidMinutes(Object? raw) => switch (raw) {
  int value when value > 0 => true,                 // 类型模式 + guard。
  _ => false,                                      // 不认识的输入明确拒绝。
};
```

## 5. Records 与解构

```dart
({String missionId, int revisionNumber}) identity = (  // 具名 Record 类型。
  missionId: 'm-1',
  revisionNumber: 2,
);
final (:missionId, :revisionNumber) = identity;      // 解构并提取同名字段。
```

## 6. 构造器、工厂、类继承与库私有性

```dart
abstract interface class MissionRepository {         // 允许外部库实现，不允许继承实现。
  Future<bool> exists(String id);                    // 异步查询的公共契约。
}

final class MissionKey {                             // 不允许外部库继承/实现。
  const MissionKey(this.value);                      // 不变值对象可使用 const 构造。
  final String value;                                // 只读字段。
}

class MemoryMissionRepository implements MissionRepository { // 实现接口而不复用具体行为。
  @override
  Future<bool> exists(String id) async => id.isNotEmpty; // 演示替身，非真实 SQLite。
}
```

Dart 3 `interface` / `final` / `base` / `sealed` 的库边界限制并不互换。`sealed` 子类必须在同一 library 中直接定义，便于 switch 穷尽检查。详细能力见 https://dart.dev/language/modifier-reference 。

## 7. Mixins、extension 和 extension type

```dart
mixin HasLabel {                                     // mixin 提供可复用实现。
  String get label;                                  // 对应用类的接口期望。
}

extension NonBlankString on String {                 // 扩展方法，静态解析。
  bool get hasNonWhitespace => trim().isNotEmpty;     // 不改变 String 本体。
}

extension type MissionCode(String value) {           // 零额外包装的静态接口。
  bool get isValid => value.isNotEmpty;               // 新接口的行为。
}
```

扩展类型不等价普通类或扩展方法；使用前校验语言版本与表示类型公开程度。严禁把 `MissionCode` 误认为已经执行了数据库格式校验。

## 8. Future/Stream/异常及关闭资源

```dart
Future<String> fetchLabel() async {                  // 完成结果用 Future 表达。
  try {                                              // 保留异步失败的异常链。
    return await Future<String>.value('READY');       // 等待结果。
  } on FormatException {                             // 只处理明确的异常类别。
    rethrow;                                          // 保留原错误上下文。
  }
}

Stream<int> ticks() async* {                          // 异步生成器产生 Stream。
  for (var i = 0; i < 3; i++) {                        // 有界循环，避免测试无限挂起。
    yield i;                                          // 向订阅者发射一个元素。
  }
}
```

## 9. API 与库语义

- `import 'dart:async';` 导入 SDK 库；`package:...` 导入包；相对路径导入同包文件。库内部 `_member` 是**库私有**。
- `show` / `hide` 限定导入范围，`as` 为命名空间前缀，`export` 构建对外 API。
- `part` / `part of` 是同一 library 的编译单元拆分，不应为了目录管理随意使用。
- `factory` 能返回缓存实例/另一实现；不能假设每次调用都创建新对象。
- 运算符重载和 `==`/`hashCode` 应维护一致语义，尤其是用于 Set/Map key 的不可变值对象。
- `assert` 在生产构建可能不执行，不应用来保障重要领域输入/唯一约束。
- `is`, `is!` 做类型检查；`as` 是断言性转换，非法时可能抛异常；`!` 是非空断言而非非空验证。

## 10. 缺失的边角语法如何处理

这份配方并未穷举所有 token、词法和表达式文法；涉及操作符优先级、class modifier 组合、泛型子类型关系、type promotion 细节、pattern guard、协变 `covariant`、sync*/async*、deferred loading、FFI/JS 互操作时，先读取 [Dart 官方 Language](https://dart.dev/language) 相应专题，再让实际 SDK 检查。不可凭经验“猜”编译器行为。
