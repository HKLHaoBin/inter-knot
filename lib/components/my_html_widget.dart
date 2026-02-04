import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:inter_knot/components/iframe_player.dart';

class InterKnotHtmlFactory extends WidgetFactory {
  @override
  bool get webView => false;
}

class MyHtmlWidget extends StatelessWidget {
  const MyHtmlWidget({
    super.key,
    required this.html,
    this.textStyle,
  });

  final String html;
  final TextStyle? textStyle;

  double _iframeAspectRatio(dom.Element element) {
    final widthRaw = element.attributes['width'];
    final heightRaw = element.attributes['height'];
    final width = double.tryParse(widthRaw ?? '');
    final height = double.tryParse(heightRaw ?? '');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 16 / 9;
    }
    return width / height;
  }

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      html,
      factoryBuilder: () => InterKnotHtmlFactory(),
      customWidgetBuilder: (element) {
        if (element.localName != 'iframe') return null;
        final rawSrc =
            element.attributes['src'] ?? element.attributes['data-src'] ?? '';
        final src = rawSrc.startsWith('//') ? 'https:$rawSrc' : rawSrc;
        if (src.isEmpty) return const SizedBox.shrink();
        return IframePlayer(
          url: src,
          aspectRatio: _iframeAspectRatio(element),
        );
      },
      textStyle: textStyle,
    );
  }
}
