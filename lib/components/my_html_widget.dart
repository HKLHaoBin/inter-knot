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

  Map<String, String>? _customStylesBuilder(dom.Element element) {
    final tagName = element.localName?.toLowerCase();

    // 表格样式：添加边框 + 不换行
    if (tagName == 'table') {
      return {
        'border': '1px solid #666',
        'border-collapse': 'collapse',
        'white-space': 'nowrap',
      };
    }
    if (tagName == 'tr') {
      return {
        'white-space': 'nowrap',
      };
    }
    if (tagName == 'td' || tagName == 'th') {
      return {
        'border': '1px solid #666',
        'padding': '8px',
        'white-space': 'nowrap',
      };
    }
    if (tagName == 'th') {
      return {
        'border': '1px solid #666',
        'padding': '8px',
        'background-color': '#f0f0f0',
        'font-weight': 'bold',
        'white-space': 'nowrap',
      };
    }

    // 代码块样式：不换行
    if (tagName == 'code' || tagName == 'pre') {
      return {
        'white-space': 'nowrap',
      };
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      html,
      factoryBuilder: () => InterKnotHtmlFactory(),
      customStylesBuilder: _customStylesBuilder,
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
