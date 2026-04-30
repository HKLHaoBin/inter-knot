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

enum ChatMockupImageSourceType {
  asset,
  memory,
}

enum ChatMockupWaitMode {
  auto,
  manual,
}

class ChatMockupImageSource {
  static const int _maxMemoryImageBytes = 8 * 1024 * 1024;
  static const Set<String> _supportedImageMimeTypes = {
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
  };

  const ChatMockupImageSource({
    required this.type,
    required this.value,
    this.mimeType,
  });

  final ChatMockupImageSourceType type;
  final String value;
  final String? mimeType;

  factory ChatMockupImageSource.memory({
    required List<int> bytes,
    required String mimeType,
  }) {
    if (!_supportedImageMimeTypes.contains(mimeType)) {
      throw const FormatException('Unsupported memory image mime type.');
    }
    if (bytes.isEmpty) {
      throw const FormatException('Empty memory image bytes.');
    }
    if (bytes.length > _maxMemoryImageBytes) {
      throw const FormatException('Memory image is too large.');
    }
    final base64 = UriData.fromBytes(bytes, mimeType: mimeType).toString();
    final commaIndex = base64.indexOf(',');
    if (commaIndex < 0 || commaIndex >= base64.length - 1) {
      throw const FormatException('Invalid memory image bytes.');
    }
    return ChatMockupImageSource(
      type: ChatMockupImageSourceType.memory,
      value: base64.substring(commaIndex + 1),
      mimeType: mimeType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'value': value,
      if (mimeType != null) 'mimeType': mimeType,
    };
  }

  factory ChatMockupImageSource.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'];
    final value = json['value'];
    if (typeName is! String || value is! String || value.isEmpty) {
      throw const FormatException('Invalid image source.');
    }
    final type = ChatMockupImageSourceType.values.firstWhere(
      (element) => element.name == typeName,
      orElse: () => throw const FormatException('Unsupported image source type.'),
    );
    final rawMimeType = json['mimeType'];
    final mimeType =
        rawMimeType is String && rawMimeType.isNotEmpty ? rawMimeType : null;
    if (type == ChatMockupImageSourceType.memory) {
      if (mimeType == null || !_supportedImageMimeTypes.contains(mimeType)) {
        throw const FormatException('Unsupported memory image mime type.');
      }
      try {
        ChatMockupImageSource.memory(
          bytes: UriData.parse('data:$mimeType;base64,$value').contentAsBytes(),
          mimeType: mimeType,
        );
      } catch (_) {
        throw const FormatException('Invalid memory image base64.');
      }
    }
    return ChatMockupImageSource(
      type: type,
      value: value,
      mimeType: mimeType,
    );
  }

  ImageProvider toImageProvider() {
    switch (type) {
      case ChatMockupImageSourceType.asset:
        return AssetImage(value);
      case ChatMockupImageSourceType.memory:
        return MemoryImage(UriData.parse('data:${mimeType ?? 'application/octet-stream'};base64,$value').contentAsBytes());
    }
  }
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
    this.imageSource,
    this.avatarSource,
    this.title,
    this.subtitle,
    this.firstText,
    this.secondText,
    this.waitMode = ChatMockupWaitMode.auto,
    this.waitSeconds = 0,
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
  final ChatMockupImageSource? imageSource;
  final ChatMockupImageSource? avatarSource;
  final String? title;
  final String? subtitle;
  final String? firstText;
  final String? secondText;
  final ChatMockupWaitMode waitMode;
  final double waitSeconds;

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
    Object? image = _noChange,
    Object? imageSource = _noChange,
    Object? avatarSource = _noChange,
    Object? title = _noChange,
    Object? subtitle = _noChange,
    Object? firstText = _noChange,
    Object? secondText = _noChange,
    ChatMockupWaitMode? waitMode,
    double? waitSeconds,
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
      image: image == _noChange ? this.image : image as ImageProvider?,
      imageSource: imageSource == _noChange
          ? this.imageSource
          : imageSource as ChatMockupImageSource?,
      avatarSource: avatarSource == _noChange
          ? this.avatarSource
          : avatarSource as ChatMockupImageSource?,
      title: resolveText(title, this.title),
      subtitle: resolveText(subtitle, this.subtitle),
      firstText: resolveText(firstText, this.firstText),
      secondText: resolveText(secondText, this.secondText),
      waitMode: waitMode ?? this.waitMode,
      waitSeconds: waitSeconds ?? this.waitSeconds,
    );
  }
}

class _ChatMockupItemNoChange {
  const _ChatMockupItemNoChange();
}
