import 'package:flutter/material.dart';

enum ChatMockupItemType {
  message,
  emoji,
  sticker,
  customImage,
  action,
  replyOptions,
  commission,
}

enum ChatMockupItemSide {
  left,
  right,
  center,
}

class ChatMockupItem {
  ChatMockupItem({
    required this.id,
    required this.type,
    required this.side,
    this.text,
    this.emoji,
    this.image,
  }) : assert(
         _isSideAllowed(type, side),
         'Invalid side $side for type $type',
       );

  final String id;
  final ChatMockupItemType type;
  final ChatMockupItemSide side;
  final String? text;
  final String? emoji;
  final ImageProvider? image;

  static bool _isSideAllowed(
    ChatMockupItemType type,
    ChatMockupItemSide side,
  ) {
    switch (type) {
      case ChatMockupItemType.message:
      case ChatMockupItemType.emoji:
      case ChatMockupItemType.sticker:
      case ChatMockupItemType.customImage:
        return side == ChatMockupItemSide.left || side == ChatMockupItemSide.right;
      case ChatMockupItemType.replyOptions:
      case ChatMockupItemType.commission:
        return side == ChatMockupItemSide.right;
      case ChatMockupItemType.action:
        return side == ChatMockupItemSide.center;
    }
  }

  ChatMockupItem copyWith({
    String? id,
    ChatMockupItemType? type,
    ChatMockupItemSide? side,
    String? text,
    String? emoji,
    ImageProvider? image,
  }) {
    return ChatMockupItem(
      id: id ?? this.id,
      type: type ?? this.type,
      side: side ?? this.side,
      text: text ?? this.text,
      emoji: emoji ?? this.emoji,
      image: image ?? this.image,
    );
  }
}
