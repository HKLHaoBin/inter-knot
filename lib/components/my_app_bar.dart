import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/my_tab.dart';
import 'package:inter_knot/components/user_badge.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';

class MyAppBar extends StatelessWidget {
  const MyAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: max(MediaQuery.of(context).size.width, 640),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.black,
          child: Row(
            children: [
              Obx(() {
                final user = c.user();
                return UserBadge(
                  avatarUrl: user?.avatar,
                  name: user?.name ?? 'Not logged in'.tr,
                  contributions: user?.contributions ?? 0,
                  level: user?.level ?? 0,
                );
              }),
              const SizedBox(width: 16),
              const Spacer(),
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
                child: Row(
                  children: [
                    Obx(() {
                      return MyTab(
                        first: true,
                        text: 'Notifications'.tr,
                        trailing:
                            c.curPage() == 0 ? const Icon(Icons.refresh) : null,
                        onTap: () {
                          if (c.curPage() == 0) c.refreshSearchData();
                          c.animateToPage(0);
                        },
                      );
                    }),
                    MyTab(
                      text: 'Toolkit'.tr,
                      onTap: () => c.animateToPage(1),
                    ),
                    MyTab(
                      text: 'Home'.tr,
                      onTap: () => c.animateToPage(2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
