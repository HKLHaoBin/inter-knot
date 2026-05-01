import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_canvas.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/android_input_lock.dart';
import 'package:inter_knot/helpers/video_archive_codec.dart';
import 'package:inter_knot/models/video_upload_prepare_result.dart';
import 'package:url_launcher/url_launcher_string.dart';

class KnockKnockPage extends StatefulWidget {
  const KnockKnockPage({super.key});

  @override
  State<KnockKnockPage> createState() => _KnockKnockPageState();
}

class _KnockKnockPageState extends State<KnockKnockPage> {
  static const _newGistLink = 'https://gist.github.com/';
  final GlobalKey<ChatMockupCanvasState> _canvasKey =
      GlobalKey<ChatMockupCanvasState>();
  bool _isHandlingClose = false;
  bool _isCanvasDraftLoaded = false;
  bool _isCanvasAiReady = false;
  bool _isCanvasEditing = false;

  String _buildPublishTemplate(VideoUploadPrepareResult result) {
    return result.recommendedBodySnippet;
  }

  Future<void> _showUploadGuideDialog(
    BuildContext context,
    ChatMockupCanvasState canvas,
    VideoUploadPrepareResult result,
  ) async {
    final isGistRequired = result.mode == VideoUploadPublishMode.gistRequired;
    final gistController = TextEditingController();
    final gistFocusNode = FocusNode();
    String? validatedGistRawUrl;
    String? gistValidationError;
    String buildFinalBodyText() {
      if (!isGistRequired) return _buildPublishTemplate(result);
      final url = validatedGistRawUrl ??
          'https://gist.githubusercontent.com/<user>/<gist-id>/raw';
      return '${'Video description'.tr}\n${'(Write the description here)'.tr}\n\n$url';
    }

    final modeText =
        result.mode == VideoUploadPublishMode.inline ? 'Inline mode'.tr : 'Gist mode (required)'.tr;
    final modeHint = result.mode == VideoUploadPublishMode.inline
        ? 'Paste {payload} at the end of body'.tr
        : 'Paste gist raw URL at the end of body (single line)'.tr;
    final steps = result.mode == VideoUploadPublishMode.inline
        ? <String>[
            'Video payload copied'.tr,
            'Open GitHub video discussion page'.tr,
            'Title format: video title + [tags]'.tr,
            'Write description, then paste {payload} on the last line'.tr,
            'Click publish'.tr,
          ]
        : <String>[
            'Video payload copied'.tr,
            'Open Gist new page, paste payload, then create'.tr,
            'Paste gist link and click "Validate and normalize"'.tr,
            'Open GitHub video discussion page'.tr,
            'Click "Copy final body" and publish'.tr,
          ];
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocalState) {
              final finalBody = buildFinalBodyText();
              final canFinish = !isGistRequired || validatedGistRawUrl != null;
              return Dialog(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 720, maxHeight: 820),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload video to GitHub'.tr,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: isGistRequired
                                ? const Color(0xFFFFF1F1)
                                : const Color(0xFFF3F8FF),
                            border: Border.all(
                              color: isGistRequired
                                  ? const Color(0xFFFF9393)
                                  : const Color(0xFF93B9FF),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Publish mode: @mode'.trParams({'mode': modeText}),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(modeHint),
                              const SizedBox(height: 4),
                              Text(
                                  'Raw @jsonChars chars, encoded @encodedChars chars'.trParams({
                                'jsonChars': '${result.jsonChars}',
                                'encodedChars': '${result.encodedChars}',
                              })),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Steps'.tr,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('${i + 1}. ${steps[i]}'),
                          ),
                        if (isGistRequired) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: gistController,
                            focusNode: gistFocusNode,
                            onTap: AndroidInputLock.lock,
                            onTapOutside: (_) {
                              if (AndroidInputLock.isLocked) return;
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            decoration: InputDecoration(
                              labelText:
                                  'Paste Gist URL (supports gist.github / gist raw)'.tr,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              AnimatedBuilder(
                                animation: Listenable.merge([
                                  AndroidInputLock.lockedListenable,
                                  gistFocusNode,
                                ]),
                                builder: (context, _) {
                                  final showConfirm = AndroidInputLock
                                          .requiresExplicitConfirm &&
                                      AndroidInputLock.isLocked &&
                                      gistFocusNode.hasFocus;
                                  if (!showConfirm) {
                                    return const SizedBox.shrink();
                                  }
                                  return OutlinedButton(
                                    onPressed: () {
                                      AndroidInputLock.unlock();
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                    },
                                    child: Text('Confirm input'.tr),
                                  );
                                },
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  AndroidInputLock.unlock();
                                  final checked =
                                      normalizeVideoPayloadGistRawUrlDetailed(
                                    gistController.text,
                                  );
                                  setLocalState(() {
                                    if (checked.rawUrl != null) {
                                      validatedGistRawUrl = checked.rawUrl;
                                      gistValidationError = null;
                                      gistController.text = checked.rawUrl!;
                                    } else {
                                      validatedGistRawUrl = null;
                                      gistValidationError = checked.error;
                                    }
                                  });
                                },
                                child: Text('Validate and normalize'.tr),
                              ),
                              if (validatedGistRawUrl != null)
                                SelectableText(
                                  'Normalized: @url'.trParams({
                                    'url': validatedGistRawUrl!,
                                  }),
                                  style: const TextStyle(color: Colors.green),
                                ),
                              if (gistValidationError != null)
                                SelectableText(
                                  'Validation failed: @error'.trParams({
                                    'error': gistValidationError!,
                                  }),
                                  style: const TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Final body (copyable)'.tr,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFF7F7F7),
                              border:
                                  Border.all(color: const Color(0xFFDDDDDD)),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(finalBody),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () async {
                                if (canvas.isEditingText) return;
                                await canvas.prepareVideoUpload();
                              },
                              child: Text('Copy payload'.tr),
                            ),
                            OutlinedButton(
                              onPressed: () => launchUrlString(_newGistLink),
                              child: Text('Open Gist'.tr),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  launchUrlString(newVideoDiscussionLink),
                              child: Text('New discussion page'.tr),
                            ),
                            OutlinedButton(
                              onPressed: isGistRequired &&
                                      validatedGistRawUrl == null
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: finalBody),
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                            content: Text('Final body copied'.tr)),
                                      );
                                    },
                              child: Text('Copy final body'.tr),
                            ),
                            FilledButton(
                              onPressed: canFinish
                                  ? () => Navigator.of(ctx).pop()
                                  : null,
                              child: Text('Done'.tr),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      AndroidInputLock.unlock();
      gistFocusNode.dispose();
      gistController.dispose();
    }
  }

  void _showDraftSaveFailedSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Draft save failed, please export current content first.'.tr)),
    );
  }

  Future<bool> _handlePendingInvalidDraftBeforeClose(
    ChatMockupCanvasState canvas,
  ) async {
    if (!canvas.hasPendingInvalidDraft) {
      final saved = await canvas.saveDraftCache();
      if (!saved) _showDraftSaveFailedSnack();
      return saved;
    }
    if (!mounted) return false;
    final action = await showDialog<_PendingInvalidDraftAction>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Pending old draft'.tr),
          content: Text(
            'An old draft is still pending. Saving a new draft now would overwrite it.'.tr,
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_PendingInvalidDraftAction.cancel),
              child: Text('Cancel'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.exportCurrentAndClose),
              child: Text('Export current content and close'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.keepOldDiscardCurrent),
              child: Text('Discard current content, keep old draft'.tr),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.discardOldSaveCurrent),
              child: Text('Discard old draft and save current content'.tr),
            ),
          ],
        );
      },
    );
    if (action == null || action == _PendingInvalidDraftAction.cancel) {
      return false;
    }
    switch (action) {
      case _PendingInvalidDraftAction.exportCurrentAndClose:
        final exported = await canvas.exportJson();
        return exported;
      case _PendingInvalidDraftAction.keepOldDiscardCurrent:
        return true;
      case _PendingInvalidDraftAction.discardOldSaveCurrent:
        final saved = await canvas.forceSaveDraftCache();
        if (!saved) _showDraftSaveFailedSnack();
        return saved;
      case _PendingInvalidDraftAction.cancel:
        return false;
    }
  }

  Future<bool> _handleClosePressed() async {
    if (_isHandlingClose) return false;
    if (_canvasKey.currentState?.isEditingText == true) return false;
    _isHandlingClose = true;
    try {
      final canvas = _canvasKey.currentState;
      if (canvas == null) {
        Get.back();
        return true;
      }
      if (!canvas.isDraftLoaded) return false;
      if (!canvas.hasUnexportedChanges) {
        final canClose = await _handlePendingInvalidDraftBeforeClose(canvas);
        if (!canClose || !mounted) return false;
        if (!mounted) return false;
        Get.back();
        return true;
      }
      if (!mounted) return false;
      final action = await showDialog<_CloseAction>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Unexported changes detected'.tr),
            content: Text('You can export before closing. If you close without exporting, no file is exported but local draft is kept.'.tr),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_CloseAction.cancel),
                child: Text('Cancel'.tr),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(_CloseAction.closeWithoutExport),
                child: Text('Close without export'.tr),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(_CloseAction.exportAndClose),
                child: Text('Export and close'.tr),
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
      final canClose = await _handlePendingInvalidDraftBeforeClose(canvas);
      if (!canClose || !mounted) return false;
      if (!mounted) return false;
      Get.back();
      return true;
    } finally {
      _isHandlingClose = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canOperateTopActions =
        _isCanvasDraftLoaded && !_isHandlingClose && !_isCanvasEditing;
    final canUpload = canOperateTopActions && _isCanvasAiReady;
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
                      onPressed: canOperateTopActions
                          ? () async {
                              if (_canvasKey.currentState?.isEditingText ==
                                  true) {
                                return;
                              }
                              await _canvasKey.currentState?.exportJson();
                            }
                          : null,
                      child: Text('Export'.tr),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: canUpload
                          ? () async {
                              final canvas = _canvasKey.currentState;
                              if (canvas == null) return;
                              if (canvas.isEditingText) return;
                              final result = await canvas.prepareVideoUpload();
                              if (result == null || !context.mounted) return;
                              await _showUploadGuideDialog(
                                context,
                                canvas,
                                result,
                              );
                            }
                          : null,
                      child: Text('Upload'.tr),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: canOperateTopActions
                          ? () {
                              if (_canvasKey.currentState?.isEditingText ==
                                  true) {
                                return;
                              }
                              _canvasKey.currentState?.showAiSettings();
                            }
                          : null,
                      child: const Text('AI'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: canOperateTopActions
                          ? () {
                              if (_canvasKey.currentState?.isEditingText ==
                                  true) {
                                return;
                              }
                              _canvasKey.currentState?.importJson();
                            }
                          : null,
                      child: Text('Import'.tr),
                    ),
                    const SizedBox(width: 8),
                    ClickRegion(
                      onTap: () {
                        if (!canOperateTopActions) {
                          return;
                        }
                        if (_canvasKey.currentState?.isEditingText == true) {
                          return;
                        }
                        unawaited(_handleClosePressed());
                      },
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
                    child: ChatMockupCanvas(
                      key: _canvasKey,
                      onDraftLoadedChanged: (loaded) {
                        if (!mounted) return;
                        setState(() {
                          _isCanvasDraftLoaded = loaded;
                          _isCanvasAiReady =
                              _canvasKey.currentState?.isAiInitialized ?? false;
                        });
                      },
                      onAiInitializedChanged: (ready) {
                        if (!mounted) return;
                        setState(() => _isCanvasAiReady = ready);
                      },
                      onEditingChanged: (editing) {
                        if (!mounted) return;
                        setState(() => _isCanvasEditing = editing);
                      },
                    ),
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

enum _PendingInvalidDraftAction {
  exportCurrentAndClose,
  keepOldDiscardCurrent,
  discardOldSaveCurrent,
  cancel,
}
