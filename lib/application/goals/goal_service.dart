import 'dart:async';
import 'package:uuid/uuid.dart';

import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_node.dart';
import '../../domain/repositories/goal_repository.dart';

/// 组织目标的创建和查询；页面不直接调用数据库仓储。
class GoalService {
  GoalService(this.repository);
  final GoalRepository repository; // 只依赖接口，App 决定传入哪种存储实现。
  final _uuid = const Uuid();
  final _changes =
      StreamController<void>.broadcast(); // 创建允许多个页面同时监听的控制器，服务通过它发送事件。
  Stream<void> get changes => _changes.stream; // 定义一个公开的只读属性，让页面拿到这个控制器提供的事件流。

  /// 把表单文字整理成一次固定的创建请求，此时还没有写入数据库。
  Goal prepareCreation({
    required String title,
    String? description,
    String? why,
  }) {
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
      isUtc: true,
    ); // 与数据库一样保留到毫秒，失败重试时不会因精度不同误判为另一份内容。
    final goal = Goal(
      id: _uuid.v4(),
      title: title.trim(),
      description: _optionalText(description),
      why: _optionalText(why),
      status: GoalStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    goal.validateForCreation();
    return goal; // 页面保留这个对象；重试沿用编号、时间及原内容。
  }

  /// 保存固定请求，成功提交之后再让列表重新查询。
  Future<void> create(Goal goal) async {
    goal.validateForCreation();
    await repository.create(goal); // 失败会把异常传回页面，此时不发送成功通知。
    _notify();
  }

  Future<List<Goal>> findAll() => repository.findAll();
  Future<Goal?> findById(String id) => repository.findById(id);
  Future<List<GoalNode>> findNodes(String goalId) =>
      repository.findNodes(goalId);
  Future<GoalNode?> findNodeById(String id) => repository.findNodeById(id);

  /// 把节点编辑框的输入整理成固定请求，交回页面保留，尚未保存到数据库。
  GoalNodeCreation prepareNodeCreation({
    required String goalId,
    required String title,
    String? parentNodeId,
    String? description,
  }) {
    final request = GoalNodeCreation(
      id: _uuid.v4(), // 同一次填写只生成一次，失败后用原请求重试。
      goalId: goalId,
      parentNodeId: parentNodeId,
      title: title.trim(),
      description: _optionalText(description),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
        isUtc: true,
      ),
    );
    request.validate();
    return request;
  }

  Future<void> createNode(GoalNodeCreation request) async {
    await repository.createNode(request); // await 等仓储提交成功，失败则直接把异常交回编辑框。
    _notify(); // 成功后向已监听 changes 的页面发送事件，让它们重新查询。
  }

  Future<void> updateNode(
    GoalNode expected, {
    required String title,
    String? description,
  }) async {
    await repository.updateNode(
      expected, // 页面原先读到的节点，用于检查文字是否已被别处修改。
      title: title.trim(),
      description: _optionalText(description),
    );
    _notify();
  }

  /// 根据页面读到的全部同级节点，把所选节点与前一个或后一个有效节点交换。
  Future<void> moveNode(
    GoalNode node, {
    required List<GoalNode> siblings,
    required bool upward,
  }) async {
    final ordered = List<GoalNode>.of(siblings)
      ..sort((left, right) => left.orderIndex.compareTo(right.orderIndex));
    if (ordered.any(
      (sibling) =>
          sibling.goalId != node.goalId ||
          sibling.parentNodeId != node.parentNodeId,
    )) {
      throw ArgumentError('只能调整同一目标下的同级节点');
    }
    final from = ordered.indexWhere((item) => item.id == node.id);
    if (from < 0 || ordered[from].archivedAt != null) {
      throw StateError('节点已变化，请刷新后重新操作');
    }
    final step = upward ? -1 : 1;
    var to = from + step;
    while (to >= 0 && to < ordered.length && ordered[to].archivedAt != null) {
      to += step; // 归档项占有存储位置，但不会成为界面上的上移/下移目标。
    }
    if (to < 0 || to >= ordered.length) return;
    final expectedIds = [for (final item in ordered) item.id];
    ordered[from] = ordered[to];
    ordered[to] = node;
    await repository.reorderNodes(
      goalId: node.goalId,
      parentNodeId: node.parentNodeId,
      expectedIds: expectedIds,
      orderedIds: [for (final item in ordered) item.id],
    ); // 仓储将整组新顺序保存，页面不逐条拼接数据库更新。
    _notify();
  }

  Future<void> archiveNode(String id) async {
    await repository.setNodeArchived(id, archived: true);
    _notify();
  }

  Future<void> restoreNode(String id) async {
    await repository.setNodeArchived(id, archived: false);
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null); // 控制器仍开放时，向它添加一次无内容的事件。
  }

  Future<void> dispose() => _changes.close(); // 由创建服务的 App 统一释放。

  String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
