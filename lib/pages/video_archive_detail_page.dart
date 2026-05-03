import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/discussion_actions.dart';
import 'package:inter_knot/helpers/logger.dart';
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

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final desc = entry.description.trim().isEmpty
        ? '暂无简介'
        : entry.description.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: Get.back,
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFF3333),
                            width: 2,
                          ),
                          color: const Color(0x66120000),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFFFF3333),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  Cover(discussion: entry.discussion),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      entry.displayTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Text(
                      desc,
                      style: const TextStyle(
                        color: Color(0xFFE0E0E0),
                        height: 1.45,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF2D2D2D)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: DiscussionCommentSection(
                      discussion: entry.discussion,
                      hData: _hData,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3333),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _startPlay(context),
                  child: const Text(
                    '开始游玩',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
