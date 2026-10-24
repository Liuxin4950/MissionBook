import 'package:drift/drift.dart';

import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_node.dart';
import '../../domain/repositories/goal_repository.dart';
import '../local/app_database.dart';

/// 将业务对象与数据库行相互转换，执行目标的真实读写。
class DriftGoalRepository implements GoalRepository {
  DriftGoalRepository(this.database); // App 传入与任务仓储共用的数据库连接。
  final AppDatabase database;

  @override
  Future<void> create(Goal goal) async {
    goal.validateForCreation();
    // transaction 由 Drift 执行回调；读取与写入作为一次操作成功或回滚。
    await database.transaction(() async {
      // 先取得写权限，再检查编号，避免两个创建请求都以为目标尚不存在。
      await database.customStatement('UPDATE goals SET id = id WHERE 0');
      final existing = await (database.select(
        database.goals,
      )..where((row) => row.id.equals(goal.id))).getSingleOrNull();
      if (existing != null) {
        if (existing.title == goal.title &&
            existing.description == goal.description &&
            existing.why == goal.why &&
            existing.status == 'ACTIVE' &&
            existing.createdAt == goal.createdAt.millisecondsSinceEpoch &&
            existing.updatedAt == goal.updatedAt.millisecondsSinceEpoch) {
          return; // 上次可能已经成功；相同请求视为成功，不再增加一条目标。
        }
        throw StateError('这个目标编号已经用于其他内容，请重新打开创建页面');
      }
      await database
          .into(database.goals)
          .insert(
            GoalsCompanion.insert(
              id: goal.id,
              title: goal.title,
              description: Value(goal.description), // Value(null) 表示明确写入空值。
              why: Value(goal.why),
              status: const Value('ACTIVE'), // 创建只允许 ACTIVE，其他状态随编辑入口实现。
              createdAt: goal.createdAt.millisecondsSinceEpoch,
              updatedAt: goal.updatedAt.millisecondsSinceEpoch,
            ),
          );
    });
  }

  @override
  Future<List<Goal>> findAll() async {
    final rows =
        await (database.select(database.goals)
              ..where((row) => row.status.equals('DROPPED').not())
              ..orderBy([
                (row) => OrderingTerm.desc(row.createdAt),
                (row) => OrderingTerm.asc(row.id), // 同一毫秒创建时也保持稳定顺序。
              ]))
            .get();
    return [for (final row in rows) _fromRow(row)];
  }

  @override
  Future<Goal?> findById(String id) async {
    final row = await (database.select(
      database.goals,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<GoalNode>> findNodes(String goalId) => _readNodes(goalId);

  @override
  Future<GoalNode?> findNodeById(String id) async {
    final row = await (database.select(
      database.goalNodes,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _nodeFromRow(row);
  }

  @override
  Future<void> createNode(GoalNodeCreation request) async {
    request.validate();
    await database.transaction(() async {
      await _lockNodes(); // 先取得写权限，再读取同级节点和分配顺序。
      final existing = await findNodeById(request.id);
      if (existing != null) {
        if (existing.goalId == request.goalId &&
            existing.parentNodeId == request.parentNodeId &&
            existing.title == request.title &&
            existing.description == request.description &&
            existing.createdAt == request.createdAt) {
          return; // 同一创建请求已经落库，重试不会追加或恢复已归档的节点。
        }
        throw StateError('这个节点编号已经用于其他内容，请重新确认保存结果');
      }
      await _requireGoal(request.goalId);
      final nodes = await _readNodes(request.goalId);
      _requireActiveParent(request.parentNodeId, nodes);
      final siblings = nodes.where(
        (node) => node.parentNodeId == request.parentNodeId,
      ); // 同级归档项也算在内，所以新节点总是追加到真实存储顺序末尾。
      await database
          .into(database.goalNodes)
          .insert(
            GoalNodesCompanion.insert(
              id: request.id,
              goalId: request.goalId,
              parentNodeId: Value(request.parentNodeId),
              title: request.title,
              description: Value(request.description),
              orderIndex: siblings.length,
              createdAt: request.createdAt.millisecondsSinceEpoch,
              updatedAt: request.createdAt.millisecondsSinceEpoch,
            ),
          );
    });
  }

  @override
  Future<void> updateNode(
    GoalNode expected, {
    required String title,
    String? description,
  }) async {
    validateGoalNodeText(title, description);
    await database.transaction(() async {
      await _lockNodes();
      final current = await _requireNode(expected.id);
      if (current.goalId != expected.goalId ||
          current.parentNodeId != expected.parentNodeId) {
        throw StateError('节点归属发生变化，请重新打开后编辑');
      }
      if (current.title == title && current.description == description) {
        return; // 保存成功但响应丢失时，原请求再次提交仍可确认成功。
      }
      if (current.archivedAt != null) throw StateError('请先恢复节点，再编辑内容');
      if (current.title != expected.title ||
          current.description != expected.description) {
        throw StateError('节点已在其他入口修改，请确认最新内容后再保存');
      }
      await (database.update(
        database.goalNodes,
      )..where((row) => row.id.equals(current.id))).write(
        GoalNodesCompanion(
          title: Value(title),
          description: Value(description),
          updatedAt: Value(_editTime([current])),
        ),
      ); // 只更新文字与编辑时刻，不用页面旧对象覆盖排序或归档信息。
    });
  }

  @override
  Future<void> reorderNodes({
    required String goalId,
    required String? parentNodeId,
    required List<String> expectedIds,
    required List<String> orderedIds,
  }) async {
    // 先复制调用者传入的列表，防止等待数据库期间列表又被页面改动。
    final expected = List<String>.of(expectedIds);
    final requested = List<String>.of(orderedIds);
    if (expected.toSet().length != expected.length ||
        requested.toSet().length != requested.length ||
        expected.length != requested.length ||
        !expected.toSet().containsAll(requested)) {
      throw ArgumentError('调序必须包含同一组不重复的同级节点');
    }
    await database.transaction(() async {
      await _lockNodes();
      await _requireGoal(goalId);
      final nodes = await _readNodes(goalId);
      _requireActiveParent(parentNodeId, nodes);
      final siblings = nodes
          .where((node) => node.parentNodeId == parentNodeId)
          .toList();
      final currentIds = siblings.map((node) => node.id).toList();
      if (_sameIds(currentIds, requested)) return; // 同一份目标顺序重复保存不再移动一次。
      if (!_sameIds(currentIds, expected)) {
        throw StateError('同级节点已变化，请按最新顺序重新操作');
      }
      final editedAt = _editTime(siblings);
      for (var index = 0; index < requested.length; index++) {
        await (database.update(
          database.goalNodes,
        )..where((row) => row.id.equals(requested[index]))).write(
          GoalNodesCompanion(
            orderIndex: Value(index),
            updatedAt: Value(editedAt),
          ),
        ); // 整组顺序在同一事务里写入，中途失败会全部回滚。
      }
    });
  }

  @override
  Future<void> setNodeArchived(String id, {required bool archived}) async {
    await database.transaction(() async {
      await _lockNodes();
      final root = await _requireNode(id);
      final nodes = await _readNodes(root.goalId);
      if (!archived) _requireActiveParent(root.parentNodeId, nodes);
      final children = <String?, List<GoalNode>>{};
      for (final node in nodes) {
        (children[node.parentNodeId] ??= []).add(node);
      }
      final subtree = <GoalNode>[];
      final pending = <GoalNode>[root];
      while (pending.isNotEmpty) {
        final node = pending.removeLast();
        subtree.add(node);
        pending.addAll(children[node.id] ?? const []);
      } // 从所选节点往下收集后代；不用递归调用，深层大纲也不会耗尽调用栈。
      final editedAt = _editTime(subtree);
      for (final node in subtree) {
        if ((node.archivedAt != null) == archived) continue;
        await (database.update(
          database.goalNodes,
        )..where((row) => row.id.equals(node.id))).write(
          GoalNodesCompanion(
            archivedAt: Value(archived ? editedAt : null),
            updatedAt: Value(editedAt),
          ),
        ); // 归档和恢复只改节点，保留原顺序，不删除或修改任何任务历史。
      }
    });
  }

  /// 取得 SQLite 写权限，让并发新增、调序和归档逐次校验最新记录。
  Future<void> _lockNodes() =>
      database.customStatement('UPDATE goal_nodes SET id = id WHERE 0');

  Future<void> _requireGoal(String id) async {
    if (await findById(id) == null) throw StateError('目标不存在，请返回目标列表确认');
  }

  Future<GoalNode> _requireNode(String id) async {
    final node = await findNodeById(id);
    if (node == null) throw StateError('节点不存在，请刷新目标路径');
    return node;
  }

  /// 查询一个目标的全部节点，按同级顺序排列，再检查是否能组成有效的树。
  Future<List<GoalNode>> _readNodes(String goalId) async {
    final rows =
        await (database.select(database.goalNodes)
              ..where((row) => row.goalId.equals(goalId))
              ..orderBy([
                (row) => OrderingTerm.asc(row.orderIndex),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    final nodes = [for (final row in rows) _nodeFromRow(row)];
    final byId = {for (final node in nodes) node.id: node};
    final siblings = <String?, List<GoalNode>>{};
    for (final node in nodes) {
      (siblings[node.parentNodeId] ??= []).add(node);
      final visited = <String>{node.id};
      var parentId = node.parentNodeId;
      while (parentId != null) {
        final parent = byId[parentId];
        if (parent == null || !visited.add(parentId)) {
          throw StateError('节点关系异常，无法安全读取目标路径');
        }
        if (node.archivedAt == null && parent.archivedAt != null) {
          throw StateError('节点归档关系异常，无法安全读取目标路径');
        }
        parentId = parent.parentNodeId;
      }
    }
    for (final group in siblings.values) {
      for (var index = 0; index < group.length; index++) {
        if (group[index].orderIndex != index) {
          throw StateError('节点顺序异常，无法安全读取目标路径');
        }
      }
    }
    return nodes;
  }

  /// 从当前目标的节点里查找父节点，拒绝跨目标引用或挂到归档节点下面。
  void _requireActiveParent(String? parentId, List<GoalNode> nodes) {
    if (parentId == null) return;
    for (final node in nodes) {
      if (node.id == parentId) {
        if (node.archivedAt != null) throw StateError('请先恢复父节点，再进行此操作');
        return;
      }
    }
    throw StateError('父节点不存在或属于其他目标，请重新选择');
  }

  int _editTime(Iterable<GoalNode> nodes) {
    var time = DateTime.now().millisecondsSinceEpoch;
    for (final node in nodes) {
      if (node.updatedAt.millisecondsSinceEpoch > time) {
        time = node.updatedAt.millisecondsSinceEpoch;
      }
    }
    return time; // 系统时钟回拨时不把最近编辑时间写到已有编辑时间之前。
  }

  bool _sameIds(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  GoalNode _nodeFromRow(GoalNodeRow row) => GoalNode(
    id: row.id,
    goalId: row.goalId,
    parentNodeId: row.parentNodeId,
    title: row.title,
    description: row.description,
    orderIndex: row.orderIndex,
    archivedAt: row.archivedAt == null ? null : _utc(row.archivedAt!),
    createdAt: _utc(row.createdAt),
    updatedAt: _utc(row.updatedAt),
  ); // 将数据库中的整数时刻还原为业务对象使用的 DateTime。

  DateTime _utc(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);

  /// 数据库行进入业务层前，还原枚举与 UTC 时间；页面无需自行转换。
  Goal _fromRow(GoalRow row) => Goal(
    id: row.id,
    title: row.title,
    description: row.description,
    why: row.why,
    status: switch (row.status) {
      'ACTIVE' => GoalStatus.active,
      'PAUSED' => GoalStatus.paused,
      'ACHIEVED' => GoalStatus.achieved,
      'DROPPED' => GoalStatus.dropped,
      _ => throw FormatException('无法识别目标状态：${row.status}'),
    },
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
  );
}
