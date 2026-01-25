import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/constants/globals.dart';
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
  Future<String> getAccessTokenByCode({
    required String code,
    required String redirectUri,
    required String codeVerifier,
  }) async {
    final res = await post<Object>(
      githubOauthProxyUrl,
      {
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
      },
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
    final rawBody = res.body ?? res.bodyString;
    if (res.statusCode != null && res.statusCode! >= 400) {
      throw Exception(
        'Failed to exchange code: ${res.statusCode} ${rawBody ?? ''}'.trim(),
      );
    }
    if (rawBody == null) {
      throw Exception('Failed to exchange code: empty response');
    }
    final data = _parseAuthResponse(rawBody);
    if (data case {'access_token': final String accessToken}) {
      return accessToken;
    }
    if (data case {'error_description': final String desc}) {
      throw Exception(desc);
    }
    throw Exception('Invalid response: ${res.body}');
  }

  Future<({DeviceLoginStatus status, String? accessToken})> getAccessToken(
    DeviceLoginModel deviceLogin,
  ) async {
    final res = await post<Object>(
      'https://github.com/login/oauth/access_token',
      null,
      query: {
        'client_id': clientId,
        'device_code': deviceLogin.deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      },
      headers: const {'Accept': 'application/json'},
    );
    if (res.body == null) throw Exception('Failed to get access token');
    final data = _parseAuthResponse(res.body!);
    if (data['error'] == 'authorization_pending') {
      return (
        status: DeviceLoginStatus.authorizationPending,
        accessToken: null,
      );
    }
    if (data['error'] == 'expired_token') {
      return (
        status: DeviceLoginStatus.expiredToken,
        accessToken: null,
      );
    }
    if (data['error'] == 'access_denied') {
      return (
        status: DeviceLoginStatus.accessDenied,
        accessToken: null,
      );
    }
    if (data case {'access_token': final String accessToken}) {
      return (
        status: DeviceLoginStatus.finished,
        accessToken: accessToken,
      );
    }
    throw Exception('Invalid response: ${res.body}');
  }

  Future<DeviceLoginModel> getDeviceLogin() async {
    final res = await post<Object>(
      'https://github.com/login/device/code',
      null,
      query: {'client_id': clientId},
      headers: const {'Accept': 'application/json'},
    );
    if (res.body == null) throw Exception('Failed to get device code');
    final data = _parseAuthResponse(res.body!);
    return DeviceLoginModel.fromJson(data);
  }
}

Map<String, dynamic> _parseAuthResponse(Object body) {
  if (body is Map<String, dynamic>) return body;
  if (body is Map) {
    return body.map((key, value) => MapEntry(key.toString(), value));
  }
  if (body is String) {
    final trimmed = body.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      throw Exception('Invalid auth response JSON: ${decoded.runtimeType}');
    }
    return Uri.splitQueryString(body);
  }
  throw Exception('Invalid auth response type: ${body.runtimeType}');
}

class BaseConnect extends GetConnect {
  static final loginApi = Get.find<LoginApi>();
  static bool _reauthNoticeShown = false;
  static bool _rateLimitNoticeShown = false;
  static final _classicToken = RegExp(r'^[0-9a-fA-F]{40}$');
  static bool _isValidToken(String token) =>
      token.startsWith('gho_') ||
      token.startsWith('ghu_') ||
      token.startsWith('ghp_') ||
      token.startsWith('github_pat_') ||
      _classicToken.hasMatch(token);

  @override
  void onInit() {
    httpClient.baseUrl = 'https://api.github.com';
    httpClient.addResponseModifier((req, rep) {
      if (rep.statusCode == HttpStatus.unauthorized) {
        box.remove('access_token');
      }
      return rep;
    });
    httpClient.maxAuthRetries = 3;
  }

  bool _isRateLimitError(List errors) {
    for (final err in errors) {
      if (err is Map) {
        final type = err['type']?.toString();
        final code = err['code']?.toString();
        if (type == 'RATE_LIMIT' || code == 'graphql_rate_limit') {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _handleRateLimitReauth() async {
    if (!_rateLimitNoticeShown && Get.context != null) {
      _rateLimitNoticeShown = true;
      await showDialog(
        context: Get.context!,
        builder: (context) => AlertDialog(
          title: Text('Rate limit exceeded'.tr),
          content: Text(
            'GitHub API rate limit exceeded. Please login again to switch accounts.'
                .tr,
          ),
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
    _rateLimitNoticeShown = false;
  }

  Future<Response<Map<String, dynamic>>> graphql(
    String data, {
    bool allowRetry = true,
  }) async {
    var token = box.read<String>('access_token') ?? '';
    final hadToken = token.isNotEmpty;
    while (!_isValidToken(token)) {
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
      if (!_isValidToken(token)) {
        break;
      }
    }
    final headers = <String, String>{};
    if (_isValidToken(token)) {
      _reauthNoticeShown = false;
      headers['Authorization'] = 'Bearer $token';
    }
    final res = await post<Map<String, dynamic>>(
      '/graphql',
      jsonEncode({'query': data}),
      headers: headers,
    );
    if (res.statusCode != HttpStatus.ok) {
      throw Exception('GitHub API error: ${res.statusCode} ${res.body}');
    }
    final body = res.body;
    if (body == null) {
      throw Exception('GitHub API error: empty response');
    }
    if (body['errors'] case final List errors) {
      if (allowRetry && _isRateLimitError(errors)) {
        await _handleRateLimitReauth();
        return graphql(data, allowRetry: false);
      }
      final msg = errors.map((e) => e.toString()).join('\n');
      throw Exception('GitHub API error: $msg');
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
    final data = res.body?['data'] as Map<String, dynamic>?;
    if (data == null || data['search'] == null) {
      throw Exception('Invalid search response: ${res.body}');
    }
    return PaginationModel.fromJson(
      // ignore: avoid_dynamic_calls
      data['search'] as Map<String, dynamic>,
      HDataModel.fromJson,
    );
  }

  Future<PaginationModel<CommentModel>> getComments(
      int number, String? endCur) async {
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
