import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_item.dart';

/// Local-only story planner: outline todos, coverage over plot segments, ideation chat.
///
/// Plot hashing mirrors [ChatMockupCanvasState._buildAiChatHistoryFromItems] — keep in sync.
class PlannerTodo {
  const PlannerTodo({
    required this.id,
    required this.text,
    required this.stale,
    this.sourceCoverageId,
  });

  final String id;
  final String text;
  final bool stale;
  final String? sourceCoverageId;

  PlannerTodo copyWith({
    String? id,
    String? text,
    bool? stale,
    String? sourceCoverageId,
  }) {
    return PlannerTodo(
      id: id ?? this.id,
      text: text ?? this.text,
      stale: stale ?? this.stale,
      sourceCoverageId: sourceCoverageId ?? this.sourceCoverageId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'stale': stale,
        if (sourceCoverageId != null) 'sourceCoverageId': sourceCoverageId,
      };

  factory PlannerTodo.fromJson(Map<String, dynamic> j) {
    return PlannerTodo(
      id: j['id'] is String ? j['id'] as String : '',
      text: j['text'] is String ? j['text'] as String : '',
      stale: j['stale'] == true,
      sourceCoverageId: j['sourceCoverageId'] is String
          ? j['sourceCoverageId'] as String
          : null,
    );
  }
}

class PlannerCoverageSegment {
  const PlannerCoverageSegment({
    required this.id,
    required this.startItemId,
    required this.endItemId,
    required this.textHash,
  });

  final String id;
  final String startItemId;
  final String endItemId;
  final String textHash;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startItemId': startItemId,
        'endItemId': endItemId,
        'textHash': textHash,
      };

  factory PlannerCoverageSegment.fromJson(Map<String, dynamic> j) {
    return PlannerCoverageSegment(
      id: j['id'] is String ? j['id'] as String : '',
      startItemId: j['startItemId'] is String ? j['startItemId'] as String : '',
      endItemId: j['endItemId'] is String ? j['endItemId'] as String : '',
      textHash: j['textHash'] is String ? j['textHash'] as String : '',
    );
  }
}

class PlannerChatTurn {
  const PlannerChatTurn({
    required this.role,
    required this.content,
    required this.createdAtMs,
  });

  final String role;
  final String content;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'createdAtMs': createdAtMs,
      };

  factory PlannerChatTurn.fromJson(Map<String, dynamic> j) {
    return PlannerChatTurn(
      role: j['role'] is String ? j['role'] as String : 'user',
      content: j['content'] is String ? j['content'] as String : '',
      createdAtMs: j['createdAtMs'] is int ? j['createdAtMs'] as int : 0,
    );
  }
}

class ChatMockupStoryPlanner {
  ChatMockupStoryPlanner({
    required this.todos,
    required this.coverage,
    required this.chat,
  });

  final List<PlannerTodo> todos;
  final List<PlannerCoverageSegment> coverage;
  final List<PlannerChatTurn> chat;

  /// Growable empty lists (not `const []`, which is unmodifiable).
  factory ChatMockupStoryPlanner.empty() => ChatMockupStoryPlanner(
        todos: <PlannerTodo>[],
        coverage: <PlannerCoverageSegment>[],
        chat: <PlannerChatTurn>[],
      );

  ChatMockupStoryPlanner copyWith({
    List<PlannerTodo>? todos,
    List<PlannerCoverageSegment>? coverage,
    List<PlannerChatTurn>? chat,
  }) {
    return ChatMockupStoryPlanner(
      todos: todos ?? List<PlannerTodo>.from(this.todos),
      coverage: coverage ?? List<PlannerCoverageSegment>.from(this.coverage),
      chat: chat ?? List<PlannerChatTurn>.from(this.chat),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'todos': todos.map((e) => e.toJson()).toList(),
        'coverage': coverage.map((e) => e.toJson()).toList(),
        'chat': chat.map((e) => e.toJson()).toList(),
      };

  /// Non-empty todos, coverage, or ideation chat — worth keeping when items are still default template.
  bool get hasLocalArchiveSignal =>
      todos.isNotEmpty || coverage.isNotEmpty || chat.isNotEmpty;

  factory ChatMockupStoryPlanner.fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return ChatMockupStoryPlanner.empty();
    }
    if (raw['version'] != 1) return ChatMockupStoryPlanner.empty();
    final todosJson = raw['todos'];
    final covJson = raw['coverage'];
    final chatJson = raw['chat'];
    final todos = <PlannerTodo>[];
    final cov = <PlannerCoverageSegment>[];
    final chat = <PlannerChatTurn>[];
    if (todosJson is List) {
      for (final e in todosJson) {
        if (e is Map<String, dynamic>) {
          todos.add(PlannerTodo.fromJson(e));
        }
      }
    }
    if (covJson is List) {
      for (final e in covJson) {
        if (e is Map<String, dynamic>) {
          cov.add(PlannerCoverageSegment.fromJson(e));
        }
      }
    }
    if (chatJson is List) {
      for (final e in chatJson) {
        if (e is Map<String, dynamic>) {
          chat.add(PlannerChatTurn.fromJson(e));
        }
      }
    }
    return ChatMockupStoryPlanner(todos: todos, coverage: cov, chat: chat);
  }
}

/// Drops coverage whose item ids or text hash no longer match; marks linked todos stale.
ChatMockupStoryPlanner revalidateStoryPlanner({
  required List<ChatMockupItem> items,
  required ChatMockupStoryPlanner planner,
}) {
  final idToIndex = <String, int>{};
  for (var i = 0; i < items.length; i++) {
    idToIndex[items[i].id] = i;
  }
  final removedCoverageIds = <String>{};
  final keptCoverage = <PlannerCoverageSegment>[];
  for (final seg in planner.coverage) {
    final ai = idToIndex[seg.startItemId];
    final bi = idToIndex[seg.endItemId];
    if (ai == null || bi == null || ai > bi) {
      removedCoverageIds.add(seg.id);
      continue;
    }
    final slice = items.sublist(ai, bi + 1);
    final h = hashPlotSlice(slice);
    if (h == seg.textHash) {
      keptCoverage.add(seg);
    } else {
      removedCoverageIds.add(seg.id);
    }
  }
  var todosChanged = false;
  final newTodos = <PlannerTodo>[];
  for (final t in planner.todos) {
    final sid = t.sourceCoverageId;
    if (sid != null && removedCoverageIds.contains(sid)) {
      if (!t.stale) todosChanged = true;
      newTodos.add(t.copyWith(stale: true));
    } else {
      newTodos.add(t);
    }
  }
  if (keptCoverage.length == planner.coverage.length && !todosChanged) {
    return planner;
  }
  return ChatMockupStoryPlanner(
    todos: newTodos,
    coverage: keptCoverage,
    chat: List<PlannerChatTurn>.from(planner.chat),
  );
}

/// Same line format as `_buildAiChatHistoryFromItems` in chat_mockup_canvas.dart.
String plannerPlotTextForItems(Iterable<ChatMockupItem> items) {
  final lines = <String>[];
  for (final item in items) {
    switch (item.type) {
      case ChatMockupItemType.message:
        final text = (item.text ?? '').trim();
        if (text.isEmpty) continue;
        final prefix = item.side == ChatMockupItemSide.left
            ? '角色'
            : item.side == ChatMockupItemSide.right
                ? '用户'
                : '消息';
        lines.add('$prefix: $text');
      case ChatMockupItemType.action:
        final text = (item.text ?? '').trim();
        if (text.isEmpty) continue;
        lines.add('动作: $text');
      case ChatMockupItemType.emoji:
        lines.add('[emoji: ${item.emoji ?? '🙂'}]');
      case ChatMockupItemType.sticker:
        lines.add('[sticker]');
      case ChatMockupItemType.customImage:
        lines.add('[image]');
      case ChatMockupItemType.replyOptions:
        lines.add('[replyOptions]');
      case ChatMockupItemType.commission:
        lines.add('[commission]');
    }
  }
  return lines.join('\n');
}

String hashPlotSlice(List<ChatMockupItem> slice) {
  final text = plannerPlotTextForItems(slice);
  return sha256.convert(utf8.encode(text)).toString();
}

class PlannerUncoveredRange {
  const PlannerUncoveredRange({
    required this.startIndex,
    required this.endIndex,
    required this.startItemId,
    required this.endItemId,
  });

  final int startIndex;
  final int endIndex;
  final String startItemId;
  final String endItemId;
}

/// Parsed outline AI response (candidate bullets for one uncovered segment).
class PlannerOutlineResult {
  const PlannerOutlineResult({required this.lines, required this.range});

  final List<String> lines;
  final PlannerUncoveredRange range;
}

List<PlannerUncoveredRange> computeUncoveredRanges({
  required List<ChatMockupItem> items,
  required List<PlannerCoverageSegment> coverage,
}) {
  final n = items.length;
  if (n == 0) return const [];
  final idToIndex = <String, int>{};
  for (var i = 0; i < n; i++) {
    idToIndex[items[i].id] = i;
  }
  final covered = List<bool>.filled(n, false);
  for (final seg in coverage) {
    final a = idToIndex[seg.startItemId];
    final b = idToIndex[seg.endItemId];
    if (a == null || b == null || a > b) continue;
    for (var i = a; i <= b; i++) {
      covered[i] = true;
    }
  }
  final out = <PlannerUncoveredRange>[];
  var i = 0;
  while (i < n) {
    if (covered[i]) {
      i++;
      continue;
    }
    final start = i;
    while (i < n && !covered[i]) {
      i++;
    }
    final end = i - 1;
    out.add(PlannerUncoveredRange(
      startIndex: start,
      endIndex: end,
      startItemId: items[start].id,
      endItemId: items[end].id,
    ));
  }
  return out;
}
