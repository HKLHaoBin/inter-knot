import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_canvas.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';

class KnockKnockPage extends StatelessWidget {
  const KnockKnockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ChatMockupTheme.canvasMaxWidth,
            ),
            child: ChatMockupCanvas(),
          ),
        ),
      ),
    );
  }
}
