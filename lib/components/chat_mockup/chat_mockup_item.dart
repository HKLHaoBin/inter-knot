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
  const ChatMockupItem({
    required this.id,
    required this.type,
    required this.side,
    this.text,
    this.emoji,
    this.image,
  });

  final String id;
  final ChatMockupItemType type;
  final ChatMockupItemSide side;
  final String? text;
  final String? emoji;
  final ImageProvider? image;

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
