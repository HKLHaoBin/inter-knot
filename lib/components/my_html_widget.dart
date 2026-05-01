import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:html/dom.dart' as dom;
import 'package:inter_knot/components/iframe_player.dart';
import 'package:inter_knot/controllers/data.dart';

class InterKnotHtmlFactory extends WidgetFactory {
  @override
  bool get webView => false;
}

class MyHtmlWidget extends StatelessWidget {
  const MyHtmlWidget({
    super.key,
    required this.html,
    this.textStyle,
    this.inDiscussionDetail = false,
  });

  final String html;
  final TextStyle? textStyle;
  final bool inDiscussionDetail;

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
    if (tagName == 'td' || tagName == 'th') {
      // 读取 align 属性支持 Markdown 表格对齐语法
      final align = element.attributes['align']?.toLowerCase();
      final isHeader = tagName == 'th';

      final styles = <String, String>{
        'border': '1px solid #555',
        'padding': '10px 14px',
        'white-space': 'nowrap',
      };

      if (isHeader) {
        styles['background-color'] = '#2a2a2a';
        styles['font-weight'] = 'bold';
        styles['color'] = '#ffffff';
      } else {
        styles['color'] = '#e0e0e0';
      }

      // 处理对齐：优先使用 align 属性，表头默认居中，数据单元格默认左对齐
      if (align == 'center') {
        styles['text-align'] = 'center';
      } else if (align == 'right') {
        styles['text-align'] = 'right';
      } else if (align == 'left') {
        styles['text-align'] = 'left';
      } else if (isHeader) {
        styles['text-align'] = 'center'; // 表头默认居中
      } else {
        styles['text-align'] = 'left'; // 数据单元格默认左对齐
      }

      return styles;
    }

    // 其他元素使用默认样式
    return _customStylesBuilder(element);
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();
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
          if (!c.canLoadIframe(src, inDiscussionDetail: inDiscussionDetail)) {
            return Text(
              'Blocked external iframe'.tr,
              style: textStyle?.copyWith(color: const Color(0xffB3B3B1)) ??
                  const TextStyle(
                    color: Color(0xffB3B3B1),
                    fontSize: 14,
                  ),
            );
          }
          return IframePlayer(
            url: src,
            aspectRatio: _iframeAspectRatio(element),
            active: inDiscussionDetail,
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
