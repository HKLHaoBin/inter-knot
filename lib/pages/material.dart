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
  bool _isHandlingClose = false;

  Future<bool> _handleClosePressed() async {
    if (_isHandlingClose) return false;
    _isHandlingClose = true;
    try {
      final canvas = _canvasKey.currentState;
      if (canvas == null) {
        Get.back();
        return true;
      }
      if (!canvas.hasUnexportedChanges) {
        await canvas.saveDraftCache();
        if (!mounted) return false;
        Get.back();
        return true;
      }
      if (!mounted) return false;
      final action = await showDialog<_CloseAction>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('存在未导出修改'),
            content: const Text('关闭前可先导出。若选择不导出并关闭，不会导出文件，但会保留本机草稿。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_CloseAction.cancel),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(_CloseAction.closeWithoutExport),
                child: const Text('不导出并关闭'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(_CloseAction.exportAndClose),
                child: const Text('导出并关闭'),
              ),
            ],
          );
        },
      );
      if (action == null || action == _CloseAction.cancel) return false;
      if (action == _CloseAction.exportAndClose) {
        final exported = await canvas.exportJson();
        if (!exported || !mounted) return false;
      }
      await canvas.saveDraftCache();
      if (!mounted) return false;
      Get.back();
      return true;
    } finally {
      _isHandlingClose = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _handleClosePressed();
      },
      child: Scaffold(
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
                      onTap: _handleClosePressed,
                      child:
                          Assets.images.closeBtn.image(width: 44, height: 44),
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
      ),
    );
  }
}

enum _CloseAction {
  exportAndClose,
  closeWithoutExport,
  cancel,
}
