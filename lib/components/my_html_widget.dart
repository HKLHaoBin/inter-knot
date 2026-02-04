import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:fwfh_url_launcher/fwfh_url_launcher.dart';
import 'package:fwfh_webview/fwfh_webview.dart';

class InterKnotHtmlFactory extends WidgetFactory
    with UrlLauncherFactory, WebViewFactory {
  @override
  bool get webViewMediaPlaybackAlwaysAllow => true;
}

class MyHtmlWidget extends StatelessWidget {
  const MyHtmlWidget({
    super.key,
    required this.html,
    this.textStyle,
  });

  final String html;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      html,
      factoryBuilder: () => InterKnotHtmlFactory(),
      textStyle: textStyle,
    );
  }
}
