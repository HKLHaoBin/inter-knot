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
      return '【影片简介】\n（在这里写简介）\n\n$url';
    }

    final modeText =
        result.mode == VideoUploadPublishMode.inline ? '内联模式' : 'Gist 模式（必需）';
    final modeHint = result.mode == VideoUploadPublishMode.inline
        ? '正文末尾直接粘贴 {payload}'
        : '正文末尾粘贴 gist raw 链接（单独一行）';
    final steps = result.mode == VideoUploadPublishMode.inline
        ? <String>[
            '已复制影片数据',
            '打开 GitHub 影片发布页',
            '标题填写：影片标题 + [标签]',
            '正文先写简介，再把 {payload} 粘贴到最后一行',
            '点击发布',
          ]
        : <String>[
            '已复制影片数据',
            '打开 Gist 新建页并粘贴内容后创建',
            '粘贴 gist 链接并点击「校验并规范化」',
            '打开 GitHub 影片发布页',
            '点击「复制最终正文」并发布',
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
                        const Text(
                          '上传影片到 GitHub',
                          style: TextStyle(
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
                                '发布模式：$modeText',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(modeHint),
                              const SizedBox(height: 4),
                              Text(
                                  '原始 ${result.jsonChars} 字符，压缩后 ${result.encodedChars} 字符'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '步骤',
                          style: TextStyle(
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
                            decoration: const InputDecoration(
                              labelText:
                                  '粘贴 Gist 链接（支持 gist.github / gist raw）',
                              border: OutlineInputBorder(),
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
                                    child: const Text('确认输入'),
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
                                child: const Text('校验并规范化'),
                              ),
                              if (validatedGistRawUrl != null)
                                SelectableText(
                                  '已规范化：$validatedGistRawUrl',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              if (gistValidationError != null)
                                SelectableText(
                                  '校验失败：$gistValidationError',
                                  style: const TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          '最终正文（可复制）',
                          style: TextStyle(
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
                              child: const Text('复制数据'),
                            ),
                            OutlinedButton(
                              onPressed: () => launchUrlString(_newGistLink),
                              child: const Text('打开 Gist'),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  launchUrlString(newVideoDiscussionLink),
                              child: const Text('新建发布页'),
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
                                        const SnackBar(
                                            content: Text('已复制最终正文')),
                                      );
                                    },
                              child: const Text('复制最终正文'),
                            ),
                            FilledButton(
                              onPressed: canFinish
                                  ? () => Navigator.of(ctx).pop()
                                  : null,
                              child: const Text('完成'),
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
      const SnackBar(content: Text('草稿保存失败，请先导出当前内容。')),
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
          title: const Text('旧草稿待处理'),
          content: const Text(
            '当前仍有旧草稿待处理，不能直接保存新草稿，否则会覆盖旧草稿。',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_PendingInvalidDraftAction.cancel),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.exportCurrentAndClose),
              child: const Text('导出当前内容并关闭'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.keepOldDiscardCurrent),
              child: const Text('丢弃当前内容，保留旧草稿'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.discardOldSaveCurrent),
              child: const Text('丢弃旧草稿并保存当前内容'),
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
                      child: const Text('导出'),
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
                      child: const Text('上传'),
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
                      child: const Text('导入'),
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
