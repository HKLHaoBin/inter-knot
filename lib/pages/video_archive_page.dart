import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/gen/assets.gen.dart';

class VideoArchivePage extends StatefulWidget {
  const VideoArchivePage({super.key});

  @override
  State<VideoArchivePage> createState() => _VideoArchivePageState();
}

class _VideoArchivePageState extends State<VideoArchivePage> {
  final ScrollController _gridScrollController = ScrollController();
  _ArchiveFilter _selectedFilter = _ArchiveFilter.listed;
  String? _selectedTitle;

  List<VideoArchiveItem> get _filteredItems {
    switch (_selectedFilter) {
      case _ArchiveFilter.all:
        return _items;
      case _ArchiveFilter.listed:
        return _items.where((item) => item.listed).toList();
      case _ArchiveFilter.unlisted:
        return _items.where((item) => !item.listed).toList();
    }
  }

  VideoArchiveItem get _selectedItem {
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      return _items.first;
    }
    if (_selectedTitle == null) {
      return filtered.first;
    }
    return filtered.firstWhere(
      (item) => item.title == _selectedTitle,
      orElse: () => filtered.first,
    );
  }

  void _setFilter(_ArchiveFilter filter) {
    setState(() {
      _selectedFilter = filter;
      final existsInFilter = _filteredItems.any(
        (item) => item.title == _selectedTitle,
      );
      if (!existsInFilter) {
        _selectedTitle = _filteredItems.isEmpty ? null : _filteredItems.first.title;
      }
    });
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = _selectedItem;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _ArchiveTopBar(
              selectedFilter: _selectedFilter,
              onFilterSelected: _setFilter,
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _DiagonalStripeBackgroundPainter(),
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 900;
                      if (isCompact) {
                        return Column(
                          children: [
                            _ArchiveInfoPanel(
                              item: selectedItem,
                              compact: true,
                            ),
                            Expanded(
                              child: _ArchiveGrid(
                                items: _filteredItems,
                                selectedTitle: selectedItem.title,
                                scrollController: _gridScrollController,
                                compact: true,
                                onItemTap: (item) {
                                  setState(() => _selectedTitle = item.title);
                                },
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          SizedBox(
                            width: constraints.maxWidth.clamp(420, 480) * 0.34,
                            child: _ArchiveInfoPanel(
                              item: selectedItem,
                              compact: false,
                            ),
                          ),
                          Expanded(
                            child: _ArchiveGrid(
                              items: _filteredItems,
                              selectedTitle: selectedItem.title,
                              scrollController: _gridScrollController,
                              compact: false,
                              onItemTap: (item) {
                                setState(() => _selectedTitle = item.title);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveTopBar extends StatelessWidget {
  const _ArchiveTopBar({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final _ArchiveFilter selectedFilter;
  final ValueChanged<_ArchiveFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: Get.back,
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF3333), width: 2),
                  color: const Color(0x66120000),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFFFF3333),
                  size: 20,
                ),
              ),
            ),
            const Spacer(),
            _ArchiveFilterButton(
              selectedFilter: selectedFilter,
              onFilterSelected: onFilterSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveFilterButton extends StatelessWidget {
  const _ArchiveFilterButton({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final _ArchiveFilter selectedFilter;
  final ValueChanged<_ArchiveFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ArchiveFilter>(
      initialValue: selectedFilter,
      onSelected: onFilterSelected,
      color: const Color(0xFF131313),
      itemBuilder: (context) => _ArchiveFilter.values
          .map(
            (filter) => PopupMenuItem<_ArchiveFilter>(
              value: filter,
              child: Text(
                filter.label,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF656565)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedFilter.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _ArchiveInfoPanel extends StatelessWidget {
  const _ArchiveInfoPanel({
    required this.item,
    required this.compact,
  });

  final VideoArchiveItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 10, compact ? 16 : 24, 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xAA0A0A0A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -40,
              child: Icon(
                Icons.blur_circular_rounded,
                size: compact ? 140 : 200,
                color: const Color(0x1FFFFFFF),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.theme,
                    style: const TextStyle(
                      color: Color(0xFFB6B6B6),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        item.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          border: Border.all(color: const Color(0xFF515151)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '等级${item.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '录像带简介',
                    style: TextStyle(
                      color: Color(0xFFB6B6B6),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.6,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveGrid extends StatelessWidget {
  const _ArchiveGrid({
    required this.items,
    required this.selectedTitle,
    required this.scrollController,
    required this.compact,
    required this.onItemTap,
  });

  final List<VideoArchiveItem> items;
  final String selectedTitle;
  final ScrollController scrollController;
  final bool compact;
  final ValueChanged<VideoArchiveItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: GridView.builder(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(compact ? 12 : 8, 12, compact ? 12 : 20, 20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 232,
          mainAxisSpacing: 24,
          crossAxisSpacing: 28,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _ArchiveCard(
            item: item,
            selected: item.title == selectedTitle,
            onTap: () => onItemTap(item),
          );
        },
      ),
    );
  }
}

class _ArchiveCard extends StatefulWidget {
  const _ArchiveCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final VideoArchiveItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ArchiveCard> createState() => _ArchiveCardState();
}

class _ArchiveCardState extends State<_ArchiveCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _hovered ? 1.02 : 1,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.selected
                    ? const Color(0xFFD7FF00)
                    : Colors.transparent,
                width: 2,
              ),
              color: _hovered ? const Color(0x22000000) : Colors.transparent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _VhsCaseFrame(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        widget.item.coverAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, __) => Assets.images.defaultCover
                            .image(fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VhsCaseFrame extends StatelessWidget {
  const _VhsCaseFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF222222), Color(0xFF101010)],
        ),
        border: Border.all(color: const Color(0xFF4A4A4A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 22,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(9)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2C2C2C), Color(0xFF161616)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 5,
            top: 12,
            bottom: 12,
            width: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 7, 8, 7),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalStripeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF090909);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final stripePaint = Paint()
      ..color = const Color(0x17FFFFFF)
      ..strokeWidth = 1.1;
    const spacing = 8.0;
    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stripePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VideoArchiveItem {
  const VideoArchiveItem({
    required this.title,
    required this.theme,
    required this.category,
    required this.level,
    required this.description,
    required this.coverAsset,
    required this.listed,
  });

  final String title;
  final String theme;
  final String category;
  final int level;
  final String description;
  final String coverAsset;
  final bool listed;
}

enum _ArchiveFilter {
  all('上架筛选'),
  listed('仅上架'),
  unlisted('未上架');

  const _ArchiveFilter(this.label);
  final String label;
}

final _items = <VideoArchiveItem>[
  const VideoArchiveItem(
    title: '空洞茶会',
    theme: '录像带主题',
    category: '访谈',
    level: 3,
    description: '访谈类节目通常会邀请一些知名嘉宾或调查员点评谜团，来揭晓空洞遗留的奇闻异事。事情的真实性不重要，重要的是观众爱听。',
    coverAsset: 'assets/images/zzz.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '星徽骑士',
    theme: '特别篇',
    category: '动作',
    level: 2,
    description: '主打快节奏追击与极限对抗，故事热血夸张，适合在加班后提神醒脑。',
    coverAsset: 'assets/images/sr.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '下班神话',
    theme: '都市轻喜',
    category: '喜剧',
    level: 2,
    description: '讲述工位英雄的下班仪式感，每集都在荒诞与温柔之间切换。',
    coverAsset: 'assets/images/yuanshen.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '真相不止一个',
    theme: '推理专栏',
    category: '悬疑',
    level: 4,
    description: '每起案件都有多重视角，观众可在细节中反复拼凑真正结论。',
    coverAsset: 'assets/images/bh3.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '甜蜜都市',
    theme: '恋爱番',
    category: '情感',
    level: 1,
    description: '轻松甜向的都市故事，用明快剪辑和温暖台词打动观众。',
    coverAsset: 'assets/images/zzz.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '吾本如斯',
    theme: '独白录',
    category: '剧情',
    level: 3,
    description: '一封封未寄出的信拼出主角成长轨迹，克制但有后劲。',
    coverAsset: 'assets/images/sr.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '漩祸山',
    theme: '灾变实录',
    category: '惊悚',
    level: 5,
    description: '高压氛围与重低音配乐并进，强调未知环境中的生存抉择。',
    coverAsset: 'assets/images/yuanshen.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '无限玩家',
    theme: '游戏频道',
    category: '竞技',
    level: 3,
    description: '记录顶尖玩家在极限规则下的攻防博弈，解说节奏紧凑。',
    coverAsset: 'assets/images/bh3.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '黄昏广场',
    theme: '街景纪行',
    category: '人文',
    level: 2,
    description: '慢镜头和环境声拉满，适合在夜深时安静观看。',
    coverAsset: 'assets/images/zzz.webp',
    listed: false,
  ),
  const VideoArchiveItem(
    title: '暴侠之拳',
    theme: '拳斗热映',
    category: '动作',
    level: 4,
    description: '拳拳到肉的镜头语言配合夸张构图，打斗张力十足。',
    coverAsset: 'assets/images/sr.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '空洞漫游指南',
    theme: '探索手册',
    category: '探险',
    level: 3,
    description: '深入各类地带的路线纪录，夹杂真实见闻与生存技巧。',
    coverAsset: 'assets/images/yuanshen.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '黑蛛童话',
    theme: '暗色寓言',
    category: '奇幻',
    level: 4,
    description: '美术风格强烈，故事以寓言方式讨论欲望与代价。',
    coverAsset: 'assets/images/bh3.webp',
    listed: false,
  ),
  const VideoArchiveItem(
    title: '暴走出价',
    theme: '竞价节目',
    category: '真人秀',
    level: 2,
    description: '节奏明快、反转密集，观众互动感强。',
    coverAsset: 'assets/images/zzz.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '黑色唱片',
    theme: '午夜电台',
    category: '音乐',
    level: 2,
    description: '以低饱和霓虹视觉包装经典旧曲，情绪氛围突出。',
    coverAsset: 'assets/images/sr.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '激涡勇兵',
    theme: '战线纪录',
    category: '科幻',
    level: 3,
    description: '群像叙事与机动战术并重，战斗段落具有强烈层次。',
    coverAsset: 'assets/images/yuanshen.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '卡乐透',
    theme: '奇遇喜剧',
    category: '喜剧',
    level: 1,
    description: '每一集都围绕一次离谱中奖展开，欢乐轻松。',
    coverAsset: 'assets/images/bh3.webp',
    listed: false,
  ),
  const VideoArchiveItem(
    title: '最后一次飞行',
    theme: '旧日冒险',
    category: '冒险',
    level: 4,
    description: '讲述老牌飞行员的收官任务，情感浓度和风险并存。',
    coverAsset: 'assets/images/zzz.webp',
    listed: true,
  ),
  const VideoArchiveItem(
    title: '邦布超胆！',
    theme: '番外短剧',
    category: '搞笑',
    level: 1,
    description: '节奏超快的短篇合集，以夸张段子和反差包袱见长。',
    coverAsset: 'assets/images/sr.webp',
    listed: false,
  ),
];
