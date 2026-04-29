import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_avatar.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_bubble.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_card.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_item.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_message.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_title_bar.dart';

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
  ChatMockupItemType? _pendingAddType;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _items.addAll(_initialItems());
  }

  @override
  Widget build(BuildContext context) {
    const leftAvatar = ChatMockupAvatar(image: _leftAvatar);
    const rightAvatar = ChatMockupAvatar(image: _rightAvatar);

    return ColoredBox(
      color: ChatMockupTheme.background,
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        onReorder: _onReorder,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        header: Column(
          children: [const ChatMockupTitleBar(), _buildAddControls()],
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return _buildItem(item, index, leftAvatar, rightAvatar);
        },
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
          behavior: HitTestBehavior.translucent,
          onTap: () => setState(() => _selectedItemId = item.id),
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
    switch (item.type) {
      case ChatMockupItemType.message:
        return ChatMockupTextBubble(
          text: item.text ?? 'Click here to edit',
          isMe: isMe,
        );
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
        return const ChatMockupActionCard(
          icon: Icons.info_outline_rounded,
          iconColor: ChatMockupTheme.infoBlue,
          title: 'Click here to edit',
          actionText: 'Action',
          isCenter: true,
        );
      case ChatMockupItemType.replyOptions:
        return const ChatMockupReplyCard();
      case ChatMockupItemType.commission:
        return const ChatMockupCommissionCard();
    }
  }

  Widget _buildSelectionControls(ChatMockupItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xff181818),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ReorderableDelayedDragStartListener(
            index: index,
            enabled: _items.length > 1,
            child: const IconButton(
              onPressed: null,
              icon: const Icon(
                Icons.drag_indicator_rounded,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _removeItem(item.id),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
          ),
        ],
      ),
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
