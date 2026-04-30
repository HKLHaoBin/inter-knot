class ChatMockupAiSettings {
  const ChatMockupAiSettings({
    required this.endpoint,
    required this.model,
    required this.apiKey,
    required this.rolePrompt,
    required this.userPrompt,
  });

  final String endpoint;
  final String model;
  final String apiKey;
  final String rolePrompt;
  final String userPrompt;

  bool get isConfigured =>
      endpoint.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      apiKey.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'model': model,
      'apiKey': apiKey,
      'rolePrompt': rolePrompt,
      'userPrompt': userPrompt,
    };
  }

  factory ChatMockupAiSettings.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final value = json[key];
      return value is String ? value : '';
    }

    return ChatMockupAiSettings(
      endpoint: readString('endpoint'),
      model: readString('model'),
      apiKey: readString('apiKey'),
      rolePrompt: readString('rolePrompt'),
      userPrompt: readString('userPrompt'),
    );
  }

  ChatMockupAiSettings copyWith({
    String? endpoint,
    String? model,
    String? apiKey,
    String? rolePrompt,
    String? userPrompt,
  }) {
    return ChatMockupAiSettings(
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      rolePrompt: rolePrompt ?? this.rolePrompt,
      userPrompt: userPrompt ?? this.userPrompt,
    );
  }

  static const empty = ChatMockupAiSettings(
    endpoint: '',
    model: '',
    apiKey: '',
    rolePrompt: '',
    userPrompt: '',
  );
}
