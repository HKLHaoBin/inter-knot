import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_avatar.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_bubble.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_card.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_item.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_message.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_title_bar.dart';

enum ChatMockupEditableField {
  text,
  title,
  subtitle,
  firstReply,
  secondReply,
}

enum _ChatMockupSettingTargetScope {
  selected,
  selectedMultiple,
  allLeft,
  allRight,
}

class ChatMockupCanvas extends StatefulWidget {
  const ChatMockupCanvas({super.key});

  @override
  State<ChatMockupCanvas> createState() => ChatMockupCanvasState();
}

class ChatMockupCanvasState extends State<ChatMockupCanvas> {
  static const _leftAvatarPath = 'assets/images/zzzicon.png';
  static const _rightAvatarPath = 'assets/images/Bangboo.gif';
  static const _stickerPath = 'assets/images/zzz.webp';
  static const _coverPath = 'assets/images/pc-page-bg.png';
  static const _jsonTypeGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
  static const _imageTypeGroup = XTypeGroup(
    label: 'Images',
    extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
    uniformTypeIdentifiers: [
      'public.png',
      'public.jpeg',
      'public.webp',
      'public.gif',
    ],
  );
  static const _leftAvatarSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _leftAvatarPath,
  );
  static const _rightAvatarSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _rightAvatarPath,
  );
  static const _defaultStickerSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _stickerPath,
  );
  static const _defaultCoverSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _coverPath,
  );

  final List<ChatMockupItem> _items = [];
  final Set<String> _selectedItemIds = <String>{};
  String? _primarySelectedItemId;
  String? _editingItemId;
  ChatMockupEditableField? _editingField;
  ChatMockupItemType? _pendingAddType;
  int _nextId = 0;

  bool _isPreviewing = false;
  int _visibleItemCount = 0;
  Timer? _playbackTimer;
  bool _isWaitingManual = false;

  late final TextEditingController _editingController;
  late final FocusNode _editingFocusNode;
  bool _isCommittingEditing = false;

  @override
  void initState() {
    super.initState();
    _items.addAll(_initialItems());
    _editingController = TextEditingController();
    _editingFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _editingController.dispose();
    _editingFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems();
    return ColoredBox(
      color: ChatMockupTheme.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
            child: Column(
              children: [
                const ChatMockupTitleBar(),
                _buildAddControls(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                onReorder: _onReorder,
                padding: const EdgeInsets.only(bottom: 24),
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    elevation: 8,
                    child: child,
                  );
                },
                itemCount: visibleItems.length,
                itemBuilder: (context, index) {
                  return _buildItem(visibleItems[index], index);
                },
              ),
            ),
          ),
          _buildPreviewControls(),
        ],
      ),
    );
  }

  List<ChatMockupItem> _initialItems() {
    return [
      _createItem(
        type: ChatMockupItemType.message,
        side: ChatMockupItemSide.left,
        text: 'Click on messages to edit and show actions.',
      ),
      _createItem(
        type: ChatMockupItemType.message,
        side: ChatMockupItemSide.right,
        text: 'Click on chat icons to change them.',
      ),
      _createItem(
        type: ChatMockupItemType.sticker,
        side: ChatMockupItemSide.right,
        imageSource: _defaultStickerSource,
      ),
      _createItem(type: ChatMockupItemType.action, side: ChatMockupItemSide.center),
      _createItem(type: ChatMockupItemType.emoji, side: ChatMockupItemSide.left),
      _createItem(type: ChatMockupItemType.emoji, side: ChatMockupItemSide.right),
      _createItem(
        type: ChatMockupItemType.customImage,
        side: ChatMockupItemSide.left,
        imageSource: _defaultCoverSource,
      ),
      _createItem(type: ChatMockupItemType.replyOptions, side: ChatMockupItemSide.right),
      _createItem(type: ChatMockupItemType.commission, side: ChatMockupItemSide.right),
    ];
  }

  Widget _buildPreviewControls() {
    if (_isPreviewing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            ElevatedButton(onPressed: _stopPreview, child: const Text('停止预览')),
            const SizedBox(width: 8),
            if (_isWaitingManual)
              ElevatedButton(
                onPressed: _continuePreviewManually,
                child: const Text('点击继续'),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ElevatedButton(onPressed: _startPreview, child: const Text('预览')),
      ),
    );
  }

  Widget _buildAddControls() {
    final isEditing = _editingItemId != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xff161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff2a2a2a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeAddButtons(disabled: isEditing),
          if (_pendingAddType != null) ...[
            const SizedBox(height: 8),
            _buildSidePicker(_pendingAddType!, disabled: isEditing),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeAddButtons({required bool disabled}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _addTypeButton('消息', ChatMockupItemType.message, disabled: disabled),
        _addTypeButton('表情', ChatMockupItemType.emoji, disabled: disabled),
        _addTypeButton('贴纸', ChatMockupItemType.sticker, disabled: disabled),
        _addTypeButton('图片', ChatMockupItemType.customImage, disabled: disabled),
        _addTypeButton('回复选项', ChatMockupItemType.replyOptions, disabled: disabled),
        _addTypeButton('动作', ChatMockupItemType.action, disabled: disabled),
        _addTypeButton('委托', ChatMockupItemType.commission, disabled: disabled),
      ],
    );
  }

  Widget _buildSidePicker(ChatMockupItemType type, {required bool disabled}) {
    final sides = _allowedSidesForType(type);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (sides.contains(ChatMockupItemSide.left))
          _addSideButton('添加到左侧', type, ChatMockupItemSide.left, disabled: disabled),
        if (sides.contains(ChatMockupItemSide.right))
          _addSideButton('添加到右侧', type, ChatMockupItemSide.right, disabled: disabled),
        if (sides.contains(ChatMockupItemSide.center))
          _addSideButton('添加到中间', type, ChatMockupItemSide.center, disabled: disabled),
        TextButton(
          onPressed: disabled ? null : () => setState(() => _pendingAddType = null),
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _addTypeButton(String label, ChatMockupItemType type, {required bool disabled}) {
    final isPending = _pendingAddType == type;
    final allowedSides = _allowedSidesForType(type);
    final requiresSideSelection = allowedSides.length > 1;
    return ElevatedButton(
      onPressed: disabled
          ? null
          : () {
              if (requiresSideSelection) {
                setState(() => _pendingAddType = type);
                return;
              }
              _addItem(type);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isPending ? const Color(0xff3a3a3a) : const Color(0xff2a2a2a),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _addSideButton(
    String label,
    ChatMockupItemType type,
    ChatMockupItemSide side, {
    required bool disabled,
  }) {
    return OutlinedButton(
      onPressed: disabled
          ? null
          : () {
              _addItem(type, side: side);
              setState(() => _pendingAddType = null);
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xff4a4a4a)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _buildItem(ChatMockupItem item, int index) {
    final isSelected = _selectedItemIds.contains(item.id);
    final isEditingThisItem = _editingItemId == item.id;
    final side = _toMessageSide(item.side);
    final avatar = item.side == ChatMockupItemSide.center
        ? null
        : ChatMockupAvatar(
            image: _resolveImageProvider(item.avatarSource ?? _defaultAvatarForSide(item.side)),
          );
    return Column(
      key: ValueKey(item.id),
      children: [
        GestureDetector(
          behavior:
              isEditingThisItem ? HitTestBehavior.deferToChild : HitTestBehavior.translucent,
          onTap: isEditingThisItem ? null : () => _onItemTap(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? ChatMockupTheme.infoBlue : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: ChatMockupMessage(
              side: side,
              avatar: avatar,
              margin: EdgeInsets.zero,
              child: _buildItemContent(item),
            ),
          ),
        ),
        if (isSelected || isEditingThisItem) _buildSelectionControls(item, index),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildItemContent(ChatMockupItem item) {
    final isMe = item.side == ChatMockupItemSide.right;
    final isEditingThisItem = _editingItemId == item.id;
    final waitLabel = item.waitMode == ChatMockupWaitMode.manual
        ? '点击继续'
        : item.waitSeconds > 0
            ? '等待 ${item.waitSeconds.toStringAsFixed(1)}s'
            : null;
    switch (item.type) {
      case ChatMockupItemType.message:
        if (isEditingThisItem && _editingField == ChatMockupEditableField.text) {
          return ChatMockupEditableTextBubble(
            controller: _editingController,
            focusNode: _editingFocusNode,
            isMe: isMe,
            hintText: 'Click here to edit',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatMockupTextBubble(text: item.text ?? 'Click here to edit', isMe: isMe),
            if (waitLabel != null) _buildWaitHint(waitLabel),
          ],
        );
      case ChatMockupItemType.emoji:
        return ChatMockupEmojiBubble(emoji: item.emoji ?? '🙂', isMe: isMe);
      case ChatMockupItemType.sticker:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatMockupImageBubble(
              image: _resolveImageProvider(item.imageSource ?? _defaultStickerSource),
              isMe: isMe,
              width: 88,
              height: 88,
            ),
            if (waitLabel != null) _buildWaitHint(waitLabel),
          ],
        );
      case ChatMockupItemType.customImage:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatMockupImageBubble(
              image: _resolveImageProvider(item.imageSource ?? _defaultCoverSource),
              isMe: isMe,
              frameColor: isMe ? null : Colors.white,
              width: 210,
              height: 132,
            ),
            if (waitLabel != null) _buildWaitHint(waitLabel),
          ],
        );
      case ChatMockupItemType.action:
        if (isEditingThisItem && _editingField == ChatMockupEditableField.text) {
          return ChatMockupDividerText(
            child: _buildEditingTextField(
              style: const TextStyle(
                color: Color(0xff5b5b5b),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
              hintText: '-- Click here to edit --',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ChatMockupDividerText(text: item.text ?? '-- Click here to edit --');
      case ChatMockupItemType.replyOptions:
        final editingFirst =
            isEditingThisItem && _editingField == ChatMockupEditableField.firstReply;
        final editingSecond =
            isEditingThisItem && _editingField == ChatMockupEditableField.secondReply;
        return ChatMockupReplyCard(
          firstText: item.firstText ?? 'Click here to edit',
          secondText: item.secondText ?? 'Click here to edit',
          firstTextChild: editingFirst
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Click here to edit',
                  textAlign: TextAlign.center,
                )
              : null,
          secondTextChild: editingSecond
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Click here to edit',
                  textAlign: TextAlign.center,
                )
              : null,
          onFirstTextTap: editingFirst
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.firstReply,
                    initialValue: item.firstText ?? '',
                  ),
          onSecondTextTap: editingSecond
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.secondReply,
                    initialValue: item.secondText ?? '',
                  ),
        );
      case ChatMockupItemType.commission:
        final editingTitle = isEditingThisItem && _editingField == ChatMockupEditableField.title;
        final editingSubtitle =
            isEditingThisItem && _editingField == ChatMockupEditableField.subtitle;
        return ChatMockupActionCard(
          icon: Icons.info_outline_rounded,
          iconColor: ChatMockupTheme.infoBlue,
          title: item.title ?? 'Click here to edit',
          actionText: item.subtitle ?? 'Commission',
          titleChild: editingTitle
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Click here to edit',
                  textAlign: TextAlign.left,
                )
              : null,
          onTitleTap: editingTitle
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.title,
                    initialValue: item.title ?? '',
                  ),
          actionTextChild: editingSubtitle
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Commission',
                  textAlign: TextAlign.center,
                )
              : null,
          onActionTextTap: editingSubtitle
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.subtitle,
                    initialValue: item.subtitle ?? '',
                  ),
        );
    }
  }

  Widget _buildWaitHint(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _handleItemTap(ChatMockupItem item) async {
    if (_selectedItemIds.length != 1) return;
    if (_editingItemId != null &&
        (_editingItemId != item.id || _editingField != ChatMockupEditableField.text)) {
      return;
    }
    switch (item.type) {
      case ChatMockupItemType.message:
      case ChatMockupItemType.action:
        _startEditing(item.id, ChatMockupEditableField.text, initialValue: item.text ?? '');
        return;
      case ChatMockupItemType.emoji:
        await _showEmojiPicker(item);
        return;
      case ChatMockupItemType.sticker:
        await _showStickerPicker(item.id);
        return;
      case ChatMockupItemType.customImage:
        await _pickImageForItem(item.id);
        return;
      case ChatMockupItemType.replyOptions:
      case ChatMockupItemType.commission:
        return;
    }
  }

  void _startEditing(
    String itemId,
    ChatMockupEditableField field, {
    required String initialValue,
  }) {
    final isEditingSameField = _editingItemId == itemId && _editingField == field;
    if (isEditingSameField) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _editingFocusNode.requestFocus();
      });
      return;
    }
    if (_editingItemId != null && (_editingItemId != itemId || _editingField != field)) {
      return;
    }
    _editingController.text = initialValue;
    setState(() {
      _editingItemId = itemId;
      _editingField = field;
      _selectedItemIds
        ..clear()
        ..add(itemId);
      _primarySelectedItemId = itemId;
    });
    final end = _editingController.text.length;
    _editingController.selection = TextSelection.collapsed(offset: end);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editingFocusNode.requestFocus();
    });
  }

  void _commitEditing() {
    if (_isCommittingEditing) return;
    final itemId = _editingItemId;
    final field = _editingField;
    if (itemId == null || field == null) return;
    _isCommittingEditing = true;
    try {
      final index = _items.indexWhere((element) => element.id == itemId);
      final input = _editingController.text.trim();
      final updated = index >= 0 ? _items[index] : null;
      if (index >= 0 && updated != null) {
        final nextItem = switch (field) {
          ChatMockupEditableField.text => updated.copyWith(text: input.isEmpty ? null : input),
          ChatMockupEditableField.title => updated.copyWith(title: input.isEmpty ? null : input),
          ChatMockupEditableField.subtitle =>
            updated.copyWith(subtitle: input.isEmpty ? null : input),
          ChatMockupEditableField.firstReply =>
            updated.copyWith(firstText: input.isEmpty ? null : input),
          ChatMockupEditableField.secondReply =>
            updated.copyWith(secondText: input.isEmpty ? null : input),
        };
        setState(() {
          _items[index] = nextItem;
          _editingItemId = null;
          _editingField = null;
        });
      } else {
        setState(() {
          _editingItemId = null;
          _editingField = null;
        });
      }
    } finally {
      _editingFocusNode.unfocus();
      _isCommittingEditing = false;
    }
  }

  Widget _buildEditingTextField({
    required TextStyle style,
    required String hintText,
    required TextAlign textAlign,
    Color cursorColor = const Color(0xff111111),
  }) {
    final hintColor = style.color?.withValues(alpha: 0.55);
    return TextField(
      controller: _editingController,
      focusNode: _editingFocusNode,
      textAlign: textAlign,
      style: style,
      cursorColor: cursorColor,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hintText,
        hintStyle: hintColor == null ? null : style.copyWith(color: hintColor),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Future<void> _showEmojiPicker(ChatMockupItem item) async {
    if (_editingItemId != null) return;
    const emojis = <String>['🙂', '😂', '😭', '😍', '😎', '😡', '🤔', '👍', '👎', '❤️', '🔥', '🎉'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: emojis.map((emoji) {
                  return SizedBox(
                    width: 48,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, emoji),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    final index = _items.indexWhere((element) => element.id == item.id);
    if (index < 0) return;
    setState(() {
      _items[index] = _items[index].copyWith(emoji: selected);
    });
  }

  Future<List<ChatMockupImageSource>> _loadSystemStickerSources() async {
    const zzzWebpPath = _stickerPath;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final stickerPngPaths = manifest
          .listAssets()
          .where(
            (k) => k.startsWith('assets/images/ZZZ-2.1-flat/') && k.toLowerCase().endsWith('.png'),
          )
          .toList()
        ..sort();
      final orderedPaths = <String>[zzzWebpPath];
      for (final path in stickerPngPaths) {
        if (path == zzzWebpPath) continue;
        orderedPaths.add(path);
      }
      return orderedPaths
          .map((path) => ChatMockupImageSource(type: ChatMockupImageSourceType.asset, value: path))
          .toList();
    } catch (_) {
      return const [_defaultStickerSource];
    }
  }

  Future<void> _showStickerPicker(String itemId) async {
    if (_editingItemId != null) return;
    final loadFuture = _loadSystemStickerSources();
    final selected = await showModalBottomSheet<ChatMockupImageSource>(
      context: context,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.65;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: height,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择贴纸',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<ChatMockupImageSource>>(
                    future: loadFuture,
                    builder: (ctx, snapshot) {
                      final stickers = snapshot.data ?? const [_defaultStickerSource];
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: stickers.map((sticker) {
                          return SizedBox(
                            width: 72,
                            height: 72,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(ctx, sticker),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image(
                                  image: _resolveImageProvider(sticker),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _pickImageForItem(itemId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2a2a2a),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('上传本地图片'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    final index = _items.indexWhere((element) => element.id == itemId);
    if (index < 0) return;
    setState(() {
      _items[index] = _items[index].copyWith(imageSource: selected, image: null);
    });
  }

  Future<void> _pickImageForItem(String itemId) async {
    if (_editingItemId != null) return;
    final file = await openFile(acceptedTypeGroups: const [_imageTypeGroup], confirmButtonText: 'Select');
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final source = ChatMockupImageSource(
      type: ChatMockupImageSourceType.memory,
      value: base64Encode(bytes),
      mimeType: _guessMimeType(file.name),
    );
    final index = _items.indexWhere((element) => element.id == itemId);
    if (index < 0) return;
    setState(() {
      _items[index] = _items[index].copyWith(imageSource: source, image: null);
    });
  }

  Widget _buildSelectionControls(ChatMockupItem item, int index) {
    final enabled = _items.length > 1;
    final isEditingThisItem = _editingItemId == item.id;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xff181818),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildDragHandle(index, enabled: enabled),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _showItemSettings(item.id),
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
          ),
          IconButton(
            onPressed: () => _removeItem(item.id),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
          ),
          if (isEditingThisItem)
            IconButton(
              onPressed: _commitEditing,
              icon: const Icon(Icons.check_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildDragHandle(int index, {required bool enabled}) {
    final handle = Semantics(
      button: true,
      label: '按住拖动排序',
      child: Opacity(
        opacity: enabled ? 1.0 : 0.38,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xff2a2a2a),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.drag_indicator_rounded, color: Colors.white70),
        ),
      ),
    );
    final decorated = MouseRegion(
      cursor: enabled ? SystemMouseCursors.grab : SystemMouseCursors.basic,
      child: enabled ? Tooltip(message: '按住拖动排序', child: handle) : handle,
    );
    return ReorderableDragStartListener(index: index, enabled: enabled, child: decorated);
  }

  ChatMockupItem _createItem({
    required ChatMockupItemType type,
    required ChatMockupItemSide side,
    String? text,
    String? emoji,
    ImageProvider? image,
    ChatMockupImageSource? imageSource,
    ChatMockupImageSource? avatarSource,
    ChatMockupWaitMode waitMode = ChatMockupWaitMode.auto,
    double waitSeconds = 0,
  }) {
    return ChatMockupItem(
      id: 'item_${_nextId++}',
      type: type,
      side: side,
      text: text,
      emoji: emoji,
      image: image,
      imageSource: imageSource,
      avatarSource: avatarSource,
      waitMode: waitMode,
      waitSeconds: waitSeconds,
    );
  }

  ChatMockupItemSide _defaultSideForType(ChatMockupItemType type) {
    switch (type) {
      case ChatMockupItemType.action:
        return ChatMockupItemSide.center;
      case ChatMockupItemType.replyOptions:
      case ChatMockupItemType.commission:
        return ChatMockupItemSide.right;
      case ChatMockupItemType.message:
      case ChatMockupItemType.emoji:
      case ChatMockupItemType.sticker:
      case ChatMockupItemType.customImage:
        return ChatMockupItemSide.left;
    }
  }

  Set<ChatMockupItemSide> _allowedSidesForType(ChatMockupItemType type) {
    switch (type) {
      case ChatMockupItemType.message:
      case ChatMockupItemType.emoji:
      case ChatMockupItemType.sticker:
      case ChatMockupItemType.customImage:
        return {ChatMockupItemSide.left, ChatMockupItemSide.right};
      case ChatMockupItemType.replyOptions:
      case ChatMockupItemType.commission:
        return {ChatMockupItemSide.right};
      case ChatMockupItemType.action:
        return {ChatMockupItemSide.center};
    }
  }

  void _addItem(ChatMockupItemType type, {ChatMockupItemSide? side}) {
    if (_editingItemId != null) return;
    final allowed = _allowedSidesForType(type);
    final chosenSide = side ?? _defaultSideForType(type);
    if (!allowed.contains(chosenSide)) return;
    final item = _createItem(type: type, side: chosenSide);
    setState(() {
      _items.add(item);
      _selectedItemIds
        ..clear()
        ..add(item.id);
      _primarySelectedItemId = item.id;
      _pendingAddType = null;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    var adjustedIndex = newIndex;
    if (oldIndex < adjustedIndex) adjustedIndex -= 1;
    adjustedIndex = adjustedIndex.clamp(0, _items.length - 1);
    if (oldIndex == adjustedIndex) return;
    final dragged = _items[oldIndex];
    final selectedDragged = _selectedItemIds.contains(dragged.id);
    if (!selectedDragged || _selectedItemIds.length <= 1) {
      setState(() {
        final item = _items.removeAt(oldIndex);
        _items.insert(adjustedIndex, item);
      });
      return;
    }
    final selectedIndexes = <int>[];
    for (var i = 0; i < _items.length; i++) {
      if (_selectedItemIds.contains(_items[i].id)) selectedIndexes.add(i);
    }
    if (selectedIndexes.length <= 1) return;
    setState(() {
      final selectedItems = selectedIndexes.map((i) => _items[i]).toList();
      var insertIndex = adjustedIndex;
      var removedBeforeTarget = 0;
      for (final i in selectedIndexes) {
        if (i < adjustedIndex) removedBeforeTarget += 1;
      }
      insertIndex -= removedBeforeTarget;
      _items.removeWhere((element) => _selectedItemIds.contains(element.id));
      insertIndex = insertIndex.clamp(0, _items.length);
      _items.insertAll(insertIndex, selectedItems);
      _primarySelectedItemId = dragged.id;
    });
  }

  void _removeItem(String id) {
    final targets = _selectedItemIds.contains(id) ? _selectedItemIds.toSet() : <String>{id};
    setState(() {
      _items.removeWhere((item) => targets.contains(item.id));
      _selectedItemIds.removeWhere(targets.contains);
      if (_primarySelectedItemId != null && targets.contains(_primarySelectedItemId)) {
        _primarySelectedItemId = null;
      }
      if (_editingItemId != null && targets.contains(_editingItemId)) {
        _editingItemId = null;
        _editingField = null;
      }
    });
  }

  void _onItemTap(ChatMockupItem item) {
    if (_isPreviewing || _editingItemId != null) return;
    setState(() {
      if (_selectedItemIds.contains(item.id)) {
        _selectedItemIds.remove(item.id);
      } else {
        _selectedItemIds.add(item.id);
      }
      _primarySelectedItemId = item.id;
    });
    _handleItemTap(item);
  }

  List<ChatMockupItem> _visibleItems() {
    if (!_isPreviewing) return _items;
    final safeCount = _visibleItemCount.clamp(0, _items.length);
    return _items.take(safeCount).toList();
  }

  void _startPreview() {
    if (_items.isEmpty) return;
    _playbackTimer?.cancel();
    setState(() {
      _isPreviewing = true;
      _visibleItemCount = 1;
      _isWaitingManual = false;
    });
    _queueNextPreviewStep();
  }

  void _stopPreview() {
    _playbackTimer?.cancel();
    setState(() {
      _isPreviewing = false;
      _visibleItemCount = _items.length;
      _isWaitingManual = false;
    });
  }

  void _continuePreviewManually() {
    if (!_isPreviewing || !_isWaitingManual) return;
    setState(() {
      _isWaitingManual = false;
      _visibleItemCount += 1;
    });
    _queueNextPreviewStep();
  }

  void _queueNextPreviewStep() {
    _playbackTimer?.cancel();
    if (!_isPreviewing || _visibleItemCount >= _items.length) return;
    final current = _items[_visibleItemCount - 1];
    if (current.waitMode == ChatMockupWaitMode.manual) {
      setState(() => _isWaitingManual = true);
      return;
    }
    final milliseconds = (current.waitSeconds * 1000).round();
    _playbackTimer = Timer(Duration(milliseconds: milliseconds), () {
      if (!mounted || !_isPreviewing) return;
      setState(() => _visibleItemCount += 1);
      _queueNextPreviewStep();
    });
  }

  ChatMockupImageSource _defaultAvatarForSide(ChatMockupItemSide side) {
    switch (side) {
      case ChatMockupItemSide.left:
        return _leftAvatarSource;
      case ChatMockupItemSide.right:
        return _rightAvatarSource;
      case ChatMockupItemSide.center:
        return _leftAvatarSource;
    }
  }

  ImageProvider _resolveImageProvider(ChatMockupImageSource source) {
    return source.toImageProvider();
  }

  String? _guessMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return null;
  }

  Iterable<String> _resolveScopeIds(_ChatMockupSettingTargetScope scope) {
    switch (scope) {
      case _ChatMockupSettingTargetScope.selected:
      case _ChatMockupSettingTargetScope.selectedMultiple:
        return _selectedItemIds;
      case _ChatMockupSettingTargetScope.allLeft:
        return _items.where((item) => item.side == ChatMockupItemSide.left).map((item) => item.id);
      case _ChatMockupSettingTargetScope.allRight:
        return _items.where((item) => item.side == ChatMockupItemSide.right).map((item) => item.id);
    }
  }

  void _applyAvatarSource(ChatMockupImageSource source, _ChatMockupSettingTargetScope scope) {
    final ids = _resolveScopeIds(scope).toSet();
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (!ids.contains(item.id) || item.side == ChatMockupItemSide.center) continue;
        _items[i] = item.copyWith(avatarSource: source);
      }
    });
  }

  void _applyWaitSetting(
    ChatMockupWaitMode mode,
    double seconds,
    _ChatMockupSettingTargetScope scope,
  ) {
    final ids = _resolveScopeIds(scope).toSet();
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        if (!ids.contains(_items[i].id)) continue;
        _items[i] = _items[i].copyWith(
          waitMode: mode,
          waitSeconds: mode == ChatMockupWaitMode.auto ? seconds : 0,
        );
      }
    });
  }

  Future<void> _showItemSettings(String itemId) async {
    if (_selectedItemIds.isEmpty) {
      setState(() {
        _selectedItemIds.add(itemId);
        _primarySelectedItemId = itemId;
      });
    }
    final selectedCount = _selectedItemIds.length;
    ChatMockupWaitMode mode = ChatMockupWaitMode.auto;
    double seconds = 1.0;
    _ChatMockupSettingTargetScope scope = selectedCount <= 1
        ? _ChatMockupSettingTargetScope.selected
        : _ChatMockupSettingTargetScope.selectedMultiple;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '设置',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<_ChatMockupSettingTargetScope>(
                    value: scope,
                    dropdownColor: const Color(0xff262626),
                    items: [
                      DropdownMenuItem(
                        value: selectedCount <= 1
                            ? _ChatMockupSettingTargetScope.selected
                            : _ChatMockupSettingTargetScope.selectedMultiple,
                        child: Text(selectedCount <= 1 ? '当前选中项' : '已选中的多个项'),
                      ),
                      const DropdownMenuItem(
                        value: _ChatMockupSettingTargetScope.allLeft,
                        child: Text('全部左侧'),
                      ),
                      const DropdownMenuItem(
                        value: _ChatMockupSettingTargetScope.allRight,
                        child: Text('全部右侧'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => scope = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final source = await _pickStickerSource();
                          if (source == null || !mounted) return;
                          _applyAvatarSource(source, scope);
                        },
                        child: const Text('使用贴纸作为头像'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final source = await _pickLocalImageSource();
                          if (source == null || !mounted) return;
                          _applyAvatarSource(source, scope);
                        },
                        child: const Text('上传本地头像'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('自动等待'),
                        selected: mode == ChatMockupWaitMode.auto,
                        onSelected: (_) => setSheetState(() => mode = ChatMockupWaitMode.auto),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('手动点击显示下一个'),
                        selected: mode == ChatMockupWaitMode.manual,
                        onSelected: (_) => setSheetState(() => mode = ChatMockupWaitMode.manual),
                      ),
                    ],
                  ),
                  if (mode == ChatMockupWaitMode.auto) ...[
                    const SizedBox(height: 10),
                    Slider(
                      max: 10,
                      divisions: 100,
                      value: seconds,
                      label: seconds.toStringAsFixed(1),
                      onChanged: (value) => setSheetState(() => seconds = value),
                    ),
                    Text(
                      '等待 ${seconds.toStringAsFixed(1)}s',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _applyWaitSetting(
                      mode,
                      mode == ChatMockupWaitMode.auto ? seconds : 0,
                      scope,
                    ),
                    child: const Text('应用等待设置'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<ChatMockupImageSource?> _pickStickerSource() async {
    final stickers = await _loadSystemStickerSources();
    if (!mounted) return null;
    return showModalBottomSheet<ChatMockupImageSource>(
      context: context,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stickers.map((source) {
              return InkWell(
                onTap: () => Navigator.pop(ctx, source),
                child: Image(
                  image: _resolveImageProvider(source),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<ChatMockupImageSource?> _pickLocalImageSource() async {
    final file = await openFile(acceptedTypeGroups: const [_imageTypeGroup], confirmButtonText: 'Select');
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return ChatMockupImageSource(
      type: ChatMockupImageSourceType.memory,
      value: base64Encode(bytes),
      mimeType: _guessMimeType(file.name),
    );
  }

  Future<void> exportJson() async {
    final payload = {
      'version': 1,
      'items': _items.map(_itemToJson).toList(),
    };
    final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
    final location = await getSaveLocation(
      acceptedTypeGroups: const [_jsonTypeGroup],
      suggestedName: 'chat_mockup.json',
      confirmButtonText: '导出',
    );
    if (location == null) return;
    final file = XFile.fromData(
      utf8.encode(jsonText),
      mimeType: 'application/json',
      name: 'chat_mockup.json',
    );
    await file.saveTo(location.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已导出 JSON')));
  }

  Future<void> importJson() async {
    try {
      final file = await openFile(acceptedTypeGroups: const [_jsonTypeGroup], confirmButtonText: '导入');
      if (file == null) return;
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid JSON root.');
      final version = decoded['version'];
      final itemsJson = decoded['items'];
      if (version != 1 || itemsJson is! List) throw const FormatException('Unsupported JSON format.');
      final imported = <ChatMockupItem>[];
      for (final item in itemsJson) {
        if (item is! Map<String, dynamic>) throw const FormatException('Invalid item entry.');
        imported.add(_itemFromJson(item));
      }
      _playbackTimer?.cancel();
      setState(() {
        _items
          ..clear()
          ..addAll(imported);
        _nextId = _computeNextId(imported);
        _selectedItemIds.clear();
        _primarySelectedItemId = null;
        _editingItemId = null;
        _editingField = null;
        _isPreviewing = false;
        _visibleItemCount = imported.length;
        _isWaitingManual = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入成功')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $error')));
    }
  }

  Map<String, dynamic> _itemToJson(ChatMockupItem item) {
    return {
      'id': item.id,
      'type': item.type.name,
      'side': item.side.name,
      'text': item.text,
      'emoji': item.emoji,
      'image': item.imageSource?.toJson(),
      'avatar': item.avatarSource?.toJson(),
      'title': item.title,
      'subtitle': item.subtitle,
      'firstText': item.firstText,
      'secondText': item.secondText,
      'wait': {'mode': item.waitMode.name, 'seconds': item.waitSeconds},
    };
  }

  ChatMockupItem _itemFromJson(Map<String, dynamic> json) {
    final typeName = json['type'];
    final sideName = json['side'];
    if (typeName is! String || sideName is! String) throw const FormatException('Missing type/side.');
    final type = ChatMockupItemType.values.firstWhere(
      (element) => element.name == typeName,
      orElse: () => throw const FormatException('Unsupported item type.'),
    );
    final side = ChatMockupItemSide.values.firstWhere(
      (element) => element.name == sideName,
      orElse: () => throw const FormatException('Unsupported item side.'),
    );
    if (!_allowedSidesForType(type).contains(side)) throw const FormatException('Type/side mismatch.');
    final wait = json['wait'];
    ChatMockupWaitMode waitMode = ChatMockupWaitMode.auto;
    double waitSeconds = 0;
    if (wait is Map<String, dynamic>) {
      final mode = wait['mode'];
      final seconds = wait['seconds'];
      if (mode is String) {
        waitMode = ChatMockupWaitMode.values.firstWhere(
          (element) => element.name == mode,
          orElse: () => throw const FormatException('Unsupported wait mode.'),
        );
      }
      if (seconds is num) waitSeconds = seconds.toDouble();
    }
    return ChatMockupItem(
      id: (json['id'] as String?) ?? 'item_${_nextId++}',
      type: type,
      side: side,
      text: json['text'] as String?,
      emoji: json['emoji'] as String?,
      imageSource: json['image'] is Map<String, dynamic>
          ? ChatMockupImageSource.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      avatarSource: json['avatar'] is Map<String, dynamic>
          ? ChatMockupImageSource.fromJson(json['avatar'] as Map<String, dynamic>)
          : null,
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      firstText: json['firstText'] as String?,
      secondText: json['secondText'] as String?,
      waitMode: waitMode,
      waitSeconds: waitMode == ChatMockupWaitMode.auto ? waitSeconds : 0,
    );
  }

  int _computeNextId(List<ChatMockupItem> items) {
    var maxId = -1;
    for (final item in items) {
      if (!item.id.startsWith('item_')) continue;
      final parsed = int.tryParse(item.id.substring(5));
      if (parsed != null && parsed > maxId) maxId = parsed;
    }
    return maxId + 1;
  }

  ChatMockupMessageSide _toMessageSide(ChatMockupItemSide side) {
    switch (side) {
      case ChatMockupItemSide.left:
        return ChatMockupMessageSide.left;
      case ChatMockupItemSide.right:
        return ChatMockupMessageSide.right;
      case ChatMockupItemSide.center:
        return ChatMockupMessageSide.center;
    }
  }
}
