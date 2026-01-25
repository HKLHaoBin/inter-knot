class AuthorModel {
  String login;
  String avatar;
  late String name;
  int level;
  int contributions;

  late final url = 'https://github.com/$login';
  String get displayName => name.trim().isEmpty ? login : name;

  AuthorModel({
    required this.login,
    required this.avatar,
    required this.level,
    required this.contributions,
    required String? name,
  }) : name = (name == null || name.trim().isEmpty) ? login : name;

  factory AuthorModel.fromJson(Map<String, dynamic> json) {
    final contributions = json['contributionsTotal'] as int? ?? 0;
    return AuthorModel(
      login: json['login'] as String,
      avatar: json['avatarUrl'] as String,
      level: contributions ~/ 100,
      contributions: contributions,
      name: json['name'] as String?,
    );
  }

  factory AuthorModel.deleted() {
    return AuthorModel(
      login: 'deleted',
      avatar: '',
      level: 0,
      contributions: 0,
      name: null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthorModel && other.login == login;

  @override
  int get hashCode => login.hashCode;
}
