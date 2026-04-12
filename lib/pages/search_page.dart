import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  final c = Get.find<Controller>();

  final keyboardVisibilityController = KeyboardVisibilityController();
  late final keyboardSubscription =
      keyboardVisibilityController.onChange.listen((visible) {
    if (!visible) FocusManager.instance.primaryFocus?.unfocus();
  });

  late final fetchData = retryThrottle(
    c.searchData,
    const Duration(milliseconds: 500),
  );

  @override
  void dispose() {
    keyboardSubscription.cancel();
    super.dispose();
  }

  Widget _buildCategoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final borderColor =
        selected ? const Color(0xffD7FF00) : const Color(0xff2D2D2D);
    final backgroundColor =
        selected ? const Color(0xff2A2A2A) : const Color(0xff1A1A1A);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool iconOnly = false,
  }) {
    return Material(
      color: const Color(0xff1A1A1A),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly ? 14 : 18,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              if (!iconOnly) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 640;

    return Stack(
      children: [
        Column(
          children: [
            Obx(() {
              if (c.discussionCategories.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: c.discussionCategories.map((category) {
                          final selected =
                              c.selectedCategoryIds.contains(category.id);
                          final label = category.name;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildCategoryChip(
                              label: label,
                              selected: selected,
                              onTap: () {
                                final value = !selected;
                                if (value) {
                                  c.selectedCategoryIds.add(category.id);
                                } else {
                                  c.selectedCategoryIds.remove(category.id);
                                }
                                c.selectedCategoryIds.refresh();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }),
            Expanded(
              child: isCompact
                  ? RefreshIndicator(
                      edgeOffset: 0,
                      displacement: 56,
                      onRefresh: () async {
                        await c.refreshSearchData();
                      },
                      child: Obx(() {
                        final selectedIds = c.selectedCategoryIds.toList()
                          ..sort();
                        return DiscussionGrid(
                          key: ValueKey(
                            'search-${selectedIds.join(",")}-${c.searchQuery()}',
                          ),
                          list: c.mergedSearchResult,
                          hasNextPage: c.searchHasNextPage(),
                          fetchData: fetchData,
                          selectedCategoryIds: selectedIds.toSet(),
                        );
                      }),
                    )
                  : Obx(() {
                      final selectedIds = c.selectedCategoryIds.toList()..sort();
                      return DiscussionGrid(
                        key: ValueKey(
                          'search-${selectedIds.join(",")}-${c.searchQuery()}',
                        ),
                        list: c.mergedSearchResult,
                        hasNextPage: c.searchHasNextPage(),
                        fetchData: fetchData,
                        selectedCategoryIds: selectedIds.toSet(),
                      );
                    }),
            ),
          ],
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: isCompact
              ? IconButton.filledTonal(
                  iconSize: 28,
                  padding: const EdgeInsets.all(12),
                  onPressed: () => launchUrlString(newDiscussionLink),
                  icon: const Icon(Icons.add),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildActionButton(
                      icon: Icons.refresh_rounded,
                      label: 'Refresh'.tr,
                      iconOnly: true,
                      onTap: () => c.refreshSearchData(),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.add,
                      label: 'Create a new discussion'.tr,
                      onTap: () => launchUrlString(newDiscussionLink),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
