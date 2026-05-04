import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Validates knock-knock preview music URLs: HTTPS / localhost shape, `.mp3`
/// / `.m4a` suffix, plus **the same** HTTP preflight on every platform (including
/// web). On web, preflight requires the audio host to allow this app's origin
/// (CORS); otherwise saving/import will fail with a network-style error.
class ChatMockupAudioUrlValidator {
  ChatMockupAudioUrlValidator._();

  static const _preflightTimeout = Duration(seconds: 12);

  /// HTTPS / localhost rules plus `.mp3` / `.m4a` suffix on the path (query allowed).
  static void assertPlayableUrlShape(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      throw const FormatException('Invalid music URL.');
    }
    if (uri.scheme == 'https') {
      // ok
    } else if (uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      // allow localhost in development
    } else {
      throw const FormatException('Only https music URL is supported.');
    }
    if (uri.host.trim().isEmpty) {
      throw const FormatException('Invalid music URL host.');
    }
    if (uri.path.trim().isEmpty) {
      throw const FormatException('Invalid music URL path.');
    }
    final pathLower = uri.path.toLowerCase();
    if (!pathLower.endsWith('.mp3') && !pathLower.endsWith('.m4a')) {
      throw const FormatException(
        '音乐 URL 须以 .mp3 或 .m4a 结尾（可带查询参数）。',
      );
    }
  }

  /// Shape check + HTTP preflight on all platforms (web included).
  static Future<void> validateForSaveOrImport(String url) async {
    final trimmed = url.trim();
    assertPlayableUrlShape(trimmed);
    await preflightHttp(trimmed);
  }

  static Future<void> preflightHttp(String url) async {
    assertPlayableUrlShape(url);
    final uri = Uri.parse(url);

    http.Response? headResp;
    try {
      headResp = await http.head(uri).timeout(_preflightTimeout);
    } catch (_) {
      headResp = null;
    }

    if (headResp != null &&
        headResp.statusCode >= 200 &&
        headResp.statusCode < 300) {
      final len = headResp.headers['content-length'];
      if (len == '0') {
        throw const FormatException('音频预检失败：Content-Length 为 0。');
      }
      final ct = headResp.headers['content-type'];
      if (_isExplicitlyAllowedContentType(ct)) {
        return;
      }
    }

    late http.Response getResp;
    try {
      getResp = await http
          .get(
            uri,
            headers: const {'Range': 'bytes=0-8191'},
          )
          .timeout(_preflightTimeout);
    } catch (e) {
      if (kIsWeb) {
        throw FormatException(
          '音频预检失败：网络错误（$e）。Web 端要求音频 URL 所在站点对当前应用来源启用 CORS，否则无法校验也无法稳定播放。',
        );
      }
      throw FormatException('音频预检失败：网络错误（$e）。');
    }

    if (getResp.statusCode != 200 && getResp.statusCode != 206) {
      throw FormatException(
        '音频预检失败：HTTP ${getResp.statusCode}。',
      );
    }
    if (getResp.bodyBytes.isEmpty) {
      throw const FormatException('音频预检失败：响应体为空。');
    }

    final ct = getResp.headers['content-type'];
    final len = getResp.headers['content-length'];
    if (len == '0') {
      throw const FormatException('音频预检失败：Content-Length 为 0。');
    }

    if (_isExplicitlyAllowedContentType(ct)) {
      return;
    }

    final primary = _primaryContentType(ct);
    if (primary == 'application/octet-stream') {
      final pathLower = uri.path.toLowerCase();
      if (pathLower.endsWith('.mp3') || pathLower.endsWith('.m4a')) {
        return;
      }
    }

    if (primary != null && primary.startsWith('audio/')) {
      return;
    }

    throw FormatException(
      '音频预检失败：Content-Type 不符合要求（${ct ?? "缺失"}）。',
    );
  }

  static String? _primaryContentType(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw.split(';').first.trim().toLowerCase();
  }

  static bool _isExplicitlyAllowedContentType(String? raw) {
    final p = _primaryContentType(raw);
    if (p == null) return false;
    const allowed = <String>{
      'audio/mpeg',
      'audio/mp3',
      'audio/mp4',
      'audio/x-m4a',
      'audio/aac',
    };
    return allowed.contains(p);
  }
}
