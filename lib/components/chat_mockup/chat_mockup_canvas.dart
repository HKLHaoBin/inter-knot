import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_avatar.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_bubble.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_card.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_message.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_title_bar.dart';

class ChatMockupCanvas extends StatelessWidget {
  const ChatMockupCanvas({super.key});

  static const AssetImage _leftAvatar = AssetImage('assets/images/zzzicon.png');
  static const AssetImage _rightAvatar = AssetImage('assets/images/Bangboo.gif');
  static const AssetImage _sticker = AssetImage('assets/images/zzz.webp');
  static const AssetImage _cover = AssetImage('assets/images/pc-page-bg.png');

  @override
  Widget build(BuildContext context) {
    const leftAvatar = ChatMockupAvatar(image: _leftAvatar);
    const rightAvatar = ChatMockupAvatar(image: _rightAvatar);

    return ColoredBox(
      color: ChatMockupTheme.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        children: const [
          ChatMockupTitleBar(),
          ChatMockupMessage(
            isMe: false,
            avatar: leftAvatar,
            child: ChatMockupTextBubble(
              text: 'Click on messages to edit and show actions.',
              isMe: false,
            ),
          ),
          ChatMockupMessage(
            isMe: true,
            avatar: rightAvatar,
            child: ChatMockupTextBubble(
              text: 'Click on chat icons to change them.',
              isMe: true,
            ),
          ),
          ChatMockupMessage(
            isMe: true,
            avatar: rightAvatar,
            child: ChatMockupImageBubble(
              image: _sticker,
              isMe: true,
              width: 88,
              height: 88,
            ),
          ),
          ChatMockupMessage(
            isMe: true,
            avatar: rightAvatar,
            child: ChatMockupActionCard(
              icon: Icons.error_outline_rounded,
              iconColor: ChatMockupTheme.warningGreen,
              title: 'Click here to edit',
              actionText: 'Add',
            ),
          ),
          ChatMockupMessage(
            isMe: false,
            avatar: leftAvatar,
            child: ChatMockupEmojiBubble(emoji: '🙂', isMe: false),
          ),
          ChatMockupMessage(
            isMe: true,
            avatar: rightAvatar,
            child: ChatMockupEmojiBubble(emoji: '🙂', isMe: true),
          ),
          ChatMockupMessage(
            isMe: false,
            avatar: leftAvatar,
            child: ChatMockupImageBubble(
              image: _sticker,
              isMe: false,
              width: 86,
              height: 86,
            ),
          ),
          ChatMockupMessage(
            isMe: true,
            avatar: rightAvatar,
            child: ChatMockupImageBubble(
              image: _sticker,
              isMe: true,
              width: 92,
              height: 92,
            ),
          ),
          ChatMockupDividerText(),
          ChatMockupMessage(
            isMe: true,
            avatar: rightAvatar,
            child: ChatMockupReplyCard(),
          ),
          ChatMockupMessage(
            isMe: true,
            avatar: rightAvatar,
            child: ChatMockupActionCard(
              icon: Icons.info_outline_rounded,
              iconColor: ChatMockupTheme.infoBlue,
              title: 'Click here to edit',
              actionText: 'View Schedule',
            ),
          ),
          ChatMockupMessage(
            isMe: false,
            avatar: leftAvatar,
            child: ChatMockupImageBubble(
              image: _cover,
              isMe: false,
              frameColor: Colors.white,
              width: 314,
              height: 214,
            ),
          ),
        ],
      ),
    );
  }
}
