part of 'assistant_tools.dart';

/// 工具名称、输入结构和目录装配；业务处理由准备器与执行器承担。
class _AssistantToolCatalog {
  _AssistantToolCatalog(this._owner);
  final AssistantTools _owner;
  List<AgentTool> build(List<AgentTool> extraTools) {
    final catalog = [
      AssistantTools._tool(
        'manageMissions',
        '按明确编号或目标、截止日期、阶段统一批量取消或物理删除任务，最多10000项。delete 永久删除任务及其执行/材料，独立来源记录和聊天保留，不能恢复；cancel 只处理未开始任务并报告跳过数量；reset 仅撤销误标的已结束任务，把原执行和材料归档，追加自选排期回到未开始，可随后 updateMission/planMissions 改期。必须来自用户明确意图，不能用补记完成替代删除。宿主固定完整范围并原子校验，不需逐条先读。',
        AssistantTools._schema(
          {
            'action': AssistantTools._enum('操作', ['cancel', 'delete', 'reset']),
            'all': AssistantTools._boolean('仅当用户明确要求全部任务时为 true；否则必须给出编号或筛选条件'),
            'missionIds': {
              'type': 'array',
              'items': {'type': 'string'},
              'minItems': 1,
              'maxItems': 10000,
              'uniqueItems': true,
            },
            'goalId': AssistantTools._string('可选目标编号'),
            'beforeDate': AssistantTools._string(
              '计划日期早于 YYYY-MM-DD，不含当日；今天以前取宿主今天',
            ),
            'phase': AssistantTools._enum(
              '可选当前完整阶段',
              MissionPhase.values.map((p) => p.name).toList(),
            ),
          },
          required: ['action'],
        ),
        (input, context) async {
          final prepared = _owner._resolveCall(context.callId);
          final proposal =
              prepared.snapshot['maintenance'] as MissionMaintenanceProposal;
          try {
            return AssistantTools._success(
              maintenanceOperationPage(
                await _owner._missions.applyMaintenance(
                  proposal,
                  operationId: context.idempotencyKey,
                ),
                0,
              ),
            );
          } on MissionEditConflict catch (error) {
            throw ToolRejected('conflict', error.message);
          } on ArgumentError catch (error) {
            throw ToolRejected(
              'invalid_input',
              error.message?.toString() ?? '无效操作',
            );
          }
        },
      ),
      AssistantTools._tool(
        'completeHistory',
        '用户明确要求补记历史任务已完成时使用。按目标和截止日期（不含当日）一次预览并提交最多10000项；仅处理历史自报任务；无记录时补记完成，执行中或暂停时正常结束，跳过已结束、已取消及有材料要求的任务。保留原计划，记录本次补报的时间和依据，不伪造过去的开始时间或专注时长。不得因时间已过自行推断完成；不能用 START+END 批量绕过。',
        AssistantTools._schema(
          {
            'goalId': AssistantTools._string('目标编号；先查真实目标'),
            'beforeDate': AssistantTools._string('截止日期 YYYY-MM-DD，不含这一天，不晚于今天'),
            'statement': AssistantTools._string('用户明确提供完成事实的原话片段，不得改写或编造'),
          },
          required: ['goalId', 'beforeDate', 'statement'],
        ),
        _owner._completeHistory,
      ),
      AssistantTools._tool(
        'createGoalOutline',
        '一次创建新目标及1–20个分层大纲节点，最多4层。整份可编辑、删除子树并按权限一次确认，全部成功或全部回滚。适用于把新学习目标拆成阶段；不用于向已有目标追加，不创建任务、不标记掌握。随后按用户时间使用 planMissions 安排任务。',
        AssistantGoalOutline.schema,
        _owner._createGoalOutline,
      ),
      AssistantTools._tool(
        'retryMission',
        '从已结束或已取消任务创建新的再次尝试，保留来源关联、归属、材料策略和原始记录。先用 getMission 核对来源，询问新日期；强制材料需用户提供本次新截止，不复制旧截止。不把原任务改回未开始。',
        AssistantTools._schema(
          {
            'missionId': AssistantTools._string('来源任务稳定编号'),
            'scheduledDate': AssistantTools._string('新尝试日期 YYYY-MM-DD'),
            'plannedMinutes': AssistantTools._integer('计划分钟，省略沿用来源'),
            'title': AssistantTools._string('新尝试名称，省略沿用来源'),
            'objective': AssistantTools._string('改进后的具体目标，省略沿用来源'),
            'steps': AssistantTools._stringArray('改进后的完整步骤，省略沿用来源'),
            'notes': AssistantTools._string('新备注，省略沿用来源'),
            'fixedStartLocal': AssistantTools._string('可选 HH:mm；省略为自选'),
            'evidenceDeadlineLocal': AssistantTools._string(
              '仅强制材料必填 YYYY-MM-DD HH:mm，应用时区',
            ),
          },
          required: ['missionId', 'scheduledDate'],
        ),
        _owner._retryMission,
      ),
      AssistantTools._tool(
        'planMissions',
        '集中安排或改期 1–100 项任务，先查真实任务和相关日期安排。整份计划可编辑、移除条目；冲突时整份零写入，成功后返回真实结果。多个任务优先用本工具。',
        AssistantScheduleService.schema,
        _owner._applyPlan,
      ),
      AssistantTools._tool(
        'getGoal',
        '默认分页返回全部目标概览；指定 goal 读取目标与节点，node 限定子树，mission 指定任务，* 分页读取范围内任务评价。',
        AssistantTools._schema({
          'goal': AssistantTools._string('目标ID或精确名称'),
          'node': AssistantTools._string('节点ID或精确名称'),
          'mission': AssistantTools._string('任务ID或精确名称，*表示当前范围任务索引'),
          'offset': AssistantTools._offsetSchema,
        }),
        _owner._goalQuery,
        readOnly: true,
      ),
      AssistantTools._tool(
        'getMission',
        '按ID或名称读任务事实；省略任务分页搜索。批量操作前统计优先 summaryOnly=true，返回完整范围精确总量与阶段计数，不必逐页读全。支持计划日期、截止日期、阶段筛选。',
        AssistantTools._schema({
          'mission': AssistantTools._string('任务ID或精确名称'),
          'search': AssistantTools._string('标题搜索'),
          'date': AssistantTools._string('计划日期 YYYY-MM-DD'),
          'beforeDate': AssistantTools._string('计划日期早于 YYYY-MM-DD，不含当天'),
          'phase': AssistantTools._enum(
            '当前完整阶段',
            MissionPhase.values.map((p) => p.name).toList(),
          ),
          'summaryOnly': AssistantTools._boolean('仅返回完整范围精确计数，不读取逐条正文'),
          'goalId': AssistantTools._string('目标ID'),
          'nodeId': AssistantTools._string('节点ID'),
          'offset': AssistantTools._offsetSchema,
        }),
        _owner._missionQuery,
        readOnly: true,
      ),
      AssistantTools._tool(
        'getSchedule',
        '分页读取指定日期日程，默认今天。',
        AssistantTools._schema({
          'date': AssistantTools._string('YYYY-MM-DD'),
          'offset': AssistantTools._offsetSchema,
        }),
        _owner._scheduleQuery,
        readOnly: true,
      ),
      AssistantTools._tool(
        'getMissionContent',
        '按需读取任务的长文字片段，每次最多2000字符，steps为JSON数组原文。',
        AssistantTools._schema(
          {
            'missionId': AssistantTools._string('任务编号'),
            'field': AssistantTools._enum('正文字段', [
              'objective',
              'steps',
              'notes',
              'description',
              'why',
            ]),
            'offset': AssistantTools._offsetSchema,
          },
          required: ['missionId', 'field'],
        ),
        _owner._missionContent,
        readOnly: true,
      ),
      AssistantTools._tool(
        'updateGoal',
        '修改目标名称、说明或原因，未提供字段保持原值。',
        AssistantTools._schema(
          {
            'goalId': AssistantTools._string('目标编号'),
            'title': AssistantTools._string('新名称'),
            'description': AssistantTools._string('新说明；空串清空'),
            'why': AssistantTools._string('新原因；空串清空'),
            'desireLevel': {
              'type': ['integer', 'null'],
              'minimum': 1,
              'maximum': 5,
              'description': '希望程度1～5；null清空',
            },
          },
          required: ['goalId'],
        ),
        _owner._updateGoal,
      ),
      AssistantTools._tool(
        'updateGoalNode',
        '修改节点名称或说明，未提供字段保持原值，不改变归属与任务。',
        AssistantTools._schema(
          {
            'nodeId': AssistantTools._string('节点编号'),
            'title': AssistantTools._string('新名称'),
            'description': AssistantTools._string('新说明；空串清空'),
          },
          required: ['nodeId'],
        ),
        _owner._updateNode,
      ),
      AssistantTools._tool(
        'getMissionRecords',
        '分页读取任务已保存的执行事件、失败原因或材料索引，区分事实与AI判断。',
        AssistantTools._schema(
          {
            'missionId': AssistantTools._string('任务编号'),
            'section': AssistantTools._enum('记录范围；revoked 是已撤销历史，不参与当前结果', [
              'execution',
              'failures',
              'evidence',
              'revoked',
            ]),
            'offset': AssistantTools._offsetSchema,
          },
          required: ['missionId', 'section'],
        ),
        (input, _) async => _owner._readResult(
          await _owner._unifiedReader.records(
            input['missionId'] as String,
            input['section'] as String,
            offset: input['offset'] as int? ?? 0,
          ),
        ),
        readOnly: true,
      ),
      AssistantTools._tool(
        'getMaterial',
        '按材料稳定编号分段读取正式文本、代码或手动记录；不把材料当成AI评价。',
        AssistantTools._schema(
          {
            'evidenceId': AssistantTools._string('材料编号'),
            'offset': AssistantTools._offsetSchema,
          },
          required: ['evidenceId'],
        ),
        (input, _) async => _owner._readResult(
          await _owner._unifiedReader.evidenceContent(
            input['evidenceId'] as String,
            offset: input['offset'] as int? ?? 0,
          ),
        ),
        readOnly: true,
      ),
      AssistantTools._tool(
        'createMission',
        '创建一个自报完成任务。保存前需通过宿主授权；同一调用身份只创建一份。',
        AssistantTools._schema(
          {
            'title': AssistantTools._string('任务名称'),
            'scheduledDate': AssistantTools._string('计划日期 YYYY-MM-DD'),
            'plannedMinutes': AssistantTools._integer('计划分钟数，大于 0'),
            'objective': AssistantTools._string('具体目标；省略时使用任务名称'),
            'fixedStartLocal': AssistantTools._string(
              '可选固定开始时间 HH:mm；不提供则为自选任务',
            ),
            'goalId': AssistantTools._string('可选目标编号'),
            'goalNodeId': AssistantTools._string('可选节点编号，必须同时提供 goalId'),
            'steps': AssistantTools._stringArray('可选行动步骤'),
            'notes': AssistantTools._string('可选方案备注'),
            'description': AssistantTools._string('可选任务说明'),
            'why': AssistantTools._string('可选安排原因'),
          },
          required: ['title', 'scheduledDate', 'plannedMinutes'],
        ),
        _owner._createMission,
      ),
      AssistantTools._tool(
        'rescheduleMission',
        '修改尚未开始任务的日期、时长或固定开始时间。使用确认前的任务快照检查冲突。',
        AssistantTools._schema(
          {
            'missionId': AssistantTools._string('任务稳定编号'),
            'scheduledDate': AssistantTools._string('新计划日期 YYYY-MM-DD'),
            'plannedMinutes': AssistantTools._integer('新计划分钟数；省略保持不变'),
            'timePolicy': AssistantTools._enum('FIXED 或 FLEXIBLE', [
              'FIXED',
              'FLEXIBLE',
            ]),
            'fixedStartLocal': AssistantTools._string('FIXED 时的开始时间 HH:mm'),
          },
          required: ['missionId', 'scheduledDate'],
        ),
        _owner._rescheduleMission,
      ),
      AssistantTools._tool(
        'updateMission',
        '修改尚未开始任务的名称、具体目标、步骤、备注、说明或安排。未提供字段保持原值。',
        AssistantTools._schema(
          {
            'missionId': AssistantTools._string('任务编号'),
            'title': AssistantTools._string('新名称'),
            'objective': AssistantTools._string('新具体目标'),
            'steps': AssistantTools._stringArray('完整新步骤列表；空数组清空'),
            'notes': AssistantTools._string('新备注；空串清空'),
            'description': AssistantTools._string('新说明；空串清空'),
            'why': AssistantTools._string('新原因；空串清空'),
            'scheduledDate': AssistantTools._string('新日期 YYYY-MM-DD'),
            'plannedMinutes': AssistantTools._integer('计划分钟'),
            'timePolicy': AssistantTools._enum('时间方式', ['FIXED', 'FLEXIBLE']),
            'fixedStartLocal': AssistantTools._string('HH:mm'),
          },
          required: ['missionId'],
        ),
        (input, context) => _owner._rescheduleMission(
          input,
          context,
          operation: 'updateMission',
        ),
      ),
      AssistantTools._tool(
        'executeMission',
        '提交 START/PAUSE/RESUME/EXTEND/END。END 的报告结果必须来自用户明确陈述。',
        AssistantTools._schema(
          {
            'missionId': AssistantTools._string('任务稳定编号'),
            'type': AssistantTools._enum('执行动作', [
              'START',
              'PAUSE',
              'RESUME',
              'EXTEND',
              'END',
            ]),
            'minutes': AssistantTools._integer('EXTEND 增加的分钟数'),
            'reason': AssistantTools._string('PAUSE 的可选原因'),
            'report': AssistantTools._enum('END 用户报告', [
              'COMPLETED',
              'NOT_COMPLETED',
            ]),
            'submitOptionalEvidence': AssistantTools._boolean(
              '可选材料任务 END 时是否稍后提交',
            ),
            'userReasonCategory': AssistantTools._string('未完成原因分类'),
            'userReasonText': AssistantTools._string('未完成原因说明'),
          },
          required: ['missionId', 'type'],
        ),
        _owner._executeMission,
      ),
      AssistantTools._tool(
        'cancelMission',
        '取消尚未开始的任务；保留原排期与方案，不伪造 END。',
        AssistantTools._schema(
          {'missionId': AssistantTools._string('任务稳定编号')},
          required: ['missionId'],
        ),
        _owner._cancelMission,
      ),
      AssistantTools._tool(
        'createGoal',
        '创建一个正在推进的目标。',
        AssistantTools._schema(
          {
            'title': AssistantTools._string('目标名称'),
            'description': AssistantTools._string('可选说明'),
            'why': AssistantTools._string('可选原因'),
            'desireLevel': {'type': 'integer', 'minimum': 1, 'maximum': 5},
          },
          required: ['title'],
        ),
        _owner._createGoal,
      ),
      AssistantTools._tool(
        'createGoalNode',
        '在有效目标下创建一个大纲节点。',
        AssistantTools._schema(
          {
            'goalId': AssistantTools._string('目标编号'),
            'title': AssistantTools._string('节点名称'),
            'parentNodeId': AssistantTools._string('可选父节点编号'),
            'description': AssistantTools._string('可选节点说明'),
          },
          required: ['goalId', 'title'],
        ),
        _owner._createGoalNode,
      ),
    ];
    // 扩展工具不得覆盖正式工具；重复名称由 AgentLoop 明确拒绝。
    catalog.addAll(
      extraTools.map(
        (t) => AgentTool(
          definition: t.definition,
          readOnly: t.readOnly,
          execute: (i, c) async {
            if (t.readOnly && _owner._readCharacters >= 64000) {
              return _owner._budgetFailure(
                'read_budget',
                '本轮读取已达上限，请根据现有摘要回答；已读范围见 read 字段。',
              );
            }
            final output = _owner._formatOutput(
              await t.execute(i, c),
              includeTimeContext: t.readOnly,
            );
            if (t.readOnly) {
              if (_owner._readCharacters + output.text.length > 64000) {
                return _owner._budgetFailure(
                  'read_budget',
                  '本轮剩余读取额度不足，请缩小范围；已读范围见 read 字段。',
                );
              }
              _owner._readCharacters += output.text.length;
            }
            return output;
          },
        ),
      ),
    );
    return [
      for (final tool in catalog)
        AgentTool(
          definition: tool.definition,
          readOnly: tool.readOnly,
          execute: (input, context) async {
            final output = await tool.execute(input, context);
            if (tool.readOnly) _owner._recordRead(tool.definition.name, output);
            return _owner._formatOutput(
              output,
              includeTimeContext: tool.readOnly,
            );
          },
        ),
    ];
  }
}
