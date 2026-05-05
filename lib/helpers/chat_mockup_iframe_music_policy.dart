import 'dart:math' as math;

import 'package:inter_knot/helpers/iframe_policy.dart';

/// Narrow iframe **embed** allowlist for **敲敲预览** background music only.
///
/// This is stricter than [IframeLoadPolicy.allowAllRisky]: we never treat arbitrary
/// HTTPS pages on "trusted" hosts as loadable—only vetted **embed** shapes.
///
/// Reuses [isSupportedIframeUri], [isStrictBilibiliPlayerEmbed], and [isTrustedIframeHost]
/// where appropriate. [decideIframeLoad] is not used directly because chat-mockup music
/// must not follow the "mask with manual load" card UX—URLs are either allowed or rejected.
///
/// **Autoplay / loop (WebView):** [ChatMockupIframeMusicEmbed] sets
/// `mediaPlaybackRequiresUserGesture: false` (see `IframePlayer`). Per-site behavior:
///
/// - **Bilibili** `player.bilibili.com/player.html?...` — player autoplays in-page; add
///   `&autoplay=0` in the site UI if needed. Loop is not controlled by this app; the
///   in-player control applies.
/// - **YouTube** `/embed/VIDEO_ID` — typically needs `?autoplay=1` in the **saved URL**
///   for auto-start; for **loop**, YouTube expects `loop=1` and `playlist=VIDEO_ID` on
///   the same URL (add these in the editor when you need loop). This validator does
///   not inject query parameters.
/// - **Netease** `music.163.com/outchain/player?type=&id=&auto=&height=` — official
///   outchain player only; all four query keys required with numeric `type`/`id`/`height`
///   (`height` capped) and `auto` ∈ {0,1}. The query `height` is the player **content**
///   hint for Netease’s script, not 1:1 our [InAppWebView] box — see
///   [chatMockupNeteaseOutchainEmbedInnerHeight].
///
/// **Limitation:** [ChatMockupMusicDirective.loop] applies to [audioUrl] via
/// `just_audio`; for [iframe] kind, loop is stored for future/editor use but embed
/// players may ignore it unless the URL carries the right query flags.

/// Protocol-relative `//host/...` → `https://host/...` (same idea as post HTML iframe src).
String normalizeChatMockupMusicIframeInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('//')) {
    return 'https:$trimmed';
  }
  return trimmed;
}

const _neteaseOutchainMaxHeightParam = 2048;

/// Extra pixels above Netease’s own `height=` query so controls / chrome are not clipped
/// (official mini embed uses `height=32` with an outer iframe ~52px).
const _neteaseOutchainEmbedChromePx = 20;

/// Floor so very small `height=` values still get a usable tap target (matches ~52 outer).
const _neteaseOutchainEmbedMinInnerHeight = 52.0;

/// Cap for mockup WebView box; URL `height` may still be large for Netease’s API.
const _neteaseOutchainEmbedMaxInnerHeight = 720.0;

bool isChatMockupMusicIframeEmbedAllowed(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (!isSupportedIframeUri(uri)) return false;
  if (_isStrictNeteaseOutchainPlayerEmbed(uri)) return true;
  if (isStrictBilibiliPlayerEmbed(uri)) return true;
  return _isYoutubeStyleMusicEmbed(uri);
}

bool _isStrictNeteaseOutchainPlayerEmbed(Uri uri) {
  if (uri.host.toLowerCase() != 'music.163.com') return false;
  if (uri.path != '/outchain/player') return false;
  const allowedKeys = {'type', 'id', 'auto', 'height'};
  if (uri.queryParametersAll.isEmpty) return false;
  for (final key in uri.queryParametersAll.keys) {
    if (!allowedKeys.contains(key)) return false;
    final values = uri.queryParametersAll[key];
    if (values == null || values.length != 1) return false;
    if (values.first.trim().isEmpty) return false;
  }
  for (final key in allowedKeys) {
    if (!uri.queryParameters.containsKey(key)) return false;
  }
  final type = uri.queryParameters['type']!;
  final id = uri.queryParameters['id']!;
  final auto = uri.queryParameters['auto']!;
  final height = uri.queryParameters['height']!;
  final typeInt = int.tryParse(type);
  final idInt = int.tryParse(id);
  final heightInt = int.tryParse(height);
  if (typeInt == null || typeInt <= 0) return false;
  if (idInt == null || idInt <= 0) return false;
  if (heightInt == null ||
      heightInt <= 0 ||
      heightInt > _neteaseOutchainMaxHeightParam) {
    return false;
  }
  if (auto != '0' && auto != '1') return false;
  return true;
}

/// `www.youtube.com/embed/...` or `www.youtube-nocookie.com/embed/...` (trusted host + path).
bool _isYoutubeStyleMusicEmbed(Uri uri) {
  if (!isTrustedIframeHost(uri)) return false;
  final host = uri.host.toLowerCase();
  if (!host.endsWith('youtube.com') && !host.endsWith('youtube-nocookie.com')) {
    return false;
  }
  final segments = uri.pathSegments;
  if (segments.length < 2) return false;
  if (segments[0] != 'embed') return false;
  final id = segments[1];
  if (id.isEmpty) return false;
  return RegExp(r'^[\w-]{11}$').hasMatch(id);
}

void assertChatMockupMusicIframeEmbedAllowed(String raw) {
  final normalized = normalizeChatMockupMusicIframeInput(raw);
  if (normalized.isEmpty) {
    throw const FormatException('iframe 播放需要非空 URL。');
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null || !isChatMockupMusicIframeEmbedAllowed(uri)) {
    const hint =
        '仅支持白名单内嵌地址（须为 https 或 // 开头的协议相对 URL，保存为 https）：网易云 music.163.com/outchain/player（仅允许查询参数 type、id、auto、height，且均为有效数字，auto 为 0 或 1，height 不超过 $_neteaseOutchainMaxHeightParam）；B 站 player.bilibili.com/player.html（严格参数）；YouTube / YouTube-nocookie 的 /embed/ 页面。';
    throw const FormatException(hint);
  }
}

/// Import/save shape check (no network I/O), same rules as [assertChatMockupMusicIframeEmbedAllowed].
Future<void> validateChatMockupMusicIframeForSaveOrImport(String url) async {
  assertChatMockupMusicIframeEmbedAllowed(url);
}

/// Netease outchain: maps URL `height` query (player content hint) to our **visible**
/// [InAppWebView] inner height so the in-page player is not cropped (≠ raw `height`).
double chatMockupNeteaseOutchainEmbedInnerHeight(int queryHeight) {
  final q = queryHeight.clamp(1, _neteaseOutchainMaxHeightParam);
  final withChrome = q + _neteaseOutchainEmbedChromePx;
  return math.min(
    math.max(withChrome.toDouble(), _neteaseOutchainEmbedMinInnerHeight),
    _neteaseOutchainEmbedMaxInnerHeight,
  );
}

/// Resolved inner content height for the visible mockup embed (pixels), after policy checks.
double chatMockupIframeMusicEmbedInnerHeight(String normalizedHttpsUrl) {
  final uri = Uri.tryParse(normalizedHttpsUrl);
  if (uri != null && _isStrictNeteaseOutchainPlayerEmbed(uri)) {
    final h = int.tryParse(uri.queryParameters['height'] ?? '');
    if (h != null && h > 0) {
      return chatMockupNeteaseOutchainEmbedInnerHeight(h);
    }
  }
  return 210 * 9 / 16;
}
