import 'dart:convert';

import '../missions/mission_service.dart';
import 'memory_service.dart';

/// 本轮注入的记忆与原因；供后续用户控制面展示，不参与事实判断。
class MemoryContextResult {
  const MemoryContextResult(this.text, this.injected);
  final String text;
  final List<Map<String, Object?>> injected;
  bool get isEmpty => text.isEmpty;
}

/// 五层数据装配成稳定、目标、话题与观察块：纯读、按 token 预算截断、失败返回空块。
class MemoryContextAssembler {
  MemoryContextAssembler({required this.memory, this.missions});
  final MemoryService memory;
  final MissionService? missions;

  static const tokenBudget = 800;
  static const stableTokenBudget = 230;
  static const goalTokenBudget = 150;
  static const topicTokenBudget = 150;
  static const episodeTokenBudget = 100;
  static const procedureTokenBudget = 150;
  static const goalBriefTokenBudget = 100;
  static const candidateLimit = 24;
  static const observationTokenBudget = 90;
  static const entryMaxRunes = 160;
  static const briefMissionLimit = 8;

  Future<MemoryContextResult> assemble({String? goalId, String? topic}) async {
    try {
      final keyword = topic?.trim() ?? '';
      // 空目标键只匹配全局行，避免其他目标挤满稳定块的有界候选。
      final stableResult = await memory.query(
        goalId: '',
        limit: 12,
        candidateLimit: 12,
        layer: 'identity',
        certainty: 'stated',
      );
      final semanticResult = await memory.query(
        goalId: '',
        limit: candidateLimit,
        candidateLimit: candidateLimit,
        layer: 'semantic',
        certainty: 'stated',
      );
      final goalResult = goalId == null
          ? const <String, Object?>{'items': <Map<String, Object?>>[]}
          : await memory.query(
              goalId: goalId,
              limit: candidateLimit,
              candidateLimit: candidateLimit,
            );
      final observationResult = await memory.query(
        goalId: goalId ?? '',
        limit: candidateLimit,
        candidateLimit: candidateLimit,
        certainty: 'unverified',
      );
      final identities = (stableResult['items'] as List)
          .cast<Map<String, Object?>>();
      final semantics = (semanticResult['items'] as List)
          .cast<Map<String, Object?>>();
      // 交错供给，避免身份候选长期占满稳定预算、语义事实再次饿死。
      final items = <Map<String, Object?>>[
        for (
          var index = 0;
          index < identities.length || index < semantics.length;
          index++
        ) ...[
          if (index < identities.length) identities[index],
          if (index < semantics.length) semantics[index],
        ],
      ];
      final goalItems = (goalResult['items'] as List)
          .cast<Map<String, Object?>>();
      final observationItems = (observationResult['items'] as List)
          .cast<Map<String, Object?>>();
      final used = <String>{};
      final injected = <Map<String, Object?>>[];
      final blocks = <String, Object?>{};
      var omitted = false;
      bool inScope(Map<String, Object?> item) =>
          item['goal_id'] == null ||
          (goalId != null && item['goal_id'] == goalId);

      List<Map<String, Object?>> fill(
        Iterable<Map<String, Object?>> candidates,
        int budget,
        String block,
        String reason,
      ) {
        final out = <Map<String, Object?>>[];
        var spent = 0;
        for (final item in candidates) {
          if (!inScope(item) || used.contains(item['id'])) continue;
          final entry = _entry(item);
          final cost = estimateTokens(jsonEncode(entry)) + 1;
          if (spent + cost > budget) {
            omitted = true;
            continue;
          }
          final proposed = {
            ...blocks,
            block: [...out, entry],
            // 始终预留省略标记，后续块不会使已接受的条目超预算。
            'omitted': true,
          };
          if (estimateTokens(jsonEncode(proposed)) > tokenBudget) {
            omitted = true;
            continue;
          }
          spent += cost;
          used.add(item['id'] as String);
          out.add(entry);
          blocks[block] = out;
          injected.add({
            'id': item['id'],
            'layer': item['layer'],
            'certainty': item['certainty'],
            'block': block,
            'reason': reason,
          });
        }
        return out;
      }

      bool confirmed(Map<String, Object?> item) =>
          item['certainty'] == 'stated' && item['layer'] != 'observation';
      final episodes = await memory.episodes(
        goalId: goalId ?? '',
        search: keyword,
        limit: 20,
      );
      final procedures = await memory.procedures(
        goalId: goalId ?? '',
        search: keyword,
        limit: 20,
      );
      final derived = {
        for (final item in [...episodes, ...procedures]) item['id']: item,
      };
      // 话题块直接用检索入口，并补齐流程步骤，避免去重后丢失派生字段。
      final topicItems = keyword.isEmpty
          ? const <Map<String, Object?>>[]
          : ((await memory.query(
                      search: keyword,
                      goalId: goalId ?? '',
                      limit: candidateLimit,
                      candidateLimit: candidateLimit,
                    ))['items']
                    as List)
                .cast<Map<String, Object?>>();
      // 先消耗话题命中，再供给每轮可用的全局事实，避免无关事实挤掉命中。
      if (keyword.isNotEmpty) {
        fill(
          topicItems
              .where((item) => confirmed(item) && item['layer'] != 'identity')
              .map((item) => derived[item['id']] ?? item),
          topicTokenBudget,
          'topic',
          'topic_match',
        );
      }
      fill(
        items.where(
          (item) =>
              item['goal_id'] == null &&
              confirmed(item) &&
              (item['layer'] == 'identity' || item['layer'] == 'semantic'),
        ),
        stableTokenBudget,
        'stable',
        'stable_core',
      );
      if (goalId != null) {
        fill(
          goalItems.where(
            (item) =>
                confirmed(item) &&
                item['goal_id'] == goalId &&
                item['layer'] != 'procedural' &&
                item['layer'] != 'episodic',
          ),
          goalTokenBudget,
          'goal',
          'goal_scope',
        );
      }
      fill(
        episodes.where(confirmed),
        episodeTokenBudget,
        'episode',
        'episode_summary',
      );
      fill(
        procedures.where(confirmed),
        procedureTokenBudget,
        'procedure',
        'procedure_steps',
      );
      fill(
        [
          ...observationItems,
          ...items,
          ...goalItems,
          ...topicItems,
          ...episodes,
          ...procedures,
        ].where(
          (item) =>
              item['certainty'] != 'stated' || item['layer'] == 'observation',
        ),
        observationTokenBudget,
        'unverified',
        'unverified_observation',
      );
      final brief = <Map<String, Object?>>[];
      if (goalId != null) {
        for (final entry in await _brief(goalId)) {
          final proposed = [...brief, entry];
          if (brief.length >= briefMissionLimit ||
              estimateTokens(jsonEncode(proposed)) > goalBriefTokenBudget ||
              estimateTokens(
                    jsonEncode({
                      ...blocks,
                      'goalBrief': proposed,
                      'omitted': true,
                    }),
                  ) >
                  tokenBudget) {
            omitted = true;
            continue;
          }
          brief.add(entry);
          blocks['goalBrief'] = brief;
        }
      }
      if (blocks.isEmpty && !omitted) {
        return const MemoryContextResult('', []);
      }
      if (omitted) blocks['omitted'] = true;
      return MemoryContextResult(jsonEncode(blocks), injected);
    } catch (_) {
      return const MemoryContextResult('', []);
    }
  }

  /// 目标 brief 只读任务事实；findForGoal 不触发材料截止补算或其他写入。
  Future<List<Map<String, Object?>>> _brief(String goalId) async {
    final service = missions;
    if (service == null) return const [];
    try {
      final details = await service.findForGoal(goalId);
      return [
        for (final detail in details)
          {
            'id': detail.mission.id,
            'title': detail.mission.title,
            'phase': detail.phase.name,
            'scheduledDate': detail.schedule.scheduledDate,
            'plannedMinutes': detail.schedule.plannedDurationMinutes,
          },
      ];
    } catch (_) {
      return const [];
    }
  }

  static Map<String, Object?> _entry(Map<String, Object?> item) {
    final content = item['content'] as String;
    final runes = content.runes.toList();
    final truncated = runes.length > entryMaxRunes;
    return {
      'id': item['id'],
      'layer': item['layer'],
      'topic': item['topic_name'],
      'content': truncated
          ? '${String.fromCharCodes(runes.take(entryMaxRunes))}…'
          : content,
      'certainty': item['certainty'],
      if (item['steps_json'] != null)
        'steps': jsonDecode(item['steps_json'] as String),
      if (item['trigger_context'] != null) 'trigger': item['trigger_context'],
      if (item['importance'] != 50) 'importance': item['importance'],
      if (item['goal_id'] != null) 'goalId': item['goal_id'],
      if (item['expires_at'] != null) 'expiresAt': item['expires_at'],
      if (item['user_edited'] == 1) 'userEdited': true,
      if (truncated) 'truncated': true,
    };
  }

  /// 与装配预算一致的加权估算，包含 JSON 结构、中文及非 BMP 字符。
  static int estimateTokens(String value) {
    var weight = 0;
    for (final rune in value.runes) {
      weight += rune < 128
          ? 4
          : rune >= 0x3400 && rune <= 0x9fff
          ? 8
          : rune > 0xffff
          ? 30
          : 15;
    }
    return (weight + 9) ~/ 10;
  }
}
