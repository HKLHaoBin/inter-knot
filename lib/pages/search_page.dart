import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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

  @override
  void dispose() {
    keyboardSubscription.cancel();
    super.dispose();
  }

  late final fetchData = retryThrottle(c.searchData);

  Widget _buildCategoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final borderColor =
        selected ? const Color(0xff96c264) : const Color(0xff2D2D2D);
    final backgroundColor =
        selected ? const Color(0xff3A3A3A) : const Color(0xff222222);
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
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SearchBar(
                controller: c.searchController,
                onSubmitted: c.searchQuery.call,
                backgroundColor:
                    const WidgetStatePropertyAll(Color(0xff222222)),
                leading: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.search),
                ),
                hintText: 'Search for discussions'.tr,
              ),
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (c.discussionCategories.isEmpty) {
                return const SizedBox.shrink();
              }
              return SizedBox(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
              );
            }),
            const SizedBox(height: 8),
            Expanded(
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
            ),
          ],
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: IconButton.filledTonal(
            iconSize: 32,
            padding: const EdgeInsets.all(12),
            onPressed: () => launchUrlString(
              newDiscussionLink,
            ),
            icon: Icon(MdiIcons.pen),
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
