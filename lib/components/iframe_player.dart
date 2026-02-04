import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_universal/webview_universal.dart';

class IframePlayer extends StatefulWidget {
  const IframePlayer({
    super.key,
    required this.url,
    required this.aspectRatio,
  });

  final String url;
  final double aspectRatio;

  @override
  State<IframePlayer> createState() => _IframePlayerState();
}

class _IframePlayerState extends State<IframePlayer> {
  final _controller = WebViewController();
  final _visibilityKey = UniqueKey();
  bool _isInitializing = false;
  bool _isReady = false;
  bool _hasError = false;

  Future<void> _initWebView() async {
    if (_isInitializing || _isReady) return;
    _isInitializing = true;
    try {
      await _controller.init(
        context: context,
        uri: Uri.parse(widget.url),
      );
      if (!mounted) return;
      setState(() {
        _isReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    } finally {
      _isInitializing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (info.visibleFraction <= 0) return;
        _initWebView();
      },
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: const Color(0xff111111),
            child: _isReady
                ? WebView(
                    _controller,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : Center(
                    child: _hasError
                        ? TextButton(
                            onPressed: () => launchUrlString(widget.url),
                            child: const Text('Open embedded content'),
                          )
                        : const CircularProgressIndicator(),
                  ),
          ),
        ),
      ),
    );
  }
}
