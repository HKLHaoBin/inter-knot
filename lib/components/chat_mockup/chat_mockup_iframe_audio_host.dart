import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:inter_knot/helpers/iframe_webview_error_utils.dart';
import 'package:inter_knot/helpers/logger.dart';

/// Offscreen 1×1 [InAppWebView] host for **chat mockup** background music embeds only.
/// Not for discover/post card HTML—see [IframePlayer] for visible cards.
///
/// When [active] becomes false (stop, track switch, session invalidate), loads
/// `about:blank` like [IframePlayer] to release media / audio focus.
///
/// **Autoplay:** [InAppWebViewSettings.mediaPlaybackRequiresUserGesture] is `false`,
/// matching [IframePlayer] so vetted embeds can start after load if the **URL** includes
/// the site’s autoplay query flags (see `chat_mockup_iframe_music_policy.dart` comments).
class ChatMockupIframeAudioHost extends StatefulWidget {
  const ChatMockupIframeAudioHost({
    super.key,
    required this.url,
    required this.active,
    this.onMainDocumentLoadFailed,
  });

  final String? url;
  final bool active;

  /// Called at most once per failed embed load (until error state is cleared),
  /// when the main document hits a fatal [WebResourceError] or HTTP error (4xx+).
  final void Function(String message)? onMainDocumentLoadFailed;

  @override
  State<ChatMockupIframeAudioHost> createState() =>
      _ChatMockupIframeAudioHostState();
}

class _ChatMockupIframeAudioHostState extends State<ChatMockupIframeAudioHost> {
  bool _isReady = false;
  bool _hasError = false;
  bool _mainDocumentLoaded = false;
  bool _isTearingDown = false;
  bool _isDisposed = false;
  bool _mainDocumentLoadFailureNotified = false;
  InAppWebViewController? _controller;

  void _clearEmbedErrorState() {
    _hasError = false;
    _mainDocumentLoadFailureNotified = false;
  }

  String _truncateDetail(String raw, {int maxLen = 120}) {
    final t = raw.trim();
    if (t.length <= maxLen) return t;
    return '${t.substring(0, maxLen - 1)}…';
  }

  void _setMainDocumentFatalError(String userDetail) {
    if (_mainDocumentLoadFailureNotified) return;
    if (!mounted) return;
    _mainDocumentLoadFailureNotified = true;
    setState(() {
      _hasError = true;
    });
    widget.onMainDocumentLoadFailed?.call(_truncateDetail(userDetail));
  }

  @override
  void initState() {
    super.initState();
    if (widget.active && (widget.url ?? '').trim().isNotEmpty) {
      _isReady = true;
    }
  }

  Future<void> _disposeWebView() async {
    if (_isTearingDown) {
      logger.d(
        'ChatMockupIframeAudioHost teardown skipped (already running): ${widget.url}',
      );
      return;
    }
    _isTearingDown = true;
    logger.d('ChatMockupIframeAudioHost teardown started: ${widget.url}');
    final controller = _controller;
    if (controller == null) {
      logger.d(
        'ChatMockupIframeAudioHost teardown finished (no controller): ${widget.url}',
      );
      _isTearingDown = false;
      return;
    }
    try {
      await controller.stopLoading();
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
      logger.d('ChatMockupIframeAudioHost teardown finished: ${widget.url}');
    } catch (e, s) {
      logger.d('ChatMockupIframeAudioHost teardown failed: $e');
      logger.d(s.toString());
    } finally {
      _isTearingDown = false;
    }
    _controller = null;
  }

  @override
  void didUpdateWidget(covariant ChatMockupIframeAudioHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wantShow =
        widget.active && (widget.url ?? '').trim().isNotEmpty;
    final oldShow =
        oldWidget.active && (oldWidget.url ?? '').trim().isNotEmpty;

    if (!wantShow && oldShow) {
      unawaited(_disposeWebView());
      if (mounted) {
        setState(() {
          _isReady = false;
          _clearEmbedErrorState();
          _mainDocumentLoaded = false;
        });
      }
      return;
    }

    if (wantShow && !oldShow) {
      if (mounted) {
        setState(() {
          _isReady = true;
          _clearEmbedErrorState();
          _mainDocumentLoaded = false;
        });
      }
    }

    if (wantShow &&
        oldShow &&
        widget.url != oldWidget.url &&
        _controller != null) {
      final next = widget.url!.trim();
      if (mounted) {
        setState(() {
          _clearEmbedErrorState();
          _mainDocumentLoaded = false;
        });
      }
      unawaited(
        _controller!.loadUrl(
          urlRequest: URLRequest(url: WebUri(next)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    logger.d('ChatMockupIframeAudioHost dispose: ${widget.url}');
    unawaited(_disposeWebView());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.url?.trim();
    final show = widget.active && trimmed != null && trimmed.isNotEmpty;
    if (!show) {
      return const SizedBox(width: 1, height: 1);
    }
    return SizedBox(
      width: 1,
      height: 1,
      child: ClipRect(
        child: _isReady && !_hasError
            ? InAppWebView(
                key: ValueKey<String>(trimmed),
                onWebViewCreated: (controller) {
                  if (_isDisposed) {
                    unawaited(controller.stopLoading());
                    unawaited(
                      controller.loadUrl(
                        urlRequest: URLRequest(url: WebUri('about:blank')),
                      ),
                    );
                    return;
                  }
                  _controller = controller;
                },
                initialUrlRequest: URLRequest(
                  url: WebUri(trimmed),
                ),
                initialSettings: InAppWebViewSettings(
                  mediaPlaybackRequiresUserGesture: false,
                  transparentBackground: true,
                ),
                onLoadStart: (_, __) {
                  if (!mounted) return;
                  setState(() {
                    _mainDocumentLoaded = false;
                  });
                },
                onLoadStop: (_, __) {
                  if (!mounted) return;
                  setState(() {
                    _mainDocumentLoaded = true;
                  });
                  debugPrint(
                    '[IframeWebView][ChatMockupIframeAudioHost] onLoadStop '
                    'mainDocumentLoaded=$_mainDocumentLoaded url=$trimmed',
                  );
                },
                onReceivedError: (_, request, error) {
                  final fatal = iframeWebViewRequestIsMainDocumentFailure(
                    request,
                    trimmed,
                  );
                  debugPrintIframeWebResourceErrorDetails(
                    label: 'ChatMockupIframeAudioHost',
                    requestUrl: request.url,
                    isForMainFrame: request.isForMainFrame,
                    error: error,
                    fatal: fatal,
                  );
                  if (!fatal || !mounted) return;
                  final desc = error.description.trim();
                  _setMainDocumentFatalError(
                    desc.isNotEmpty ? desc : 'WebView 错误 (${error.type})',
                  );
                },
                onReceivedHttpError: (_, request, response) {
                  final code = response.statusCode;
                  final mainDoc = iframeWebViewHttpErrorIsMainDocumentFailure(
                    request,
                    trimmed,
                  );
                  final fatal = mainDoc && code != null && code >= 400;
                  debugPrintIframeWebHttpErrorDetails(
                    label: 'ChatMockupIframeAudioHost',
                    requestUrl: request.url,
                    isForMainFrame: request.isForMainFrame,
                    statusCode: code ?? -1,
                    fatal: fatal,
                  );
                  if (!fatal || !mounted) return;
                  _setMainDocumentFatalError('HTTP $code');
                },
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
