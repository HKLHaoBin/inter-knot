import 'package:inter_knot/helpers/chat_mockup_ai_stream_preview.dart';
import 'package:test/test.dart';

void main() {
  group('ChatMockupAiStreamPreview field scan', () {
    test('loose unquoted action with bare value', () {
      const raw = '{ action: hello line }';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events, hasLength(1));
      expect(events[0].kind, ChatMockupAiFieldKind.action);
      expect(events[0].rawValue, 'hello line');
    });

    test('loose single-quoted character key and value', () {
      const raw = "{ 'character': 'hi there' }";
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events, hasLength(1));
      expect(events[0].kind, ChatMockupAiFieldKind.character);
      expect(events[0].rawValue, 'hi there');
    });

    test('strict JSON value ends at first closing quote (inner raw quote)', () {
      const raw = '{"character":"他说"你好"}';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events, hasLength(1));
      expect(events[0].kind, ChatMockupAiFieldKind.character);
      expect(events[0].rawValue, '他说');
    });

    test('stream preview emits prefix before closing quote', () {
      const raw = '{"character":"第一句\n第二';
      final stream = ChatMockupAiStreamPreview.scanDirectorFields(
        raw,
        forStreamPreview: true,
      );
      expect(stream, hasLength(1));
      expect(stream[0].kind, ChatMockupAiFieldKind.character);
      expect(stream[0].rawValue, '第一句\n第二');

      final finalizeStyle = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(finalizeStyle, isEmpty);
    });

    test('multiple fields preserve source order', () {
      const raw = '{ action: a\nuser: b\ncharacter: c }';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
      ]);
      expect(events.map((e) => e.rawValue).toList(), ['a', 'b', 'c']);
    });

    test('role scan recognizes 用户 then character in order', () {
      const raw = "{'用户':'ignored','character':'left only'}";
      final events = ChatMockupAiStreamPreview.scanRoleOrContinueFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
      ]);
    });

    test('mixed strict JSON then loose lines (director)', () {
      const raw = '{"action":"a"\nuser: b\ncharacter: c}';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
      ]);
      expect(events.map((e) => e.rawValue).toList(), ['a', 'b', 'c']);
    });

    test('mixed loose then strict then loose (director)', () {
      const raw = 'action: a\n"character":"b"\nuser: c';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.character,
        ChatMockupAiFieldKind.user,
      ]);
      expect(events.map((e) => e.rawValue).toList(), ['a', 'b', 'c']);
    });
  });
}
