import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inter_knot/api/chat_mockup_ai_api.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_avatar.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_bubble.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_card.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_item.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_message.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_title_bar.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/chat_mockup_ai_settings_store.dart';
import 'package:inter_knot/helpers/video_archive_codec.dart';
import 'package:inter_knot/models/chat_mockup_ai_settings.dart';
import 'package:inter_knot/models/chat_mockup_prompt_preset.dart';

enum ChatMockupAiMode { director, role }

enum ChatMockupEditableField {
  text,
  title,
  subtitle,
  firstReply,
  secondReply,
}

enum _ChatMockupSettingTargetScope {
  selected,
  selectedMultiple,
  allLeft,
  allRight,
}

class ChatMockupCanvas extends StatefulWidget {
  const ChatMockupCanvas({
    super.key,
    this.onDraftLoadedChanged,
    this.initialPayload,
    this.readOnly = false,
    this.browseMode = false,
    this.autoStartPlayback = false,
    this.lockAiMode = false,
    this.onPlaybackCompleted,
    this.onAiInitializedChanged,
  });

  final ValueChanged<bool>? onDraftLoadedChanged;
  final Map<String, dynamic>? initialPayload;
  final bool readOnly;
  final bool browseMode;
  final bool autoStartPlayback;
  final bool lockAiMode;
  final VoidCallback? onPlaybackCompleted;
  final ValueChanged<bool>? onAiInitializedChanged;

  @override
  State<ChatMockupCanvas> createState() => ChatMockupCanvasState();
}

class ChatMockupCanvasState extends State<ChatMockupCanvas> {
  static const _leftAvatarPath = 'assets/images/zzzicon.png';
  static const _rightAvatarPath = 'assets/images/Bangboo.gif';
  static const _stickerPath = 'assets/images/zzz.webp';
  static const _coverPath = 'assets/images/pc-page-bg.png';
  static const _jsonTypeGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
  static const _imageTypeGroup = XTypeGroup(
    label: 'Images',
    extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
    uniformTypeIdentifiers: [
      'public.png',
      'public.jpeg',
      'public.webp',
      'public.gif',
    ],
  );
  static const _leftAvatarSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _leftAvatarPath,
  );
  static const _rightAvatarSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _rightAvatarPath,
  );
  static const _defaultStickerSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _stickerPath,
  );
  static const _defaultCoverSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _coverPath,
  );
  static const _draftCacheKey = 'chat_mockup_draft';

  final List<ChatMockupItem> _items = [];
  final Set<String> _selectedItemIds = <String>{};
  final Set<String> _newlyAddedItemIds = <String>{};
  String? _primarySelectedItemId;
  String? _editingItemId;
  ChatMockupEditableField? _editingField;
  ChatMockupItemType? _pendingAddType;
  int _nextId = 0;

  static const double _bottomFollowTolerance = 24;
  late final ScrollController _scrollController;
  bool _isFollowingLatest = true;
  bool _showJumpToLatestButton = false;
  int _followLatestScrollToken = 0;

  bool _isPreviewing = false;
  bool _isPlaybackComplete = false;
  int _visibleItemCount = 0;
  int _previewRunId = 0;
  Timer? _playbackTimer;
  bool _isWaitingManual = false;
  bool _isDraftLoaded = false;
  String? _loadError;
  String? _lastExportedSnapshot;
  bool _hasUnexportedChanges = false;
  bool get isDraftLoaded => _isDraftLoaded;
  bool get isAiInitialized => _isAiInitialized;

  late final TextEditingController _editingController;
  late final FocusNode _editingFocusNode;
  bool _isCommittingEditing = false;

  final ChatMockupAiSettingsStore _aiSettingsStore =
      const ChatMockupAiSettingsStore();
  final ChatMockupAiApi _aiApi = const ChatMockupAiApi();
  ChatMockupAiSettings _aiSettings = ChatMockupAiSettings.empty;
  ChatMockupPromptPreset? _promptPreset;
  bool _isAiInitialized = false;
  final Completer<void> _aiInitCompleter = Completer<void>();
  ChatMockupAiMode _aiMode = ChatMockupAiMode.director;
  bool _isAiSending = false;
  late final TextEditingController _aiInputController;
  late final FocusNode _aiInputFocusNode;
  String? _videoRolePrompt;
  String? _videoUserPrompt;

  bool get hasUnexportedChanges {
    if (!_isDraftLoaded) {
      return _hasUnexportedChanges;
    }
    if (_lastExportedSnapshot == null) {
      return true;
    }
    return _currentExportSnapshot() != _lastExportedSnapshot;
  }

  bool get _isBrowseMode => widget.browseMode;
  bool get _isReadOnlyCanvas => widget.readOnly || _isBrowseMode;

  @override
  void initState() {
    super.initState();
    _editingController = TextEditingController();
    _editingFocusNode = FocusNode();
    _scrollController = ScrollController();
    _aiInputController = TextEditingController();
    _aiInputController.addListener(_handleAiInputChanged);
    _aiInputFocusNode = FocusNode();
    if (widget.lockAiMode) {
      _aiMode = ChatMockupAiMode.role;
    }
    unawaited(_initializeAi());
    unawaited(_initializeDraft());
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _editingController.dispose();
    _editingFocusNode.dispose();
    _scrollController.dispose();
    _aiInputController.removeListener(_handleAiInputChanged);
    _aiInputController.dispose();
    _aiInputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDraftLoaded) {
      return const ColoredBox(
        color: ChatMockupTheme.background,
        child: SizedBox.expand(),
      );
    }
    if (_loadError != null) {
      return ColoredBox(
        color: ChatMockupTheme.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              color: const Color(0xff1f1f1f),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '影片数据加载失败',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _loadError!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final visibleItems = _visibleItems();
    return ColoredBox(
      color: ChatMockupTheme.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
            child: Column(
              children: [
                const ChatMockupTitleBar(),
                if (!_isReadOnlyCanvas) _buildAddControls(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Stack(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: ReorderableListView.builder(
                      scrollController: _scrollController,
                      buildDefaultDragHandles: false,
                      onReorder: _onReorder,
                      padding: const EdgeInsets.only(bottom: 24),
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          color: Colors.transparent,
                          elevation: 8,
                          child: child,
                        );
                      },
                      itemCount: visibleItems.length,
                      itemBuilder: (context, index) {
                        return _buildItem(visibleItems[index], index);
                      },
                    ),
                  ),
                  if (_showJumpToLatestButton)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _buildJumpToLatestButton(),
                    ),
                ],
              ),
            ),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Future<void> _initializeAi() async {
    final settings = await _aiSettingsStore.load();
    ChatMockupPromptPreset? preset;
    try {
      final jsonText =
          await rootBundle.loadString('assets/prompts/Tavo_default.json');
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        preset = ChatMockupPromptPreset.fromTavernLikeJson(decoded);
      }
    } catch (_) {
      preset = null;
    }
    if (!mounted) return;
    setState(() {
      if (_isBrowseMode) {
        _aiSettings = settings.copyWith(
          rolePrompt: _videoRolePrompt ?? settings.rolePrompt,
          userPrompt: _videoUserPrompt ?? settings.userPrompt,
        );
      } else {
        _aiSettings = settings;
      }
      _promptPreset = preset;
      _isAiInitialized = true;
    });
    if (!_aiInitCompleter.isCompleted) {
      _aiInitCompleter.complete();
    }
    widget.onAiInitializedChanged?.call(true);
  }

  void _handleAiInputChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> showAiSettings() async {
    if (!_isDraftLoaded) return;
    if (!mounted) return;
    if (!_isAiInitialized) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('AI 设置加载中...')));
      return;
    }

    final endpointController =
        TextEditingController(text: _aiSettings.endpoint);
    final modelController = TextEditingController(text: _aiSettings.model);
    final apiKeyController = TextEditingController(text: _aiSettings.apiKey);
    final rolePromptController =
        TextEditingController(text: _aiSettings.rolePrompt);
    final userPromptController =
        TextEditingController(text: _aiSettings.userPrompt);

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xff161616),
        builder: (ctx) {
          Widget field({
            required String label,
            required TextEditingController controller,
            bool obscureText = false,
            int minLines = 1,
            int maxLines = 1,
            String? hintText,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  obscureText: obscureText,
                  minLines: obscureText ? 1 : minLines,
                  maxLines: obscureText ? 1 : maxLines,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xff202020),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xff2a2a2a)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xff2a2a2a)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            );
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                12 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 设置',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    field(
                      label: '角色卡提示词',
                      controller: rolePromptController,
                      minLines: 3,
                      maxLines: 8,
                      hintText: '用于描述角色信息（不会进入导出 JSON）',
                    ),
                    const SizedBox(height: 12),
                    field(
                      label: '用户身份提示词',
                      controller: userPromptController,
                      minLines: 3,
                      maxLines: 8,
                      hintText: '用于描述用户身份（不会进入导出 JSON）',
                    ),
                    const SizedBox(height: 12),
                    field(
                      label: '接口地址（OpenAI-compatible）',
                      controller: endpointController,
                      hintText: '可填服务地址；会自动补 /chat/completions',
                    ),
                    const SizedBox(height: 12),
                    field(
                      label: '模型',
                      controller: modelController,
                      hintText: '例如 gpt-4.1-mini 或你接口支持的模型名',
                    ),
                    const SizedBox(height: 12),
                    field(
                      label: 'API key（仅本机保存）',
                      controller: apiKeyController,
                      obscureText: true,
                      hintText: '不会进入导出 JSON / 草稿 JSON',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(ctx);
                          final next = ChatMockupAiSettings(
                            endpoint: endpointController.text.trim(),
                            model: modelController.text.trim(),
                            apiKey: apiKeyController.text,
                            rolePrompt: rolePromptController.text,
                            userPrompt: userPromptController.text,
                          );
                          await _aiSettingsStore.save(next);
                          if (!mounted) return;
                          setState(() => _aiSettings = next);
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('AI 设置已保存（仅本机）')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2a2a2a),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      endpointController.dispose();
      modelController.dispose();
      apiKeyController.dispose();
      rolePromptController.dispose();
      userPromptController.dispose();
    }
  }

  List<ChatMockupItem> _initialItems() {
    return [
      _createItem(
        type: ChatMockupItemType.message,
        side: ChatMockupItemSide.left,
        text: 'Click on messages to edit and show actions.',
      ),
      _createItem(
        type: ChatMockupItemType.message,
        side: ChatMockupItemSide.right,
        text: 'Click on chat icons to change them.',
      ),
      _createItem(
        type: ChatMockupItemType.sticker,
        side: ChatMockupItemSide.right,
        imageSource: _defaultStickerSource,
      ),
      _createItem(
          type: ChatMockupItemType.action, side: ChatMockupItemSide.center),
      _createItem(
          type: ChatMockupItemType.emoji, side: ChatMockupItemSide.left),
      _createItem(
          type: ChatMockupItemType.emoji, side: ChatMockupItemSide.right),
      _createItem(
        type: ChatMockupItemType.customImage,
        side: ChatMockupItemSide.left,
        imageSource: _defaultCoverSource,
      ),
      _createItem(
          type: ChatMockupItemType.replyOptions,
          side: ChatMockupItemSide.right),
      _createItem(
          type: ChatMockupItemType.commission, side: ChatMockupItemSide.right),
    ];
  }

  Widget _buildPreviewControls() {
    if (_isBrowseMode) {
      return const SizedBox.shrink();
    }
    if (_isPreviewing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            ElevatedButton(onPressed: _stopPreview, child: const Text('停止预览')),
            const SizedBox(width: 8),
            if (_isWaitingManual)
              ElevatedButton(
                onPressed: _continuePreviewManually,
                child: const Text('点击继续'),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child:
            ElevatedButton(onPressed: _startPreview, child: const Text('预览')),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPreviewControls(),
        _buildAiComposer(),
      ],
    );
  }

  bool get _canSendAi {
    if (!_isDraftLoaded) return false;
    if (_isAiSending) return false;
    if (!_aiSettings.isConfigured) return false;
    if (_editingItemId != null) return false;
    if (_isPreviewing) return false;
    if (_isBrowseMode && !_isPlaybackComplete) return false;
    final input = _aiInputController.text.trim();
    return input.isNotEmpty;
  }

  Widget _buildAiComposer() {
    if (_isBrowseMode && !_isPlaybackComplete) {
      return const SizedBox.shrink();
    }
    final disabled = !_isDraftLoaded || _isPreviewing;
    final canSend = _canSendAi && !disabled;
    final modeLabel = _aiMode == ChatMockupAiMode.director ? '导演模式' : '角色模式';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          if (widget.lockAiMode)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('角色模式', style: TextStyle(color: Colors.white70)),
            )
          else
            DropdownButton<ChatMockupAiMode>(
              value: _aiMode,
              dropdownColor: const Color(0xff262626),
              onChanged: disabled || _isAiSending
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _aiMode = value);
                    },
              items: const [
                DropdownMenuItem(
                  value: ChatMockupAiMode.director,
                  child: Text('导演模式', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: ChatMockupAiMode.role,
                  child: Text('角色模式', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isBrowseMode)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('继续对话'),
                          onPressed: () {
                            _aiInputController.text = '继续对话';
                            _aiInputController.selection =
                                TextSelection.collapsed(
                                    offset: _aiInputController.text.length);
                            _aiInputFocusNode.requestFocus();
                          },
                        ),
                        ActionChip(
                          label: const Text('询问刚才发生了什么'),
                          onPressed: () {
                            _aiInputController.text = '询问刚才发生了什么';
                            _aiInputController.selection =
                                TextSelection.collapsed(
                                    offset: _aiInputController.text.length);
                            _aiInputFocusNode.requestFocus();
                          },
                        ),
                        ActionChip(
                          label: const Text('让角色补充说明'),
                          onPressed: () {
                            _aiInputController.text = '让角色补充说明';
                            _aiInputController.selection =
                                TextSelection.collapsed(
                                    offset: _aiInputController.text.length);
                            _aiInputFocusNode.requestFocus();
                          },
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _aiInputController,
                  focusNode: _aiInputFocusNode,
                  enabled: !disabled && !_isAiSending,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _aiMode == ChatMockupAiMode.director
                        ? '输入剧情走向（不会直接作为消息插入）'
                        : '输入要发送的消息（换行会拆分）',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xff202020),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xff2a2a2a)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xff2a2a2a)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) async {
                    if (!_canSendAi) return;
                    await _sendAiRequest();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: canSend ? _sendAiRequest : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2a2a2a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(_isAiSending ? '发送中' : '发送'),
            ),
          ),
          if (!_aiSettings.isConfigured)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Tooltip(
                message: '请先在 AI 设置中补全接口/模型/API key',
                child: Text(
                  modeLabel,
                  style: const TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendAiRequest() async {
    if (widget.lockAiMode) {
      await _sendRoleAiRequest();
      return;
    }
    if (_aiMode == ChatMockupAiMode.director) {
      await _sendDirectorAiRequest();
      return;
    }
    await _sendRoleAiRequest();
  }

  String _buildAiChatHistory() {
    final lines = <String>[];
    for (final item in _items) {
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

  String _buildAiSystemPrompt({
    required ChatMockupAiMode mode,
    required String scenarioOrUserInput,
  }) {
    final preset = _promptPreset;
    final parts = <String>[];

    String buildMainConstraints() {
      if (mode == ChatMockupAiMode.director) {
        return [
          '你需要输出严格 JSON（不要带 Markdown 代码块）：',
          '{ "turns": [ { "action": "...", "user": "...", "character": "..." } ] }',
          '约束：turns 数量 5~7。action/user/character 可为空字符串。',
          '换行规则：一个换行=一条新消息，空行丢弃，trim()。',
        ].join('\n');
      }
      return [
        '你需要输出严格 JSON（不要带 Markdown 代码块）：',
        '{ "action": "...", "character": "角色消息1\\n角色消息2" }',
        '约束：character 生成 3~5 条消息，每条用换行分隔。',
        '换行规则：一个换行=一条新消息，空行丢弃，trim()。',
      ].join('\n');
    }

    void addSection(String title, String content) {
      final trimmed = content.trim();
      if (trimmed.isEmpty) return;
      parts.add('【$title】\n$trimmed');
    }

    if (preset == null || preset.order.isEmpty) {
      addSection('Main', buildMainConstraints());
      addSection('用户身份', _aiSettings.userPrompt);
      addSection('角色卡', _aiSettings.rolePrompt);
      if (mode == ChatMockupAiMode.director) {
        addSection('剧情走向', scenarioOrUserInput);
      }
      addSection('聊天历史', _buildAiChatHistory());
      return parts.join('\n\n');
    }

    for (final id in preset.order) {
      final enabled = preset.enabledById[id] ?? false;
      if (!enabled) continue;
      switch (id) {
        case 'main':
          final base = preset.promptsById[id] ?? '';
          addSection(
            'Main',
            [base, buildMainConstraints()]
                .where((e) => e.trim().isNotEmpty)
                .join('\n'),
          );
        case 'personaDescription':
          addSection('用户身份', _aiSettings.userPrompt);
        case 'charDescription':
          addSection('角色卡', _aiSettings.rolePrompt);
        case 'scenario':
          if (mode == ChatMockupAiMode.director) {
            addSection('剧情走向', scenarioOrUserInput);
          }
        case 'chatHistory':
          addSection('聊天历史', _buildAiChatHistory());
        default:
          continue;
      }
    }

    if (parts.isEmpty) {
      addSection('Main', buildMainConstraints());
    }
    return parts.join('\n\n');
  }

  Map<String, dynamic> _decodeAiJsonObject(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      final fenceIndex = text.indexOf('\n');
      if (fenceIndex >= 0) {
        text = text.substring(fenceIndex + 1);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      text = text.trim();
    }
    final first = text.indexOf('{');
    final last = text.lastIndexOf('}');
    if (first >= 0 && last > first) {
      text = text.substring(first, last + 1);
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI 输出不是 JSON 对象');
    }
    return decoded;
  }

  List<String> _splitAiMessageLines(String value) {
    return value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _addActionLines(List<ChatMockupItem> pending, String value) {
    for (final line in _splitAiMessageLines(value)) {
      if (pending.length >= 40) return;
      pending.add(
        _createItem(
          type: ChatMockupItemType.action,
          side: ChatMockupItemSide.center,
          text: line,
        ),
      );
    }
  }

  String? _readAnyString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is String) return v;
    }
    return null;
  }

  void _appendNewItems(List<ChatMockupItem> items) {
    if (items.isEmpty) return;
    setState(() {
      _items.addAll(items);
      for (final it in items) {
        _newlyAddedItemIds.add(it.id);
      }
      _visibleItemCount = _items.length;
      _markUnexportedChanges();
    });
    _setFollowingLatest(true);
    _scrollToLatest(animated: true);
  }

  Future<void> _sendDirectorAiRequest() async {
    final input = _aiInputController.text.trim();
    if (input.isEmpty) return;
    if (!_aiSettings.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先补全 AI 设置')));
      return;
    }
    if (_editingItemId != null || _isPreviewing || _isAiSending) return;

    setState(() => _isAiSending = true);
    try {
      final systemPrompt = _buildAiSystemPrompt(
        mode: ChatMockupAiMode.director,
        scenarioOrUserInput: input,
      );
      final content = await _aiApi.createChatCompletion(
        endpoint: _aiSettings.endpoint,
        apiKey: _aiSettings.apiKey,
        model: _aiSettings.model,
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': '请只输出 JSON。'},
        ],
      );

      final decoded = _decodeAiJsonObject(content);
      final turns = decoded['turns'];
      if (turns is! List) {
        throw const FormatException('AI 输出缺少 turns 数组');
      }

      final pending = <ChatMockupItem>[];
      for (final t in turns) {
        if (pending.length >= 40) break;
        if (t is! Map<String, dynamic>) continue;
        final action = _readAnyString(t, ['action', '动作']) ?? '';
        final user = _readAnyString(t, ['user', 'right', '消息右']) ?? '';
        final character =
            _readAnyString(t, ['character', 'assistant', 'left', '消息左']) ?? '';

        _addActionLines(pending, action);

        for (final line in _splitAiMessageLines(user)) {
          if (pending.length >= 40) break;
          pending.add(_createItem(
            type: ChatMockupItemType.message,
            side: ChatMockupItemSide.right,
            text: line,
          ));
        }
        for (final line in _splitAiMessageLines(character)) {
          if (pending.length >= 40) break;
          pending.add(_createItem(
            type: ChatMockupItemType.message,
            side: ChatMockupItemSide.left,
            text: line,
          ));
        }
      }

      if (!mounted) return;
      _aiInputController.clear();
      _appendNewItems(pending);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('AI 失败: $error')));
    } finally {
      if (mounted) {
        setState(() => _isAiSending = false);
      }
    }
  }

  Future<void> _sendRoleAiRequest() async {
    final input = _aiInputController.text.trim();
    if (input.isEmpty) return;
    if (!_aiSettings.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先补全 AI 设置')));
      return;
    }
    if (_editingItemId != null || _isPreviewing || _isAiSending) return;

    final userLines = _splitAiMessageLines(input);
    if (userLines.isEmpty) return;

    final insertedUserItems = <ChatMockupItem>[
      for (final line in userLines.take(40))
        _createItem(
          type: ChatMockupItemType.message,
          side: ChatMockupItemSide.right,
          text: line,
        ),
    ];

    _aiInputController.clear();
    _appendNewItems(insertedUserItems);

    setState(() => _isAiSending = true);
    try {
      final systemPrompt = _buildAiSystemPrompt(
        mode: ChatMockupAiMode.role,
        scenarioOrUserInput: input,
      );
      final content = await _aiApi.createChatCompletion(
        endpoint: _aiSettings.endpoint,
        apiKey: _aiSettings.apiKey,
        model: _aiSettings.model,
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': '请只输出 JSON。'},
        ],
      );

      final decoded = _decodeAiJsonObject(content);
      final action = _readAnyString(decoded, ['action', '动作']) ?? '';
      final character =
          _readAnyString(decoded, ['character', 'assistant', 'left', '消息左']) ??
              '';

      final pending = <ChatMockupItem>[];
      _addActionLines(pending, action);
      for (final line in _splitAiMessageLines(character)) {
        if (pending.length >= 40) break;
        pending.add(_createItem(
          type: ChatMockupItemType.message,
          side: ChatMockupItemSide.left,
          text: line,
        ));
      }

      if (!mounted) return;
      _appendNewItems(pending);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('AI 失败: $error')));
    } finally {
      if (mounted) {
        setState(() => _isAiSending = false);
      }
    }
  }

  Widget _buildAddControls() {
    final isEditing = _editingItemId != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xff161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff2a2a2a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeAddButtons(disabled: isEditing),
          if (_pendingAddType != null) ...[
            const SizedBox(height: 8),
            _buildSidePicker(_pendingAddType!, disabled: isEditing),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeAddButtons({required bool disabled}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _addTypeButton('消息', ChatMockupItemType.message, disabled: disabled),
        _addTypeButton('表情', ChatMockupItemType.emoji, disabled: disabled),
        _addTypeButton('贴纸', ChatMockupItemType.sticker, disabled: disabled),
        _addTypeButton('图片', ChatMockupItemType.customImage,
            disabled: disabled),
        _addTypeButton('回复选项', ChatMockupItemType.replyOptions,
            disabled: disabled),
        _addTypeButton('动作', ChatMockupItemType.action, disabled: disabled),
        _addTypeButton('委托', ChatMockupItemType.commission, disabled: disabled),
      ],
    );
  }

  Widget _buildSidePicker(ChatMockupItemType type, {required bool disabled}) {
    final sides = _allowedSidesForType(type);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (sides.contains(ChatMockupItemSide.left))
          _addSideButton('添加到左侧', type, ChatMockupItemSide.left,
              disabled: disabled),
        if (sides.contains(ChatMockupItemSide.right))
          _addSideButton('添加到右侧', type, ChatMockupItemSide.right,
              disabled: disabled),
        if (sides.contains(ChatMockupItemSide.center))
          _addSideButton('添加到中间', type, ChatMockupItemSide.center,
              disabled: disabled),
        TextButton(
          onPressed:
              disabled ? null : () => setState(() => _pendingAddType = null),
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _addTypeButton(String label, ChatMockupItemType type,
      {required bool disabled}) {
    final isPending = _pendingAddType == type;
    final allowedSides = _allowedSidesForType(type);
    final requiresSideSelection = allowedSides.length > 1;
    return ElevatedButton(
      onPressed: disabled
          ? null
          : () {
              if (requiresSideSelection) {
                setState(() => _pendingAddType = type);
                return;
              }
              _addItem(type);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isPending ? const Color(0xff3a3a3a) : const Color(0xff2a2a2a),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _addSideButton(
    String label,
    ChatMockupItemType type,
    ChatMockupItemSide side, {
    required bool disabled,
  }) {
    return OutlinedButton(
      onPressed: disabled
          ? null
          : () {
              _addItem(type, side: side);
              setState(() => _pendingAddType = null);
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xff4a4a4a)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _buildItem(ChatMockupItem item, int index) {
    final isSelected = _selectedItemIds.contains(item.id);
    final isEditingThisItem = _editingItemId == item.id;
    final isMultiSelecting = _selectedItemIds.length > 1;
    final shouldShowBatchControls =
        isMultiSelecting && item.id == _primarySelectedItemId;
    final side = _toMessageSide(item.side);
    final avatar = item.side == ChatMockupItemSide.center
        ? null
        : ChatMockupAvatar(
            image: _resolveImageProvider(
                item.avatarSource ?? _defaultAvatarForSide(item.side)),
          );
    final entranceEnabled =
        _isPreviewing || _newlyAddedItemIds.contains(item.id);
    final entranceKey =
        _isPreviewing ? 'preview_$_previewRunId:${item.id}' : 'edit:${item.id}';
    return Column(
      key: ValueKey(item.id),
      children: [
        _ChatMockupItemEntrance(
          enabled: entranceEnabled,
          animationKey: entranceKey,
          onCompleted: () {
            if (!_newlyAddedItemIds.contains(item.id)) return;
            setState(() => _newlyAddedItemIds.remove(item.id));
          },
          child: GestureDetector(
            behavior: isEditingThisItem
                ? HitTestBehavior.deferToChild
                : HitTestBehavior.translucent,
            onTap: isEditingThisItem || _isReadOnlyCanvas
                ? null
                : () => _onItemTap(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? ChatMockupTheme.infoBlue
                      : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: ChatMockupMessage(
                side: side,
                avatar: avatar,
                margin: EdgeInsets.zero,
                child: _buildItemContent(item),
              ),
            ),
          ),
        ),
        if (!_isReadOnlyCanvas &&
            !isMultiSelecting &&
            (isSelected || isEditingThisItem))
          _buildSelectionControls(item, index),
        if (!_isReadOnlyCanvas && shouldShowBatchControls)
          _buildBatchSelectionControls(item, index),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildItemContent(ChatMockupItem item) {
    final isMe = item.side == ChatMockupItemSide.right;
    final isEditingThisItem = _editingItemId == item.id;
    final waitLabel = item.waitMode == ChatMockupWaitMode.manual
        ? '点击继续'
        : item.waitSeconds > 0
            ? '等待 ${item.waitSeconds.toStringAsFixed(1)}s'
            : null;
    late final Widget content;
    switch (item.type) {
      case ChatMockupItemType.message:
        if (isEditingThisItem &&
            _editingField == ChatMockupEditableField.text) {
          content = ChatMockupEditableTextBubble(
            controller: _editingController,
            focusNode: _editingFocusNode,
            isMe: isMe,
            hintText: 'Click here to edit',
          );
        } else {
          content = ChatMockupTextBubble(
              text: item.text ?? 'Click here to edit', isMe: isMe);
        }
      case ChatMockupItemType.emoji:
        content = ChatMockupEmojiBubble(emoji: item.emoji ?? '🙂', isMe: isMe);
      case ChatMockupItemType.sticker:
        content = ChatMockupImageBubble(
          image:
              _resolveImageProvider(item.imageSource ?? _defaultStickerSource),
          isMe: isMe,
          width: 88,
          height: 88,
        );
      case ChatMockupItemType.customImage:
        content = ChatMockupImageBubble(
          image: _resolveImageProvider(item.imageSource ?? _defaultCoverSource),
          isMe: isMe,
          frameColor: isMe ? null : Colors.white,
          width: 210,
          height: 132,
        );
      case ChatMockupItemType.action:
        if (isEditingThisItem &&
            _editingField == ChatMockupEditableField.text) {
          content = ChatMockupDividerText(
            child: _buildEditingTextField(
              style: const TextStyle(
                color: Color(0xff5b5b5b),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
              hintText: '-- Click here to edit --',
              textAlign: TextAlign.center,
            ),
          );
        } else {
          content = ChatMockupDividerText(
              text: item.text ?? '-- Click here to edit --');
        }
      case ChatMockupItemType.replyOptions:
        final editingFirst = isEditingThisItem &&
            _editingField == ChatMockupEditableField.firstReply;
        final editingSecond = isEditingThisItem &&
            _editingField == ChatMockupEditableField.secondReply;
        final canStartFieldEdit = _canStartCardFieldEditing(item.id);
        content = ChatMockupReplyCard(
          firstText: item.firstText ?? 'Click here to edit',
          secondText: item.secondText ?? 'Click here to edit',
          firstTextChild: editingFirst
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Click here to edit',
                  textAlign: TextAlign.center,
                )
              : null,
          secondTextChild: editingSecond
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Click here to edit',
                  textAlign: TextAlign.center,
                )
              : null,
          onFirstTextTap: editingFirst || !canStartFieldEdit
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.firstReply,
                    initialValue: item.firstText ?? '',
                  ),
          onSecondTextTap: editingSecond || !canStartFieldEdit
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.secondReply,
                    initialValue: item.secondText ?? '',
                  ),
        );
      case ChatMockupItemType.commission:
        final editingTitle =
            isEditingThisItem && _editingField == ChatMockupEditableField.title;
        final editingSubtitle = isEditingThisItem &&
            _editingField == ChatMockupEditableField.subtitle;
        final canStartFieldEdit = _canStartCardFieldEditing(item.id);
        content = ChatMockupActionCard(
          icon: Icons.info_outline_rounded,
          iconColor: ChatMockupTheme.infoBlue,
          title: item.title ?? 'Click here to edit',
          actionText: item.subtitle ?? 'Commission',
          titleChild: editingTitle
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Click here to edit',
                  textAlign: TextAlign.left,
                )
              : null,
          onTitleTap: editingTitle || !canStartFieldEdit
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.title,
                    initialValue: item.title ?? '',
                  ),
          actionTextChild: editingSubtitle
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Commission',
                  textAlign: TextAlign.center,
                )
              : null,
          onActionTextTap: editingSubtitle || !canStartFieldEdit
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.subtitle,
                    initialValue: item.subtitle ?? '',
                  ),
        );
    }

    if (waitLabel == null) {
      return content;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        _buildWaitHint(waitLabel),
      ],
    );
  }

  Future<void> _triggerSingleItemAction(String itemId) async {
    if (_editingItemId != null || _isPreviewing) return;
    final index = _items.indexWhere((element) => element.id == itemId);
    if (index < 0) return;
    final item = _items[index];
    setState(() {
      _selectedItemIds
        ..clear()
        ..add(item.id);
      _primarySelectedItemId = item.id;
    });
    if (item.type == ChatMockupItemType.replyOptions ||
        item.type == ChatMockupItemType.commission) {
      await _showCardFieldEditorPicker(item);
      return;
    }
    await _handleItemTap(item);
  }

  bool _canStartCardFieldEditing(String itemId) {
    return _editingItemId == itemId && _selectedItemIds.length == 1;
  }

  Future<void> _showCardFieldEditorPicker(ChatMockupItem item) async {
    final field = await showModalBottomSheet<ChatMockupEditableField>(
      context: context,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        final options = switch (item.type) {
          ChatMockupItemType.replyOptions =>
            <MapEntry<String, ChatMockupEditableField>>[
              const MapEntry('编辑第一个回复', ChatMockupEditableField.firstReply),
              const MapEntry('编辑第二个回复', ChatMockupEditableField.secondReply),
            ],
          ChatMockupItemType.commission =>
            <MapEntry<String, ChatMockupEditableField>>[
              const MapEntry('编辑标题', ChatMockupEditableField.title),
              const MapEntry('编辑副标题', ChatMockupEditableField.subtitle),
            ],
          _ => const <MapEntry<String, ChatMockupEditableField>>[],
        };
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (entry) => ListTile(
                    title: Text(entry.key,
                        style: const TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(ctx, entry.value),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (field == null) return;
    switch (field) {
      case ChatMockupEditableField.firstReply:
        _startEditing(item.id, field, initialValue: item.firstText ?? '');
        return;
      case ChatMockupEditableField.secondReply:
        _startEditing(item.id, field, initialValue: item.secondText ?? '');
        return;
      case ChatMockupEditableField.title:
        _startEditing(item.id, field, initialValue: item.title ?? '');
        return;
      case ChatMockupEditableField.subtitle:
        _startEditing(item.id, field, initialValue: item.subtitle ?? '');
        return;
      case ChatMockupEditableField.text:
        _startEditing(item.id, field, initialValue: item.text ?? '');
        return;
    }
  }

  Widget _buildWaitHint(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _handleItemTap(ChatMockupItem item) async {
    if (_selectedItemIds.length != 1) return;
    if (_editingItemId != null &&
        (_editingItemId != item.id ||
            _editingField != ChatMockupEditableField.text)) {
      return;
    }
    switch (item.type) {
      case ChatMockupItemType.message:
      case ChatMockupItemType.action:
        _startEditing(item.id, ChatMockupEditableField.text,
            initialValue: item.text ?? '');
        return;
      case ChatMockupItemType.emoji:
        await _showEmojiPicker(item);
        return;
      case ChatMockupItemType.sticker:
        await _showStickerPicker(item.id);
        return;
      case ChatMockupItemType.customImage:
        await _pickImageForItem(item.id);
        return;
      case ChatMockupItemType.replyOptions:
      case ChatMockupItemType.commission:
        return;
    }
  }

  void _startEditing(
    String itemId,
    ChatMockupEditableField field, {
    required String initialValue,
  }) {
    final isEditingSameField =
        _editingItemId == itemId && _editingField == field;
    if (isEditingSameField) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _editingFocusNode.requestFocus();
      });
      return;
    }
    if (_editingItemId != null &&
        (_editingItemId != itemId || _editingField != field)) {
      return;
    }
    _editingController.text = initialValue;
    setState(() {
      _editingItemId = itemId;
      _editingField = field;
      _selectedItemIds
        ..clear()
        ..add(itemId);
      _primarySelectedItemId = itemId;
    });
    final end = _editingController.text.length;
    _editingController.selection = TextSelection.collapsed(offset: end);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editingFocusNode.requestFocus();
    });
  }

  void _commitEditing() {
    if (_isCommittingEditing) return;
    final itemId = _editingItemId;
    final field = _editingField;
    if (itemId == null || field == null) return;
    _isCommittingEditing = true;
    try {
      final index = _items.indexWhere((element) => element.id == itemId);
      final input = _editingController.text.trim();
      final updated = index >= 0 ? _items[index] : null;
      if (index >= 0 && updated != null) {
        final nextItem = switch (field) {
          ChatMockupEditableField.text =>
            updated.copyWith(text: input.isEmpty ? null : input),
          ChatMockupEditableField.title =>
            updated.copyWith(title: input.isEmpty ? null : input),
          ChatMockupEditableField.subtitle =>
            updated.copyWith(subtitle: input.isEmpty ? null : input),
          ChatMockupEditableField.firstReply =>
            updated.copyWith(firstText: input.isEmpty ? null : input),
          ChatMockupEditableField.secondReply =>
            updated.copyWith(secondText: input.isEmpty ? null : input),
        };
        setState(() {
          _items[index] = nextItem;
          _editingItemId = null;
          _editingField = null;
          _markUnexportedChanges();
        });
      } else {
        setState(() {
          _editingItemId = null;
          _editingField = null;
        });
      }
    } finally {
      _editingFocusNode.unfocus();
      _isCommittingEditing = false;
    }
  }

  Widget _buildEditingTextField({
    required TextStyle style,
    required String hintText,
    required TextAlign textAlign,
    Color cursorColor = const Color(0xff111111),
  }) {
    final hintColor = style.color?.withValues(alpha: 0.55);
    return TextField(
      controller: _editingController,
      focusNode: _editingFocusNode,
      textAlign: textAlign,
      style: style,
      cursorColor: cursorColor,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hintText,
        hintStyle: hintColor == null ? null : style.copyWith(color: hintColor),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Future<void> _showEmojiPicker(ChatMockupItem item) async {
    if (_editingItemId != null) return;
    const emojis = <String>[
      '🙂',
      '😂',
      '😭',
      '😍',
      '😎',
      '😡',
      '🤔',
      '👍',
      '👎',
      '❤️',
      '🔥',
      '🎉'
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: emojis.map((emoji) {
                  return SizedBox(
                    width: 48,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, emoji),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    final index = _items.indexWhere((element) => element.id == item.id);
    if (index < 0) return;
    setState(() {
      _items[index] = _items[index].copyWith(emoji: selected);
      _markUnexportedChanges();
    });
  }

  Future<List<ChatMockupImageSource>> _loadSystemStickerSources() async {
    const zzzWebpPath = _stickerPath;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final stickerPngPaths = manifest
          .listAssets()
          .where(
            (k) =>
                k.startsWith('assets/images/ZZZ-2.1-flat/') &&
                k.toLowerCase().endsWith('.png'),
          )
          .toList()
        ..sort();
      final orderedPaths = <String>[zzzWebpPath];
      for (final path in stickerPngPaths) {
        if (path == zzzWebpPath) continue;
        orderedPaths.add(path);
      }
      return orderedPaths
          .map((path) => ChatMockupImageSource(
              type: ChatMockupImageSourceType.asset, value: path))
          .toList();
    } catch (_) {
      return const [_defaultStickerSource];
    }
  }

  Future<void> _showStickerPicker(String itemId) async {
    if (_editingItemId != null) return;
    final loadFuture = _loadSystemStickerSources();
    final selected = await showModalBottomSheet<ChatMockupImageSource>(
      context: context,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.65;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: height,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择贴纸',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<ChatMockupImageSource>>(
                    future: loadFuture,
                    builder: (ctx, snapshot) {
                      final stickers =
                          snapshot.data ?? const [_defaultStickerSource];
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: stickers.map((sticker) {
                          return SizedBox(
                            width: 72,
                            height: 72,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(ctx, sticker),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image(
                                  image: _resolveImageProvider(sticker),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _pickImageForItem(itemId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2a2a2a),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('上传本地图片'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    final index = _items.indexWhere((element) => element.id == itemId);
    if (index < 0) return;
    setState(() {
      _items[index] =
          _items[index].copyWith(imageSource: selected, image: null);
      _markUnexportedChanges();
    });
  }

  Future<void> _pickImageForItem(String itemId) async {
    if (_editingItemId != null) return;
    final file = await openFile(
        acceptedTypeGroups: const [_imageTypeGroup],
        confirmButtonText: 'Select');
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final mimeType = _guessMimeType(file.name);
    if (mimeType == null) return;
    ChatMockupImageSource source;
    try {
      source = ChatMockupImageSource.memory(bytes: bytes, mimeType: mimeType);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片无效: $error')),
      );
      return;
    }
    final index = _items.indexWhere((element) => element.id == itemId);
    if (index < 0) return;
    setState(() {
      _items[index] = _items[index].copyWith(imageSource: source, image: null);
      _markUnexportedChanges();
    });
  }

  Widget _buildSelectionControls(ChatMockupItem item, int index) {
    final enabled = _items.length > 1;
    final isEditingThisItem = _editingItemId == item.id;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xff181818),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildDragHandle(index, enabled: enabled),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _showItemSettings(item.id),
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
          ),
          IconButton(
            onPressed: () => _triggerSingleItemAction(item.id),
            icon: const Icon(Icons.edit_rounded, color: Colors.white70),
          ),
          IconButton(
            onPressed: () => _removeItem(item.id),
            icon:
                const Icon(Icons.delete_outline_rounded, color: Colors.white70),
          ),
          if (isEditingThisItem)
            IconButton(
              onPressed: _commitEditing,
              icon: const Icon(Icons.check_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildBatchSelectionControls(ChatMockupItem item, int index) {
    final enabled = _items.length > 1;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xff181818),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildDragHandle(index, enabled: enabled),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _showItemSettings(item.id),
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
          ),
          IconButton(
            onPressed: () => _removeItem(item.id),
            icon:
                const Icon(Icons.delete_outline_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle(int index, {required bool enabled}) {
    final handle = Semantics(
      button: true,
      label: '按住拖动排序',
      child: Opacity(
        opacity: enabled ? 1.0 : 0.38,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xff2a2a2a),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child:
              const Icon(Icons.drag_indicator_rounded, color: Colors.white70),
        ),
      ),
    );
    final decorated = MouseRegion(
      cursor: enabled ? SystemMouseCursors.grab : SystemMouseCursors.basic,
      child: enabled ? Tooltip(message: '按住拖动排序', child: handle) : handle,
    );
    return ReorderableDragStartListener(
        index: index, enabled: enabled, child: decorated);
  }

  ChatMockupItem _createItem({
    required ChatMockupItemType type,
    required ChatMockupItemSide side,
    String? text,
    String? emoji,
    ImageProvider? image,
    ChatMockupImageSource? imageSource,
    ChatMockupImageSource? avatarSource,
    ChatMockupWaitMode waitMode = ChatMockupWaitMode.auto,
    double waitSeconds = 0,
  }) {
    return ChatMockupItem(
      id: 'item_${_nextId++}',
      type: type,
      side: side,
      text: text,
      emoji: emoji,
      image: image,
      imageSource: imageSource,
      avatarSource: avatarSource,
      waitMode: waitMode,
      waitSeconds: waitSeconds,
    );
  }

  ChatMockupItemSide _defaultSideForType(ChatMockupItemType type) {
    switch (type) {
      case ChatMockupItemType.action:
        return ChatMockupItemSide.center;
      case ChatMockupItemType.replyOptions:
      case ChatMockupItemType.commission:
        return ChatMockupItemSide.right;
      case ChatMockupItemType.message:
      case ChatMockupItemType.emoji:
      case ChatMockupItemType.sticker:
      case ChatMockupItemType.customImage:
        return ChatMockupItemSide.left;
    }
  }

  Set<ChatMockupItemSide> _allowedSidesForType(ChatMockupItemType type) {
    switch (type) {
      case ChatMockupItemType.message:
      case ChatMockupItemType.emoji:
      case ChatMockupItemType.sticker:
      case ChatMockupItemType.customImage:
        return {ChatMockupItemSide.left, ChatMockupItemSide.right};
      case ChatMockupItemType.replyOptions:
      case ChatMockupItemType.commission:
        return {ChatMockupItemSide.right};
      case ChatMockupItemType.action:
        return {ChatMockupItemSide.center};
    }
  }

  void _addItem(ChatMockupItemType type, {ChatMockupItemSide? side}) {
    if (_editingItemId != null || _isReadOnlyCanvas) return;
    final allowed = _allowedSidesForType(type);
    final chosenSide = side ?? _defaultSideForType(type);
    if (!allowed.contains(chosenSide)) return;
    final item = _createItem(type: type, side: chosenSide);
    setState(() {
      _items.add(item);
      _newlyAddedItemIds.add(item.id);
      _selectedItemIds
        ..clear()
        ..add(item.id);
      _primarySelectedItemId = item.id;
      _pendingAddType = null;
      _visibleItemCount = _items.length;
      _markUnexportedChanges();
    });
    _scrollToLatestIfFollowing();
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (_isReadOnlyCanvas) return;
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    final dragged = _items[oldIndex];
    final selectedDragged = _selectedItemIds.contains(dragged.id);
    if (!selectedDragged || _selectedItemIds.length <= 1) {
      var adjustedIndex = newIndex;
      if (oldIndex < adjustedIndex) adjustedIndex -= 1;
      adjustedIndex = adjustedIndex.clamp(0, _items.length - 1);
      if (oldIndex == adjustedIndex) return;
      setState(() {
        final item = _items.removeAt(oldIndex);
        _items.insert(adjustedIndex, item);
        _markUnexportedChanges();
      });
      return;
    }
    final selectedIndexes = <int>[];
    for (var i = 0; i < _items.length; i++) {
      if (_selectedItemIds.contains(_items[i].id)) selectedIndexes.add(i);
    }
    if (selectedIndexes.length <= 1) return;
    setState(() {
      final selectedItems = selectedIndexes.map((i) => _items[i]).toList();
      var insertIndex = newIndex;
      for (final i in selectedIndexes) {
        if (i < newIndex) {
          insertIndex -= 1;
        }
      }
      _items.removeWhere((element) => _selectedItemIds.contains(element.id));
      insertIndex = insertIndex.clamp(0, _items.length);
      _items.insertAll(insertIndex, selectedItems);
      _primarySelectedItemId = dragged.id;
      _markUnexportedChanges();
    });
  }

  void _removeItem(String id) {
    if (_isReadOnlyCanvas) return;
    final targets =
        _selectedItemIds.contains(id) ? _selectedItemIds.toSet() : <String>{id};
    setState(() {
      _items.removeWhere((item) => targets.contains(item.id));
      _newlyAddedItemIds.removeWhere(targets.contains);
      _selectedItemIds.removeWhere(targets.contains);
      if (_primarySelectedItemId != null &&
          targets.contains(_primarySelectedItemId)) {
        _primarySelectedItemId = null;
      }
      if (_editingItemId != null && targets.contains(_editingItemId)) {
        _editingItemId = null;
        _editingField = null;
      }
      _visibleItemCount = _items.length;
      _markUnexportedChanges();
    });
  }

  void _onItemTap(ChatMockupItem item) {
    if (_isPreviewing || _editingItemId != null || _isReadOnlyCanvas) return;
    setState(() {
      if (_selectedItemIds.contains(item.id)) {
        _selectedItemIds.remove(item.id);
        if (_primarySelectedItemId == item.id) {
          _primarySelectedItemId =
              _selectedItemIds.isEmpty ? null : _selectedItemIds.last;
        }
      } else {
        _selectedItemIds.add(item.id);
        _primarySelectedItemId = item.id;
      }
    });
  }

  List<ChatMockupItem> _visibleItems() {
    if (!_isPreviewing) return _items;
    final safeCount = _visibleItemCount.clamp(0, _items.length);
    return _items.take(safeCount).toList();
  }

  void _startPreview() {
    if (_items.isEmpty) return;
    _playbackTimer?.cancel();
    setState(() {
      _previewRunId += 1;
      _isPreviewing = true;
      _visibleItemCount = 1;
      _isWaitingManual = false;
      _isPlaybackComplete = false;
    });
    _setFollowingLatest(true);
    _scrollToLatest(animated: false);
    _queueNextPreviewStep();
  }

  void _stopPreview() {
    _playbackTimer?.cancel();
    setState(() {
      _isPreviewing = false;
      _visibleItemCount = _items.length;
      _isWaitingManual = false;
      _isPlaybackComplete = true;
    });
    _scrollToLatestIfFollowing();
  }

  void _continuePreviewManually() {
    if (!_isPreviewing || !_isWaitingManual) return;
    setState(() {
      _isWaitingManual = false;
      _visibleItemCount += 1;
    });
    _scrollToLatestIfFollowing();
    _queueNextPreviewStep();
  }

  void _queueNextPreviewStep() {
    _playbackTimer?.cancel();
    if (!_isPreviewing) return;
    if (_visibleItemCount >= _items.length) {
      _finishPlayback();
      return;
    }
    final current = _items[_visibleItemCount - 1];
    if (current.waitMode == ChatMockupWaitMode.manual && !_isBrowseMode) {
      setState(() => _isWaitingManual = true);
      return;
    }
    final waitSeconds = current.waitMode == ChatMockupWaitMode.manual
        ? 0.8
        : current.waitSeconds;
    final milliseconds = (waitSeconds * 1000).round();
    _playbackTimer = Timer(Duration(milliseconds: milliseconds), () {
      if (!mounted || !_isPreviewing) return;
      final nextCount = _visibleItemCount + 1;
      setState(() => _visibleItemCount = nextCount);
      _scrollToLatestIfFollowing();
      if (nextCount >= _items.length) {
        _finishPlayback();
        return;
      }
      _queueNextPreviewStep();
    });
  }

  void _finishPlayback() {
    if (!mounted) return;
    setState(() {
      _isPreviewing = false;
      _isWaitingManual = false;
      _visibleItemCount = _items.length;
      _isPlaybackComplete = true;
      if (widget.lockAiMode) {
        _aiMode = ChatMockupAiMode.role;
      }
    });
    widget.onPlaybackCompleted?.call();
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= _bottomFollowTolerance;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final isUserDriven = (notification is ScrollUpdateNotification &&
            notification.dragDetails != null) ||
        (notification is OverscrollNotification &&
            notification.dragDetails != null) ||
        notification is UserScrollNotification;

    final isNearBottom = _isNearBottom();
    if (isNearBottom) {
      _setFollowingLatest(true);
      return false;
    }

    if (isUserDriven) {
      _followLatestScrollToken += 1;
      _setFollowingLatest(false);
    }
    return false;
  }

  void _setFollowingLatest(bool value) {
    final shouldShowButton = !value;
    if (_isFollowingLatest == value &&
        _showJumpToLatestButton == shouldShowButton) {
      return;
    }
    setState(() {
      _isFollowingLatest = value;
      _showJumpToLatestButton = shouldShowButton;
    });
  }

  void _scrollToLatestIfFollowing() {
    if (!_isFollowingLatest) return;
    _scrollToLatest(animated: true);
  }

  void _scrollToLatest({required bool animated}) {
    _followLatestScrollToken += 1;
    final token = _followLatestScrollToken;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || token != _followLatestScrollToken) return;
      if (!_scrollController.hasClients) return;

      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }

      if (!mounted || token != _followLatestScrollToken) return;
      if (!_isNearBottom()) return;
      _setFollowingLatest(true);
    });
  }

  Widget _buildJumpToLatestButton() {
    return FloatingActionButton.small(
      heroTag: 'chat_mockup_jump_to_latest',
      tooltip: '向下',
      onPressed: () {
        _setFollowingLatest(true);
        _scrollToLatest(animated: true);
      },
      child: const Icon(Icons.keyboard_arrow_down),
    );
  }

  ChatMockupImageSource _defaultAvatarForSide(ChatMockupItemSide side) {
    switch (side) {
      case ChatMockupItemSide.left:
        return _leftAvatarSource;
      case ChatMockupItemSide.right:
        return _rightAvatarSource;
      case ChatMockupItemSide.center:
        return _leftAvatarSource;
    }
  }

  ImageProvider _resolveImageProvider(ChatMockupImageSource source) {
    return source.toImageProvider();
  }

  String? _guessMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return null;
  }

  Iterable<String> _resolveScopeIds(_ChatMockupSettingTargetScope scope) {
    switch (scope) {
      case _ChatMockupSettingTargetScope.selected:
      case _ChatMockupSettingTargetScope.selectedMultiple:
        return _selectedItemIds;
      case _ChatMockupSettingTargetScope.allLeft:
        return _items
            .where((item) => item.side == ChatMockupItemSide.left)
            .map((item) => item.id);
      case _ChatMockupSettingTargetScope.allRight:
        return _items
            .where((item) => item.side == ChatMockupItemSide.right)
            .map((item) => item.id);
    }
  }

  void _applyAvatarSource(
      ChatMockupImageSource source, _ChatMockupSettingTargetScope scope) {
    final ids = _resolveScopeIds(scope).toSet();
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (!ids.contains(item.id) || item.side == ChatMockupItemSide.center) {
          continue;
        }
        _items[i] = item.copyWith(avatarSource: source);
      }
      _markUnexportedChanges();
    });
  }

  void _applyWaitSetting(
    ChatMockupWaitMode mode,
    double seconds,
    _ChatMockupSettingTargetScope scope,
  ) {
    final ids = _resolveScopeIds(scope).toSet();
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        if (!ids.contains(_items[i].id)) {
          continue;
        }
        _items[i] = _items[i].copyWith(
          waitMode: mode,
          waitSeconds: mode == ChatMockupWaitMode.auto ? seconds : 0,
        );
      }
      _markUnexportedChanges();
    });
  }

  Future<void> _showItemSettings(String itemId) async {
    if (_selectedItemIds.isEmpty) {
      setState(() {
        _selectedItemIds.add(itemId);
        _primarySelectedItemId = itemId;
      });
    }
    final baseId = _primarySelectedItemId ?? itemId;
    final baseIndex = _items.indexWhere((element) => element.id == baseId);
    final baseItem = baseIndex >= 0 ? _items[baseIndex] : null;
    final selectedCount = _selectedItemIds.length;
    ChatMockupWaitMode mode = baseItem?.waitMode ?? ChatMockupWaitMode.auto;
    double seconds = baseItem?.waitSeconds ?? 1.0;
    if (seconds <= 0) {
      seconds = 1.0;
    }
    _ChatMockupSettingTargetScope scope = selectedCount <= 1
        ? _ChatMockupSettingTargetScope.selected
        : _ChatMockupSettingTargetScope.selectedMultiple;
    final scopeItems = <DropdownMenuItem<_ChatMockupSettingTargetScope>>[
      if (selectedCount <= 1)
        const DropdownMenuItem(
          value: _ChatMockupSettingTargetScope.selected,
          child: Text('当前选中项'),
        ),
      if (selectedCount > 1)
        DropdownMenuItem(
          value: _ChatMockupSettingTargetScope.selectedMultiple,
          child: Text('已选中的 $selectedCount 项'),
        ),
      const DropdownMenuItem(
        value: _ChatMockupSettingTargetScope.allLeft,
        child: Text('全部左侧'),
      ),
      const DropdownMenuItem(
        value: _ChatMockupSettingTargetScope.allRight,
        child: Text('全部右侧'),
      ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  12, 12, 12, 12 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '设置',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<_ChatMockupSettingTargetScope>(
                    value: scope,
                    dropdownColor: const Color(0xff262626),
                    items: scopeItems,
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => scope = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final source = await _pickStickerSource();
                          if (source == null || !mounted) return;
                          _applyAvatarSource(source, scope);
                        },
                        child: const Text('使用贴纸作为头像'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final source = await _pickLocalImageSource();
                          if (source == null || !mounted) return;
                          _applyAvatarSource(source, scope);
                        },
                        child: const Text('上传本地头像'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('自动等待'),
                        selected: mode == ChatMockupWaitMode.auto,
                        onSelected: (_) =>
                            setSheetState(() => mode = ChatMockupWaitMode.auto),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('手动点击显示下一个'),
                        selected: mode == ChatMockupWaitMode.manual,
                        onSelected: (_) => setSheetState(
                            () => mode = ChatMockupWaitMode.manual),
                      ),
                    ],
                  ),
                  if (mode == ChatMockupWaitMode.auto) ...[
                    const SizedBox(height: 10),
                    Slider(
                      max: 10,
                      divisions: 100,
                      value: seconds,
                      label: seconds.toStringAsFixed(1),
                      onChanged: (value) =>
                          setSheetState(() => seconds = value),
                    ),
                    Text(
                      '等待 ${seconds.toStringAsFixed(1)}s',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _applyWaitSetting(
                      mode,
                      mode == ChatMockupWaitMode.auto ? seconds : 0,
                      scope,
                    ),
                    child: const Text('应用等待设置'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<ChatMockupImageSource?> _pickStickerSource() async {
    final stickers = await _loadSystemStickerSources();
    if (!mounted) return null;
    return showModalBottomSheet<ChatMockupImageSource>(
      context: context,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stickers.map((source) {
              return InkWell(
                onTap: () => Navigator.pop(ctx, source),
                child: Image(
                  image: _resolveImageProvider(source),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<ChatMockupImageSource?> _pickLocalImageSource() async {
    final file = await openFile(
        acceptedTypeGroups: const [_imageTypeGroup],
        confirmButtonText: 'Select');
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final mimeType = _guessMimeType(file.name);
    if (mimeType == null) return null;
    try {
      return ChatMockupImageSource.memory(bytes: bytes, mimeType: mimeType);
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片无效: $error')),
      );
      return null;
    }
  }

  Future<bool> exportJson() async {
    if (!_isDraftLoaded) {
      return false;
    }
    final payload = _buildJsonPayload(includeDraftMetadata: false);
    final jsonText = _encodeJsonPayload(payload);
    final location = await getSaveLocation(
      acceptedTypeGroups: const [_jsonTypeGroup],
      suggestedName: 'chat_mockup.json',
      confirmButtonText: '导出',
    );
    if (location == null) return false;
    final file = XFile.fromData(
      utf8.encode(jsonText),
      mimeType: 'application/json',
      name: 'chat_mockup.json',
    );
    await file.saveTo(location.path);
    if (!mounted) return false;
    setState(() {
      _lastExportedSnapshot =
          _encodeJsonPayload(_buildJsonPayload(includeDraftMetadata: false));
      _hasUnexportedChanges = false;
    });
    if (!mounted) return false;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已导出 JSON')));
    return true;
  }

  Future<void> importJson() async {
    try {
      final file = await openFile(
          acceptedTypeGroups: const [_jsonTypeGroup], confirmButtonText: '导入');
      if (file == null) return;
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid JSON root.');
      }
      await _restoreFromJsonPayload(decoded, preserveDraftMetadata: false);
      if (!mounted) return;
      setState(() {
        _lastExportedSnapshot =
            _encodeJsonPayload(_buildJsonPayload(includeDraftMetadata: false));
        _hasUnexportedChanges = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('导入成功')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导入失败: $error')));
    }
  }

  Map<String, dynamic> _itemToJson(ChatMockupItem item) {
    return {
      'id': item.id,
      'type': item.type.name,
      'side': item.side.name,
      'text': item.text,
      'emoji': item.emoji,
      'image': item.imageSource?.toJson(),
      'avatar': item.avatarSource?.toJson(),
      'title': item.title,
      'subtitle': item.subtitle,
      'firstText': item.firstText,
      'secondText': item.secondText,
      'wait': {'mode': item.waitMode.name, 'seconds': item.waitSeconds},
    };
  }

  void _markUnexportedChanges() {
    _hasUnexportedChanges = hasUnexportedChanges;
  }

  Map<String, dynamic> _buildJsonPayload({required bool includeDraftMetadata}) {
    final payload = <String, dynamic>{
      'version': 1,
      'items': _items.map(_itemToJson).toList(),
    };
    if (includeDraftMetadata) {
      payload['lastExportedSnapshot'] = _lastExportedSnapshot;
      payload['hasUnexportedChanges'] = _hasUnexportedChanges;
    }
    return payload;
  }

  String _encodeJsonPayload(Map<String, dynamic> payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String _currentExportSnapshot() {
    return _encodeJsonPayload(_buildJsonPayload(includeDraftMetadata: false));
  }

  Future<void> _initializeDraft() async {
    if (_isBrowseMode) {
      try {
        final payload = widget.initialPayload;
        if (payload != null) {
          final chatMockup = payload['chatMockup'];
          if (chatMockup is Map<String, dynamic>) {
            await _restoreFromJsonPayload(chatMockup,
                preserveDraftMetadata: false);
          } else {
            final defaults = _initialItems();
            setState(() {
              _items
                ..clear()
                ..addAll(defaults);
              _nextId = _computeNextId(defaults);
              _visibleItemCount = defaults.length;
            });
          }
          final ai = payload['ai'];
          if (ai is Map<String, dynamic>) {
            _videoRolePrompt =
                ai['rolePrompt'] is String ? ai['rolePrompt'] as String : '';
            _videoUserPrompt =
                ai['userPrompt'] is String ? ai['userPrompt'] as String : '';
            _aiSettings = _aiSettings.copyWith(
              rolePrompt: _videoRolePrompt,
              userPrompt: _videoUserPrompt,
            );
          }
        } else {
          final defaults = _initialItems();
          setState(() {
            _items
              ..clear()
              ..addAll(defaults);
            _nextId = _computeNextId(defaults);
            _visibleItemCount = defaults.length;
          });
        }
        if (!mounted) return;
        setState(() {
          _isDraftLoaded = true;
          _isPlaybackComplete = false;
          _loadError = null;
          if (widget.lockAiMode) {
            _aiMode = ChatMockupAiMode.role;
          }
        });
        _setFollowingLatest(true);
        _scrollToLatest(animated: false);
        widget.onDraftLoadedChanged?.call(true);
        if (widget.autoStartPlayback) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _items.isEmpty || _loadError != null) return;
            _startPreview();
          });
        }
        return;
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _isDraftLoaded = true;
          _isPlaybackComplete = false;
          _loadError = '$error';
        });
        widget.onDraftLoadedChanged?.call(true);
        return;
      }
    }
    final restored = await loadDraftCache();
    if (!mounted) return;
    if (!restored) {
      final defaults = _initialItems();
      setState(() {
        _items
          ..clear()
          ..addAll(defaults);
        _newlyAddedItemIds.clear();
        _nextId = _computeNextId(defaults);
        _selectedItemIds.clear();
        _primarySelectedItemId = null;
        _editingItemId = null;
        _editingField = null;
        _isPreviewing = false;
        _visibleItemCount = defaults.length;
        _isWaitingManual = false;
        _lastExportedSnapshot = _currentExportSnapshot();
        _hasUnexportedChanges = false;
        _isDraftLoaded = true;
      });
      _setFollowingLatest(true);
      _scrollToLatest(animated: false);
      widget.onDraftLoadedChanged?.call(true);
      return;
    }
    setState(() {
      _visibleItemCount = _items.length;
      _isDraftLoaded = true;
      _hasUnexportedChanges = hasUnexportedChanges;
    });
    _setFollowingLatest(true);
    _scrollToLatest(animated: false);
    widget.onDraftLoadedChanged?.call(true);
  }

  Future<void> _restoreFromJsonPayload(
    Map<String, dynamic> payload, {
    required bool preserveDraftMetadata,
  }) async {
    final version = payload['version'];
    final itemsJson = payload['items'];
    if (version != 1 || itemsJson is! List) {
      throw const FormatException('Unsupported JSON format.');
    }
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final availableAssets = manifest.listAssets().toSet();
    final imported = <ChatMockupItem>[];
    for (final item in itemsJson) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid item entry.');
      }
      imported.add(_itemFromJson(item, availableAssets: availableAssets));
    }
    final normalizedImported = _normalizeImportedItemIds(imported);
    _playbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(normalizedImported);
      _newlyAddedItemIds.clear();
      _nextId = _computeNextId(normalizedImported);
      _selectedItemIds.clear();
      _primarySelectedItemId = null;
      _editingItemId = null;
      _editingField = null;
      _isPreviewing = false;
      _visibleItemCount = normalizedImported.length;
      _isWaitingManual = false;
      if (preserveDraftMetadata) {
        final cachedSnapshot = payload['lastExportedSnapshot'];
        final cachedHasUnexportedChanges =
            payload['hasUnexportedChanges'] == true;
        if (cachedSnapshot is String && cachedSnapshot.isNotEmpty) {
          _lastExportedSnapshot = cachedSnapshot;
          _hasUnexportedChanges =
              _currentExportSnapshot() != _lastExportedSnapshot;
        } else {
          if (cachedHasUnexportedChanges) {
            _lastExportedSnapshot = null;
            _hasUnexportedChanges = true;
          } else {
            _lastExportedSnapshot = _currentExportSnapshot();
            _hasUnexportedChanges = false;
          }
        }
      }
    });
  }

  Future<bool> loadDraftCache() async {
    final cached = box.read(_draftCacheKey);
    if (cached is! String || cached.isEmpty) return false;
    try {
      final decoded = jsonDecode(cached);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid cache root.');
      }
      await _restoreFromJsonPayload(decoded, preserveDraftMetadata: true);
      return true;
    } catch (_) {
      await clearInvalidDraftCache();
      return false;
    }
  }

  Future<void> saveDraftCache() async {
    if (!_isDraftLoaded || _isBrowseMode) {
      return;
    }
    final payload = _buildJsonPayload(includeDraftMetadata: true);
    final encoded = _encodeJsonPayload(payload);
    await box.write(_draftCacheKey, encoded);
  }

  Future<void> clearInvalidDraftCache() async {
    await box.remove(_draftCacheKey);
  }

  ChatMockupItem _itemFromJson(
    Map<String, dynamic> json, {
    required Set<String> availableAssets,
  }) {
    final typeName = json['type'];
    final sideName = json['side'];
    if (typeName is! String || sideName is! String) {
      throw const FormatException('Missing type/side.');
    }
    final type = ChatMockupItemType.values.firstWhere(
      (element) => element.name == typeName,
      orElse: () => throw const FormatException('Unsupported item type.'),
    );
    final side = ChatMockupItemSide.values.firstWhere(
      (element) => element.name == sideName,
      orElse: () => throw const FormatException('Unsupported item side.'),
    );
    if (!_allowedSidesForType(type).contains(side)) {
      throw const FormatException('Type/side mismatch.');
    }
    final wait = json['wait'];
    ChatMockupWaitMode waitMode = ChatMockupWaitMode.auto;
    double waitSeconds = 0;
    if (wait is Map<String, dynamic>) {
      final mode = wait['mode'];
      final seconds = wait['seconds'];
      if (mode is String) {
        waitMode = ChatMockupWaitMode.values.firstWhere(
          (element) => element.name == mode,
          orElse: () => throw const FormatException('Unsupported wait mode.'),
        );
      }
      if (seconds is num) {
        waitSeconds = seconds.toDouble().clamp(0, 10).toDouble();
      }
    }
    final imageSource = json['image'] is Map<String, dynamic>
        ? ChatMockupImageSource.fromJson(json['image'] as Map<String, dynamic>)
        : null;
    final avatarSource = json['avatar'] is Map<String, dynamic>
        ? ChatMockupImageSource.fromJson(json['avatar'] as Map<String, dynamic>)
        : null;
    _validateAssetSource(imageSource, availableAssets);
    _validateAssetSource(avatarSource, availableAssets);
    return ChatMockupItem(
      id: (json['id'] as String?) ?? 'item_${_nextId++}',
      type: type,
      side: side,
      text: json['text'] as String?,
      emoji: json['emoji'] as String?,
      imageSource: imageSource,
      avatarSource: avatarSource,
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      firstText: json['firstText'] as String?,
      secondText: json['secondText'] as String?,
      waitMode: waitMode,
      waitSeconds: waitMode == ChatMockupWaitMode.auto ? waitSeconds : 0,
    );
  }

  void _validateAssetSource(
    ChatMockupImageSource? source,
    Set<String> availableAssets,
  ) {
    if (source == null || source.type != ChatMockupImageSourceType.asset) {
      return;
    }
    if (!availableAssets.contains(source.value)) {
      throw FormatException('Missing asset: ${source.value}');
    }
  }

  List<ChatMockupItem> _normalizeImportedItemIds(List<ChatMockupItem> items) {
    final normalized = <ChatMockupItem>[];
    final seen = <String>{};
    var nextId = _computeNextId(items);
    for (final item in items) {
      final id = item.id.trim();
      if (id.isNotEmpty && !seen.contains(id)) {
        seen.add(id);
        normalized.add(item.copyWith(id: id));
        continue;
      }
      var generated = 'item_$nextId';
      while (seen.contains(generated)) {
        nextId += 1;
        generated = 'item_$nextId';
      }
      seen.add(generated);
      normalized.add(item.copyWith(id: generated));
      nextId += 1;
    }
    return normalized;
  }

  int _computeNextId(List<ChatMockupItem> items) {
    var maxId = -1;
    for (final item in items) {
      if (!item.id.startsWith('item_')) continue;
      final parsed = int.tryParse(item.id.substring(5));
      if (parsed != null && parsed > maxId) maxId = parsed;
    }
    return maxId + 1;
  }

  ChatMockupMessageSide _toMessageSide(ChatMockupItemSide side) {
    switch (side) {
      case ChatMockupItemSide.left:
        return ChatMockupMessageSide.left;
      case ChatMockupItemSide.right:
        return ChatMockupMessageSide.right;
      case ChatMockupItemSide.center:
        return ChatMockupMessageSide.center;
    }
  }

  Future<bool> prepareVideoUpload() async {
    if (!_isDraftLoaded) return false;
    try {
      if (!_isAiInitialized) {
        await _aiInitCompleter.future.timeout(const Duration(seconds: 5));
      }
      final chatMockup = _buildJsonPayload(includeDraftMetadata: false);
      final payload = buildVideoUploadPayload(
        chatMockup: chatMockup,
        rolePrompt: _aiSettings.rolePrompt,
        userPrompt: _aiSettings.userPrompt,
      );
      final encodedResult = encodeVideoPayloadWithStats(payload);
      final wrapped = wrapEncodedPayload(encodedResult.encoded);
      await Clipboard.setData(ClipboardData(text: wrapped));
      if (!mounted) return false;
      final warning =
          encodedResult.base64Chars > 60000 ? '；数据仍较大，请减少本地图片或改用远程图片' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '影片数据已压缩并复制到剪贴板：原始 ${encodedResult.jsonChars} 字符，压缩后 ${encodedResult.base64Chars} 字符$warning',
          ),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('上传数据准备失败: $e')));
      return false;
    }
  }
}

class _ChatMockupItemEntrance extends StatefulWidget {
  const _ChatMockupItemEntrance({
    required this.child,
    required this.enabled,
    required this.animationKey,
    this.onCompleted,
  });

  final Widget child;
  final bool enabled;
  final String animationKey;
  final VoidCallback? onCompleted;

  @override
  State<_ChatMockupItemEntrance> createState() =>
      _ChatMockupItemEntranceState();
}

class _ChatMockupItemEntranceState extends State<_ChatMockupItemEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(curve);
    _fade = Tween<double>(begin: 0, end: 1).animate(curve);
    _runIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ChatMockupItemEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationKey != widget.animationKey ||
        (!oldWidget.enabled && widget.enabled)) {
      _runIfNeeded();
    }
  }

  void _runIfNeeded() {
    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }
    _controller
      ..value = 0
      ..forward().whenComplete(() {
        if (!mounted) return;
        widget.onCompleted?.call();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
