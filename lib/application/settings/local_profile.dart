/// 本机资料是应用偏好，不是账号，也不参与任务与目标的业务事实。
class LocalProfile {
  const LocalProfile({this.name = '本机使用者', this.bio = ''});

  final String name;
  final String bio;

  LocalProfile cleaned() {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('请填写称呼');
    return LocalProfile(name: cleanName, bio: bio.trim());
  }

  Map<String, String> toJson() => {'name': name, 'bio': bio};

  factory LocalProfile.fromJson(Map<String, dynamic> json) => LocalProfile(
    name: json['name'] as String,
    bio: json['bio'] as String? ?? '',
  ).cleaned();
}
