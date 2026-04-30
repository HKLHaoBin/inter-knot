import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/discussion_category_helper.dart';
import 'package:inter_knot/helpers/video_archive_codec.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/video_archive_entry.dart';
import 'package:inter_knot/pages/video_player_page.dart';

class VideoArchivePage extends StatefulWidget {
  const VideoArchivePage({super.key});

  @override
  State<VideoArchivePage> createState() => _VideoArchivePageState();
}

class _VideoArchivePageState extends State<VideoArchivePage> {
  final Api _api = Get.find<Api>();
  bool _loading = true;
  String? _error;
  final List<VideoArchiveEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.search('category:$videoDiscussionCategoryName', null);
      final loaded = <VideoArchiveEntry>[];
      for (final item in page.nodes) {
        final discussion = await item.discussion;
        if (discussion == null) continue;
        if (!isVideoDiscussion(discussion)) continue;
        loaded.add(_parseEntry(discussion));
      }
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  VideoArchiveEntry _parseEntry(DiscussionModel discussion) {
    final tags = RegExp(r'\[([^\]]+)\]')
        .allMatches(discussion.title)
        .map((m) => (m.group(1) ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final displayTitle = discussion.title.replaceAll(RegExp(r'\[[^\]]+\]'), '').trim();
    try {
      final body = extractVideoBodyParts(discussion.rawBodyText);
      if (body.encodedPayload == null || body.encodedPayload!.isEmpty) {
        throw const FormatException('正文末尾缺少 {payload}');
      }
      final decoded = decodeVideoPayload(body.encodedPayload!);
      return VideoArchiveEntry(
        discussion: discussion,
        displayTitle: displayTitle.isEmpty ? discussion.title : displayTitle,
        tags: tags,
        description: body.description,
        encodedPayload: body.encodedPayload,
        decodedPayload: decoded,
        errorMessage: null,
      );
    } catch (e) {
      return VideoArchiveEntry(
        discussion: discussion,
        displayTitle: displayTitle.isEmpty ? discussion.title : displayTitle,
        tags: tags,
        description: discussion.bodyText,
        encodedPayload: null,
        decodedPayload: null,
        errorMessage: '$e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('录像带陈列'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: SelectableText(_error!))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 290,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return InkWell(
                      onTap: () {
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
                      },
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: entry.discussion.cover != null &&
                                          entry.discussion.cover!.isNotEmpty &&
                                          !entry.discussion.coverIsIframe
                                      ? Image.network(
                                          entry.discussion.cover!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (context, _, __) {
                                            return Assets.images.defaultCover
                                                .image(fit: BoxFit.cover);
                                          },
                                        )
                                      : Assets.images.defaultCover
                                          .image(fit: BoxFit.cover, width: double.infinity),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                entry.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.tags.isEmpty ? '-' : entry.tags.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.description.isEmpty
                                    ? (entry.isValid ? '暂无简介' : '数据格式错误')
                                    : entry.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
