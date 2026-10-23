import '../entities/execution_event.dart'; // 引入执行事件及动作、报告结果枚举。
import '../entities/mission.dart'; // 引入任务的材料策略枚举。
import '../entities/mission_phase.dart'; // 任务阶段是计算结果，不是数据库字段。
import '../entities/failure_record.dart';

/// 校验一条执行事件的字段组合；不修改对象，也不读写数据库。
///
/// validateExecutionEvent 意为“校验执行事件”，由业务入口主动调用。
/// verificationPolicy 来自所属任务，决定结束事件是否需要材料选择。
/// 通过时正常返回；不合法时抛出 ArgumentError（参数错误异常），中断当前调用。
/// 序号连续、前后时间、动作流转、排期归属及操作重试由后续时间线和事务校验。
// void 表示不返回结果值；调用方通过“是否抛出异常”判断本次检查是否通过。
void validateExecutionEvent(
  ExecutionEvent event, // event：调用方传入的那一条事件对象。
  VerificationPolicy verificationPolicy, // verificationPolicy：所属任务的材料策略。
) {
  // id 是事件编号，missionId 是所属任务编号。
  // trim() 去掉首尾空白，isEmpty 判断是否为空，|| 表示任一条件成立。
  // 这里只检查，不会把去空白后的文本重新写回原对象。
  if (event.id.trim().isEmpty || event.missionId.trim().isEmpty) {
    throw ArgumentError('事件编号和任务编号不能为空');
  }
  if (event.sequence < 1) {
    // sequence：这条事件在同一任务中的顺序号。
    throw ArgumentError('事件序号必须从 1 开始');
  }
  // occurredAt 是发生时刻；isUtc 判断是否采用 UTC，! 表示取反。
  if (!event.occurredAt.isUtc) {
    throw ArgumentError('事件发生时刻必须使用 UTC');
  }

  // 可空类型只约束“允许 null”；这里根据动作进一步约束何时必填。
  // type 是动作类型；ExecutionEventType.start 表示“开始”。
  if (event.type == ExecutionEventType.start) {
    // revisionId：从事件中取出的排期版本编号；final 表示之后不重新赋值。
    final revisionId = event.scheduleRevisionId;
    if (revisionId == null || revisionId.trim().isEmpty) {
      throw ArgumentError('开始事件必须指定排期版本');
    }
  } else if (event.scheduleRevisionId != null) {
    throw ArgumentError('只有开始事件可以携带排期版本');
  }

  // extend 表示“延长”；grantedDurationMinutes 是本次增加的分钟数。
  if (event.type == ExecutionEventType.extend) {
    final minutes = event.grantedDurationMinutes;
    // minutes 是取出的分钟数；null 表示没有提供，<= 0 表示非正数。
    if (minutes == null || minutes <= 0) {
      throw ArgumentError('延长事件必须提供大于 0 的增加分钟数');
    }
  } else if (event.grantedDurationMinutes != null) {
    throw ArgumentError('只有延长事件可以携带增加分钟数');
  }

  // pause 表示“暂停”，reason 是暂停原因；!= 表示不等于，&& 表示条件同时成立。
  if (event.type != ExecutionEventType.pause && event.reason != null) {
    throw ArgumentError('只有暂停事件可以携带暂停原因');
  }

  // end 表示“结束”；userReportedResult 是用户报告的完成或未完成结果。
  if (event.type == ExecutionEventType.end) {
    if (event.userReportedResult == null) {
      throw ArgumentError('结束事件必须提供用户报告结果');
    }
  } else if (event.userReportedResult != null) {
    throw ArgumentError('只有结束事件可以携带用户报告结果');
  }

  // 只有这一种组合需要 true/false；其他组合必须用 null 表达“不适用”。
  // needsEvidenceChoice 意为“需要材料选择”，保存下面三个条件共同判断的结果。
  // completed 是“报告完成”，optionalEvidence 是“材料可选策略”。
  final needsEvidenceChoice =
      event.type == ExecutionEventType.end &&
      event.userReportedResult == UserReportedResult.completed &&
      verificationPolicy == VerificationPolicy.optionalEvidence;
  if (needsEvidenceChoice) {
    // submitOptionalEvidence：true 稍后提交材料，false 直接结束，null 未提供选择。
    if (event.submitOptionalEvidence == null) {
      throw ArgumentError('可选材料任务报告完成时，必须选择是否稍后提交材料');
    }
  } else if (event.submitOptionalEvidence != null) {
    throw ArgumentError('当前事件不适用可选材料选择，必须为空');
  }
  // 执行到这里表示字段检查通过，控制权返回调用方，继续其后面的代码。
}

/// 校验一个任务的完整执行时间线；调用方必须按 sequence 升序提供全部事件。
///
/// validateExecutionHistory 意为“校验执行历史”。这里只读取传入的事实，
/// 不排序、不改数据、不保存；关系或流转不合法时抛出 ArgumentError。
/// 排期版本归属、全局唯一执行中任务、END 失败记录和重试身份仍需事务校验。
void validateExecutionHistory(
  Mission mission, // mission：这条时间线所属的任务，提供编号、取消事实和材料策略。
  List<ExecutionEvent> events, // events：该任务的完整事件列表，不是分页或某天的片段。
) {
  // 只需要判断是否合法时，调用同一核心，忽略返回的执行状态即可。
  _replayExecutionHistory(mission, events);
}

/// derivePreEndMissionPhase 意为“推导执行结束前的任务阶段”。
///
/// 当前只处理待开始、执行中、已暂停、已取消。完整六阶段还需要报告、
/// 正式材料和失败记录等关联事实；不得把此入口作为完整任务阶段查询。
/// 合法 END 暂抛 UnsupportedError；非法时间线仍先抛 ArgumentError。
MissionPhase derivePreEndMissionPhase(
  Mission mission, // 调用方提供的所属任务。
  List<ExecutionEvent> events, // 按序号排列的完整执行事件。
) {
  // replay 意为“按顺序重放、推演”。核心一次遍历同时校验并算出执行状态。
  // 这里不再先校验一次，然后另外循环计算同一套动作转换。
  final state = _replayExecutionHistory(mission, events);
  return _phaseBeforeEnd(mission, state);
}

/// 当前已开放的自报任务闭环；材料策略的 END 不在此入口猜测关闭。
/// 未完成必须有同一次 END 原子提交的失败事实，查询遇到缺失明确报错。
MissionPhase deriveSelfReportMissionPhase(
  Mission mission,
  List<ExecutionEvent> events,
  List<FailureRecord> failures,
) {
  final state = _replayExecutionHistory(mission, events);
  if (state != _ExecutionState.ended) {
    if (failures.isNotEmpty) throw const FormatException('尚未结束的任务不应有失败记录');
    return _phaseBeforeEnd(mission, state);
  }
  if (mission.verificationPolicy != VerificationPolicy.selfReport) {
    throw UnsupportedError('材料任务的结束阶段尚未接入');
  }
  final end = events.last;
  final notCompleted =
      end.userReportedResult == UserReportedResult.notCompleted;
  if (notCompleted) {
    if (failures.length != 1 ||
        failures.single.missionId != mission.id ||
        failures.single.trigger != 'USER_MARKED_NOT_COMPLETED' ||
        failures.single.occurredAt != end.occurredAt) {
      throw const FormatException('未完成报告缺少一致的失败记录');
    }
  } else if (failures.isNotEmpty) {
    throw const FormatException('自报完成任务不应有失败记录');
  }
  return MissionPhase.closed;
}

MissionPhase _phaseBeforeEnd(Mission mission, _ExecutionState state) {
  if (mission.cancelledAt != null) {
    // 核心已经确认取消任务没有事件，因此不会用取消掩盖非法历史。
    return MissionPhase.cancelled;
  }

  // 将执行状态映射为任务阶段；这里只转换结果，不再处理每一条动作。
  switch (state) {
    case _ExecutionState.notStarted:
      return MissionPhase.notStarted;
    case _ExecutionState.running:
      return MissionPhase.running;
    case _ExecutionState.paused:
      return MissionPhase.paused;
    case _ExecutionState.ended:
      // 执行已结束，不足以确定材料是否仍待提交，所以不能直接返回 closed。
      throw UnsupportedError('此函数只推导结束前阶段；END后的阶段需要报告及材料相关事实');
  }
}

// 唯一的时间线推演核心；名称前的 _ 表示仅本规则库内部使用。
// 返回 _ExecutionState 执行状态，供上面两个入口按各自用途使用。
// 包含合法 END 的历史也能校验通过；是否支持完整阶段由查询入口单独说明。
_ExecutionState _replayExecutionHistory(
  Mission mission,
  List<ExecutionEvent> events,
) {
  if (mission.id.trim().isEmpty) {
    throw ArgumentError('任务编号不能为空');
  }
  if (mission.cancelledAt != null && events.isNotEmpty) {
    throw ArgumentError('已取消的任务不能存在执行事件');
  }

  // state 是检查过程中记住的执行状态；每次调用都从“未开始”重新推演。
  // 它不是数据库字段，也不是包含材料流程的完整任务阶段。
  var state = _ExecutionState.notStarted;
  var expectedSequence = 1; // expectedSequence：接下来应当出现的事件序号。
  DateTime? previousTime; // previousTime：上一条事件的发生时刻；第一条前为空。
  final eventIds = <String>{}; // eventIds：本次已见过的事件编号集合，用来发现重复。

  // for-in 按调用方提供的列表顺序，每次取出一条事件交给下面的检查。
  for (final event in events) {
    // 复用已有函数；单条字段检查失败时，异常直接向调用方传递。
    validateExecutionEvent(event, mission.verificationPolicy);
    if (event.missionId != mission.id) {
      throw ArgumentError('时间线中混入了其他任务的事件');
    }
    // Set.add 添加新编号时返回 true；编号已存在时返回 false。
    if (!eventIds.add(event.id)) {
      throw ArgumentError('时间线中的事件编号不能重复');
    }
    if (event.sequence != expectedSequence) {
      throw ArgumentError('事件序号必须连续，本条应为 $expectedSequence');
    }
    // isBefore 表示“早于”；允许相同时刻，由 sequence 区分顺序。
    if (previousTime != null && event.occurredAt.isBefore(previousTime)) {
      throw ArgumentError('事件发生时刻不能早于上一条，请检查系统时间');
    }

    // switch 根据本条动作选中一个分支；依据“动作发生前”的状态决定是否允许。
    switch (event.type) {
      case ExecutionEventType.start: // 开始：只能从未开始进入执行中。
        if (state != _ExecutionState.notStarted) {
          throw ArgumentError('只有未开始的任务才能开始');
        }
        state = _ExecutionState.running;
        break; // 当前动作检查完成，离开 switch，继续下面的公共处理。
      case ExecutionEventType.pause: // 暂停：只能从执行中进入暂停。
        if (state != _ExecutionState.running) {
          throw ArgumentError('只有执行中的任务才能暂停');
        }
        state = _ExecutionState.paused;
        break;
      case ExecutionEventType.resume: // 继续：只能从暂停恢复为执行中。
        if (state != _ExecutionState.paused) {
          throw ArgumentError('只有暂停的任务才能继续');
        }
        state = _ExecutionState.running;
        break;
      case ExecutionEventType.extend: // 延长：执行中、暂停均可，但不改变状态。
        if (state != _ExecutionState.running &&
            state != _ExecutionState.paused) {
          throw ArgumentError('只有执行中或暂停的任务才能延长');
        }
        break;
      case ExecutionEventType.end: // 结束：执行中、暂停均可，之后不再允许动作。
        if (state != _ExecutionState.running &&
            state != _ExecutionState.paused) {
          throw ArgumentError('只有执行中或暂停的任务才能结束');
        }
        state = _ExecutionState.ended;
        break;
    }

    // 本条全部通过后才前进，供下一轮检查使用；不会修改 event 本身。
    expectedSequence += 1;
    previousTime = event.occurredAt;
  }
  return state; // 把推演结果交回调用方；不会保存成另一份可写状态。
}

// 名称前的 _ 表示仅当前 Dart 库内部使用；这里只服务于上面的推演过程。
enum _ExecutionState {
  notStarted, // 未开始。
  running, // 执行中。
  paused, // 已暂停。
  ended, // 已有结束事件；不等于材料流程也已完成。
}
