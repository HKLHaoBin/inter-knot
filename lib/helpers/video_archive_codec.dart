import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/models/discussion.dart';

const _videoPayloadType = 'inter-knot-video';
const _videoPayloadVersion = 1;
const _videoPayloadEncodedPrefix = 'IKV1:gzip+b64:';
const maxInlinePayloadChars = 60000;

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

typedef GistRawUrlNormalizeResult = ({
  String? rawUrl,
  String? error,
});

({String description, String? encodedPayload, String? gistRawUrl, String? gistUrlError})
extractVideoBodyParts(
  String bodyText,
) {
  final match = RegExp(r'\{([^{}\s]+)\}\s*$').firstMatch(bodyText);
  if (match != null) {
    final encoded = match.group(1)?.trim();
    final description = bodyText.substring(0, match.start).trim();
    return (
      description: description,
      encodedPayload: encoded,
      gistRawUrl: null,
      gistUrlError: null,
    );
  }
  final trailingLink = _extractTrailingLinkToken(bodyText);
  if (trailingLink == null) {
    return (
      description: bodyText.trim(),
      encodedPayload: null,
      gistRawUrl: null,
      gistUrlError: null,
    );
  }
  final normalized = normalizeVideoPayloadGistRawUrlDetailed(trailingLink.url);
  if (normalized.rawUrl == null) {
    if (!_looksLikeGistLink(trailingLink.url)) {
      return (
        description: bodyText.trim(),
        encodedPayload: null,
        gistRawUrl: null,
        gistUrlError: null,
      );
    }
    return (
      description: bodyText.substring(0, trailingLink.start).trim(),
      encodedPayload: null,
      gistRawUrl: null,
      gistUrlError: normalized.error,
    );
  }
  final description = bodyText.substring(0, trailingLink.start).trim();
  return (
    description: description,
    encodedPayload: null,
    gistRawUrl: normalized.rawUrl,
    gistUrlError: null,
  );
}

String? normalizeVideoPayloadGistRawUrl(String? urlText) {
  return normalizeVideoPayloadGistRawUrlDetailed(urlText).rawUrl;
}

GistRawUrlNormalizeResult normalizeVideoPayloadGistRawUrlDetailed(String? urlText) {
  final raw = urlText?.trim() ?? '';
  if (raw.isEmpty) {
    return (rawUrl: null, error: '链接为空');
  }
  final uri = Uri.tryParse(raw);
  if (uri == null) {
    return (rawUrl: null, error: '链接格式无效');
  }
  if (uri.scheme.toLowerCase() != 'https') {
    return (rawUrl: null, error: '仅支持 https 链接');
  }
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (host == 'gist.githubusercontent.com') {
    if (segments.length < 2) {
      return (rawUrl: null, error: 'gist raw 链接缺少 owner 或 gist id');
    }
    if (segments.length >= 3 && segments[2] == 'raw') {
      return (
        rawUrl: uri.replace(query: '', fragment: '').toString(),
        error: null,
      );
    }
    final owner = segments[0];
    final gistId = segments[1];
    return (
      rawUrl: Uri.https(
        'gist.githubusercontent.com',
        '/$owner/$gistId/raw',
      ).toString(),
      error: null,
    );
  }
  if (host == 'gist.github.com') {
    if (segments.length < 2) {
      return (rawUrl: null, error: 'gist 页面链接缺少 owner 或 gist id');
    }
    final owner = segments[0];
    final gistId = segments[1];
    return (
      rawUrl: Uri.https(
        'gist.githubusercontent.com',
        '/$owner/$gistId/raw',
      ).toString(),
      error: null,
    );
  }
  return (rawUrl: null, error: '仅支持 gist.github.com 或 gist.githubusercontent.com');
}

String? extractEncodedPayloadToken(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final wrapped = RegExp(r'^\{([^{}\s]+)\}$').firstMatch(trimmed);
  if (wrapped != null) return wrapped.group(1)?.trim();
  final fromBody = extractVideoBodyParts(trimmed).encodedPayload;
  if (fromBody != null && fromBody.isNotEmpty) return fromBody;
  if (trimmed.contains(RegExp(r'\s'))) return null;
  return trimmed;
}

({String url, int start})? _extractTrailingLinkToken(String bodyText) {
  final markdownLink =
      RegExp(r'\[[^\]]+\]\((https?://[^\s)]+)\)\s*$').firstMatch(bodyText);
  if (markdownLink != null) {
    final url = markdownLink.group(1)?.trim();
    if (url != null && url.isNotEmpty) {
      return (url: url, start: markdownLink.start);
    }
  }
  final autoLink = RegExp(r'<(https?://[^>\s]+)>\s*$').firstMatch(bodyText);
  if (autoLink != null) {
    final url = autoLink.group(1)?.trim();
    if (url != null && url.isNotEmpty) {
      return (url: url, start: autoLink.start);
    }
  }
  final bareLink = RegExp(r'(https?://[^\s]+)\s*$').firstMatch(bodyText);
  if (bareLink != null) {
    final url = bareLink.group(1)?.trim();
    if (url != null && url.isNotEmpty) {
      return (url: url, start: bareLink.start);
    }
  }
  return null;
}

bool _looksLikeGistLink(String urlText) {
  final uri = Uri.tryParse(urlText.trim());
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host == 'gist.github.com' || host == 'gist.githubusercontent.com';
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
