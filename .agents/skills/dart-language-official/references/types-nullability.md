# 类型系统、Null Safety、泛型与不可变语义

官方来源：[Type system](https://dart.dev/language/type-system) · [Null safety](https://dart.dev/null-safety) · [Generics](https://dart.dev/language/generics) · [Variables](https://dart.dev/language/variables) · [Extension types](https://dart.dev/language/extension-types)

## 必查规则

- `(LANGUAGE)` `String` 不允许包含 `null`；需要可空时声明 `String?`。Null safety 是静态类型约束，但动态检查、FFI、平台互操作仍需验证。
- `(LANGUAGE)` `Object` 与 `Object?` 不同：前者非空；`dynamic` 则允许不经静态检查调用成员，不应与类型安全替代。
- `(LANGUAGE)` `late` 允许延迟初始化，但未初始化的访问可能运行期失败；不应用来规避正确构造器设计。
- `(LANGUAGE)` `final` 保证绑定不再改指向，并**不**保证引用的 `List` 可变内容不变；`const` 在编译期创建常量对象，适用条件不同。
- `(GUIDE)` 既不要每处重复显然可推断的局部类型，也不要在公共 API/解析边界依赖不明确的 `dynamic`。
- `(TEAM)` 跨外部 JSON/数据库边界，采用显式可判定类型检查，不用强制 `as T` 冒充验证；遇到未知枚举不得静默默认最接近值。

## 含义示例

```dart
String requireTitle(Object? candidate) {                       // 原始输入边界允许未知类型。
  if (candidate is! String) {                                  // 明确检查输入类型。
    throw const FormatException('title must be a string');      // 使用可解释的格式异常。
  }
  final String title = candidate.trim();                        // 输入规范化只处理空白。
  if (title.isEmpty) {                                          // 区分空字符串与缺失。
    throw const FormatException('title must not be empty');     // 阻止无意义数据进入领域。
  }
  return title;                                                  // 返回非空且非空白标题。
}
```

### 不要这样写

```dart
String unsafeTitle(dynamic x) => (x as String?)!;              // 可能抛错且未校验 trim 后是否为空。
```

`String` 不等于业务层的 `NonBlankTitle`。语法和类型系统不会自动证明“非空白”。需要通过构造器/工厂/验证逻辑建立不变量。单位同理：`int` 不能表达“分钟是正整数”，`DateTime` 不会自动保证排期时区。

## 类型守卫审查要点

- 是否区分 `null`（未知/缺席）与空字符串（用户明确填空）？
- `T?` 是否代表真实业务可选而非开发偷懒？
- 是否存在对网络/JSON/数据库原始 `dynamic` 的隐式转换？
- `as` 是否只用于已经确证的类型，还是掩盖输入可能不合规？
- `List.unmodifiable`、`Map.unmodifiable` 等是否需要用于保护外部可见数据？浅层不可变不能深度冻结所有对象。
- `enum.index` 是否被用于持久化？若是，改为稳定显式编码（业务约定）。
- 是否充分审查了整数溢出、单位、毫秒/秒转换、UTC 与日历日期不同的语义？
