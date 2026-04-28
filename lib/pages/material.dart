import 'package:flutter/material.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/gen/assets.gen.dart';

void main() {
  runApp(const KnockKnockApp());
}

class KnockKnockApp extends StatelessWidget {
  const KnockKnockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const KnockKnockPage(),
      theme: ThemeData(
        fontFamily: 'Arial',
        useMaterial3: true,
      ),
    );
  }
}

class KnockKnockPage extends StatelessWidget {
  const KnockKnockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff151515),
      body: Center(
        child: AspectRatio(
          aspectRatio: 1146 / 727,
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff1d1d1d),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xff3b3b3b), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: const Stack(
                children: [
                  Positioned.fill(child: BackgroundPattern()),
                  Column(
                    children: [
                      TopBar(),
                      Expanded(child: MainContent()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BackgroundPattern extends StatelessWidget {
  const BackgroundPattern({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: BackgroundPatternPainter(),
    );
  }
}

class BackgroundPatternPainter extends CustomPainter {
  const BackgroundPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xff202020);
    canvas.drawRect(Offset.zero & size, base);

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;

    for (var i = -2; i < 8; i++) {
      final path = Path()
        ..moveTo(i * size.width / 5, 0)
        ..lineTo(i * size.width / 5 + 120, 0)
        ..lineTo(i * size.width / 5 - 40, size.height)
        ..lineTo(i * size.width / 5 - 180, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }

    final bigLetterPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32;

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          fontSize: size.height * 0.9,
          fontWeight: FontWeight.w900,
          foreground: bigLetterPaint,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(size.width * 0.38, size.height * 0.08),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(horizontal: 38),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        border: const Border(
          bottom: BorderSide(color: Color(0xff303030), width: 2),
        ),
      ),
      child: Row(
        children: [
          Transform.rotate(
            angle: -0.18,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xffffe300),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(width: 3),
              ),
              child: const Icon(
                Icons.phone_android,
                color: Colors.black,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'knock knock',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ClickRegion(
              onTap: () => Navigator.of(context).maybePop(),
              child: Assets.images.closeBtn.image(),
            ),
          ),
        ],
      ),
    );
  }
}

class MainContent extends StatefulWidget {
  const MainContent({super.key});

  @override
  State<MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<MainContent> {
  int selectedTabIndex = 1;
  int selectedContactIndex = 2;
  bool catalogExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(38, 20, 38, 28),
      child: Row(
        children: [
          SizedBox(
            width: 292,
            child: ContactPanel(
              selectedTabIndex: selectedTabIndex,
              onTabSelected: (index) => setState(() => selectedTabIndex = index),
              selectedContactIndex: selectedContactIndex,
              onContactSelected: (index) =>
                  setState(() => selectedContactIndex = index),
              catalogExpanded: catalogExpanded,
              onCatalogToggle: () =>
                  setState(() => catalogExpanded = !catalogExpanded),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: ChatPanel(
              selectedContactName: kContacts[selectedContactIndex].name,
            ),
          ),
        ],
      ),
    );
  }
}

class ContactPanel extends StatelessWidget {
  const ContactPanel({
    super.key,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.selectedContactIndex,
    required this.onContactSelected,
    required this.catalogExpanded,
    required this.onCatalogToggle,
  });

  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final int selectedContactIndex;
  final ValueChanged<int> onContactSelected;
  final bool catalogExpanded;
  final VoidCallback onCatalogToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          children: [
            ContactTabs(
              selectedTabIndex: selectedTabIndex,
              onTabSelected: onTabSelected,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ContactList(
                selectedContactIndex: selectedContactIndex,
                onContactSelected: onContactSelected,
              ),
            ),
            const SizedBox(height: 10),
            CatalogButton(
              expanded: catalogExpanded,
              onTap: onCatalogToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class ContactTabs extends StatelessWidget {
  const ContactTabs({
    super.key,
    required this.selectedTabIndex,
    required this.onTabSelected,
  });

  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;

  static const _icons = [
    Icons.directions_run_rounded,
    Icons.person,
    Icons.groups_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xff1b1b1b),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(_icons.length, (index) {
          return Expanded(
            child: tabIcon(
              icon: _icons[index],
              selected: selectedTabIndex == index,
              onTap: () => onTabSelected(index),
            ),
          );
        }),
      ),
    );
  }

  Widget tabIcon({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ClickRegion(
      onTap: onTap,
      child: Center(
        child: OverflowBox(
          minHeight: 38,
          maxHeight: 56,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, selected ? -2 : 0, 0),
            width: double.infinity,
            height: selected ? 52 : 38,
            decoration: BoxDecoration(
              color: selected ? const Color(0xffffe600) : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              icon,
              color: selected ? Colors.black : Colors.white,
              size: 27,
            ),
          ),
        ),
      ),
    );
  }
}

class ContactList extends StatelessWidget {
  const ContactList({
    super.key,
    required this.selectedContactIndex,
    required this.onContactSelected,
  });

  final int selectedContactIndex;
  final ValueChanged<int> onContactSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kContacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return ContactCard(
          data: kContacts[index],
          selected: selectedContactIndex == index,
          onTap: () => onContactSelected(index),
        );
      },
    );
  }
}

class ContactData {
  final String name;
  final String subtitle;
  final String avatar;

  const ContactData(this.name, this.subtitle, this.avatar);
}

class ContactCard extends StatelessWidget {
  final ContactData data;
  final bool selected;
  final VoidCallback onTap;

  const ContactCard({
    super.key,
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xffffe600) : const Color(0xff363636);
    final nameColor = selected ? Colors.black : Colors.white;
    final subColor = selected ? const Color(0xff6b6500) : const Color(0xffa7a7a7);

    return ClickRegion(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(
            color: selected ? const Color(0xff252500) : const Color(0xff2b2b2b),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            GameAvatar(
              label: data.avatar,
              size: 54,
              ringColor: selected ? Colors.white : const Color(0xff242424),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DefaultTextStyle(
                style: TextStyle(color: nameColor),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: nameColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogButton extends StatelessWidget {
  const CatalogButton({
    super.key,
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClickRegion(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: expanded ? const Color(0xff111111) : Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xff242424), width: 2),
        ),
        child: Row(
          children: [
            const Text(
              '目录设置',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Icon(
              expanded
                  ? Icons.arrow_drop_up_rounded
                  : Icons.arrow_drop_down_rounded,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPanel extends StatelessWidget {
  const ChatPanel({
    super.key,
    required this.selectedContactName,
  });

  final String selectedContactName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: panelDecoration(),
      child: Column(
        children: [
          ChatHeader(contactName: selectedContactName),
          const Expanded(
            child: ChatBody(),
          ),
        ],
      ),
    );
  }
}

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.contactName,
  });

  final String contactName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xff202020), width: 3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_rounded,
            color: Color(0xff454545),
            size: 25,
          ),
          const SizedBox(width: 8),
          Text(
            contactName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBody extends StatelessWidget {
  const ChatBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 22, 18),
          children: const [
            LeftMessage(text: '什么事？'),
            SizedBox(height: 48),
            RightMessage(text: '走啊你兄弟'),
            SizedBox(height: 36),
            LeftMessage(text: '去跳舞？'),
            SizedBox(height: 36),
            RightMessage(text: '看个电影吧？'),
            SizedBox(height: 36),
            LeftMessage(text: '电影'),
            SizedBox(height: 10),
            LeftMessage(text: '好。'),
            SizedBox(height: 10),
            LeftMessage(text: '那么跟在光影广场见面'),
            SizedBox(height: 10),
            LeftMessage(text: '一起去电影院吧。'),
          ],
        ),
        Center(
          child: Opacity(
            opacity: 0.35,
            child: Icon(
              Icons.fullscreen_exit_rounded,
              color: Colors.white.withValues(alpha: 0.55),
              size: 36,
            ),
          ),
        ),
      ],
    );
  }
}

class LeftMessage extends StatelessWidget {
  final String text;

  const LeftMessage({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const GameAvatar(
          label: '👤',
          size: 46,
          ringColor: Colors.white,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: ChatBubble(
            text: text,
            color: Colors.white,
            textColor: Colors.black,
            alignment: BubbleAlignment.left,
          ),
        ),
      ],
    );
  }
}

class RightMessage extends StatelessWidget {
  final String text;

  const RightMessage({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: ChatBubble(
            text: text,
            color: const Color(0xff2469ff),
            textColor: Colors.white,
            alignment: BubbleAlignment.right,
          ),
        ),
        const SizedBox(width: 10),
        const GameAvatar(
          label: '🐟',
          size: 46,
          ringColor: Color(0xffbdf6ff),
        ),
      ],
    );
  }
}

enum BubbleAlignment {
  left,
  right,
}

class ChatBubble extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final BubbleAlignment alignment;

  const ChatBubble({
    super.key,
    required this.text,
    required this.color,
    required this.textColor,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(alignment == BubbleAlignment.left ? 6 : 20),
      topRight: Radius.circular(alignment == BubbleAlignment.right ? 6 : 20),
      bottomLeft: const Radius.circular(20),
      bottomRight: const Radius.circular(20),
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          height: 1.15,
        ),
      ),
    );
  }
}

class GameAvatar extends StatelessWidget {
  final String label;
  final double size;
  final Color ringColor;

  const GameAvatar({
    super.key,
    required this.label,
    required this.size,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ringColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xffdffaff),
              Color(0xff78d1e8),
              Color(0xff262626),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: size * 0.44),
        ),
      ),
    );
  }
}

BoxDecoration panelDecoration() {
  return BoxDecoration(
    color: Colors.black.withValues(alpha: 0.78),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xff151515), width: 3),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.85),
        blurRadius: 8,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

const kContacts = [
  ContactData('「忍の」田富侠客', '暂无新的消息', '😸'),
  ContactData('真困', '新的大本营重置了，啊 —', '🧊'),
  ContactData('寂寞鸭', '【已办】消息信息', '👤'),
  ContactData('乱叫怪', '这下要露馅心了，哥不 —', '⚡'),
  ContactData('乱七八糟抢盗', '打了几遍才想起来吗 —', '😼'),
  ContactData('周生陌生人', '一摊照，跳到同一张鱼 —', '🧊'),
];
