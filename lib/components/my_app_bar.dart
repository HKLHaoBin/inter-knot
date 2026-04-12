import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/my_tab.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';

class MyAppBar extends StatelessWidget {
  const MyAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 640;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: isCompact ? width : max(width, 640),
        child: Container(
          padding:
              EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 6 : 8),
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(
              bottom: BorderSide(
                color: Colors.white12,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (isCompact)
                  Obx(() {
                    final user = c.user();
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => c.animateToPage(2),
                      child: Avatar(
                        user?.avatar,
                        size: 36,
                      ),
                    );
                  })
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/zzzicon.png',
                        width: 48,
                        height: 48,
                        filterQuality: FilterQuality.medium,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'INTER-KNOT',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16),
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: 700,
                          maxHeight: isCompact ? 36 : 48,
                        ),
                        child: SearchBar(
                          controller: c.searchController,
                          onChanged: c.searchQuery.call,
                          onSubmitted: c.searchQuery.call,
                          constraints: BoxConstraints(
                            minHeight: isCompact ? 36 : 48,
                            maxHeight: isCompact ? 36 : 48,
                          ),
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(
                                horizontal: isCompact ? 8 : 16),
                          ),
                          backgroundColor:
                              const WidgetStatePropertyAll(Color(0xff1E1E1E)),
                          leading: Padding(
                            padding: EdgeInsets.only(left: isCompact ? 4 : 8),
                            child: Icon(
                              Icons.search,
                              color: const Color(0xffB0B0B0),
                              size: isCompact ? 20 : 24,
                            ),
                          ),
                          hintText: 'Search for discussions'.tr,
                          hintStyle: WidgetStatePropertyAll(
                            TextStyle(
                              color: const Color(0xff808080),
                              fontSize: isCompact ? 14 : null,
                            ),
                          ),
                          textStyle: WidgetStatePropertyAll(
                            TextStyle(
                              color: const Color(0xffE0E0E0),
                              fontSize: isCompact ? 14 : null,
                            ),
                          ),
                          side: WidgetStatePropertyAll(
                            BorderSide(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          trailing: [
                            AnimatedBuilder(
                              animation: c.searchController,
                              builder: (context, _) {
                                final hasText =
                                    c.searchController.text.trim().isNotEmpty;
                                if (!hasText) return const SizedBox.shrink();

                                return IconButton(
                                  tooltip: 'Cancel'.tr,
                                  onPressed: () {
                                    c.searchController.clear();
                                    c.searchQuery('');
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  },
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: const Color(0xffB0B0B0),
                                    size: isCompact ? 18 : 20,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isCompact)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xff313131),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(maxRadius),
                      image: DecorationImage(
                        image: Assets.images.tabBgPoint.provider(),
                        repeat: ImageRepeat.repeat,
                      ),
                    ),
                    child: Obx(() {
                      final page = c.curPage();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MyTab(
                            first: true,
                            text: 'Discover'.tr,
                            isSelected: page == 0,
                            trailing:
                                page == 0 ? const Icon(Icons.refresh) : null,
                            onTap: () {
                              if (c.curPage() == 0) c.refreshSearchData();
                              c.animateToPage(0);
                            },
                          ),
                          MyTab(
                            text: 'Toolkit'.tr,
                            isSelected: page == 1,
                            onTap: () => c.animateToPage(1),
                          ),
                          MyTab(
                            text: 'Home'.tr,
                            isSelected: page == 2,
                            last: true,
                            onTap: () => c.animateToPage(2),
                          ),
                        ],
                      );
                    }),
                  ),
                if (!isCompact) const SizedBox(width: 8) else const SizedBox()
              ],
            ),
          ),
        ),
      ),
    );
  }
}
