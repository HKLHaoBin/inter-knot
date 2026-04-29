import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';

class ChatMockupTitleBar extends StatelessWidget {
  const ChatMockupTitleBar({
    super.key,
    this.title = 'Click here to edit chat title',
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.grey,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: ChatMockupTheme.titleStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(
            color: Color(0xff2a2a2a),
            thickness: 1,
            height: 1,
          ),
        ],
      ),
    );
  }
}
