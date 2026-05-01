class ChatMockupAiSettings {
  const ChatMockupAiSettings({
    required this.endpoint,
    required this.model,
    required this.apiKey,
    required this.rolePrompt,
    required this.userPrompt,
    required this.directorSendPrompt,
    required this.roleSendPrompt,
  });

  final String endpoint;
  final String model;
  final String apiKey;
  final String rolePrompt;
  final String userPrompt;
  final String directorSendPrompt;
  final String roleSendPrompt;

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
      'directorSendPrompt': directorSendPrompt,
      'roleSendPrompt': roleSendPrompt,
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
      directorSendPrompt: readString('directorSendPrompt'),
      roleSendPrompt: readString('roleSendPrompt'),
    );
  }

  ChatMockupAiSettings copyWith({
    String? endpoint,
    String? model,
    String? apiKey,
    String? rolePrompt,
    String? userPrompt,
    String? directorSendPrompt,
    String? roleSendPrompt,
  }) {
    return ChatMockupAiSettings(
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      rolePrompt: rolePrompt ?? this.rolePrompt,
      userPrompt: userPrompt ?? this.userPrompt,
      directorSendPrompt: directorSendPrompt ?? this.directorSendPrompt,
      roleSendPrompt: roleSendPrompt ?? this.roleSendPrompt,
    );
  }

  static const empty = ChatMockupAiSettings(
    endpoint: '',
    model: '',
    apiKey: '',
    rolePrompt: '',
    userPrompt: '',
    directorSendPrompt: '',
    roleSendPrompt: '',
  );
}
