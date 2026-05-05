import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_bubble.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/helpers/chat_mockup_iframe_music_policy.dart';
import 'package:inter_knot/helpers/iframe_webview_error_utils.dart';
import 'package:inter_knot/helpers/logger.dart';

/// Visible [InAppWebView] for **chat mockup** iframe background music during preview.
///
/// When [active] becomes false, loads `about:blank` like [IframePlayer] to release media.
class ChatMockupIframeMusicEmbed extends StatefulWidget {
  const ChatMockupIframeMusicEmbed({
    super.key,
    required this.url,
    required this.active,
    required this.isMe,
    this.onMainDocumentLoadFailed,
  });

  final String? url;
  final bool active;
  final bool isMe;

  /// Called at most once per failed embed load (until error state is cleared),
  /// when the main document hits a fatal [WebResourceError] or HTTP error (4xx+).
  final void Function(String message)? onMainDocumentLoadFailed;

  @override
  State<ChatMockupIframeMusicEmbed> createState() =>
      _ChatMockupIframeMusicEmbedState();
}

class _ChatMockupIframeMusicEmbedState extends State<ChatMockupIframeMusicEmbed> {
  static const double _maxInnerWidth = 210;

  bool _isReady = false;
  bool _hasError = false;
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
        'ChatMockupIframeMusicEmbed teardown skipped (already running): ${widget.url}',
      );
      return;
    }
    _isTearingDown = true;
    logger.d('ChatMockupIframeMusicEmbed teardown started: ${widget.url}');
    final controller = _controller;
    if (controller == null) {
      logger.d(
        'ChatMockupIframeMusicEmbed teardown finished (no controller): ${widget.url}',
      );
      _isTearingDown = false;
      return;
    }
    try {
      await controller.stopLoading();
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
      logger.d('ChatMockupIframeMusicEmbed teardown finished: ${widget.url}');
    } catch (e, s) {
      logger.d('ChatMockupIframeMusicEmbed teardown failed: $e');
      logger.d(s.toString());
    } finally {
      _isTearingDown = false;
    }
    _controller = null;
  }

  @override
  void didUpdateWidget(covariant ChatMockupIframeMusicEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wantShow = widget.active && (widget.url ?? '').trim().isNotEmpty;
    final oldShow = oldWidget.active && (oldWidget.url ?? '').trim().isNotEmpty;

    if (!wantShow && oldShow) {
      unawaited(_disposeWebView());
      if (mounted) {
        setState(() {
          _isReady = false;
          _clearEmbedErrorState();
        });
      }
      return;
    }

    if (wantShow && !oldShow) {
      if (mounted) {
        setState(() {
          _isReady = true;
          _clearEmbedErrorState();
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
    logger.d('ChatMockupIframeMusicEmbed dispose: ${widget.url}');
    unawaited(_disposeWebView());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.url?.trim();
    final show = widget.active && trimmed != null && trimmed.isNotEmpty;
    if (!show) {
      return const SizedBox.shrink();
    }
    final innerH = chatMockupIframeMusicEmbedInnerHeight(trimmed);
    final background =
        widget.isMe ? ChatMockupTheme.outgoing : ChatMockupTheme.incoming;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ChatMockupBubbleShell(
        isMe: widget.isMe,
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: _maxInnerWidth,
              height: innerH,
              child: _isReady && !_hasError
                  ? InAppWebView(
                      key: ValueKey<String>(trimmed),
                      onWebViewCreated: (controller) {
                        if (_isDisposed) {
                          unawaited(controller.stopLoading());
                          unawaited(
                            controller.loadUrl(
                              urlRequest:
                                  URLRequest(url: WebUri('about:blank')),
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
                      onLoadStart: (_, __) {},
                      onLoadStop: (_, __) {
                        debugPrint(
                          '[IframeWebView][ChatMockupIframeMusicEmbed] onLoadStop '
                          'url=$trimmed',
                        );
                      },
                      onReceivedError: (_, request, error) {
                        final fatal = iframeWebViewRequestIsMainDocumentFailure(
                          request,
                          trimmed,
                        );
                        debugPrintIframeWebResourceErrorDetails(
                          label: 'ChatMockupIframeMusicEmbed',
                          requestUrl: request.url,
                          isForMainFrame: request.isForMainFrame,
                          error: error,
                          fatal: fatal,
                        );
                        if (!fatal || !mounted) return;
                        final desc = error.description.trim();
                        _setMainDocumentFatalError(
                          desc.isNotEmpty
                              ? desc
                              : 'WebView 错误 (${error.type})',
                        );
                      },
                      onReceivedHttpError: (_, request, response) {
                        final code = response.statusCode;
                        final mainDoc =
                            iframeWebViewHttpErrorIsMainDocumentFailure(
                          request,
                          trimmed,
                        );
                        final fatal = mainDoc && code != null && code >= 400;
                        debugPrintIframeWebHttpErrorDetails(
                          label: 'ChatMockupIframeMusicEmbed',
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
          ),
        ),
      ),
    );
  }
}
