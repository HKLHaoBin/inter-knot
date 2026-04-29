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

class ChatMockupCanvas extends StatefulWidget {
  const ChatMockupCanvas({super.key});

  @override
  State<ChatMockupCanvas> createState() => _ChatMockupCanvasState();
}

class _ChatMockupCanvasState extends State<ChatMockupCanvas> {
  static const AssetImage _leftAvatar = AssetImage('assets/images/zzzicon.png');
  static const AssetImage _rightAvatar = AssetImage('assets/images/Bangboo.gif');
  static const AssetImage _sticker = AssetImage('assets/images/zzz.webp');
  static const AssetImage _cover = AssetImage('assets/images/pc-page-bg.png');

  final List<ChatMockupItem> _items = [];
  String? _selectedItemId;
  String? _editingItemId;
  ChatMockupEditableField? _editingField;
  ChatMockupItemType? _pendingAddType;
  int _nextId = 0;

  late final TextEditingController _editingController;
  late final FocusNode _editingFocusNode;
  bool _isCommittingEditing = false;

  @override
  void initState() {
    super.initState();
    _items.addAll(_initialItems());
    _editingController = TextEditingController();
    _editingFocusNode = FocusNode();
    _editingFocusNode.addListener(() {
      if (!_editingFocusNode.hasFocus && _editingItemId != null) {
        _commitEditing();
      }
    });
  }

  @override
  void dispose() {
    _editingController.dispose();
    _editingFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const leftAvatar = ChatMockupAvatar(image: _leftAvatar);
    const rightAvatar = ChatMockupAvatar(image: _rightAvatar);

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
                  // 使用投影反馈区分“拖动中”与“选中编辑态”。
                  return Material(
                    color: Colors.transparent,
                    elevation: 8,
                    child: child,
                  );
                },
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildItem(item, index, leftAvatar, rightAvatar);
                },
              ),
            ),
          ),
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
        image: _sticker,
      ),
      _createItem(type: ChatMockupItemType.action, side: ChatMockupItemSide.center),
      _createItem(type: ChatMockupItemType.emoji, side: ChatMockupItemSide.left),
      _createItem(type: ChatMockupItemType.emoji, side: ChatMockupItemSide.right),
      _createItem(
        type: ChatMockupItemType.customImage,
        side: ChatMockupItemSide.left,
        image: _cover,
      ),
      _createItem(
        type: ChatMockupItemType.replyOptions,
        side: ChatMockupItemSide.right,
      ),
      _createItem(
        type: ChatMockupItemType.commission,
        side: ChatMockupItemSide.right,
      ),
    ];
  }

  Widget _buildAddControls() {
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
          _buildTypeAddButtons(),
          if (_pendingAddType != null) ...[
            const SizedBox(height: 8),
            _buildSidePicker(_pendingAddType!),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeAddButtons() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _addTypeButton('消息', ChatMockupItemType.message),
        _addTypeButton('表情', ChatMockupItemType.emoji),
        _addTypeButton('贴纸', ChatMockupItemType.sticker),
        _addTypeButton('图片', ChatMockupItemType.customImage),
        _addTypeButton('回复选项', ChatMockupItemType.replyOptions),
        _addTypeButton('动作', ChatMockupItemType.action),
        _addTypeButton('委托', ChatMockupItemType.commission),
      ],
    );
  }

  Widget _buildSidePicker(ChatMockupItemType type) {
    final sides = _allowedSidesForType(type);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (sides.contains(ChatMockupItemSide.left))
          _addSideButton('添加到左侧', type, ChatMockupItemSide.left),
        if (sides.contains(ChatMockupItemSide.right))
          _addSideButton('添加到右侧', type, ChatMockupItemSide.right),
        if (sides.contains(ChatMockupItemSide.center))
          _addSideButton('添加到中间', type, ChatMockupItemSide.center),
        TextButton(
          onPressed: () => setState(() => _pendingAddType = null),
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _addTypeButton(String label, ChatMockupItemType type) {
    final isPending = _pendingAddType == type;
    final allowedSides = _allowedSidesForType(type);
    final requiresSideSelection = allowedSides.length > 1;
    return ElevatedButton(
      onPressed: () {
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
    ChatMockupItemSide side,
  ) {
    return OutlinedButton(
      onPressed: () {
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

  Widget _buildItem(
    ChatMockupItem item,
    int index,
    Widget leftAvatar,
    Widget rightAvatar,
  ) {
    final isSelected = _selectedItemId == item.id;
    final isEditingThisItem = _editingItemId == item.id;
    final side = _toMessageSide(item.side);
    final avatar = item.side == ChatMockupItemSide.left
        ? leftAvatar
        : item.side == ChatMockupItemSide.right
            ? rightAvatar
            : null;

    return Column(
      key: ValueKey(item.id),
      children: [
        GestureDetector(
          behavior: isEditingThisItem
              ? HitTestBehavior.deferToChild
              : HitTestBehavior.translucent,
          onTap: isEditingThisItem
              ? null
              : () async {
                  setState(() => _selectedItemId = item.id);
                  await _handleItemTap(item);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? ChatMockupTheme.infoBlue : Colors.transparent,
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
        if (isSelected) _buildSelectionControls(item, index),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildItemContent(ChatMockupItem item) {
    final isMe = item.side == ChatMockupItemSide.right;
    final isEditingThisItem = _editingItemId == item.id;
    switch (item.type) {
      case ChatMockupItemType.message:
        if (isEditingThisItem && _editingField == ChatMockupEditableField.text) {
          return ChatMockupEditableTextBubble(
            controller: _editingController,
            focusNode: _editingFocusNode,
            isMe: isMe,
            hintText: 'Click here to edit',
            onSubmitted: (_) => _commitEditing(),
          );
        }
        return ChatMockupTextBubble(text: item.text ?? 'Click here to edit', isMe: isMe);
      case ChatMockupItemType.emoji:
        return ChatMockupEmojiBubble(
          emoji: item.emoji ?? '🙂',
          isMe: isMe,
        );
      case ChatMockupItemType.sticker:
        return ChatMockupImageBubble(
          image: item.image ?? _sticker,
          isMe: isMe,
          width: 88,
          height: 88,
        );
      case ChatMockupItemType.customImage:
        return ChatMockupImageBubble(
          image: item.image ?? _cover,
          isMe: isMe,
          frameColor: isMe ? null : Colors.white,
          width: 210,
          height: 132,
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
        final editingFirst = isEditingThisItem && _editingField == ChatMockupEditableField.firstReply;
        final editingSecond = isEditingThisItem && _editingField == ChatMockupEditableField.secondReply;
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

  Future<void> _handleItemTap(ChatMockupItem item) async {
    switch (item.type) {
      case ChatMockupItemType.message:
      case ChatMockupItemType.action:
        _startEditing(
          item.id,
          ChatMockupEditableField.text,
          initialValue: item.text ?? '',
        );
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
    if (_editingItemId != null &&
        (_editingItemId != itemId || _editingField != field)) {
      _commitEditing();
    }

    _editingController.text = initialValue;

    setState(() {
      _editingItemId = itemId;
      _editingField = field;
      _selectedItemId = itemId;
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
      final updated = index >= 0
          ? _items[index]
          : null; // used only when index exists

      if (index >= 0 && updated != null) {
        final nextItem = switch (field) {
          ChatMockupEditableField.text => updated.copyWith(
              text: input.isEmpty ? null : input,
            ),
          ChatMockupEditableField.title => updated.copyWith(
              title: input.isEmpty ? null : input,
            ),
          ChatMockupEditableField.subtitle => updated.copyWith(
              subtitle: input.isEmpty ? null : input,
            ),
          ChatMockupEditableField.firstReply => updated.copyWith(
              firstText: input.isEmpty ? null : input,
            ),
          ChatMockupEditableField.secondReply => updated.copyWith(
              secondText: input.isEmpty ? null : input,
            ),
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
        hintStyle: hintColor == null
            ? null
            : style.copyWith(color: hintColor),
        contentPadding: EdgeInsets.zero,
      ),
      onSubmitted: (_) => _commitEditing(),
      onEditingComplete: _commitEditing,
    );
  }

  Future<void> _showEmojiPicker(ChatMockupItem item) async {
    _commitEditing();

    const emojis = <String>[
      '🙂',
      '😂',
      '😭',
      '😍',
      '😎',
      '😡',
      '🤔',
      '👍',
      '👎',
      '❤️',
      '🔥',
      '🎉',
    ];

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
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                '如果你有《绝区零》的 emoji 表情，欢迎联系我。',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
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

  Future<List<AssetImage>> _loadSystemStickerAssets() async {
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    final manifestMap = jsonDecode(manifestJson) as Map<String, dynamic>;

    const zzzWebpPath = 'assets/images/zzz.webp';
    final stickerPngPaths = manifestMap.keys
        .where((k) =>
            k.startsWith('assets/images/ZZZ-2.1/') &&
            k.toLowerCase().endsWith('.png'))
        .toList()
      ..sort();

    // 保证 zzz.webp 永远位于最前，后续紧跟 ZZZ-2.1 下所有已打包 png。
    final orderedPaths = <String>[zzzWebpPath];
    for (final p in stickerPngPaths) {
      if (p == zzzWebpPath) continue;
      orderedPaths.add(p);
    }

    return orderedPaths.map((p) => AssetImage(p)).toList();
  }

  Future<void> _showStickerPicker(String itemId) async {
    _commitEditing();

    final pickerContext = context;
    final systemStickerAssets = await _loadSystemStickerAssets();
    if (!pickerContext.mounted) return;

    final selected = await showModalBottomSheet<ImageProvider>(
      context: pickerContext,
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: systemStickerAssets.map((sticker) {
                      return SizedBox(
                        width: 72,
                        height: 72,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, sticker),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image(
                              image: sticker,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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
      _items[index] = _items[index].copyWith(image: selected);
    });
  }

  Future<void> _pickImageForItem(String itemId) async {
    _commitEditing();

    const imageTypeGroup = XTypeGroup(
      label: 'Images',
      extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
      uniformTypeIdentifiers: [
        'public.png',
        'public.jpeg',
        'public.webp',
        'public.gif',
      ],
    );

    final file = await openFile(
      acceptedTypeGroups: const [imageTypeGroup],
      confirmButtonText: 'Select',
    );

    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    final imageProvider = MemoryImage(bytes);

    final index = _items.indexWhere((element) => element.id == itemId);
    if (index < 0) return;

    setState(() {
      _items[index] = _items[index].copyWith(image: imageProvider);
    });
  }

  Widget _buildSelectionControls(ChatMockupItem item, int index) {
    final enabled = _items.length > 1;
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
            onPressed: () => _removeItem(item.id),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
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
          child: const Icon(
            Icons.drag_indicator_rounded,
            color: Colors.white70,
          ),
        ),
      ),
    );

    final decorated = MouseRegion(
      cursor: enabled ? SystemMouseCursors.grab : SystemMouseCursors.basic,
      child: enabled
          ? Tooltip(
              message: '按住拖动排序',
              child: handle,
            )
          : handle,
    );

    return ReorderableDragStartListener(
      index: index,
      enabled: enabled,
      child: decorated,
    );
  }

  ChatMockupItem _createItem({
    required ChatMockupItemType type,
    required ChatMockupItemSide side,
    String? text,
    String? emoji,
    ImageProvider? image,
  }) {
    return ChatMockupItem(
      id: 'item_${_nextId++}',
      type: type,
      side: side,
      text: text,
      emoji: emoji,
      image: image,
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
    final allowed = _allowedSidesForType(type);
    final chosenSide = side ?? _defaultSideForType(type);
    if (!allowed.contains(chosenSide)) {
      return;
    }

    final item = _createItem(type: type, side: chosenSide);
    setState(() {
      _items.add(item);
      _selectedItemId = item.id;
      _pendingAddType = null;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _items.length) {
      return;
    }

    var adjustedIndex = newIndex;
    if (oldIndex < adjustedIndex) {
      adjustedIndex -= 1;
    }
    adjustedIndex = adjustedIndex.clamp(0, _items.length - 1);
    if (oldIndex == adjustedIndex) {
      return;
    }

    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(adjustedIndex, item);
    });
  }

  void _removeItem(String id) {
    setState(() {
      _items.removeWhere((item) => item.id == id);
      if (_selectedItemId == id) {
        _selectedItemId = null;
      }
      if (_editingItemId == id) {
        _editingItemId = null;
        _editingField = null;
      }
    });
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
