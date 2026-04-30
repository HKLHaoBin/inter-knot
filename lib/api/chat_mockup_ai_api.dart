import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatMockupAiApi {
  const ChatMockupAiApi();

  Uri _normalizeEndpoint(String endpoint) {
    var raw = endpoint.trim();
    if (raw.isEmpty) {
      throw const FormatException('接口地址为空');
    }
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    final uri = Uri.parse(raw);
    final path = uri.path;
    if (path.endsWith('/chat/completions')) {
      return uri;
    }
    if (path.endsWith('/v1')) {
      return uri.replace(path: '$path/chat/completions');
    }
    if (path.endsWith('/v1/')) {
      return uri.replace(path: '${path}chat/completions');
    }
    final normalizedPath =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    return uri.replace(path: '$normalizedPath/chat/completions');
  }

  Future<String> createChatCompletion({
    required String endpoint,
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.8,
  }) async {
    final uri = _normalizeEndpoint(endpoint);
    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': temperature,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const FormatException('请求超时（60s）');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
          '请求失败: HTTP ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('响应不是 JSON 对象');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('响应缺少 choices');
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('响应 choices[0] 非对象');
    }
    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw const FormatException('响应缺少 message');
    }
    final content = message['content'];
    if (content is! String) {
      throw const FormatException('响应缺少 content');
    }
    return content;
  }
}
