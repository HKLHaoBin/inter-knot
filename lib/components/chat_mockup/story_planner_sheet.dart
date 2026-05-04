import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_item.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_story_planner.dart';

/// Bottom sheet: outer [ExpansionTile]「剧情构思」with inner「剧情大纲」「构思」.
///
/// Callback bundle keeps [StoryPlannerSheet] decoupled from [ChatMockupCanvasState].
class StoryPlannerSheetController {
  StoryPlannerSheetController({
    required this.getPlanner,
    required this.applyPlanner,
    required this.getItems,
    required this.buildPlotHistory,
    required this.runOutlineAi,
    required this.runIdeationAi,
    required this.rollbackPlannerChatLastUserIfMatches,
    required this.getPlannerAiBusy,
    required this.setPlannerAiBusy,
    required this.isAiInitialized,
    required this.isAiConfigured,
  });

  final ChatMockupStoryPlanner Function() getPlanner;
  final void Function(ChatMockupStoryPlanner next) applyPlanner;
  final List<ChatMockupItem> Function() getItems;
  final String Function(Iterable<ChatMockupItem> items) buildPlotHistory;
  final Future<PlannerOutlineResult?> Function(
    void Function(String accumulated)? onStreamChunk,
  ) runOutlineAi;
  final Future<String?> Function(
    String userMessage,
    void Function(String accumulated)? onStreamChunk,
  ) runIdeationAi;
  final void Function(String userContent) rollbackPlannerChatLastUserIfMatches;
  final bool Function() getPlannerAiBusy;
  final void Function(bool busy) setPlannerAiBusy;
  final bool Function() isAiInitialized;
  final bool Function() isAiConfigured;
}

class StoryPlannerSheet extends StatefulWidget {
  const StoryPlannerSheet({super.key, required this.controller});

  final StoryPlannerSheetController controller;

  @override
  State<StoryPlannerSheet> createState() => _StoryPlannerSheetState();
}

class _StoryPlannerSheetState extends State<StoryPlannerSheet> {
  final _ideationInput = TextEditingController();
  final _manualTodo = TextEditingController();
  String _ideationStreamPreview = '';
  bool _outlineStreamSlot = false;
  bool _ideationStreamSlot = false;
  List<String> _outlineCandidates = const [];
  PlannerUncoveredRange? _pendingOutlineRange;
  String? _outlineError;

  StoryPlannerSheetController get c => widget.controller;

  @override
  void dispose() {
    _ideationInput.dispose();
    _manualTodo.dispose();
    super.dispose();
  }

  void _syncFromParent() {
    if (mounted) setState(() {});
  }

  /// Coverage row for [range] at current item text; reuses same start/end/hash if already present.
  ({List<PlannerCoverageSegment> coverage, String covId})
      _coverageForPendingSegment({
    required ChatMockupStoryPlanner p,
    required PlannerUncoveredRange range,
    required List<ChatMockupItem> items,
  }) {
    final slice = items.sublist(range.startIndex, range.endIndex + 1);
    final h = hashPlotSlice(slice);
    final list = List<PlannerCoverageSegment>.from(p.coverage);
    for (final seg in list) {
      if (seg.startItemId == range.startItemId &&
          seg.endItemId == range.endItemId &&
          seg.textHash == h) {
        return (coverage: list, covId: seg.id);
      }
    }
    final covId = 'cov_${DateTime.now().microsecondsSinceEpoch}';
    list.add(PlannerCoverageSegment(
      id: covId,
      startItemId: range.startItemId,
      endItemId: range.endItemId,
      textHash: h,
    ));
    return (coverage: list, covId: covId);
  }

  /// Manual / 非候选：不绑定 coverage。
  void _addTodoLine(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final p = c.getPlanner();
    final id = 'todo_${DateTime.now().microsecondsSinceEpoch}';
    final next = p.copyWith(
      todos: [...p.todos, PlannerTodo(id: id, text: t, stale: false)],
    );
    c.applyPlanner(next);
    _syncFromParent();
  }

  /// 候选行「加入待办」：先认领本段 coverage，再视情况追加待办（同文案则只认领、不重复建 todo）。
  void _addTodoLineFromCandidate(String rawLine) {
    final t = rawLine.trim();
    if (t.isEmpty) return;
    var p = c.getPlanner();
    final range = _pendingOutlineRange;
    final items = c.getItems();
    final hadPendingSegment = range != null &&
        range.startIndex < items.length &&
        range.endIndex < items.length;

    String? covId;
    if (hadPendingSegment) {
      final merged = _coverageForPendingSegment(
        p: p,
        range: range,
        items: items,
      );
      p = p.copyWith(coverage: merged.coverage);
      covId = merged.covId;
    }

    final duplicateTodo = p.todos.any((x) => x.text.trim() == t);
    if (!duplicateTodo) {
      final id = 'todo_${DateTime.now().microsecondsSinceEpoch}';
      c.applyPlanner(p.copyWith(
        todos: [
          ...p.todos,
          PlannerTodo(
            id: id,
            text: t,
            stale: false,
            sourceCoverageId: covId,
          ),
        ],
      ));
    } else {
      c.applyPlanner(p);
      if (hadPendingSegment && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已存在同名待办，已为本段认领覆盖'),
          ),
        );
      }
    }
    _syncFromParent();
  }

  void _removeTodo(String id) {
    final p = c.getPlanner();
    final next = p.copyWith(
      todos: p.todos.where((e) => e.id != id).toList(),
    );
    c.applyPlanner(next);
    _syncFromParent();
  }

  Future<void> _editTodo(PlannerTodo todo) async {
    final ctrl = TextEditingController(text: todo.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xff262626),
          title: const Text('编辑待办', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 1,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '待办内容',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Color(0xff1a1a1a),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    final nextText = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !mounted || nextText.isEmpty) return;
    final p = c.getPlanner();
    c.applyPlanner(p.copyWith(
      todos: [
        for (final t in p.todos)
          t.id == todo.id ? t.copyWith(text: nextText) : t,
      ],
    ));
    _syncFromParent();
  }

  void _clearStaleOnTodo(String id) {
    final p = c.getPlanner();
    final next = p.copyWith(
      todos: [
        for (final t in p.todos) t.id == id ? t.copyWith(stale: false) : t,
      ],
    );
    c.applyPlanner(next);
    _syncFromParent();
  }

  void _markCoverageForPending({required bool addTodosFromCandidates}) {
    final range = _pendingOutlineRange;
    if (range == null) return;
    final items = c.getItems();
    if (range.startIndex >= items.length || range.endIndex >= items.length) {
      return;
    }
    final p = c.getPlanner();
    final merged = _coverageForPendingSegment(
      p: p,
      range: range,
      items: items,
    );
    final todos = List<PlannerTodo>.from(p.todos);
    if (addTodosFromCandidates) {
      for (var i = 0; i < _outlineCandidates.length; i++) {
        final line = _outlineCandidates[i];
        final t = line.trim();
        if (t.isEmpty) continue;
        if (todos.any((x) => x.text.trim() == t)) continue;
        todos.add(PlannerTodo(
          id: 'todo_${DateTime.now().microsecondsSinceEpoch}_$i',
          text: t,
          stale: false,
          sourceCoverageId: merged.covId,
        ));
      }
    }
    c.applyPlanner(p.copyWith(
      coverage: merged.coverage,
      todos: todos,
    ));
    setState(() {
      _outlineCandidates = const [];
      _pendingOutlineRange = null;
      _outlineError = null;
    });
  }

  Future<void> _onGenerateOutline() async {
    if (!c.isAiInitialized()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 设置加载中…')),
      );
      return;
    }
    if (!c.isAiConfigured()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先补全 AI 设置')),
      );
      return;
    }
    setState(() {
      _outlineError = null;
      _ideationStreamPreview = '';
    });
    c.setPlannerAiBusy(true);
    setState(() => _outlineStreamSlot = true);
    try {
      final r = await c.runOutlineAi((acc) {
        if (!mounted) return;
        setState(() => _ideationStreamPreview = acc);
      });
      if (!mounted) return;
      if (r == null) {
        setState(() {
          _outlineCandidates = const [];
          _pendingOutlineRange = null;
          _outlineError = '生成失败或无可处理段落';
        });
        return;
      }
      if (r.lines.isEmpty) {
        setState(() {
          _outlineCandidates = const [];
          _pendingOutlineRange = r.range;
          _outlineError = '模型未返回候选条目';
        });
        return;
      }
      setState(() {
        _outlineCandidates = r.lines;
        _pendingOutlineRange = r.range;
        _outlineError = null;
        _ideationStreamPreview = '';
      });
    } finally {
      c.setPlannerAiBusy(false);
      if (mounted) {
        setState(() {
          _outlineStreamSlot = false;
        });
      }
    }
  }

  Future<void> _sendIdeation() async {
    final msg = _ideationInput.text.trim();
    if (msg.isEmpty) return;
    if (!c.isAiInitialized()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 设置加载中…')),
      );
      return;
    }
    if (!c.isAiConfigured()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先补全 AI 设置')),
      );
      return;
    }
    final p0 = c.getPlanner();
    final userTurn = PlannerChatTurn(
      role: 'user',
      content: msg,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    c.applyPlanner(p0.copyWith(chat: [...p0.chat, userTurn]));
    _ideationInput.clear();
    setState(() {
      _ideationStreamPreview = '';
      _ideationStreamSlot = true;
    });
    c.setPlannerAiBusy(true);
    try {
      final reply = await c.runIdeationAi(msg, (acc) {
        if (!mounted) return;
        setState(() => _ideationStreamPreview = acc);
      });
      if (!mounted) return;
      if (reply == null) {
        c.rollbackPlannerChatLastUserIfMatches(msg);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('构思已中断：画布已刷新，未写入回复')),
          );
        }
        return;
      }
      final trimmed = reply.trim();
      if (trimmed.isEmpty) {
        c.rollbackPlannerChatLastUserIfMatches(msg);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('构思未写入：模型返回为空')),
          );
        }
        return;
      }
      final p1 = c.getPlanner();
      c.applyPlanner(p1.copyWith(chat: [
        ...p1.chat,
        PlannerChatTurn(
          role: 'assistant',
          content: trimmed,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      ]));
      setState(() => _ideationStreamPreview = '');
    } catch (e) {
      c.rollbackPlannerChatLastUserIfMatches(msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('构思对话失败: $e')),
        );
      }
    } finally {
      c.setPlannerAiBusy(false);
      if (mounted) {
        setState(() {
          _ideationStreamSlot = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = c.getPlanner();
    final items = c.getItems();
    final gaps = computeUncoveredRanges(items: items, coverage: p.coverage);
    final busy = c.getPlannerAiBusy();
    final gapPreview = gaps.isEmpty
        ? '（当前剧情均已覆盖大纲范围）'
        : gaps.map((g) => '${g.startItemId} → ${g.endItemId}').join('；');

    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Material(
          color: const Color(0xff161616),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: Colors.white24,
                    hoverColor: Colors.white12,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    children: [
                      ExpansionTile(
                        initiallyExpanded: true,
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        title: const Text(
                          '剧情构思',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          '展开后使用「剧情大纲」与「构思」',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        iconColor: Colors.white70,
                        collapsedIconColor: Colors.white70,
                        textColor: Colors.white,
                        collapsedTextColor: Colors.white,
                        backgroundColor: const Color(0xff1c1c1c),
                        collapsedBackgroundColor: const Color(0xff1c1c1c),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        children: [
                          ExpansionTile(
                            initiallyExpanded: true,
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text(
                              '剧情大纲',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            iconColor: Colors.white60,
                            collapsedIconColor: Colors.white60,
                            textColor: Colors.white,
                            collapsedTextColor: Colors.white,
                            backgroundColor: const Color(0xff202020),
                            collapsedBackgroundColor: const Color(0xff202020),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '未覆盖剧情段：$gapPreview',
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    if (gaps.isNotEmpty)
                                      Text(
                                        c.buildPlotHistory(
                                          items.sublist(
                                            gaps.first.startIndex,
                                            gaps.first.endIndex + 1,
                                          ),
                                        ),
                                        maxLines: 6,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11),
                                      ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed:
                                          busy ? null : _onGenerateOutline,
                                      icon: busy
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Icon(Icons.auto_awesome),
                                      label: Text(
                                          busy ? '生成中…' : '为下一段未覆盖剧情生成候选大纲'),
                                    ),
                                    if (_outlineStreamSlot &&
                                        _ideationStreamPreview.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: SelectableText(
                                          _ideationStreamPreview,
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12),
                                        ),
                                      ),
                                    if (_outlineError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          _outlineError!,
                                          style: const TextStyle(
                                              color: Colors.orangeAccent,
                                              fontSize: 12),
                                        ),
                                      ),
                                    if (_outlineCandidates.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      const Text(
                                        '候选大纲（逐条加入会认领本段覆盖）',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      for (final line in _outlineCandidates)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: SelectableText(
                                                  line,
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: busy
                                                    ? null
                                                    : () =>
                                                        _addTodoLineFromCandidate(
                                                            line),
                                                child: const Text('加入待办'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton(
                                            onPressed: busy ||
                                                    _pendingOutlineRange == null
                                                ? null
                                                : () => _markCoverageForPending(
                                                      addTodosFromCandidates:
                                                          true,
                                                    ),
                                            child: const Text('全部加入待办并标记覆盖'),
                                          ),
                                          OutlinedButton(
                                            onPressed: busy ||
                                                    _pendingOutlineRange == null
                                                ? null
                                                : () => _markCoverageForPending(
                                                      addTodosFromCandidates:
                                                          false,
                                                    ),
                                            child: const Text('仅标记本段已覆盖'),
                                          ),
                                          TextButton(
                                            onPressed: busy
                                                ? null
                                                : () => setState(() {
                                                      _outlineCandidates =
                                                          const [];
                                                      _pendingOutlineRange =
                                                          null;
                                                      _outlineError = null;
                                                    }),
                                            child: const Text('清除候选'),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const Divider(
                                        height: 32, color: Color(0xff333333)),
                                    const Text(
                                      '正式待办',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _manualTodo,
                                            style: const TextStyle(
                                                color: Colors.white),
                                            decoration: const InputDecoration(
                                              hintText: '手动添加待办',
                                              hintStyle: TextStyle(
                                                  color: Colors.white30),
                                              filled: true,
                                              fillColor: Color(0xff202020),
                                            ),
                                            onSubmitted: (_) {
                                              _addTodoLine(_manualTodo.text);
                                              _manualTodo.clear();
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add,
                                              color: Colors.white70),
                                          onPressed: () {
                                            _addTodoLine(_manualTodo.text);
                                            _manualTodo.clear();
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (p.todos.isEmpty)
                                      const Text('暂无待办',
                                          style:
                                              TextStyle(color: Colors.white38)),
                                    for (final t in p.todos)
                                      ListTile(
                                        dense: true,
                                        title: Text(
                                          t.text,
                                          style: TextStyle(
                                            color: t.stale
                                                ? Colors.orangeAccent
                                                : Colors.white,
                                          ),
                                        ),
                                        subtitle: t.stale
                                            ? const Text(
                                                '可能已过期（正文相对大纲生成时已改动）',
                                                style: TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11),
                                              )
                                            : null,
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (t.stale)
                                              TextButton(
                                                onPressed: () =>
                                                    _clearStaleOnTodo(t.id),
                                                child: const Text('标为有效'),
                                              ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                color: Colors.white54,
                                              ),
                                              onPressed: () => _editTodo(t),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.white38),
                                              onPressed: () =>
                                                  _removeTodo(t.id),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          ExpansionTile(
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text(
                              '构思',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            iconColor: Colors.white60,
                            collapsedIconColor: Colors.white60,
                            textColor: Colors.white,
                            collapsedTextColor: Colors.white,
                            backgroundColor: const Color(0xff202020),
                            collapsedBackgroundColor: const Color(0xff202020),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      height: 240,
                                      child: ListView(
                                        padding: EdgeInsets.zero,
                                        children: [
                                          for (final m in p.chat)
                                            Align(
                                              alignment: m.role == 'user'
                                                  ? Alignment.centerRight
                                                  : Alignment.centerLeft,
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 8),
                                                padding:
                                                    const EdgeInsets.all(10),
                                                constraints: BoxConstraints(
                                                  maxWidth:
                                                      MediaQuery.sizeOf(context)
                                                              .width *
                                                          0.82,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: m.role == 'user'
                                                      ? const Color(0xff2a3f5f)
                                                      : const Color(0xff2a2a2a),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: SelectableText(
                                                  m.content,
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          if (_ideationStreamSlot &&
                                              busy &&
                                              _ideationStreamPreview.isNotEmpty)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: SelectableText(
                                                '…\n$_ideationStreamPreview',
                                                style: const TextStyle(
                                                    color: Colors.white54),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _ideationInput,
                                            minLines: 1,
                                            maxLines: 3,
                                            enabled: !busy,
                                            style: const TextStyle(
                                                color: Colors.white),
                                            decoration: const InputDecoration(
                                              hintText: '与 AI 讨论后续走向（不写正文）',
                                              hintStyle: TextStyle(
                                                  color: Colors.white30),
                                              filled: true,
                                              fillColor: Color(0xff202020),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton(
                                          onPressed:
                                              busy ? null : _sendIdeation,
                                          child: Text(busy ? '…' : '发送'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
