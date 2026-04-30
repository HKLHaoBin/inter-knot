import 'dart:convert';

import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/models/discussion.dart';

const _videoPayloadType = 'inter-knot-video';
const _videoPayloadVersion = 1;

String encodeVideoPayload(Map<String, dynamic> payload) {
  final jsonText = jsonEncode(payload);
  var encoded = base64Encode(utf8.encode(jsonText));
  encoded = base64Encode(utf8.encode(encoded));
  encoded = base64Encode(utf8.encode(encoded));
  return encoded;
}

String wrapEncodedPayload(String encoded) => '{$encoded}';

Map<String, dynamic> decodeVideoPayload(String encoded) {
  final first = utf8.decode(base64Decode(encoded));
  final second = utf8.decode(base64Decode(first));
  final third = utf8.decode(base64Decode(second));
  final decoded = jsonDecode(third);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('影片 payload 不是 JSON 对象');
  }
  _validateVideoPayload(decoded);
  return decoded;
}

({String description, String? encodedPayload}) extractVideoBodyParts(
  String bodyText,
) {
  final match = RegExp(r'\{([^{}\s]+)\}\s*$').firstMatch(bodyText);
  if (match == null) {
    return (description: bodyText.trim(), encodedPayload: null);
  }
  final encoded = match.group(1)?.trim();
  final description = bodyText.substring(0, match.start).trim();
  return (description: description, encodedPayload: encoded);
}

bool isVideoDiscussionPayload(Map<String, dynamic> payload) {
  try {
    _validateVideoPayload(payload);
    return true;
  } catch (_) {
    return false;
  }
}

Map<String, dynamic> buildVideoUploadPayload({
  required Map<String, dynamic> chatMockup,
  required String rolePrompt,
  required String userPrompt,
}) {
  return <String, dynamic>{
    'type': _videoPayloadType,
    'version': _videoPayloadVersion,
    'chatMockup': chatMockup,
    'ai': {
      'rolePrompt': rolePrompt,
      'userPrompt': userPrompt,
    },
  };
}

void ensureIsVideoDiscussion(DiscussionModel discussion) {
  if (discussion.categoryName?.trim() != videoDiscussionCategoryName) {
    throw const FormatException('不是影片分类讨论');
  }
}

void _validateVideoPayload(Map<String, dynamic> payload) {
  if (payload['type'] != _videoPayloadType) {
    throw const FormatException('影片 payload type 不匹配');
  }
  if (payload['version'] != _videoPayloadVersion) {
    throw const FormatException('影片 payload version 不匹配');
  }
  final chatMockup = payload['chatMockup'];
  if (chatMockup is! Map<String, dynamic>) {
    throw const FormatException('chatMockup 缺失');
  }
  final items = chatMockup['items'];
  if (items is! List) {
    throw const FormatException('chatMockup.items 缺失');
  }
}
