import 'dart:convert';

/// Streaming JSON repair + safe parse helpers for projecting AI output into UI.
class ChatMockupAiStreamPreview {
  ChatMockupAiStreamPreview._();

  /// Same as [repairForProjection] — kept for callers that only need preview text.
  static String previewTextFromRaw(String rawBuffer) {
    return repairForProjection(rawBuffer);
  }

  /// Strip fences, take `{`… suffix; drop excess closers, trim structural trailing
  /// commas, then append missing closers so [tryParseProjectedObject] can succeed
  /// on partial streams.
  static String repairForProjection(String rawBuffer) {
    return _repairJsonTailForPreview(rawBuffer.trim());
  }

  /// Returns decoded root object after [repairForProjection], or `null` if parse fails.
  static Map<String, dynamic>? tryParseProjectedObject(String repaired) {
    try {
      final decoded = jsonDecode(repaired);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
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
