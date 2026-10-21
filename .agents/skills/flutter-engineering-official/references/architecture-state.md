# Flutter 官方架构建议：分层、SSOT、状态与业务工作流

参考：[Guide](https://docs.flutter.dev/app-architecture/guide) · [Recommendations](https://docs.flutter.dev/app-architecture/recommendations) · [Common concepts](https://docs.flutter.dev/app-architecture/concepts) · [Case study](https://docs.flutter.dev/app-architecture/case-study)

**重要：Flutter 官方明确说明这些是推荐，不是不可变的语言规则。**

## 推荐权重

| 项目 | 官方强度 | Agent 操作 |
| --- | --- | --- |
| UI 层与 Data 层分离 | Strongly recommend | 页面不含领域事实写入逻辑 |
| Repository 模式 | Strongly recommend | 隔离来源，Repository 管自己的数据真相 |
| Views + ViewModels (MVVM) | Strongly recommend | View 按 UI state 显示，事件交给 ViewModel 命令 |
| 不变数据模型 | Strongly recommend | 对外提供只读快照，不让多个位置任意修改 |
| 单向数据流 | Strongly recommend | 事件流向写入层，事实/投影向 UI 层发布 |
| GoRouter | Recommend | 现有路由适合无需强改，评估新增导航复杂性 |
| Command | Recommend | 避免把复杂异步写动作塞进 Widget 回调 |
| `ChangeNotifier` 与 `Listenable` | Conditional | 按规模、现有依赖选择，不是强制 |
| Domain layer / UseCases | Conditional | 跨多个 repository 或复杂可复用逻辑时增设 |

## 目录布局示例（团队实现建议）

```text
lib/
  main.dart
  ui/
    core/
      widgets/
    missions/
      mission_screen.dart
      mission_view_model.dart
  domain/
    mission.dart
    mission_workflow.dart
    mission_phase_projection.dart
  data/
    repositories/
      mission_repository.dart
    services/
      mission_database_service.dart
  routing/
    app_router.dart
```

此结构适合复杂本地业务，但**不意味着**官方有唯一目录模板。官方更注重依赖方向与职责分离。

## 职责清单

| 角色 | 可以做 | 不应做 |
| --- | --- | --- |
| View | 渲染、输入、布局/动画、轻量展示逻辑 | SQL、业务事件追加、未知模型推断 |
| ViewModel | 维护不可变 UI State、调用 Command/Workflow、合成展示数据 | 成为唯一业务真相、私自覆盖持久化事件 |
| Workflow/UseCase | 领域校验、跨仓库操作编排、事务边界（本项目特定） | 绑定 Widget 的 BuildContext、无条件出网 |
| Repository | 提供数据真相、持久化读写抽象、数据转换 | 与其他 Repository 相互形成环式依赖 |
| Service | 访问 SQLite/平台插件/外部 API 等具体边界 | 返回伪造业务状态、替代领域决策 |

## 状态与原子性

- 本地 `ChangeNotifier` 的 bool `isRunning` 只是 UI 投影，不能抵抗两个事件回调的事务竞争。
- 单向数据流和不可变模型降低局部复杂性，不自动实现真正的数据库隔离级别、幂等约束、跨进程唯一性。
- 离线优先应用应将持久化事件作为恢复依据，ViewModel 重新读取事实重建界面状态。

## 依赖注入

优先构造器注入：Widget -> ViewModel <- Workflow <- Repository <- DBService。Service 生命周期由应用启动或 composition root 管理；避免隐式全局 `GetIt`/singleton 无法替换而影响测试。官方样例建议 Provider，但这是其例程选择而非 SDK 语言强制。
