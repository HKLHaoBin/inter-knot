import 'dart:convert';

import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/models/chat_mockup_ai_settings.dart';

class ChatMockupAiSettingsStore {
  const ChatMockupAiSettingsStore();

  static const String storageKey = 'chat_mockup_ai_settings';

  Future<ChatMockupAiSettings> load() async {
    final cached = box.read(storageKey);
    if (cached is! String || cached.isEmpty) {
      return ChatMockupAiSettings.empty;
    }
    try {
      final decoded = jsonDecode(cached);
      if (decoded is! Map<String, dynamic>) {
        return ChatMockupAiSettings.empty;
      }
      return ChatMockupAiSettings.fromJson(decoded);
    } catch (_) {
      return ChatMockupAiSettings.empty;
    }
  }

  Future<void> save(ChatMockupAiSettings settings) async {
    final encoded = jsonEncode(settings.toJson());
    await box.write(storageKey, encoded);
  }
}
