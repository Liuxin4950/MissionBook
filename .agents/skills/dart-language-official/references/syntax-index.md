# Dart 语言语法主题覆盖矩阵（面向 Agent）

> 标签：`LANGUAGE` 代表语言/SDK约束；`GUIDE` 代表官方讲解或推荐。**本矩阵是覆盖检查表，不是形式语法全文**。官方 Dart 3 形式规范正在更新，语言功能以具体官方语言页、语言特性提案、当前 SDK `dart analyze` 为准。

完整入口：[Dart Language](https://dart.dev/language) · [Dart 3 specification status](https://dart.dev/resources/language/spec) · [Language evolution](https://dart.dev/resources/language/evolution)

## A. 基础、词法、类型与表达式

| 检查项 | 应识别的语法与行为 | 审查关注点 | 官方来源 |
| --- | --- | --- | --- |
| 词法/保留词 | identifiers, `var`, `final`, `const`, `late`, 关键字、注释、字面量 | 与上下文关键字区分；不要臆造变量作用域 | [Keywords](https://dart.dev/language/keywords) |
| 注释/元数据 | `//`, `///`, `/* */`, `@override`, `@deprecated` | `///` 为 dartdoc；annotation 不意味着运行期检查 | [Comments](https://dart.dev/language/comments) / [Metadata](https://dart.dev/language/metadata) |
| 局部和字段声明 | `final`, `const`, `late`, typed declarations, inference | `final` 单次赋值，`const` 编译时常量；`late` 访问前赋值风险 | [Variables](https://dart.dev/language/variables) |
| 内建类型 | `int`, `double`, `num`, `String`, `bool`, `List<T>`, `Set<T>`, `Map<K,V>`, `Record` | 数值单位、`Object?` 与 `dynamic` 不是一回事 | [Built-in types](https://dart.dev/language/built-in-types) |
| 操作符 | `?.`, `??`, `??=`, `!`, `is`, `as`, `==`, `~/`, `~/=`, `..`, `?..`, `?[]` | 空值保护优于不安全断言；`==` 与 `identical` 不同 | [Operators](https://dart.dev/language/operators) |
| 表达式求值与类型 | static/dynamic types, promotions, control-flow analysis | `dynamic` 会削弱静态保证；不要“强转以消警告” | [Type system](https://dart.dev/language/type-system) |
| Null safety | `T?`、非空 `T`、flow promotion、`required`、late | 不用 `!` 隐藏应校验的输入 | [Null safety](https://dart.dev/null-safety) |
| 字符串与模板 | interpolation `$value`, `${expr}`, raw strings `r''`, multiline strings | 外部数据不要无验证直接拼 JSON/SQL | [Built-in types](https://dart.dev/language/built-in-types) |
| 集合字面量 | `<T>[]`, `<T>{}`, `<K,V>{}`, `...`, `...?`, collection `if`, collection `for` | 空 `{}` 默认是 Map，不是 Set；不要把 UI 集合当数据库事务 | [Collections](https://dart.dev/language/collections) |
| 泛型 | `<T>`, bounds `T extends X`, variance constraints | 显式表达容器类型，禁止无意识 raw generic | [Generics](https://dart.dev/language/generics) |
| 类型别名 | `typedef`, generic function type | 别名不一定构成新身份/约束类型 | [Typedefs](https://dart.dev/language/typedefs) |

## B. 控制流、函数、模式匹配

| 检查项 | 应识别的语法与行为 | 审查关注点 | 官方来源 |
| --- | --- | --- | --- |
| 控制流 | `if/else`, `for`, `for in`, `while`, `do while`, `break`, `continue`, `switch`, `assert` | `assert` 不能承担生产环境输入校验 | [Branches](https://dart.dev/language/branches) / [Loops](https://dart.dev/language/loops) |
| 函数 | 函数声明、箭头函数、闭包、词法闭包、tear-off | 参数/返回值类型、纯函数与副作用 | [Functions](https://dart.dev/language/functions) |
| 参数 | 位置、可选 `[]`、命名 `{}`、`required`、默认值 | 语义上必填的参数必须标记 `required` 或非空不可省略 | [Functions](https://dart.dev/language/functions) |
| 异常语法 | `throw`, `try`, `on`, `catch`, `finally`, `rethrow` | `Error` 不是所有业务失败的默认表示 | [Error handling](https://dart.dev/language/error-handling) |
| Records (>=3.0) | `(String, int)`, `({String id, int count})`, `$1`, `.id` | 记录是结构类型；长期业务概念不总适合匿名 Record | [Records](https://dart.dev/language/records) |
| Patterns (>=3.0) | `var (a,b)=...`; list/map/object patterns; `if-case`; `switch` pattern | 类型匹配、destructure、覆盖所有分支 | [Patterns](https://dart.dev/language/patterns) / [Pattern types](https://dart.dev/language/pattern-types) |
| Switch expressions | `switch (value) { casePattern => expr, ... }` | sealed/enum exhaustiveness；避免 `_` 吞掉新增状态 | [Branches](https://dart.dev/language/branches) |
| Iterable/Generators | `sync*`, `yield`, `yield*`, `async*`, `await for` | 懒执行/取消/错误传播；不要无限流泄漏 | [Functions](https://dart.dev/language/functions) / [Async](https://dart.dev/language/async) |

## C. 类、接口、库与组合

| 检查项 | 应识别的语法与行为 | 审查关注点 | 官方来源 |
| --- | --- | --- | --- |
| class/object | fields, getters/setters, instance/static methods, operator overloading, `this` | 数据和行为封装、可变性与不变量 | [Classes](https://dart.dev/language/classes) / [Methods](https://dart.dev/language/methods) |
| 构造器 | generative, named, const, redirecting, factory, initializer list, `super` | `factory` 可返回缓存或子类；不随意执行隐藏副作用 | [Constructors](https://dart.dev/language/constructors) |
| 继承 | `extends`, `implements`, `with`, `on`, `super`, overrides | extends 复用实现、implements 声明接口、with 混入代码的差异 | [Extend](https://dart.dev/language/extend) / [Mixins](https://dart.dev/language/mixins) |
| 类修饰符 (>=3.0) | `abstract`, `interface`, `base`, `final`, `sealed`, `mixin` | 库外继承/实现限制；不等同 Java sealed | [Class modifiers](https://dart.dev/language/class-modifiers) / [Reference](https://dart.dev/language/modifier-reference) |
| 枚举 | `enum`, enhanced enum, `.name`, enum 成员与字段 | 持久化稳定字符串编码，不依赖枚举位置 | [Enums](https://dart.dev/language/enums) |
| 扩展方法 | `extension ... on T` | 不更改原类；扩展静态解析，避免 API 命名冲突 | [Extension methods](https://dart.dev/language/extension-methods) |
| 扩展类型 | `extension type Name(T it)` | 表示类型与运行期表示差异；勿假定是运行时封装对象 | [Extension types](https://dart.dev/language/extension-types) |
| callable object | `call()` | 避免把隐式调用当作无副作用 | [Callable objects](https://dart.dev/language/callable-objects) |
| 库/导入 | `import`, `export`, `show`, `hide`, `as`, `part`, `part of`, deferred | `_` 对库私有；避免循环依赖、野生 barrel export | [Libraries](https://dart.dev/language/libraries) |
| 库 API 设计 | public/internal boundary, consistent terms | API 合同、兼容升级、命名稳定性 | [Effective Dart Design](https://dart.dev/effective-dart/design) |

## D. 并发、异步与平台

| 检查项 | 应识别的语法与行为 | 审查关注点 | 官方来源 |
| --- | --- | --- | --- |
| 异步 | `Future<T>`, `async`, `await`, `Future.wait`, error propagation | 不可忘记 await 关键写入；不能用 Future 替代事务 | [Async](https://dart.dev/language/async) / [Futures tutorial](https://dart.dev/libraries/async/async-await) |
| Stream | `Stream<T>`, `await for`, subscription, `async*` | 订阅取消、错误通道、是否广播 | [Streams tutorial](https://dart.dev/libraries/async/using-streams) |
| isolates | 消息传递、isolate memory isolation | isolate != thread/shared mutable memory；DB 连接所属隔离域 | [Concurrency](https://dart.dev/language/concurrency) |
| 互操作 | FFI、平台通道、JS/Wasm 限制 | 不将平台特定 API 静默投放其他平台 | [Interop](https://dart.dev/interop) |

## 易混淆语法：最小对照

```dart
final String title = 'Mission';                    // 编译期类型为 String，仅能赋值一次。
const int defaultMinutes = 25;                     // 编译期常量。
String? optionalReason;                            // 可空，默认 null。
final String display = optionalReason ?? '无原因'; // 仅在空时提供展示默认值。
final (String, int) entry = ('start', 1);          // Dart 3 Record 的位置字段。
final String eventName = entry.$1;                 // 按位置访问 Record。
```

## Agent 执行注意

1. 查对应主题的**官方细则**，不能只依据本表概述决定类型规则。尤其涉及类修饰符、类型提升、扩展类型/模式匹配时。
2. 解析语言级错误优先查看 IDE/Analyzer 的诊断 ID；相似文字不等于相同原因。
3. `dart format` 解决布局但不替代命名/API/业务审查。
4. 文本标注 `>=3.0` 等只表示最早所需语言版本；最新变更请看语言演进页。
