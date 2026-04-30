import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/models/discussion.dart';

const _videoPayloadType = 'inter-knot-video';
const _videoPayloadVersion = 1;
const _videoPayloadEncodedPrefix = 'IKV1:gzip+b64:';

typedef VideoPayloadEncodeResult = ({
  String encoded,
  int jsonChars,
  int compressedBytes,
  int base64Chars,
});

String encodeVideoPayload(Map<String, dynamic> payload) {
  return encodeVideoPayloadWithStats(payload).encoded;
}

VideoPayloadEncodeResult encodeVideoPayloadWithStats(
  Map<String, dynamic> payload,
) {
  final jsonText = jsonEncode(payload);
  final jsonBytes = utf8.encode(jsonText);
  final compressed = const GZipEncoder().encode(jsonBytes);
  final base64Text = base64Encode(compressed);
  return (
    encoded: '$_videoPayloadEncodedPrefix$base64Text',
    jsonChars: jsonText.length,
    compressedBytes: compressed.length,
    base64Chars: base64Text.length,
  );
}

String wrapEncodedPayload(String encoded) => '{$encoded}';

Map<String, dynamic> decodeVideoPayload(String encoded) {
  final decoded = jsonDecode(_decodeVideoPayloadJsonText(encoded));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('影片 payload 不是 JSON 对象');
  }
  _validateVideoPayload(decoded);
  return decoded;
}

String _decodeVideoPayloadJsonText(String encoded) {
  final normalized = encoded.trim();
  if (normalized.startsWith(_videoPayloadEncodedPrefix)) {
    final payloadBase64 =
        normalized.substring(_videoPayloadEncodedPrefix.length);
    final compressedBytes = base64Decode(payloadBase64);
    final uncompressedBytes = const GZipDecoder().decodeBytes(compressedBytes);
    return utf8.decode(uncompressedBytes);
  }
  final first = utf8.decode(base64Decode(normalized));
  final second = utf8.decode(base64Decode(first));
  return utf8.decode(base64Decode(second));
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
