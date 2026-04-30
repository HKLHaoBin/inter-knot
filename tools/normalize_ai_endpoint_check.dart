import 'package:inter_knot/api/chat_mockup_ai_api.dart';

void main() {
  const api = ChatMockupAiApi();
  final inputs = <String>[
    'https://example.com/v4',
    'https://example.com/v4/',
    'https://example.com/v4/chat/completions',
    'https://api.openai.com/v1',
    'example.com/v4',
  ];

  for (final input in inputs) {
    try {
      final uri = api.debugNormalizeEndpoint(input);
      // ignore: avoid_print
      print('$input -> $uri');
    } catch (e) {
      // ignore: avoid_print
      print('$input -> ERROR: $e');
    }
  }
}
