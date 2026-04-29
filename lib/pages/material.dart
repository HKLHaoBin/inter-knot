import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_canvas.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/gen/assets.gen.dart';

class KnockKnockPage extends StatelessWidget {
  const KnockKnockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 10),
                child: ClickRegion(
                  onTap: Get.back,
                  child: Assets.images.closeBtn.image(width: 44, height: 44),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ChatMockupTheme.canvasMaxWidth,
                  ),
                  child: const ChatMockupCanvas(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
