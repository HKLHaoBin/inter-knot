import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';

class ChatMockupMessage extends StatelessWidget {
  const ChatMockupMessage({
    super.key,
    required this.isMe,
    required this.child,
    required this.avatar,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final bool isMe;
  final Widget child;
  final Widget avatar;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth =
        MediaQuery.sizeOf(context).width * ChatMockupTheme.bubbleMaxWidthFactor;

    return Container(
      margin: margin,
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isMe
            ? [
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                    child: child,
                  ),
                ),
                const SizedBox(width: 8),
                avatar,
              ]
            : [
                avatar,
                const SizedBox(width: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                    child: child,
                  ),
                ),
              ],
      ),
    );
  }
}
