import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussion_card.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/discussion_category_helper.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/discussion_page.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class DiscussionEmptyState extends StatelessWidget {
  const DiscussionEmptyState({
    super.key,
    required this.message,
    this.imageAsset,
    this.imageSize = 120,
    this.textStyle,
  });

  final String message;
  final String? imageAsset;
  final double imageSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageAsset != null && imageAsset!.isNotEmpty;
    final hasMessage = message.trim().isNotEmpty;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        if (hasImage)
          Image.asset(
            imageAsset!,
            width: imageSize,
            height: imageSize,
          ),
        if (hasImage && hasMessage) const SizedBox(height: 16),
        if (hasMessage)
          Text(
            message,
            style: textStyle,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

bool _matchesAiReviewFilter({
  required HDataModel item,
  Set<AiReviewRating>? selectedAiReviewRatings,
}) {
  if (selectedAiReviewRatings == null || selectedAiReviewRatings.isEmpty) {
    return true;
  }
  final rating = item.aiReviewRatingFromLabels;
  if (rating == null) return false;
  return selectedAiReviewRatings.contains(rating);
}

bool _matchesCategoryFilter({
  required DiscussionModel discussion,
  Set<String>? selectedCategoryIds,
}) {
  if (selectedCategoryIds != null && selectedCategoryIds.isNotEmpty) {
    final categoryId = discussion.categoryId;
    if (categoryId == null || !selectedCategoryIds.contains(categoryId)) {
      return false;
    }
  }
  return true;
}

Future<bool> _hasRenderableMatch({
  required List<HDataModel> items,
  Set<String>? selectedCategoryIds,
}) async {
  for (final item in items) {
    try {
      final discussion = await item.discussion;
      if (discussion == null) continue;
      if (isVideoDiscussion(discussion)) continue;
      if (!_matchesCategoryFilter(
        discussion: discussion,
        selectedCategoryIds: selectedCategoryIds,
      )) {
        continue;
      }
      return true;
    } catch (_) {
      continue;
    }
  }
  return false;
}

/// When category chips are active: pre-resolve [items] so [WaterfallFlow] only
/// lays out rows that are not known shrink candidates (video / category mismatch).
Future<({bool anyRenderableMatch, List<HDataModel> displayItems})>
    _prepareCategoryFilteredItems({
  required List<HDataModel> items,
  required Set<String> selectedCategoryIds,
}) async {
  var anyRenderableMatch = false;
  final displayItems = <HDataModel>[];
  for (final item in items) {
    try {
      final discussion = await item.discussion;
      if (discussion != null &&
          !isVideoDiscussion(discussion) &&
          _matchesCategoryFilter(
            discussion: discussion,
            selectedCategoryIds: selectedCategoryIds,
          )) {
        anyRenderableMatch = true;
      }
      if (discussion != null &&
          (isVideoDiscussion(discussion) ||
              !_matchesCategoryFilter(
                discussion: discussion,
                selectedCategoryIds: selectedCategoryIds,
              ))) {
        continue;
      }
      displayItems.add(item);
    } catch (_) {
      displayItems.add(item);
    }
  }
  return (
    anyRenderableMatch: anyRenderableMatch,
    displayItems: displayItems,
  );
}

bool _sameHDataSequence(List<HDataModel> a, List<HDataModel> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i].number != b[i].number) {
      return false;
    }
  }
  return true;
}

bool _sameStringSet(Set<String> a, Set<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final id in a) {
    if (!b.contains(id)) {
      return false;
    }
  }
  return true;
}

class _DiscussionGridCategoryFilterBody extends StatefulWidget {
  const _DiscussionGridCategoryFilterBody({
    required this.filteredList,
    required this.selectedCategoryIds,
    required this.list,
    required this.hasNextPage,
    required this.buildEmptyState,
    required this.buildGrid,
    required this.buildLoadMorePrompt,
  });

  final List<HDataModel> filteredList;
  final Set<String> selectedCategoryIds;
  final List<HDataModel> list;
  final bool hasNextPage;
  final Widget Function() buildEmptyState;
  final Widget Function(List<HDataModel> items) buildGrid;
  final Widget Function() buildLoadMorePrompt;

  @override
  State<_DiscussionGridCategoryFilterBody> createState() =>
      _DiscussionGridCategoryFilterBodyState();
}

class _DiscussionGridCategoryFilterBodyState
    extends State<_DiscussionGridCategoryFilterBody> {
  late Future<({bool anyRenderableMatch, List<HDataModel> displayItems})>
      _prepFuture;

  @override
  void initState() {
    super.initState();
    _prepFuture = _prepareCategoryFilteredItems(
      items: widget.filteredList,
      selectedCategoryIds: widget.selectedCategoryIds,
    );
  }

  @override
  void didUpdateWidget(covariant _DiscussionGridCategoryFilterBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameHDataSequence(oldWidget.filteredList, widget.filteredList) ||
        !_sameStringSet(
          oldWidget.selectedCategoryIds,
          widget.selectedCategoryIds,
        )) {
      _prepFuture = _prepareCategoryFilteredItems(
        items: widget.filteredList,
        selectedCategoryIds: widget.selectedCategoryIds,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          bool anyRenderableMatch,
          List<HDataModel> displayItems,
        })>(
      future: _prepFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return widget.buildGrid(widget.filteredList);
        }
        final data = snapshot.data;
        final hasMatch = data?.anyRenderableMatch ?? false;
        if (!hasMatch) {
          if (widget.hasNextPage && widget.list.isNotEmpty) {
            return widget.buildLoadMorePrompt();
          }
          if (widget.hasNextPage && widget.list.isEmpty) {
            return widget.buildGrid(widget.list);
          }
          return widget.buildEmptyState();
        }
        return widget.buildGrid(data!.displayItems);
      },
    );
  }
}

class DiscussionGrid extends StatelessWidget {
  const DiscussionGrid({
    super.key,
    required this.list,
    required this.hasNextPage,
    this.fetchData,
    this.selectedCategoryIds,
    this.selectedAiReviewRatings,
    this.isLoadingCurrentPage = false,
  });

  final List<HDataModel> list;
  final bool hasNextPage;
  final void Function()? fetchData;
  final Set<String>? selectedCategoryIds;
  final Set<AiReviewRating>? selectedAiReviewRatings;
  final bool isLoadingCurrentPage;

  @override
  Widget build(BuildContext context) {
    final filteredList = list
        .where(
          (item) => _matchesAiReviewFilter(
            item: item,
            selectedAiReviewRatings: selectedAiReviewRatings,
          ),
        )
        .toList();
    final hasCategoryFilter =
        selectedCategoryIds != null && selectedCategoryIds!.isNotEmpty;

    if (list.isEmpty && hasNextPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fetchData?.call();
      });
    }

    Widget buildEmptyState() {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: DiscussionEmptyState(
                message: 'Empty'.tr,
                imageAsset: Assets.images.zzz.path,
                textStyle: const TextStyle(
                  color: Color(0xff808080),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget buildGrid(List<HDataModel> items) {
      return LayoutBuilder(
        builder: (context, con) {
          final width = MediaQuery.of(context).size.width;
          final isCompact = width < 640;
          final mainAxisSpacing = isCompact ? 10.0 : 12.0;
          final crossAxisSpacing = isCompact ? 8.0 : 10.0;
          final maxCrossAxisExtent = isCompact ? 273.0 : 264.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1450),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.depth == 0 &&
                      notification.metrics.extentAfter < 500 &&
                      hasNextPage) {
                    fetchData?.call();
                  }
                  return false;
                },
                child: WaterfallFlow.builder(
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                  gridDelegate:
                      SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: maxCrossAxisExtent,
                    mainAxisSpacing: mainAxisSpacing,
                    crossAxisSpacing: crossAxisSpacing,
                    lastChildLayoutTypeBuilder: (index) => index == items.length
                        ? LastChildLayoutType.foot
                        : LastChildLayoutType.none,
                  ),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      if (hasNextPage) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Assets.images.zzz.image(
                              width: 80,
                              height: 80,
                            ),
                          ),
                        );
                      }
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('No more data'.tr),
                        ),
                      );
                    }

                    final item = items.elementAt(index);
                    return FutureBuilder<DiscussionModel?>(
                      future: item.discussion,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final discussion = snapshot.data!;
                          if (isVideoDiscussion(discussion)) {
                            return const SizedBox.shrink();
                          }
                          if (!_matchesCategoryFilter(
                            discussion: discussion,
                            selectedCategoryIds: selectedCategoryIds,
                          )) {
                            return const SizedBox.shrink();
                          }
                          return DiscussionCard(
                            discussion: discussion,
                            hData: item,
                            onTap: () {
                              showGeneralDialog(
                                context: context,
                                barrierDismissible: true,
                                barrierLabel: 'Close'.tr,
                                pageBuilder:
                                    (context, animation, secondaryAnimation) {
                                  return DiscussionPage(
                                    discussion: snapshot.data!,
                                    hData: item,
                                  );
                                },
                                transitionDuration: 300.ms,
                                transitionBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween(
                                        begin: const Offset(0.1, 0.0),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.ease,
                                        ),
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        }
                        if (snapshot.hasError) {
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            color: const Color(0xff222222),
                            child: AspectRatio(
                              aspectRatio: 5 / 6,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: SelectableText('${snapshot.error}'),
                                ),
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.done) {
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            color: const Color(0xff222222),
                            child: InkWell(
                              onTap: () => launchUrlString(item.url),
                              child: AspectRatio(
                                aspectRatio: 5 / 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text('Discussion deleted'.tr),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          color: const Color(0xff222222),
                          child: InkWell(
                            onTap: () => launchUrlString(item.url),
                            child: const AspectRatio(
                              aspectRatio: 5 / 6,
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    }

    Widget buildLoadMorePrompt() {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No matches on this page'.tr,
                    style: const TextStyle(
                      color: Color(0xff808080),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: fetchData,
                    child: Text('Load more'.tr),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (isLoadingCurrentPage) {
      return buildGrid(list);
    }

    if (hasCategoryFilter) {
      return _DiscussionGridCategoryFilterBody(
        filteredList: filteredList,
        selectedCategoryIds: selectedCategoryIds!,
        list: list,
        hasNextPage: hasNextPage,
        buildEmptyState: buildEmptyState,
        buildGrid: buildGrid,
        buildLoadMorePrompt: buildLoadMorePrompt,
      );
    }

    return FutureBuilder<bool>(
      future: _hasRenderableMatch(items: filteredList),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return buildGrid(filteredList);
        }
        final hasMatch = snapshot.data ?? false;
        if (!hasMatch) {
          if (hasNextPage && list.isNotEmpty) {
            return buildLoadMorePrompt();
          }
          if (hasNextPage && list.isEmpty) {
            return buildGrid(list);
          }
          return buildEmptyState();
        }
        return buildGrid(filteredList);
      },
    );
  }
}
