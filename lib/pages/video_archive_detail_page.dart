import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/components/discussion_badge.dart';
import 'package:inter_knot/components/discussion_labels.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/ai_review_helper.dart';
import 'package:inter_knot/helpers/discussion_actions.dart';
import 'package:inter_knot/helpers/discussion_category_helper.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/video_archive_entry.dart';
import 'package:inter_knot/pages/discussion_page.dart';
import 'package:inter_knot/pages/video_player_page.dart';

class VideoArchiveDetailPage extends StatefulWidget {
  const VideoArchiveDetailPage({super.key, required this.entry});

  final VideoArchiveEntry entry;

  @override
  State<VideoArchiveDetailPage> createState() => _VideoArchiveDetailPageState();
}

class _VideoArchiveDetailPageState extends State<VideoArchiveDetailPage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final Controller _c = Get.find<Controller>();
  late final HDataModel _hData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final d = widget.entry.discussion;
    _hData = HDataModel(
      number: d.number,
      updatedAt: d.lastEditedAt ?? d.createdAt,
      isPinned: false,
      labels: d.labels,
    );
    _scrollController.addListener(_onScroll);
    d.fetchComments().then((_) async {
      try {
        while (mounted &&
            _scrollController.hasClients &&
            _scrollController.position.maxScrollExtent == 0 &&
            d.hasNextPage()) {
          await d.fetchComments();
        }
      } catch (e, s) {
        logger.e('Failed to get scroll position', error: e, stackTrace: s);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final d = widget.entry.discussion;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 200 && d.hasNextPage()) {
      d.fetchComments();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _c.isLogin()) {
      widget.entry.discussion.refreshComments();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _startPlay(BuildContext context) {
    final entry = widget.entry;
    if (!entry.isValid) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('数据格式错误'),
          content: SelectableText(entry.errorMessage ?? '未知错误'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
      return;
    }
    Get.to(() => VideoPlayerPage(entry: entry));
  }

  Widget _discussionStyleStartPlaySlot(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff222222),
              borderRadius: BorderRadius.circular(maxRadius),
              border: Border.all(color: const Color(0xff2D2D2D), width: 4),
            ),
            child: ClickRegion(
              onTap: () => _startPlay(context),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline),
                  SizedBox(width: 8),
                  Text(
                    '开始游玩',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final entry = widget.entry;

    return SafeArea(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: screenW < 800 ? 1 : 0.8,
            heightFactor: screenW < 800 ? 1 : 0.9,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color.fromARGB(59, 255, 255, 255),
                borderRadius: screenW < 800
                    ? BorderRadius.zero
                    : const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: screenW < 800
                      ? BorderRadius.zero
                      : const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                ),
                child: ClipRRect(
                  borderRadius: screenW < 800
                      ? BorderRadius.zero
                      : const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                  child: Scaffold(
                    backgroundColor: const Color(0xff121212),
                    body: Column(
                      children: [
                        DiscussionHeaderBar(
                          discussion: entry.discussion,
                          onClose: () => Get.back(),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, con) {
                              if (con.maxWidth < 600) {
                                return ListView(
                                  controller: _scrollController,
                                  children: [
                                    Container(
                                      constraints:
                                          const BoxConstraints(maxHeight: 500),
                                      width: double.infinity,
                                      child: Cover(
                                        discussion: entry.discussion,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        24,
                                        16,
                                        0,
                                      ),
                                      child: _VideoArchiveDetailContentBox(
                                        entry: entry,
                                        hData: _hData,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        16,
                                        16,
                                        0,
                                      ),
                                      child: _discussionStyleStartPlaySlot(
                                        context,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(color: Color(0xff2D2D2D)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: DiscussionCommentSection(
                                        discussion: entry.discussion,
                                        hData: _hData,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        top: 16,
                                        left: 16,
                                        right: 8,
                                        bottom: 16,
                                      ),
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xff313132),
                                          width: 4,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Cover(
                                          discussion: entry.discussion,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 5,
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        top: 16,
                                        left: 8,
                                        right: 16,
                                        bottom: 16,
                                      ),
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xff070707),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: SingleChildScrollView(
                                        controller: _scrollController,
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            24,
                                            16,
                                            24,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _VideoArchiveDetailContentBox(
                                                entry: entry,
                                                hData: _hData,
                                              ),
                                              const SizedBox(height: 16),
                                              _discussionStyleStartPlaySlot(
                                                context,
                                              ),
                                              const SizedBox(height: 16),
                                              const Divider(
                                                color: Color(0xff2D2D2D),
                                              ),
                                              DiscussionCommentSection(
                                                discussion: entry.discussion,
                                                hData: _hData,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoArchiveDetailContentBox extends StatelessWidget {
  const _VideoArchiveDetailContentBox({
    required this.entry,
    required this.hData,
  });

  final VideoArchiveEntry entry;
  final HDataModel hData;

  @override
  Widget build(BuildContext context) {
    final discussion = entry.discussion;
    final badges = <Widget>[];
    final aiReviewRating =
        discussion.aiReviewRatingFromLabels ?? hData.aiReviewRatingFromLabels;
    final aiReviewView = mapAiReviewRatingView(aiReviewRating);
    final categoryView = mapDiscussionCategory(discussion.categoryName);
    final visibleLabels = filterBusinessLabels(discussion.labels);
    if (hData.isPin) {
      badges.add(
        DiscussionBadge(
          text: 'Top'.tr,
          color: const Color(0xffD7FF00),
        ),
      );
    }
    if (aiReviewView != null) {
      badges.add(
        DiscussionBadge(
          text: aiReviewView.displayName.tr,
          color: aiReviewView.color,
        ),
      );
    }
    if (categoryView != null) {
      badges.add(
        DiscussionBadge(
          text: categoryView.displayName,
          color: categoryView.color,
        ),
      );
    }

    final bodyText = entry.description.trim().isEmpty
        ? '暂无简介'
        : entry.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.displayTitle,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        if (badges.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges,
          ),
          const SizedBox(height: 8),
        ],
        if (visibleLabels.isNotEmpty) ...[
          DiscussionLabels(
            labels: visibleLabels,
            fontSize: 12,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Published on: '.tr + discussion.createdAt.toLocal().toString(),
        ),
        if (discussion.lastEditedAt != null)
          Text(
            'Last edited on: '.tr +
                discussion.lastEditedAt!.toLocal().toString(),
          ),
        const SizedBox(height: 16),
        SelectionArea(
          child: Text(
            bodyText,
            style: const TextStyle(fontSize: 16, height: 1.45),
          ),
        ),
        if (discussion.poll != null) ...[
          const SizedBox(height: 16),
          _VideoArchivePollSection(poll: discussion.poll!),
        ],
      ],
    );
  }
}

Widget _videoArchivePollOption(PollOptionModel option, int totalVotes) {
  final percent = totalVotes == 0 ? 0.0 : option.totalVoteCount / totalVotes;
  final percentLabel = (percent * 100).toStringAsFixed(0);
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                option.option,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            if (option.viewerHasVoted)
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Color(0xff96c264),
              ),
            const SizedBox(width: 6),
            Text(
              '${option.totalVoteCount} ($percentLabel%)',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xffB3B3B1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: const Color(0xff2D2D2D),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff96c264)),
          ),
        ),
      ],
    ),
  );
}

class _VideoArchivePollSection extends StatelessWidget {
  const _VideoArchivePollSection({required this.poll});

  final PollModel poll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff222222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff2D2D2D), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Polls'.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (poll.viewerHasVoted) ...[
                const SizedBox(width: 8),
                MyChip('You voted'.tr),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            poll.question,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Total votes: '.tr + poll.totalVoteCount.toString(),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xffB3B3B1),
            ),
          ),
          ...poll.options
              .map((o) => _videoArchivePollOption(o, poll.totalVoteCount)),
        ],
      ),
    );
  }
}
