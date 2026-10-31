import 'mission_read_repository.dart';
export 'mission_read_repository.dart';
import 'mission_command_repository.dart';
export 'mission_command_repository.dart';
import 'mission_evidence_repository.dart';
export 'mission_evidence_repository.dart';
import 'mission_scheduling_repository.dart';
export 'mission_scheduling_repository.dart';

/// 应用持有的任务仓储：实现共享连接的四组能力，查询不隐含维护写入。
abstract interface class MissionRepository
    implements
        MissionReadRepository,
        MissionCommandRepository,
        MissionEvidenceRepository,
        MissionSchedulingRepository {}
