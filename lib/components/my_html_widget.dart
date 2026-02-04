import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:visibility_detector/visibility_detector.dart';

class InterKnotHtmlFactory extends WidgetFactory {
  InterKnotHtmlFactory({this.enableWebView = true});

  final bool enableWebView;

  @override
  bool get webView => enableWebView;

  @override
  bool get webViewMediaPlaybackAlwaysAllow => true;
}

class MyHtmlWidget extends StatefulWidget {
  const MyHtmlWidget({
    super.key,
    required this.html,
    this.textStyle,
  });

  final String html;
  final TextStyle? textStyle;

  @override
  State<MyHtmlWidget> createState() => _MyHtmlWidgetState();
}

class _MyHtmlWidgetState extends State<MyHtmlWidget> {
  static final _iframePattern = RegExp(r'<\s*iframe\b', caseSensitive: false);
  final _visibilityKey = UniqueKey();
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _activated = !_iframePattern.hasMatch(widget.html);
  }

  @override
  void didUpdateWidget(covariant MyHtmlWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html == widget.html) return;
    _activated = !_iframePattern.hasMatch(widget.html);
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (_activated || info.visibleFraction <= 0) return;
        if (!mounted) return;
        setState(() {
          _activated = true;
        });
      },
      child: HtmlWidget(
        widget.html,
        factoryBuilder: () => InterKnotHtmlFactory(enableWebView: _activated),
        textStyle: widget.textStyle,
      ),
    );
  }
}
