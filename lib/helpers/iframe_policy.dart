enum IframeLoadPolicy {
  denyAll,
  allowBilibiliStrict,
  allowAllRisky,
}

const _allowedBilibiliQueryKeys = <String>{
  'isOutside',
  'aid',
  'bvid',
  'cid',
  'p',
};

bool isSupportedIframeUri(Uri uri) =>
    (uri.scheme == 'https' || uri.scheme.isEmpty) &&
    uri.host.trim().isNotEmpty &&
    uri.fragment.trim().isEmpty;

/// Strictly allow bilibili player URL with standard embed parameters only.
bool isStrictBilibiliPlayerEmbed(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (uri.host != 'player.bilibili.com') return false;
  if (uri.path != '/player.html') return false;

  if (uri.queryParametersAll.isEmpty) return false;
  for (final key in uri.queryParametersAll.keys) {
    if (!_allowedBilibiliQueryKeys.contains(key)) return false;
  }

  final isOutside = uri.queryParameters['isOutside'];
  final cid = uri.queryParameters['cid'];
  final p = uri.queryParameters['p'];
  final aid = uri.queryParameters['aid'];
  final bvid = uri.queryParameters['bvid'];

  if (isOutside != 'true') return false;
  if (cid == null || int.tryParse(cid) == null || int.parse(cid) <= 0) {
    return false;
  }
  if (p != null && (int.tryParse(p) == null || int.parse(p) <= 0)) {
    return false;
  }
  if (aid == null && bvid == null) return false;
  if (aid != null && (int.tryParse(aid) == null || int.parse(aid) <= 0)) {
    return false;
  }
  if (bvid != null &&
      !RegExp(r'^BV[0-9A-Za-z]{10}$', caseSensitive: false).hasMatch(bvid)) {
    return false;
  }
  return true;
}
