import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/feedback_btn.dart';
import 'package:inter_knot/components/updata.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/helpers/snack.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:inter_knot/helpers/web_url.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/discussion_category.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/release.dart';
import 'package:inter_knot/models/report_comment.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Controller extends GetxController {
  late final SharedPreferences pref;
  final api = Get.find<Api>();

  final searchQuery = ''.obs;
  final searchResult = <HDataModel>{}.obs;
  final pinnedDiscussions = <HDataModel>{}.obs;
  String? searchEndCur;
  final searchHasNextPage = true.obs;
  final selectedCategoryIds = <String>{}.obs;
  final discussionCategories = <DiscussionCategoryModel>[].obs;
  final _categoryEndCursors = <String, String?>{};
  final _categoryHasNextPage = <String, bool>{};
  final _categoryFetchCache = <String, Set<String?>>{};

  String rootToken = '';

  String getToken() => pref.getString('access_token') ?? '';
  Future<void> setToken(String v) => pref.setString('access_token', v);

  final isLogin = false.obs;
  final user = Rx<AuthorModel?>(null);

  final report = <int, Set<ReportCommentModel>>{}.obs;

  final bookmarks = <HDataModel>{}.obs;
  final history = <HDataModel>{}.obs;

  late final info = PackageInfo.fromPlatform();

  bool canVisit(DiscussionModel discussion, bool isPin) =>
      report[discussion.number] == null ||
      [owner, ...collaborators].contains(discussion.author.login) ||
      isPin ||
      report[discussion.number]!.length < 6;

  final curPage = 0.obs;

  final accelerator = ''.obs;

  String get _redirectUri {
    final base = Uri.base;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: base.path,
    ).toString();
  }

  Future<void> _handleWebOAuthRedirect() async {
    final params = Uri.base.queryParameters;
    if (!params.containsKey('code') && !params.containsKey('error')) {
      return;
    }
    replaceUrl(_redirectUri);
    final errorParam = params['error'];
    if (errorParam != null) {
      await box.remove('oauth_state');
      await box.remove('oauth_code_verifier');
      showErrorSnack(params['error_description'] ?? errorParam);
      return;
    }
    final code = params['code'];
    final state = params['state'];
    final savedState = box.read('oauth_state') as String?;
    final verifier = box.read('oauth_code_verifier') as String?;
    if (code == null || state == null || savedState != state || verifier == null) {
      await box.remove('oauth_state');
      await box.remove('oauth_code_verifier');
      showErrorSnack('Invalid OAuth state. Please retry.'.tr);
      return;
    }
    try {
      final loginApi = Get.find<LoginApi>();
      final token = await loginApi.getAccessTokenByCode(
        code: code,
        redirectUri: _redirectUri,
        codeVerifier: verifier,
      );
      await box.remove('oauth_state');
      await box.remove('oauth_code_verifier');
      await box.write('access_token', token);
      isLogin(true);
      await handleLoginSuccess();
    } catch (e, s) {
      await box.remove('oauth_state');
      await box.remove('oauth_code_verifier');
      showErrorSnack(e, s);
    }
  }

  Future<void> handleLoginSuccess() async {
    await box.write(
      accessTokenTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (Get.isRegistered<Api>()) {
      Get.find<Api>().resetReauthNotice();
    }
    pinnedDiscussions.clear();
    isFetchPinDiscussions = true;
    searchCache.clear();
    searchResult.clear();
    searchEndCur = null;
    searchHasNextPage.value = true;
    HDataModel.discussionsCache.clear();
    await fetchPinnedDiscussions();
    await refreshSearchData();
    if (Get.isRegistered<Api>()) {
      Get.find<Api>().getSelfUserInfo().then(user.call);
    }
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    pref = await SharedPreferences.getInstance();
    if (!(pref.getBool(refreshTokenMigratedKey) ?? false)) {
      pref.remove('refresh_token');
      await pref.setBool(refreshTokenMigratedKey, true);
    }
    pageController
        .addListener(() => curPage(pageController.page?.round() ?? 0));
    pref.remove('root_token');
    isLogin(pref.getBool('isLogin') ?? false);
    ever(isLogin, (v) => pref.setBool('isLogin', v));
    logger.i(isLogin());
    accelerator(pref.getString('accelerator') ?? '');
    ever(accelerator, (v) => pref.setString('accelerator', v));
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleWebOAuthRedirect();
      });
    }
    if (isLogin()) api.getSelfUserInfo().then(user.call);
    debounce(
      searchQuery,
      (query) {
        searchController.text = query;
        resetSearchState();
        searchData();
      },
      time: 500.ms,
    );
    debounce(
      selectedCategoryIds,
      (_) {
        resetSearchState();
        searchData();
      },
      time: 300.ms,
    );
    if (isLogin()) {
      fetchPinnedDiscussions();
      fetchDiscussionCategories();
      searchData();
    }
    bookmarks.addAll(
        pref.getStringList('bookmarks')?.map(HDataModel.fromStr) ?? []);
    history
        .addAll(pref.getStringList('history')?.map(HDataModel.fromStr) ?? []);
    ever(bookmarks, (v) {
      pref.setStringList(
        'bookmarks',
        v.map((e) => '${e.number},${e.updatedAt}').toList(),
      );
    });
    ever(history, (v) {
      pref.setStringList(
        'history',
        v.map((e) => '${e.number},${e.updatedAt}').toList(),
      );
    });
    if (isLogin()) {
      api.getAllReports(reportDiscussionNumber).then(report.call);
      api.getNewVersion().then(getVersionHandle);
    } else {
      api.getAllReports(reportDiscussionNumber).then(report.call);
      api.getNewVersion().then(getVersionHandle);
    }
    fetchDiscussionCategories();
  }

  Future<void> getVersionHandle(ReleaseModel? release) async {
    if (release == null) {
      showDialog(
        context: Get.context!,
        builder: (context) {
          return AlertDialog(
            title: Text('Error: Unable to detect the latest version'.tr),
            content: SelectableText(
              'Unable to detect the latest version, please go to @releasesLink to update manually.'
                  .trParams({'releasesLink': releasesLink}),
            ),
            actions: [
              FeedbackBtn('Error: Unable to detect the latest version'.tr),
              TextButton(
                onPressed: () => launchUrlString(releasesLink),
                child: Text('Open'.tr),
              ),
              TextButton(
                onPressed: () => Get.back(),
                child: Text('OK'.tr),
              ),
            ],
          );
        },
      );
    } else {
      try {
        final info = await PackageInfo.fromPlatform();
        final newVersion = Version.parse(release.version);
        final curVersion = Version.parse('${info.version}+${info.buildNumber}');
        if (newVersion > curVersion) {
          final newFullVer = 'v${release.version}';
          final curFullVer = 'v${info.version}+${info.buildNumber}';
          final descriptionHTML = release.descriptionHTML ?? '';
          showDialog(
            context: Get.context!,
            barrierDismissible: !mustUpdate(newVersion, curVersion),
            builder: (context) => Updata(
              newFullVer: newFullVer,
              curFullVer: curFullVer,
              descriptionHTML: descriptionHTML,
              mustUpdate: mustUpdate(newVersion, curVersion),
              release: release,
            ),
          );
        }
      } catch (e, s) {
        logger.e(e, stackTrace: s);
      }
    }
  }

  bool mustUpdate(Version newVer, Version curVer) =>
      newVer.major > curVer.major || newVer.minor > curVer.minor;

  final selectedIndex = 0.obs;
  final pageController = PageController();

  Future<void> animateToPage(int index) {
    selectedIndex.value = index;
    return pageController.animateToPage(
      index,
      duration: 0.5.s,
      curve: Curves.ease,
    );
  }

  bool isFetchPinDiscussions = true;
  final searchController = SearchController();

  late final refreshSearchData = throttle(() async {
    resetSearchState();
    HDataModel.discussionsCache.clear();
    await searchData();
  });

  final searchCache = <String?>{};
  void resetSearchState() {
    searchResult.clear();
    searchEndCur = null;
    searchHasNextPage.value = true;
    searchCache.clear();
    _categoryEndCursors.clear();
    _categoryHasNextPage.clear();
    _categoryFetchCache.clear();
  }

  String buildSearchQuery(String query) {
    final baseQuery = query.trim();
    if (selectedCategoryIds.isEmpty) return baseQuery;
    final categoryQuery = selectedCategoryIds
        .map(_categoryNameById)
        .whereType<String>()
        .map((name) => 'category:"$name"')
        .join(' OR ');
    if (categoryQuery.isEmpty) return baseQuery;
    if (baseQuery.isEmpty) return '($categoryQuery)';
    return '$baseQuery ($categoryQuery)';
  }

  String? _categoryNameById(String id) {
    for (final category in discussionCategories) {
      if (category.id == id) return category.name;
    }
    return null;
  }

  Future<void> searchData() async {
    final query = searchQuery().trim();
    final isCategoryOnly = selectedCategoryIds.isNotEmpty && query.isEmpty;
    if (searchHasNextPage.isFalse) return;
    if (!isCategoryOnly) {
      if (searchCache.contains(searchEndCur)) return;
      searchCache.add(searchEndCur);
    }
    try {
      if (selectedCategoryIds.isNotEmpty && query.isEmpty) {
        await _fetchByCategories();
      } else {
        final page = await api.search(buildSearchQuery(query), searchEndCur);
        searchEndCur = page.endCursor;
        searchHasNextPage.value = page.hasNextPage;
        searchResult.addAll(page.nodes);
      }
    } catch (e, s) {
      logger.e('Search failed', error: e, stackTrace: s);
      showErrorSnack(e, s);
      searchHasNextPage.value = false;
    }
  }

  Future<void> _fetchByCategories() async {
    if (selectedCategoryIds.isEmpty) return;
    bool anyHasNext = false;
    for (final categoryId in selectedCategoryIds) {
      final hasNext = _categoryHasNextPage[categoryId] ?? true;
      if (!hasNext) continue;
      final endCur = _categoryEndCursors[categoryId];
      final cache =
          _categoryFetchCache.putIfAbsent(categoryId, () => <String?>{});
      if (cache.contains(endCur)) continue;
      cache.add(endCur);
      final page = await api.getDiscussionsByCategory(categoryId, endCur);
      _categoryEndCursors[categoryId] = page.endCursor;
      _categoryHasNextPage[categoryId] = page.hasNextPage;
      anyHasNext = anyHasNext || page.hasNextPage;
      searchResult.addAll(page.nodes);
    }
    searchHasNextPage.value = anyHasNext;
  }

  Future<void> fetchPinnedDiscussions() async {
    if (!isFetchPinDiscussions) return;
    try {
      isFetchPinDiscussions = false;
      String? endCur;
      var hasNextPage = true;
      while (hasNextPage) {
        final page = await api.getPinnedDiscussions(endCur);
        pinnedDiscussions.addAll(page.nodes);
        endCur = page.endCursor;
        hasNextPage = page.hasNextPage;
      }
      logger.i('Pinned discussions fetched: ${pinnedDiscussions.length}');
    } catch (e, s) {
      isFetchPinDiscussions = true;
      logger.e('Pinned discussions fetch failed', error: e, stackTrace: s);
    }
  }

  Future<void> fetchDiscussionCategories() async {
    if (discussionCategories.isNotEmpty) return;
    try {
      final categories = await api.getDiscussionCategories();
      discussionCategories.assignAll(categories);
    } catch (e, s) {
      logger.e('Discussion categories fetch failed', error: e, stackTrace: s);
    }
  }

  List<HDataModel> get mergedSearchResult {
    final pinned = pinnedDiscussions().toList();
    final merged = <HDataModel>[];
    final isCategoryOnly =
        selectedCategoryIds.isNotEmpty && searchQuery().trim().isEmpty;
    if (isCategoryOnly) {
      merged.addAll(searchResult());
      merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return merged;
    }
    final pinnedNumbers = pinned.map((e) => e.number).toSet();
    merged.addAll(pinned);
    for (final item in searchResult()) {
      if (!pinnedNumbers.contains(item.number)) {
        merged.add(item);
      }
    }
    return merged;
  }
}

bool canReport(DiscussionModel discussion, bool isPin) =>
    ![owner, ...collaborators].contains(discussion.author.login) && !isPin;
