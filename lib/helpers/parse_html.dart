import 'package:html/parser.dart';
import 'package:inter_knot/constants/globals.dart';

String _decodeHtmlEntities(String input) {
  return input
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}

String _restoreEscapedIframe(String html) {
  final pattern = RegExp(
    r'&lt;\s*iframe\b[\s\S]*?&lt;\s*/\s*iframe\s*&gt;',
    caseSensitive: false,
  );
  return html.replaceAllMapped(pattern, (m) => _decodeHtmlEntities(m[0]!));
}

({String? cover, bool coverIsIframe, String html}) parseHtml(
  String html, [
  bool isComment = false,
]) {
  final document = parseFragment(_restoreEscapedIframe(html));
  document.querySelectorAll('iframe').forEach((iframe) {
    final src = iframe.attributes['src'];
    if (src == null || src.isEmpty) return;
    if (!src.startsWith('//')) return;
    iframe.attributes['src'] = 'https:$src';
  });
  document.querySelectorAll('img').forEach((img) {
    final src = img.attributes['src'];
    if (src == null || src.isEmpty) return;
    if (src.startsWith(imageProxyUrl)) return;
    final uri = Uri.tryParse(src);
    if (uri == null) return;
    final isGithubUserImages = uri.host.endsWith('githubusercontent.com');
    if (!isGithubUserImages) return;
    final proxied = '$imageProxyUrl?url=${Uri.encodeComponent(src)}';
    img.attributes['src'] = proxied;
  });
  if (!isComment) {
    final coverElement = document.querySelector('img,iframe');
    final cover = switch (coverElement?.localName) {
      'img' => coverElement?.attributes['src'],
      'iframe' => coverElement?.outerHtml,
      _ => null,
    };
    final coverIsIframe = coverElement?.localName == 'iframe';
    coverElement?.remove();
    var parent = coverElement?.parent;
    while (parent != null && parent.nodes.isEmpty) {
      parent.remove();
      parent = parent.parent;
    }
    return (html: document.outerHtml, cover: cover, coverIsIframe: coverIsIframe);
  }
  document.querySelectorAll('.email-hidden-toggle').forEach((e) => e.remove());
  document.querySelectorAll('.email-hidden-reply').forEach((e) => e.remove());
  return (html: document.outerHtml, cover: null, coverIsIframe: false);
}
