import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
  final _visibilityKey = UniqueKey();
  bool _isInitializing = false;
  bool _isReady = false;
  bool _hasError = false;

  Future<void> _initWebView() async {
    if (_isInitializing || _isReady) return;
    _isInitializing = true;
    try {
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
          child: ColoredBox(
            color: const Color(0xff111111),
            child: _isReady && !_hasError
                ? InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(widget.url),
                    ),
                    initialSettings: InAppWebViewSettings(
                      mediaPlaybackRequiresUserGesture: false,
                      transparentBackground: true,
                    ),
                    onReceivedError: (_, __, ___) {
                      if (!mounted) return;
                      setState(() {
                        _hasError = true;
                      });
                    },
                    onReceivedHttpError: (_, __, ___) {
                      if (!mounted) return;
                      setState(() {
                        _hasError = true;
                      });
                    },
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
