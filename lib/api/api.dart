import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/constants/graphql_query.dart' as graphql_query;
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/transform_reports.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/device_login.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/pagination.dart';
import 'package:inter_knot/models/release.dart';
import 'package:inter_knot/pages/login_page.dart';
import 'package:inter_knot/secret.dart';

class LoginApi extends GetConnect {
  Future<({DeviceLoginStatus status, String? accessToken})> getAccessToken(
    DeviceLoginModel deviceLogin,
  ) async {
    final res = await post<Map<String, dynamic>>(
      'https://github.com/login/oauth/access_token',
      null,
      query: {
        'client_id': clientId,
        'device_code': deviceLogin.deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      },
    );
    if (res.body == null) throw Exception('Failed to get access token');
    if (res.body!['error'] == 'authorization_pending') {
      return (
        status: DeviceLoginStatus.authorizationPending,
        accessToken: null,
      );
    }
    if (res.body!['error'] == 'expired_token') {
      return (
        status: DeviceLoginStatus.expiredToken,
        accessToken: null,
      );
    }
    if (res.body!['error'] == 'access_denied') {
      return (
        status: DeviceLoginStatus.accessDenied,
        accessToken: null,
      );
    }
    if (res.body case {'access_token': final String accessToken}) {
      return (
        status: DeviceLoginStatus.finished,
        accessToken: accessToken,
      );
    }
    throw Exception('Invalid response: $res');
  }

  Future<DeviceLoginModel> getDeviceLogin() async {
    final res = await post<Map<String, dynamic>>(
      'https://github.com/login/device/code',
      null,
      query: {'client_id': clientId},
    );
    return DeviceLoginModel.fromJson(res.body!);
  }
}

class BaseConnect extends GetConnect {
  static final loginApi = Get.find<LoginApi>();
  static bool _reauthNoticeShown = false;

  @override
  void onInit() {
    httpClient.baseUrl = 'https://api.github.com';
    httpClient.addRequestModifier<Map<String, dynamic>>(
      (Request<Map<String, dynamic>> request) {
        if (kIsWeb) {
          request.headers.remove('content-length');
        }
        return request;
      },
    );
    httpClient.addAuthenticator<Map<String, dynamic>>(
      (Request<Map<String, dynamic>> request) async {
      var token = box.read<String>('access_token') ?? '';
      final hadToken = token.isNotEmpty;
      while (!token.startsWith('ghu_')) {
        if (hadToken && !_reauthNoticeShown && Get.context != null) {
          _reauthNoticeShown = true;
          showDialog(
            context: Get.context!,
            builder: (context) => AlertDialog(
              title: Text('Login'.tr),
              content: Text('Token expired, please login again'.tr),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: Text('OK'.tr),
                ),
              ],
            ),
          );
        }
        await Future(() => Get.to(() => const LoginPage()));
        token = box.read<String>('access_token') ?? '';
        if (!token.startsWith('ghu_')) {
          break;
        }
      }
      if (token.startsWith('ghu_')) {
        _reauthNoticeShown = false;
        request.headers['Authorization'] = 'Bearer $token';
      }
        return request;
      },
    );
    httpClient.addResponseModifier((req, rep) {
      if (rep.statusCode == HttpStatus.unauthorized) {
        box.remove('access_token');
      }
    });
    httpClient.maxAuthRetries = 3;
  }

  Future<Response<Map<String, dynamic>>> graphql(String data) async {
    final res =
        await post<Map<String, dynamic>>('/graphql', jsonEncode({'query': data}));
    if (res.statusCode != HttpStatus.ok) {
      throw Exception('GitHub API error: ${res.statusCode} ${res.body}');
    }
    return res;
  }
}

class Api extends BaseConnect {
  Future<DiscussionModel> getDiscussion(int number) async {
    final res = await graphql(graphql_query.getDiscussion(number));
    return DiscussionModel.fromJson(
      // ignore: avoid_dynamic_calls
      res.body!['data']['repository']['discussion'] as Map<String, dynamic>,
    );
  }

  Future<PaginationModel<HDataModel>> search(
      String query, String? endCur) async {
    final res = await graphql(graphql_query.search(query, endCur));
    return PaginationModel.fromJson(
      // ignore: avoid_dynamic_calls
      res.body!['data']['search'] as Map<String, dynamic>,
      HDataModel.fromJson,
    );
  }

  Future<PaginationModel<CommentModel>> getComments(
      int number, String endCur) async {
    final res = await graphql(graphql_query.getComments(number, endCur));
    return PaginationModel.fromJson(
      // ignore: avoid_dynamic_calls
      res.body!['data']['repository']['discussion']['comments']
          as Map<String, dynamic>,
      CommentModel.fromJson,
    );
  }

  Future<Response<Map<String, dynamic>>> addDiscussionComment(
    String discussionId,
    String body,
  ) =>
      graphql(graphql_query.addDiscussionComment(discussionId, body));

  Future<Response<Map<String, dynamic>>> deleteDiscussion(String id) =>
      graphql(graphql_query.deleteDiscussion(id));

  Future<PaginationModel<HDataModel>> getPinnedDiscussions(
      String? endCur) async {
    final res = await graphql(graphql_query.getPinnedDiscussions(endCur));
    return PaginationModel.fromJson(
      // ignore: avoid_dynamic_calls
      res.body!['data']['repository']['pinnedDiscussions']
          as Map<String, dynamic>,
      HDataModel.fromPinnedJson,
    );
  }

  Future<AuthorModel> getSelfUserInfo() async {
    final res = await graphql(graphql_query.getSelfUserInfo());
    final data = res.body?['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Invalid response: $res');
    final viewer = data['viewer'] as Map<String, dynamic>;
    return AuthorModel.fromJson(viewer);
  }

  Future<AuthorModel> getUserInfo(String login) async {
    final res = await graphql(graphql_query.getUserInfo(login));
    final data = res.body?['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Invalid response: $res');
    final user = data['user'] as Map<String, dynamic>;
    return AuthorModel.fromJson(user);
  }

  Future<ReleaseModel> getNewVersion() async {
    final res = await graphql(graphql_query.getNewVersion());
    return ReleaseModel.fromJson(
      // ignore: avoid_dynamic_calls
      res.body!['data']['repository']['releases']['nodes'][0]
          as Map<String, dynamic>,
    );
  }

  Future<Report> getAllReports(int number) async {
    final res = <({String login, Set<int> numbers, String bodyHTML})>[];
    String? after;
    while (true) {
      final data = await graphql(graphql_query.getAllReports(number, after));
      if (data.body
          case {
            'data': {
              'repository': {
                'discussion': {
                  'comments': {
                    'pageInfo': {
                      'hasNextPage': final bool hasNextPage,
                      'endCursor': final String? endCursor
                    },
                    'nodes': final List nodes
                  }
                }
              }
            }
          }) {
        res.addAll(
          nodes
              .map((e) {
                if (e
                    case {
                      'author': {
                        'login': final String login,
                      },
                      'body': final String body,
                      'bodyHTML': final String bodyHTML,
                    }) {
                  return (login: login, bodyHTML: bodyHTML, body: body);
                }
                return null;
              })
              .whereType<({String login, String bodyHTML, String body})>()
              .map((e) {
                if (!e.body.contains('原因')) return null;
                final numbers = RegExp(r'#(\d+)')
                    .allMatches(e.body)
                    .map((e) => e.group(1))
                    .whereType<String>()
                    .map((e) => int.parse(e))
                    .toSet();
                if (numbers.isEmpty) return null;
                return (
                  login: e.login,
                  bodyHTML: e.bodyHTML,
                  numbers: numbers,
                );
              })
              .whereType<({String login, Set<int> numbers, String bodyHTML})>(),
        );
        if (!hasNextPage) break;
        after = endCursor;
      }
    }
    return transformReports(res);
  }
}
