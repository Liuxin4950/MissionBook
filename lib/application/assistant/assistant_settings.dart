import 'dart:convert';

import 'package:agent_core/agent_core.dart';

/// 宿主决定哪些操作等用户确认；模型和附件都不能改变这一选择。
enum AssistantPermissionMode {
  standard('询问', '每次查询和修改都先问我'),
  relaxed('自动', '查询自动执行；创建、修改和执行任务先问我'),
  full('完全', '查询与修改全部自动执行，AI 拥有最高操作权限');

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
  planner('计划顾问', '规划时先核对目标、已有安排和可用时间，关注优先级、时长与冲突；信息不足时询问。'),
  writing('写作伙伴', '协助梳理主题、受众与结构，保留用户原意，给出具体措辞或修改建议。需要补充事实时先询问。'),
  reviewer('复盘伙伴', '结合真实行动与记录，梳理有效做法、困难与下一步调整。区分用户陈述、记录事实和推测。'),
  focus('行动陪练', '帮助把眼前任务拆成能立即开始的小步骤，每次聚焦一项行动，并根据用户反馈调整节奏。');

  const AssistantRole(this.label, this.instruction);
  final String label;
  final String instruction;
}

enum AssistantReplyStyle {
  concise('简洁直接', '先给结论和下一步，用简短段落回答，需要时再展开解释。'),
  explanatory('耐心讲解', '循序讲清原因、输入、处理与结果，适当举例，避免一次堆积过多术语。'),
  supportive('温和鼓励', '语气温和，承认实际困难，给具体可做的小步骤；不空泛夸奖，不编造进展。'),
  checklist('要点清单', '用简短要点或步骤呈现，优先列出可执行事项。每项只保留必要信息，按需补充解释。'),
  questioning('提问引导', '用少量关键问题引导用户思考，一次聚焦一个问题。用户需要直接答案时先回答，再补充思考线索。'),
  comparative('对比分析', '比较可行选项的适用条件、收益与代价。适合时使用紧凑表格，最后给出有依据的建议。');

  const AssistantReplyStyle(this.label, this.instruction);
  final String label;
  final String instruction;
}

enum AssistantAvatar { spark, book, compass }

/// 角色设定只调整称呼与表达；工具授权始终由宿主设置决定。
class AssistantPersona {
  const AssistantPersona({
    this.name = '书祺',
    this.role = AssistantRole.assistant,
    this.replyStyle = AssistantReplyStyle.concise,
    this.customRole,
    this.customReplyStyle,
    this.avatar = AssistantAvatar.spark,
    this.customAvatarBase64,
    this.userAddress = '',
  });
  final String name;
  final AssistantRole role;
  final AssistantReplyStyle replyStyle;
  // 未设置自定义正文时沿用预设，旧配置可以直接读取。
  final String? customRole;
  final String? customReplyStyle;
  static const maxInstructionLength = 2000;

  String get roleLabel => customRole == null ? role.label : '自定义定位';
  String get replyStyleLabel =>
      customReplyStyle == null ? replyStyle.label : '自定义风格';
  String get roleInstruction => customRole?.trim() ?? role.instruction;
  String get replyStyleInstruction =>
      customReplyStyle?.trim() ?? replyStyle.instruction;
  final AssistantAvatar avatar;
  // 本机头像缩略图的 PNG 内容，与角色设置一同保存。
  final String? customAvatarBase64;
  static const avatarEdge = 192;
  static const maxAvatarBytes = 192 * 1024;
  // 用户希望助手怎样称呼自己；留空沿用自然称呼，不另存一份记忆事实。
  final String userAddress;

  void validate() {
    if (customRole != null) validateInstruction(customRole!, '角色定位');
    if (customReplyStyle != null) {
      validateInstruction(customReplyStyle!, '回答风格');
    }
    if (customAvatarBase64 != null && !_validAvatar(customAvatarBase64!)) {
      throw ArgumentError('头像图片无效，请重新选择');
    }
    if (name.trim().isEmpty ||
        name.trim().runes.length > 24 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      throw ArgumentError('角色名称请填写 1–24 个字符，不包含换行或控制字符');
    }
    if (userAddress.trim().runes.length > 24 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(userAddress)) {
      throw ArgumentError('称呼最多 24 个字符，不包含换行或控制字符');
    }
  }

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'role': role.name,
    'replyStyle': replyStyle.name,
    if (customRole != null) 'customRole': customRole!.trim(),
    if (customReplyStyle != null) 'customReplyStyle': customReplyStyle!.trim(),
    'avatar': avatar.name,
    if (customAvatarBase64 != null) 'customAvatarBase64': customAvatarBase64,
    'userAddress': userAddress.trim(),
  };

  factory AssistantPersona.fromJson(Map<String, Object?> value) {
    final persona = AssistantPersona(
      customRole: _readInstruction(value['customRole']),
      customReplyStyle: _readInstruction(value['customReplyStyle']),
      customAvatarBase64:
          value['customAvatarBase64'] is String &&
              _validAvatar(value['customAvatarBase64'] as String)
          ? value['customAvatarBase64'] as String
          : null,
      name: value['name'] is String ? value['name'] as String : '书祺',
      userAddress: value['userAddress'] is String
          ? value['userAddress'] as String
          : '',
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

  /// 校验用户编写的定位或风格，编辑器与持久化共用同一限制。
  static void validateInstruction(String text, String label) {
    if (text.trim().isEmpty ||
        text.trim().runes.length > maxInstructionLength ||
        RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(text)) {
      throw ArgumentError('$label请填写 1–$maxInstructionLength 个字符，可换行');
    }
  }

  static String? _readInstruction(Object? value) {
    if (value is! String) return null;
    try {
      validateInstruction(value, '自定义内容');
      return value.trim();
    } on ArgumentError {
      return null;
    }
  }

  static bool _validAvatar(String value) {
    if (value.length > (maxAvatarBytes * 4 / 3).ceil()) return false;
    try {
      final bytes = base64Decode(value);
      const signature = [137, 80, 78, 71, 13, 10, 26, 10];
      if (bytes.length < 24 || bytes.length > maxAvatarBytes) return false;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[index] != signature[index]) return false;
      }
      final header = bytes.buffer.asByteData(bytes.offsetInBytes, bytes.length);
      final width = header.getUint32(16);
      final height = header.getUint32(20);
      return width > 0 &&
          width <= avatarEdge &&
          height > 0 &&
          height <= avatarEdge;
    } on FormatException {
      return false;
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
    required this.modelProfileId,
    this.permissionMode = AssistantPermissionMode.relaxed,
    this.customProfile,
    this.hasDeepSeekCredential = false,
    this.hasCustomCredential = false,
    this.speech = const AssistantSpeechSettings(),
    this.hasTranscriptionCredential = false,
    this.persona = const AssistantPersona(),
    this.reasoningEfforts = const {},
  });

  final bool hasDeepSeekCredential;
  final bool hasCustomCredential;
  final ModelProfile? customProfile;
  final AssistantSpeechSettings speech;
  final bool hasTranscriptionCredential;
  final String modelProfileId;
  final AssistantPermissionMode permissionMode;
  final AssistantPersona persona;
  final Map<String, ReasoningEffort> reasoningEfforts;
  bool get hasCredential =>
      modelProfileId == 'custom' ? hasCustomCredential : hasDeepSeekCredential;
}

abstract interface class AssistantSettingsStore {
  Future<AssistantSettings> load();
  Future<String?> resolveCredential(String credentialKey);
  Future<void> saveCredential(String credentialKey, String value);
  Future<void> saveModelProfile(String profileId);
  Future<void> saveReasoningEffort(String profileId, ReasoningEffort effort);
  Future<void> saveCustomProfile(ModelProfile profile);
  Future<void> savePermissionMode(AssistantPermissionMode mode);
  Future<void> saveSpeechSettings(AssistantSpeechSettings settings);
  Future<void> savePersona(AssistantPersona persona);
}
