import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_canvas.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/gen/assets.gen.dart';

class KnockKnockPage extends StatefulWidget {
  const KnockKnockPage({super.key});

  @override
  State<KnockKnockPage> createState() => _KnockKnockPageState();
}

class _KnockKnockPageState extends State<KnockKnockPage> {
  final GlobalKey<ChatMockupCanvasState> _canvasKey =
      GlobalKey<ChatMockupCanvasState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _canvasKey.currentState?.exportJson(),
                    child: const Text('导出'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _canvasKey.currentState?.importJson(),
                    child: const Text('导入'),
                  ),
                  const SizedBox(width: 8),
                  ClickRegion(
                    onTap: Get.back,
                    child: Assets.images.closeBtn.image(width: 44, height: 44),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ChatMockupTheme.canvasMaxWidth,
                  ),
                  child: ChatMockupCanvas(key: _canvasKey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
