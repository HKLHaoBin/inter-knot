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
/// **Autoplay / loop (WebView):** [ChatMockupIframeAudioHost] sets
/// `mediaPlaybackRequiresUserGesture: false` (see `IframePlayer`). Per-site behavior:
///
/// - **Bilibili** `player.bilibili.com/player.html?...` — player autoplays in-page; add
///   `&autoplay=0` in the site UI if needed. Loop is not controlled by this app; the
///   in-player control applies.
/// - **YouTube** `/embed/VIDEO_ID` — typically needs `?autoplay=1` in the **saved URL**
///   for auto-start; for **loop**, YouTube expects `loop=1` and `playlist=VIDEO_ID` on
///   the same URL (add these in the editor when you need loop). This validator does
///   not inject query parameters.
///
/// **Limitation:** [ChatMockupMusicDirective.loop] applies to [audioUrl] via
/// `just_audio`; for [iframe] kind, loop is stored for future/editor use but embed
/// players may ignore it unless the URL carries the right query flags.
bool isChatMockupMusicIframeEmbedAllowed(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (!isSupportedIframeUri(uri)) return false;
  if (isStrictBilibiliPlayerEmbed(uri)) return true;
  return _isYoutubeStyleMusicEmbed(uri);
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
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    throw const FormatException('iframe 播放需要非空 URL。');
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null || !isChatMockupMusicIframeEmbedAllowed(uri)) {
    throw const FormatException(
      '仅支持白名单内嵌地址：B 站 player.bilibili.com/player.html（严格参数），或 YouTube / YouTube-nocookie 的 /embed/ 页面（https）。',
    );
  }
}

/// Import/save shape check (no network I/O), same rules as [assertChatMockupMusicIframeEmbedAllowed].
Future<void> validateChatMockupMusicIframeForSaveOrImport(String url) async {
  assertChatMockupMusicIframeEmbedAllowed(url);
}
