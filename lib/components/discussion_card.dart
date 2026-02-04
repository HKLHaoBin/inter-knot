import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/comment_count.dart';
import 'package:inter_knot/components/my_html_widget.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DiscussionCard extends StatefulWidget {
  const DiscussionCard({
    super.key,
    this.onTap,
    required this.discussion,
    required this.hData,
  });

  final DiscussionModel discussion;
  final HDataModel hData;
  final void Function()? onTap;

  @override
  State<DiscussionCard> createState() => _DiscussionCardState();
}

class _DiscussionCardState extends State<DiscussionCard>
    with AutomaticKeepAliveClientMixin {
  final c = Get.find<Controller>();
  double elevation = 1.0;
  static const _debugLayout = false;

  Color _parseLabelColor(String hex) {
    final normalized = hex.trim().replaceAll('#', '');
    final value = normalized.length == 3
        ? normalized.split('').map((c) => '$c$c').join()
        : normalized;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null || value.length != 6) {
      return const Color(0xff6e7681);
    }
    return Color(0xff000000 | parsed);
  }

  Color _labelTextColor(Color background) {
    return background.computeLuminance() > 0.5
        ? const Color(0xff0d1117)
        : Colors.white;
  }

  Widget _buildLabelChip(String name, String colorHex) {
    final background = _parseLabelColor(colorHex);
    final foreground = _labelTextColor(background);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: background.withValues(alpha: 0.9),
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }

  List<Widget> _buildTagChips() {
    final chips = <Widget>[];
    final categoryName = widget.discussion.categoryName?.trim();
    if (categoryName != null && categoryName.isNotEmpty) {
      chips.add(_buildLabelChip(categoryName, '6e7681'));
    }
    chips.addAll(
      widget.discussion.labels
          .map((label) => _buildLabelChip(label.name, label.color)),
    );
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() {
      final historyItems = c.history.whereType<HDataModel>();
      final tagChips = _buildTagChips();
      return Badge(
        isLabelVisible: !historyItems
                .map((e) => e.number)
                .contains(widget.discussion.number) ||
            historyItems
                    .firstWhere(
                      (e) => e.number == widget.discussion.number,
                      orElse: () => widget.hData,
                    )
                    .updatedAt !=
                widget.hData.updatedAt,
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: elevation,
          color: const Color(0xff222222),
          child: Obx(() {
            if (!c.canVisit(widget.discussion, widget.hData.isPin)) {
              return AspectRatio(
                aspectRatio: 5 / 6,
                child: InkWell(
                  onTap: () => launchUrlString(widget.discussion.url),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'This discussion is suspected of violating regulations'
                              .tr,
                        ),
                        Text(
                          'This discussion was reported by @count people'
                              .trParams({
                            'count': c.report[widget.discussion.number]!.length
                                .toString(),
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return InkWell(
              onTap: () => widget.onTap?.call(),
              onTapDown: (_) => setState(() => elevation = 4),
              onTapUp: (_) => setState(() => elevation = 1),
              onTapCancel: () => setState(() => elevation = 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 600,
                          minHeight: 100,
                        ),
                        child: Cover(discussion: widget.discussion),
                      ),
                      if (_debugLayout)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.redAccent.withValues(alpha: 0.6),
                                ),
                              ),
                              alignment: Alignment.topLeft,
                              padding: const EdgeInsets.all(6),
                              child: const Text(
                                'DEBUG: cover',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        left: 12,
                        child: CommentCount(
                          discussion: widget.discussion,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.hData.isPin)
                        Positioned(
                          top: 8,
                          right: 12,
                          child: Text(
                            'Top'.tr,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          Positioned(
                            top: -26,
                            child: Avatar(
                              widget.discussion.author.avatar,
                              size: 50,
                            ),
                          ),
                          const Visibility(
                            visible: false,
                            child: Padding(
                              padding: EdgeInsets.only(left: 54),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  SizedBox.shrink(),
                                  SizedBox(height: 4),
                                  Divider(height: 1),
                                ],
                              ),
                            ),
                          ),
                          if (_debugLayout)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.greenAccent.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  alignment: Alignment.topLeft,
                                  padding: const EdgeInsets.all(6),
                                  child: const Text(
                                    'DEBUG: avatar row',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.discussion.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        if (_debugLayout)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'DEBUG: title',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (tagChips.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tagChips,
                      ),
                    ),
                  ],
                  if (widget.discussion.rawBodyText.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        widget.discussion.bodyText,
                        style: const TextStyle(color: Color(0xffB3B3B1)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ),
                    if (_debugLayout)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'DEBUG: summary',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            );
          }),
        ),
      );
    });
  }

  @override
  bool get wantKeepAlive => true;
}

class Cover extends StatelessWidget {
  const Cover({super.key, required this.discussion});

  final DiscussionModel discussion;

  @override
  Widget build(BuildContext context) {
    if (discussion.coverIsIframe && discussion.cover != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: MyHtmlWidget(html: discussion.cover!),
      );
    }
    return discussion.cover == null
        ? Assets.images.defaultCover.image(
            width: double.infinity,
            fit: BoxFit.cover,
          )
        : Image.network(
            discussion.cover!,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, p) {
              if (p == null) return child;
              final total = p.expectedTotalBytes;
              final cur = p.cumulativeBytesLoaded;
              return AspectRatio(
                aspectRatio: 643 / 408,
                child: Center(
                  child: CircularProgressIndicator(
                    value: total == null || cur == 0 ? null : cur / total,
                  ),
                ),
              );
            },
            errorBuilder: (context, e, s) => Assets.images.defaultCover.image(
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          );
  }
}
