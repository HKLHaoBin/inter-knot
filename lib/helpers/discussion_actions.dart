import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/models/discussion.dart';

extension DiscussionActions on DiscussionModel {
  bool hasNextPage() => comments.isNotEmpty && comments.last.hasNextPage;

  Future<void> fetchComments() async {
    if (!hasNextPage()) return;
    final cursor = comments.last.endCursor;
    if (cursor == null) return;
    final api = Get.find<Api>();
    final page = await api.getComments(number, cursor);
    comments.add(page);
  }

  Future<void> refreshComments() async {
    final api = Get.find<Api>();
    final page = await api.getComments(number, null);
    comments.assignAll([page]);
  }
}
