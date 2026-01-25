import 'package:html/parser.dart';
import 'package:inter_knot/constants/globals.dart';

({String? cover, String html}) parseHtml(
  String html, [
  bool isComment = false,
]) {
  final document = parseFragment(html);
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
    final img = document.querySelector('img');
    final cover = img?.attributes['src'];
    img?.remove();
    var parent = img?.parent;
    while (parent != null && parent.nodes.isEmpty) {
      parent.remove();
      parent = parent.parent;
    }
    return (html: document.outerHtml, cover: cover);
  }
  document.querySelectorAll('.email-hidden-toggle').forEach((e) => e.remove());
  document.querySelectorAll('.email-hidden-reply').forEach((e) => e.remove());
  return (html: document.outerHtml, cover: null);
}
