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
  static const _noChange = _ChatMockupItemNoChange();

  ChatMockupItem({
    required this.id,
    required this.type,
    required this.side,
    this.text,
    this.emoji,
    this.image,
    this.title,
    this.subtitle,
    this.firstText,
    this.secondText,
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
  final String? title;
  final String? subtitle;
  final String? firstText;
  final String? secondText;

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
    Object? text = _noChange,
    String? emoji,
    ImageProvider? image,
    Object? title = _noChange,
    Object? subtitle = _noChange,
    Object? firstText = _noChange,
    Object? secondText = _noChange,
  }) {
    String? resolveText(Object? value, String? current) {
      if (value == _noChange) return current;
      return value as String?;
    }

    return ChatMockupItem(
      id: id ?? this.id,
      type: type ?? this.type,
      side: side ?? this.side,
      text: resolveText(text, this.text),
      emoji: emoji ?? this.emoji,
      image: image ?? this.image,
      title: resolveText(title, this.title),
      subtitle: resolveText(subtitle, this.subtitle),
      firstText: resolveText(firstText, this.firstText),
      secondText: resolveText(secondText, this.secondText),
    );
  }
}

class _ChatMockupItemNoChange {
  const _ChatMockupItemNoChange();
}
