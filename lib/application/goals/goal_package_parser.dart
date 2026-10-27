import 'dart:convert';

import '../../domain/entities/goal_package_import.dart';

/// 按输入块处理 JSON；只保留一条任务/节点，不建立整包 AST。
///
/// nodes/children 与 missions 数组逐条交给暂存层，根对象仅留下空数组标记。
class GoalPackageParser {
  GoalPackageParser({required this.onNode, required this.onMission});
  final void Function(Map<String, Object?>, int, int?, int) onNode;
  final void Function(Map<String, Object?>, int) onMission;
  final _stack = <_Frame>[];
  Map<String, Object?>? root;
  StringBuffer? _token;
  bool _string = false;
  bool _escaped = false;
  bool _done = false;
  int _values = 0;
  int _nodeCount = 0;
  int _steps = 0;

  int get nodeCount => _nodeCount;
  int missionCount = 0;

  void add(String chunk) {
    for (var i = 0; i < chunk.length; i++) {
      final code = chunk.codeUnitAt(i);
      if (_token != null) {
        if (_string) {
          _token!.writeCharCode(code);
          if (_token!.length > 240002) _fail('LIMIT_TEXT', '文本过长');
          if (_escaped) {
            _escaped = false;
          } else if (code == 92) {
            _escaped = true;
          } else if (code == 34) {
            final raw = _token.toString();
            _token = null;
            _string = false;
            Object? value;
            try {
              value = jsonDecode(raw);
            } on FormatException {
              _fail('INVALID_JSON', '字符串或转义无效');
            }
            final text = value! as String;
            validateUnicode(text);
            if (text.runes.length > 20000) {
              _fail('LIMIT_TEXT', '文本超过 20000 个字符');
            }
            _accept(text);
          }
          continue;
        }
        if (!_delimiter(code)) {
          _token!.writeCharCode(code);
          if (_token!.length > 24) _fail('INVALID_JSON', '数字或字面量无效');
          continue;
        }
        _finishLiteral();
      }
      if (_space(code)) continue;
      if (code == 34) {
        _token = StringBuffer('"');
        _string = true;
      } else if (code == 123 || code == 91) {
        _begin(code == 91);
      } else if (code == 125 || code == 93) {
        _end(code == 93);
      } else if (code == 58) {
        if (_stack.isEmpty || _stack.last.array || _stack.last.state != 1) {
          _fail('INVALID_JSON', '冒号位置无效');
        }
        _stack.last.state = 2;
      } else if (code == 44) {
        if (_stack.isEmpty) _fail('INVALID_JSON', '逗号位置无效');
        final frame = _stack.last;
        if (frame.state != (frame.array ? 1 : 3)) {
          _fail('INVALID_JSON', '逗号位置无效');
        }
        frame.state = frame.array ? 2 : 4;
      } else {
        if (_done) _fail('INVALID_JSON', '根对象后还有内容');
        _token = StringBuffer()..writeCharCode(code);
        _string = false;
      }
    }
  }

  Map<String, Object?> finish() {
    if (_token != null) {
      if (_string) _fail('INVALID_JSON', '字符串被截断');
      _finishLiteral();
    }
    if (!_done || _stack.isNotEmpty || root == null) {
      _fail('INVALID_JSON', 'JSON 未完整结束');
    }
    return root!;
  }

  void _finishLiteral() {
    final token = _token.toString();
    _token = null;
    if (token == 'true') {
      _accept(true);
    } else if (token == 'false') {
      _accept(false);
    } else if (token == 'null') {
      _accept(null);
    } else {
      if (!RegExp(r'^-?(0|[1-9][0-9]*)$').hasMatch(token)) {
        _fail('INTEGER_TYPE', '只接受整数数字，不接受小数或指数写法');
      }
      final number = int.tryParse(token);
      if (number == null) _fail('INTEGER_TYPE', '整数超出范围');
      _accept(number);
    }
  }

  List<Object> _valuePath() {
    if (_stack.isEmpty) {
      if (_done) _fail('INVALID_JSON', '只能有一个根对象');
      return [];
    }
    final parent = _stack.last;
    if (parent.array) {
      if (parent.state != 0 && parent.state != 2) {
        _fail('INVALID_JSON', '数组元素之间缺少逗号');
      }
      final limit = _streamArray(parent.path) ? GoalImportLimits.missions : 100;
      if (parent.index >= limit) _fail('LIMIT_ITEMS', '数组元素超过限制');
      return [...parent.path, parent.index];
    }
    if (parent.state != 2) _fail('INVALID_JSON', '对象属性缺少名称或冒号');
    return [...parent.path, parent.key!];
  }

  void _begin(bool array) {
    final path = _valuePath();
    if (_stack.length >= GoalImportLimits.jsonDepth) {
      _fail('LIMIT_DEPTH', 'JSON 嵌套超过 64 层');
    }
    _count();
    final expectedArray = _arrayPath(path);
    if (array != expectedArray || (!array && _fields(path) == null)) {
      _fail('INVALID_TYPE', array ? '此处不能是数组' : '此处不能是对象', path);
    }
    int? nodeIndex;
    int? parentIndex;
    if (_nodePath(path)) {
      nodeIndex = _nodeCount++;
      if (_nodeCount > GoalImportLimits.nodes || path.length ~/ 2 > 12) {
        _fail('LIMIT_NODE_TREE', '最多 500 个节点、12 层', path);
      }
      for (final frame in _stack.reversed) {
        if (frame.nodeIndex != null) {
          parentIndex = frame.nodeIndex;
          break;
        }
      }
    }
    _stack.add(
      _Frame(
        path,
        array,
        stream: array && _streamArray(path),
        nodeIndex: nodeIndex,
        parentIndex: parentIndex,
      ),
    );
  }

  void _end(bool array) {
    if (_stack.isEmpty || _stack.last.array != array) {
      _fail('INVALID_JSON', '括号不匹配');
    }
    final frame = _stack.removeLast();
    if (frame.state != 0 && frame.state != (array ? 1 : 3)) {
      _fail('INVALID_JSON', '对象/数组被截断或存在尾逗号', frame.path);
    }
    final Object value = array ? frame.list : frame.map;
    if (frame.nodeIndex != null) {
      onNode(
        frame.map,
        frame.nodeIndex!,
        frame.parentIndex,
        frame.path.last as int,
      );
    }
    if (_missionPath(frame.path)) {
      if (utf8.encode(jsonEncode(frame.map)).length >
          GoalImportLimits.missionBytes) {
        _fail('LIMIT_MISSION_BYTES', '单条任务超过 256 KiB', frame.path);
      }
      missionCount++;
      onMission(frame.map, frame.path.last as int);
    }
    if (array && frame.path.isNotEmpty && frame.path.last == 'steps') {
      _steps += frame.list.length;
      if (_steps > GoalImportLimits.steps) {
        _fail('LIMIT_STEPS', '全包步骤超过 100000');
      }
    }
    _complete(value, frame.path);
  }

  void _accept(Object? value) {
    if (_stack.isNotEmpty &&
        !_stack.last.array &&
        (_stack.last.state == 0 || _stack.last.state == 4)) {
      if (value is! String) _fail('INVALID_JSON', '对象属性名必须为字符串');
      final frame = _stack.last;
      if (frame.map.containsKey(value)) _fail('DUPLICATE_FIELD', '重复属性：$value');
      if (!_fields(frame.path)!.contains(value)) {
        _fail('UNKNOWN_FIELD', '不允许出现属性：$value', [...frame.path, value]);
      }
      frame.key = value;
      frame.state = 1;
      // 在读值前标记，重复对象键不能被 Map 覆盖掩盖。
      frame.map[value] = null;
      return;
    }
    final path = _valuePath();
    _count();
    if (_arrayPath(path) || _fields(path) != null) {
      _fail('INVALID_TYPE', '这里需要对象或数组', path);
    }
    _complete(value, path);
  }

  void _complete(Object? value, List<Object> path) {
    if (_stack.isEmpty) {
      if (value is! Map<String, Object?>) _fail('INVALID_TYPE', '根必须是对象');
      root = value;
      _done = true;
      return;
    }
    final parent = _stack.last;
    if (parent.array) {
      if (!parent.stream) parent.list.add(value);
      parent.index++;
      parent.state = 1;
    } else {
      parent.map[parent.key!] = value;
      parent.key = null;
      parent.state = 3;
    }
  }

  void _count() {
    if (++_values > GoalImportLimits.jsonValues) {
      _fail('LIMIT_VALUES', 'JSON 值数量超过 1000000');
    }
  }

  static bool _nodePath(List<Object> path) {
    if (path.length < 2 || path.length.isOdd || path.first != 'nodes') {
      return false;
    }
    for (var i = 1; i < path.length; i++) {
      if (i.isOdd ? path[i] is! int : path[i] != 'children') return false;
    }
    return true;
  }

  static bool _missionPath(List<Object> path) =>
      path.length == 2 && path[0] == 'missions' && path[1] is int;

  static bool _streamArray(List<Object> path) =>
      path.length == 1 && (path[0] == 'nodes' || path[0] == 'missions') ||
      path.isNotEmpty &&
          path.last == 'children' &&
          _nodePath(path.sublist(0, path.length - 1));

  static bool _arrayPath(List<Object> path) =>
      _streamArray(path) ||
      path.length == 4 &&
          _missionPath(path.sublist(0, 2)) &&
          path[2] == 'executionPlan' &&
          path[3] == 'steps';

  static Set<String>? _fields(List<Object> path) {
    if (path.isEmpty) {
      return {
        'schema',
        'version',
        'packageId',
        'goal',
        'defaults',
        'nodes',
        'missions',
      };
    }
    if (path.length == 1 && path[0] == 'goal') {
      return {'title', 'description', 'why'};
    }
    if (path.length == 1 && path[0] == 'defaults') {
      return {'timeZone', 'plannedDurationMinutes', 'verificationPolicy'};
    }
    if (_nodePath(path)) return {'key', 'title', 'description', 'children'};
    if (_missionPath(path)) {
      return {
        'key',
        'nodeKey',
        'title',
        'description',
        'why',
        'verificationPolicy',
        'schedule',
        'executionPlan',
      };
    }
    if (path.length == 3 && _missionPath(path.sublist(0, 2))) {
      if (path[2] == 'schedule') {
        return {
          'scheduledDate',
          'timePolicy',
          'timeZone',
          'plannedDurationMinutes',
          'fixedStartAt',
          'evidenceDeadlineAt',
        };
      }
      if (path[2] == 'executionPlan') {
        return {'objective', 'steps', 'verificationCriteria', 'notes'};
      }
    }
    return null;
  }

  static bool _space(int c) => c == 32 || c == 9 || c == 10 || c == 13;
  static bool _delimiter(int c) =>
      _space(c) || c == 44 || c == 93 || c == 125 || c == 58;
  Never _fail(String code, String message, [List<Object>? path]) =>
      throw GoalImportException(
        code,
        '/${(path ?? (_stack.isEmpty ? [] : _stack.last.path)).join('/')}',
        message,
      );

  static void validateUnicode(String value) {
    for (var i = 0; i < value.length; i++) {
      final unit = value.codeUnitAt(i);
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++i >= value.length ||
            value.codeUnitAt(i) < 0xdc00 ||
            value.codeUnitAt(i) > 0xdfff) {
          throw const GoalImportException(
            'INVALID_UNICODE',
            '/',
            '存在未配对的 Unicode 代理字符',
          );
        }
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        throw const GoalImportException(
          'INVALID_UNICODE',
          '/',
          '存在未配对的 Unicode 代理字符',
        );
      }
    }
  }
}

class _Frame {
  _Frame(
    this.path,
    this.array, {
    required this.stream,
    this.nodeIndex,
    this.parentIndex,
  });
  final List<Object> path;
  final bool array;
  final bool stream;
  final int? nodeIndex;
  final int? parentIndex;
  final map = <String, Object?>{};
  final list = <Object?>[];
  String? key;
  int state = 0;
  int index = 0;
}
