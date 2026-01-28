import 'package:get/get.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/label.dart';
import 'package:inter_knot/models/pagination.dart';

class DiscussionModel {
  String title;
  String bodyHTML;
  String rawBodyText;
  String? cover;
  int number;
  String id;
  DateTime createdAt;
  DateTime? lastEditedAt;
  int commentsCount;
  AuthorModel author;
  String? categoryName;
  final List<LabelModel> labels;
  final RxList<PaginationModel<CommentModel>> comments;
  String get bodyText => rawBodyText.replaceAll(RegExp(r'\s+'), ' ').trim();
  String get url => '$discussionsLink/$number';

  DiscussionModel({
    required this.title,
    required this.bodyHTML,
    required this.rawBodyText,
    required this.cover,
    required this.number,
    required this.id,
    required this.createdAt,
    required this.commentsCount,
    required this.lastEditedAt,
    required this.author,
    required this.categoryName,
    required this.labels,
    required List<PaginationModel<CommentModel>> comments,
  }) : comments = comments.obs;

  factory DiscussionModel.fromJson(Map<String, dynamic> json) {
    final (:cover, :html) = parseHtml(json['bodyHTML'] as String);
    final comments = json['comments'] as Map<String, dynamic>?;
    final category = json['category'] as Map<String, dynamic>?;
    final labelsJson = json['labels'] as Map<String, dynamic>?;
    final labelNodes = labelsJson?['nodes'] as List<dynamic>? ?? [];
    return DiscussionModel(
      title: json['title'] as String,
      bodyHTML: html,
      cover: cover,
      rawBodyText: json['bodyText'] as String,
      number: (json['number'] as int?) ?? 0,
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      commentsCount: (comments?['totalCount'] as int?) ?? 0,
      lastEditedAt:
          (json['lastEditedAt'] as String?).use((v) => DateTime.parse(v)),
      author: AuthorModel.fromJson(json['author'] as Map<String, dynamic>),
      categoryName: category?['name'] as String?,
      labels: labelNodes
          .whereType<Map<String, dynamic>>()
          .map(LabelModel.fromJson)
          .toList(),
      comments: [
        PaginationModel.fromJson(
          // ignore: avoid_dynamic_calls
          json['comments'] as Map<String, dynamic>,
          CommentModel.fromJson,
        ),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiscussionModel && other.number == number;

  @override
  int get hashCode => number;
}
