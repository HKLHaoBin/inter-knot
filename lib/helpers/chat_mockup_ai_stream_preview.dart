import 'dart:convert';

/// Logical channel for a parsed JSON string field in AI output.
enum ChatMockupAiFieldKind {
  action,
  user,
  character,
}

/// One successfully parsed `"key": "value"` occurrence in document order.
class ChatMockupAiFieldEvent {
  const ChatMockupAiFieldEvent({
    required this.kind,
    required this.rawValue,
  });

  final ChatMockupAiFieldKind kind;
  final String rawValue;
}

/// Helpers for AI reply text: bracket repair + strict parse for **finalize pass 2**,
/// [previewTextFromRaw] only, and ordered field scanning for streaming / finalize
/// pass 3. Live stream projection does **not** use [repairForProjection] or
/// [tryParseProjectedObject].
///
/// Field scanning walks the buffer once, in document order: at each position it
/// tries JSON-like `"key": "value"` first, then **loose** forms (`action:`, quoted
/// `'key':`, etc.) so strict and loose segments can **alternate** in one output.
/// [forStreamPreview] enables unterminated `"value"` prefixes for streaming UI.
class ChatMockupAiStreamPreview {
  ChatMockupAiStreamPreview._();

  /// Normalized text for UI preview only (same pipeline as [repairForProjection]).
  static String previewTextFromRaw(String rawBuffer) {
    return repairForProjection(rawBuffer);
  }

  /// Strip fences, take `{`… suffix; drop excess closers, trim structural trailing
  /// commas, then append missing closers so [tryParseProjectedObject] can succeed
  /// on **repaired** buffers (streaming finalize pass 2, not field scan).
  static String repairForProjection(String rawBuffer) {
    return _repairJsonTailForPreview(rawBuffer.trim());
  }

  /// [jsonDecode] of a string already passed through [repairForProjection]; used in
  /// finalize pass 2. Returns `null` on failure.
  static Map<String, dynamic>? tryParseProjectedObject(String repaired) {
    try {
      final decoded = jsonDecode(repaired);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Trim, strip Markdown ``` fences, then scan from first `{` (if any).
  static String preprocessForFieldScan(String raw) {
    var t = raw.trim();
    if (t.startsWith('```')) {
      final fenceIndex = t.indexOf('\n');
      if (fenceIndex >= 0) {
        t = t.substring(fenceIndex + 1);
      }
      if (t.endsWith('```')) {
        t = t.substring(0, t.length - 3);
      }
      t = t.trim();
    }
    final start = t.indexOf('{');
    if (start >= 0) {
      t = t.substring(start);
    }
    return t;
  }

  /// Ordered [ChatMockupAiFieldEvent] for director-style output (`user` included).
  ///
  /// [forStreamPreview]: when `true`, unterminated `"value"` fragments still emit a
  /// prefix (streaming UI); finalize paths should use default `false`.
  static List<ChatMockupAiFieldEvent> scanDirectorFields(
    String raw, {
    bool forStreamPreview = false,
  }) {
    final p = preprocessForFieldScan(raw);
    return _scanMergedStrictAndLoose(
      p,
      includeUser: true,
      allowUnclosedQuotedValueAsPrefix: forStreamPreview,
    );
  }

  /// Ordered events for role / continue modes (`user` / `用户` are recognized
  /// so stray keys do not shift parsing; canvas ignores them for placement).
  static List<ChatMockupAiFieldEvent> scanRoleOrContinueFields(
    String raw, {
    bool forStreamPreview = false,
  }) {
    final p = preprocessForFieldScan(raw);
    return _scanMergedStrictAndLoose(
      p,
      includeUser: false,
      allowUnclosedQuotedValueAsPrefix: forStreamPreview,
    );
  }

  /// Longer keys first so `"character"` does not lose to a shorter prefix.
  static const List<_KeySpec> _keySpecsDirector = [
    _KeySpec('character', ChatMockupAiFieldKind.character),
    _KeySpec('assistant', ChatMockupAiFieldKind.character),
    _KeySpec('action', ChatMockupAiFieldKind.action),
    _KeySpec('user', ChatMockupAiFieldKind.user),
    _KeySpec('用户', ChatMockupAiFieldKind.user),
    _KeySpec('left', ChatMockupAiFieldKind.character),
    _KeySpec('消息左', ChatMockupAiFieldKind.character),
    _KeySpec('动作', ChatMockupAiFieldKind.action),
  ];

  static const List<_KeySpec> _keySpecsRole = [
    _KeySpec('character', ChatMockupAiFieldKind.character),
    _KeySpec('assistant', ChatMockupAiFieldKind.character),
    _KeySpec('action', ChatMockupAiFieldKind.action),
    _KeySpec('user', ChatMockupAiFieldKind.user),
    _KeySpec('用户', ChatMockupAiFieldKind.user),
    _KeySpec('left', ChatMockupAiFieldKind.character),
    _KeySpec('消息左', ChatMockupAiFieldKind.character),
    _KeySpec('动作', ChatMockupAiFieldKind.action),
  ];

  /// One pass: outside JSON-ish strings, try strict `"key":"value"` then loose
  /// key forms at the same cursor so formats can mix in one buffer.
  static List<ChatMockupAiFieldEvent> _scanMergedStrictAndLoose(
    String s, {
    required bool includeUser,
    required bool allowUnclosedQuotedValueAsPrefix,
  }) {
    final specs = includeUser ? _keySpecsDirector : _keySpecsRole;
    final out = <ChatMockupAiFieldEvent>[];
    var i = 0;
    var inString = false;
    var escape = false;

    while (i < s.length) {
      final c = s.codeUnitAt(i);

      if (inString) {
        if (escape) {
          escape = false;
          i++;
          continue;
        }
        if (c == 92) {
          escape = true;
          i++;
          continue;
        }
        if (c == 34) {
          inString = false;
        }
        i++;
        continue;
      }

      final j = _skipWs(s, i);
      if (j > i) {
        i = j;
        continue;
      }

      if (s.codeUnitAt(i) == 34) {
        final strictRes = _tryStrictQuotedKeyValue(
          s,
          i,
          specs,
          allowUnclosedQuotedValueAsPrefix,
        );
        if (strictRes != null) {
          out.add(strictRes.$1);
          i = strictRes.$2;
          continue;
        }
        final looseAtQuote = _tryLooseKeyValueAt(
          s,
          i,
          specs,
          allowUnclosedQuotedValueAsPrefix,
        );
        if (looseAtQuote != null) {
          out.add(looseAtQuote.$1);
          i = looseAtQuote.$2;
          continue;
        }
        inString = true;
        i++;
        continue;
      }

      final looseRes = _tryLooseKeyValueAt(
        s,
        i,
        specs,
        allowUnclosedQuotedValueAsPrefix,
      );
      if (looseRes != null) {
        out.add(looseRes.$1);
        i = looseRes.$2;
        continue;
      }

      i++;
    }

    return out;
  }

  static (ChatMockupAiFieldEvent, int)? _tryStrictQuotedKeyValue(
    String s,
    int openQuote,
    List<_KeySpec> specs,
    bool allowUnclosedQuotedValueAsPrefix,
  ) {
    final match = _matchKeyAt(s, openQuote, specs);
    if (match == null) return null;
    final kind = match.kind;
    var j = match.indexAfterKeyQuote;
    j = _skipWs(s, j);
    if (j >= s.length || s.codeUnitAt(j) != 58) return null;
    j++;
    j = _skipWs(s, j);
    if (j >= s.length || s.codeUnitAt(j) != 34) return null;
    j++;
    final parsed = _parseJsonStringValue(
      s,
      j,
      allowUnclosedPrefix: allowUnclosedQuotedValueAsPrefix,
    );
    if (parsed == null) return null;
    return (
      ChatMockupAiFieldEvent(kind: kind, rawValue: parsed.$1),
      parsed.$2,
    );
  }

  static (ChatMockupAiFieldEvent, int)? _tryLooseKeyValueAt(
    String s,
    int i,
    List<_KeySpec> specs,
    bool allowUnclosedQuotedValueAsPrefix,
  ) {
    final m = _tryLooseMatchKey(s, i, specs);
    if (m == null) return null;
    final kind = m.$1;
    var j = _skipWs(s, m.$2);
    if (j >= s.length || s.codeUnitAt(j) != 58) return null;
    j++;
    j = _skipWs(s, j);
    final parsed = _parseLooseValue(
      s,
      j,
      allowUnclosedQuotedValueAsPrefix: allowUnclosedQuotedValueAsPrefix,
    );
    if (parsed == null) return null;
    return (
      ChatMockupAiFieldEvent(kind: kind, rawValue: parsed.$1),
      parsed.$2,
    );
  }

  /// Returns `(kind, indexAfterKeyToken)` where next non-ws should be `:`.
  static (ChatMockupAiFieldKind, int)? _tryLooseMatchKey(
    String s,
    int i,
    List<_KeySpec> specs,
  ) {
    for (final spec in specs) {
      final key = spec.key;
      final kind = spec.kind;

      if (s.codeUnitAt(i) == 39 &&
          i + 1 + key.length + 1 <= s.length &&
          s.startsWith(key, i + 1) &&
          s.codeUnitAt(i + 1 + key.length) == 39) {
        return (kind, i + 1 + key.length + 1);
      }

      if (s.codeUnitAt(i) == 34 &&
          i + 1 + key.length + 1 <= s.length &&
          s.startsWith(key, i + 1) &&
          s.codeUnitAt(i + 1 + key.length) == 34) {
        return (kind, i + 1 + key.length + 1);
      }

      if (i + key.length <= s.length &&
          s.startsWith(key, i) &&
          _looseKeyLeftBoundaryOk(s, i) &&
          _looseKeyRightBoundaryOk(s, i + key.length)) {
        return (kind, i + key.length);
      }
    }
    return null;
  }

  static bool _looseKeyLeftBoundaryOk(String s, int i) {
    if (i == 0) return true;
    return !_isAsciiIdUnit(s.codeUnitAt(i - 1));
  }

  static bool _looseKeyRightBoundaryOk(String s, int afterKey) {
    if (afterKey >= s.length) return false;
    final c = s.codeUnitAt(afterKey);
    return c == 58 || c == 32 || c == 9 || c == 10 || c == 13;
  }

  static bool _isAsciiIdUnit(int c) {
    return (c >= 0x41 && c <= 0x5a) ||
        (c >= 0x61 && c <= 0x7a) ||
        (c >= 0x30 && c <= 0x39) ||
        c == 0x5f;
  }

  static (String, int)? _parseLooseValue(
    String s,
    int start, {
    required bool allowUnclosedQuotedValueAsPrefix,
  }) {
    if (start >= s.length) return null;
    final c0 = s.codeUnitAt(start);
    if (c0 == 34) {
      return _parseJsonStringValue(
        s,
        start + 1,
        allowUnclosedPrefix: allowUnclosedQuotedValueAsPrefix,
      );
    }
    if (c0 == 39) {
      return _parseSingleQuotedStringValue(
        s,
        start + 1,
        allowUnclosedPrefix: allowUnclosedQuotedValueAsPrefix,
      );
    }
    return _parseBareLooseValue(s, start);
  }

  /// Single-quoted JSON-ish string; `\'` and `\\` supported.
  static (String, int)? _parseSingleQuotedStringValue(
    String s,
    int start, {
    required bool allowUnclosedPrefix,
  }) {
    final buf = StringBuffer();
    var i = start;
    var escape = false;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (escape) {
        if (c == 39) {
          buf.writeCharCode(39);
        } else if (c == 92) {
          buf.writeCharCode(92);
        } else {
          buf.writeCharCode(c);
        }
        escape = false;
        i++;
        continue;
      }
      if (c == 92) {
        escape = true;
        i++;
        continue;
      }
      if (c == 39) {
        return (buf.toString(), i + 1);
      }
      buf.writeCharCode(c);
      i++;
    }
    if (allowUnclosedPrefix) {
      return (buf.toString(), s.length);
    }
    return null;
  }

  /// Unquoted value until newline, `,`, `}`, or `]` (trimmed).
  static (String, int)? _parseBareLooseValue(String s, int start) {
    var i = start;
    final buf = StringBuffer();
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 10 || c == 13) {
        break;
      }
      if (c == 44 || c == 125 || c == 93) {
        break;
      }
      buf.writeCharCode(c);
      i++;
    }
    final text = buf.toString().trim();
    if (text.isEmpty) return null;
    return (text, i);
  }

  static _KeyMatch? _matchKeyAt(String s, int openQuote, List<_KeySpec> specs) {
    for (final spec in specs) {
      final key = spec.key;
      final need = 1 + key.length + 1;
      if (openQuote + need > s.length) continue;
      if (!s.startsWith(key, openQuote + 1)) continue;
      if (s.codeUnitAt(openQuote + 1 + key.length) != 34) continue;
      return _KeyMatch(spec.kind, openQuote + need);
    }
    return null;
  }

  static int _skipWs(String s, int from) {
    var pos = from;
    while (pos < s.length) {
      final u = s.codeUnitAt(pos);
      if (u == 32 || u == 9 || u == 10 || u == 13) {
        pos++;
      } else {
        break;
      }
    }
    return pos;
  }

  /// [start] = first code unit inside the string (after opening `"`).
  ///
  /// When [allowUnclosedPrefix] is `false` (finalize / strict scan), returns
  /// `null` if the closing `"` is missing. When `true` (streaming preview), returns
  /// the decoded prefix and [s.length] as end index so the UI can update before the
  /// value is complete.
  static (String, int)? _parseJsonStringValue(
    String s,
    int start, {
    bool allowUnclosedPrefix = false,
  }) {
    final buf = StringBuffer();
    var i = start;
    var escape = false;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (escape) {
        if (c == 34) {
          buf.writeCharCode(34);
        } else if (c == 92) {
          buf.writeCharCode(92);
        } else if (c == 47) {
          buf.writeCharCode(47);
        } else if (c == 98) {
          buf.writeCharCode(8);
        } else if (c == 102) {
          buf.writeCharCode(12);
        } else if (c == 110) {
          buf.writeCharCode(10);
        } else if (c == 114) {
          buf.writeCharCode(13);
        } else if (c == 116) {
          buf.writeCharCode(9);
        } else if (c == 117) {
          if (i + 4 >= s.length) {
            if (allowUnclosedPrefix) {
              return (buf.toString(), s.length);
            }
            return null;
          }
          final hex = s.substring(i + 1, i + 5);
          final code = int.tryParse(hex, radix: 16);
          if (code == null) {
            if (allowUnclosedPrefix) {
              return (buf.toString(), s.length);
            }
            return null;
          }
          buf.writeCharCode(code);
          i += 4;
        } else {
          buf.writeCharCode(c);
        }
        escape = false;
        i++;
        continue;
      }
      if (c == 92) {
        escape = true;
        i++;
        continue;
      }
      if (c == 34) {
        return (buf.toString(), i + 1);
      }
      buf.writeCharCode(c);
      i++;
    }
    if (allowUnclosedPrefix) {
      return (buf.toString(), s.length);
    }
    return null;
  }

  static String _repairJsonTailForPreview(String raw) {
    var t = raw;
    if (t.startsWith('```')) {
      final fenceEnd = t.indexOf('\n');
      if (fenceEnd >= 0) {
        t = t.substring(fenceEnd + 1);
      }
    }
    if (t.endsWith('```')) {
      t = t.substring(0, t.length - 3).trimRight();
    }
    final start = t.indexOf('{');
    if (start < 0) {
      return t.trim();
    }
    t = t.substring(start);
    return _normalizeBracketPreview(t);
  }

  /// Single pass: copy output, skip excess `}`/`]`, strip `,` before closes,
  /// append missing closers.
  static String _normalizeBracketPreview(String insideFromBrace) {
    final stack = <int>[];
    final out = <int>[];
    var inString = false;
    var escape = false;

    void stripStructuralTrailingCommaWs() {
      while (out.isNotEmpty) {
        final c = out.last;
        if (c == 32 || c == 9 || c == 10 || c == 13) {
          out.removeLast();
        } else if (c == 44) {
          out.removeLast();
          while (out.isNotEmpty) {
            final c2 = out.last;
            if (c2 == 32 || c2 == 9 || c2 == 10 || c2 == 13) {
              out.removeLast();
            } else {
              break;
            }
          }
          break;
        } else {
          break;
        }
      }
    }

    for (var i = 0; i < insideFromBrace.length; i++) {
      final c = insideFromBrace.codeUnitAt(i);
      if (escape) {
        out.add(c);
        escape = false;
        continue;
      }
      if (c == 92 && inString) {
        out.add(c);
        escape = true;
        continue;
      }
      if (c == 34) {
        out.add(c);
        inString = !inString;
        continue;
      }
      if (inString) {
        out.add(c);
        continue;
      }

      if (c == 123) {
        stack.add(123);
        out.add(c);
      } else if (c == 91) {
        stack.add(91);
        out.add(c);
      } else if (c == 125) {
        if (stack.isNotEmpty && stack.last == 123) {
          stripStructuralTrailingCommaWs();
          stack.removeLast();
          out.add(c);
        }
        // excess `}` — omit
      } else if (c == 93) {
        if (stack.isNotEmpty && stack.last == 91) {
          stripStructuralTrailingCommaWs();
          stack.removeLast();
          out.add(c);
        }
        // excess `]` — omit
      } else {
        out.add(c);
      }
    }

    while (stack.isNotEmpty) {
      stripStructuralTrailingCommaWs();
      final open = stack.removeLast();
      out.add(open == 123 ? 125 : 93);
    }
    return String.fromCharCodes(out);
  }
}

class _KeySpec {
  const _KeySpec(this.key, this.kind);

  final String key;
  final ChatMockupAiFieldKind kind;
}

class _KeyMatch {
  const _KeyMatch(this.kind, this.indexAfterKeyQuote);

  final ChatMockupAiFieldKind kind;
  final int indexAfterKeyQuote;
}
