import 'package:agent_core/agent_core.dart';

/// 宿主决定哪些操作等用户确认；模型和附件都不能改变这一选择。
enum AssistantPermissionMode {
  standard('默认权限', '每次工具查询和修改都先确认'),
  relaxed('宽松权限', '查询直接执行；创建、修改和执行任务仍需确认'),
  full('完整权限', '当前已接入的查询与修改自动执行');

  const AssistantPermissionMode(this.label, this.description);
  final String label;
  final String description;

  bool requiresConfirmation({required bool isWrite}) => switch (this) {
    standard => true,
    relaxed => isWrite,
    full => false,
  };
}

enum AssistantRole {
  assistant('效率助理', '围绕用户目标组织任务、说明依据，帮助把想法变成可执行的下一步。'),
  coach('学习教练', '解释时先讲业务需要和思路，再沿真实调用说明；区分完成任务与已经掌握，不擅自评价用户能力。'),
  planner('计划顾问', '规划时先核对目标、已有安排和可用时间，关注优先级、时长与冲突；信息不足时询问。');

  const AssistantRole(this.label, this.instruction);
  final String label;
  final String instruction;
}

enum AssistantReplyStyle {
  concise('简洁直接', '先给结论和下一步，用简短段落回答，需要时再展开解释。'),
  explanatory('耐心讲解', '循序讲清原因、输入、处理与结果，适当举例，避免一次堆积过多术语。'),
  supportive('温和鼓励', '语气温和，承认实际困难，给具体可做的小步骤；不空泛夸奖，不编造进展。');

  const AssistantReplyStyle(this.label, this.instruction);
  final String label;
  final String instruction;
}

enum AssistantAvatar { spark, book, compass }

/// 角色设定只调整称呼与表达；工具授权始终由宿主设置决定。
class AssistantPersona {
  const AssistantPersona({
    this.name = '助手',
    this.role = AssistantRole.assistant,
    this.replyStyle = AssistantReplyStyle.concise,
    this.avatar = AssistantAvatar.spark,
  });
  final String name;
  final AssistantRole role;
  final AssistantReplyStyle replyStyle;
  final AssistantAvatar avatar;

  void validate() {
    if (name.trim().isEmpty ||
        name.trim().runes.length > 24 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      throw ArgumentError('角色名称请填写 1–24 个字符，不包含换行或控制字符');
    }
  }

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'role': role.name,
    'replyStyle': replyStyle.name,
    'avatar': avatar.name,
  };

  factory AssistantPersona.fromJson(Map<String, Object?> value) {
    final persona = AssistantPersona(
      name: value['name'] is String ? value['name'] as String : '助手',
      role:
          AssistantRole.values
              .where((role) => role.name == value['role'])
              .firstOrNull ??
          AssistantRole.assistant,
      replyStyle:
          AssistantReplyStyle.values
              .where((style) => style.name == value['replyStyle'])
              .firstOrNull ??
          AssistantReplyStyle.concise,
      avatar:
          AssistantAvatar.values
              .where((avatar) => avatar.name == value['avatar'])
              .firstOrNull ??
          AssistantAvatar.spark,
    );
    try {
      persona.validate();
      return persona;
    } on ArgumentError {
      return const AssistantPersona();
    }
  }
}

/// 录音转写使用独立服务；聊天模型的 Key 不默认授予音频服务。
class AssistantSpeechSettings {
  const AssistantSpeechSettings({
    this.useTranscription = false,
    this.endpoint = '',
    this.model = '',
  });
  final bool useTranscription;
  final String endpoint;
  final String model;

  void validate() {
    if (!useTranscription) return;
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '::1'].contains(uri.host)))) {
      throw ArgumentError('转写地址需为完整 HTTPS 地址（本机服务允许 HTTP），不能包含账号、查询参数或片段');
    }
    if (model.trim().isEmpty) throw ArgumentError('请填写转写模型名称');
  }
}

class AssistantSettings {
  const AssistantSettings({
    required this.hasCredential,
    required this.modelProfileId,
    bool autoApproveWrites = false,
    AssistantPermissionMode? permissionMode,
    this.customProfile,
    this.hasDeepSeekCredential,
    this.hasCustomCredential = false,
    this.speech = const AssistantSpeechSettings(),
    this.hasTranscriptionCredential = false,
    this.persona = const AssistantPersona(),
  }) : permissionMode =
           permissionMode ??
           (autoApproveWrites
               ? AssistantPermissionMode.full
               : AssistantPermissionMode.relaxed);

  final bool hasCredential;
  final bool? hasDeepSeekCredential;
  final bool hasCustomCredential;
  final ModelProfile? customProfile;
  final AssistantSpeechSettings speech;
  final bool hasTranscriptionCredential;
  final String modelProfileId;
  final AssistantPermissionMode permissionMode;
  final AssistantPersona persona;
  bool get autoApproveWrites => permissionMode == AssistantPermissionMode.full;
}

abstract interface class AssistantSettingsStore {
  Future<AssistantSettings> load();
  Future<String?> resolveCredential(String credentialKey);
  Future<void> saveCredential(String credentialKey, String value);
  Future<void> saveModelProfile(String profileId);
  Future<void> saveCustomProfile(ModelProfile profile);
  Future<void> saveAutoApproveWrites(bool value);
  Future<void> savePermissionMode(AssistantPermissionMode mode);
  Future<void> saveSpeechSettings(AssistantSpeechSettings settings);
  Future<void> savePersona(AssistantPersona persona);
}
