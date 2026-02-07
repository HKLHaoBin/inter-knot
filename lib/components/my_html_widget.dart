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

    // 代码块样式：不换行
    if (tagName == 'code' || tagName == 'pre') {
      return {
        'white-space': 'nowrap',
      };
    }

    return null;
  }

  /// 构建表格的自定义样式，适配深色主题
  Map<String, String>? _tableStylesBuilder(dom.Element element) {
    final tagName = element.localName?.toLowerCase();

    // 表格样式：添加边框 + 不换行 + 宽度自适应
    if (tagName == 'table') {
      return {
        'border': '1px solid #555',
        'border-collapse': 'collapse',
        'white-space': 'nowrap',
        'width': 'auto',
        'min-width': '100%',
      };
    }
    if (tagName == 'tr') {
      return {
        'white-space': 'nowrap',
      };
    }
    if (tagName == 'td') {
      return {
        'border': '1px solid #555',
        'padding': '10px 14px',
        'white-space': 'nowrap',
        'color': '#e0e0e0',
      };
    }
    if (tagName == 'th') {
      return {
        'border': '1px solid #555',
        'padding': '10px 14px',
        'background-color': '#2a2a2a',
        'font-weight': 'bold',
        'white-space': 'nowrap',
        'color': '#ffffff',
        'text-align': 'left',
      };
    }

    // 其他元素使用默认样式
    return _customStylesBuilder(element);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      html,
      factoryBuilder: () => InterKnotHtmlFactory(),
      customStylesBuilder: _customStylesBuilder,
      customWidgetBuilder: (element) {
        // 处理 iframe 视频嵌入
        if (element.localName == 'iframe') {
          final rawSrc =
              element.attributes['src'] ?? element.attributes['data-src'] ?? '';
          final src = rawSrc.startsWith('//') ? 'https:$rawSrc' : rawSrc;
          if (src.isEmpty) return const SizedBox.shrink();
          return IframePlayer(
            url: src,
            aspectRatio: _iframeAspectRatio(element),
          );
        }

        // 处理表格：添加横向滚动容器
        if (element.localName == 'table') {
          return _ScrollableTable(
            tableHtml: element.outerHtml,
            textStyle: textStyle,
            tableStylesBuilder: _tableStylesBuilder,
          );
        }

        return null;
      },
      textStyle: textStyle,
    );
  }
}

/// 可横向滚动的表格组件
class _ScrollableTable extends StatelessWidget {
  const _ScrollableTable({
    required this.tableHtml,
    this.textStyle,
    required this.tableStylesBuilder,
  });

  final String tableHtml;
  final TextStyle? textStyle;
  final Map<String, String>? Function(dom.Element) tableStylesBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF555555)),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF1e1e1e),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 32,
            ),
            child: HtmlWidget(
              tableHtml,
              factoryBuilder: () => InterKnotHtmlFactory(),
              customStylesBuilder: tableStylesBuilder,
              textStyle: textStyle?.copyWith(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
