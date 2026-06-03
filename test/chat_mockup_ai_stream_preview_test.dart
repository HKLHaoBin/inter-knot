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

  group('XML field scan', () {
    test('director two turns preserve action/user/character order', () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[动作一]]></action>
    <user><![CDATA[用户一]]></user>
    <character><![CDATA[角色一]]></character>
  </turn>
  <turn>
    <action>动作二</action>
    <user>用户二</user>
    <character>角色二</character>
  </turn>
</chat>''';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.user,
        ChatMockupAiFieldKind.character,
      ]);
      expect(events.map((e) => e.rawValue).toList(), [
        '动作一',
        '用户一',
        '角色一',
        '动作二',
        '用户二',
        '角色二',
      ]);
    });

    test('role action and character; user tag does not shift character', () {
      const raw = '''
<chat>
  <action><![CDATA[旁白]]></action>
  <user><![CDATA[不应产出]]></user>
  <character><![CDATA[左气泡]]></character>
</chat>''';
      final events = ChatMockupAiStreamPreview.scanRoleOrContinueFields(raw);
      expect(events.map((e) => e.kind).toList(), [
        ChatMockupAiFieldKind.action,
        ChatMockupAiFieldKind.character,
      ]);
      expect(events.map((e) => e.rawValue).toList(), ['旁白', '左气泡']);
    });

    test('CDATA preserves quotes newlines and angle-bracket-like text', () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[他说"你好"
以及 <tag> 不是标签]]></action>
    <user><![CDATA[]]></user>
    <character><![CDATA[中文标点，。！]]></character>
  </turn>
</chat>''';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events[0].rawValue, '他说"你好"\n以及 <tag> 不是标签');
      expect(events[1].rawValue, '');
      expect(events[2].rawValue, '中文标点，。！');
    });

    test('stream preview emits prefix for unclosed character tag', () {
      const raw = '''
<chat>
  <turn>
    <action></action>
    <user></user>
    <character><![CDATA[第一句
第二''';
      final stream = ChatMockupAiStreamPreview.scanDirectorFields(
        raw,
        forStreamPreview: true,
      );
      expect(stream.last.kind, ChatMockupAiFieldKind.character);
      expect(stream.last.rawValue, '第一句\n第二');

      final finalizeStyle = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(
          finalizeStyle.where((e) => e.kind == ChatMockupAiFieldKind.character),
          isEmpty);
    });

    test('markdown fence stripped before XML scan', () {
      const raw = '''
```xml
<chat>
  <action><![CDATA[a]]></action>
  <character><![CDATA[b]]></character>
</chat>
```''';
      final events = ChatMockupAiStreamPreview.scanRoleOrContinueFields(raw);
      expect(events.map((e) => e.rawValue).toList(), ['a', 'b']);
    });

    test('plain tag text decodes XML entities', () {
      const raw = '''
<chat>
  <turn>
    <action>&lt;旁白&gt; &amp; 更多</action>
    <user></user>
    <character>角色</character>
  </turn>
</chat>''';
      final events = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(events.first.rawValue, '<旁白> & 更多');
    });
  });

  group('XML strict parse', () {
    test('director returns turns map compatible with JSON builders', () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[a1]]></action>
    <user><![CDATA[u1]]></user>
    <character><![CDATA[c1]]></character>
  </turn>
  <turn>
    <action></action>
    <user></user>
    <character>c2</character>
  </turn>
</chat>''';
      final map = ChatMockupAiStreamPreview.tryParseStrictXmlDirector(raw);
      expect(map, isNotNull);
      final turns = map!['turns'] as List;
      expect(turns, hasLength(2));
      expect(turns[0], {
        'action': 'a1',
        'user': 'u1',
        'character': 'c1',
      });
      expect(turns[1], {
        'action': '',
        'user': '',
        'character': 'c2',
      });
    });

    test('role returns action and character map', () {
      const raw = '''
<chat>
  <action><![CDATA[旁白]]></action>
  <character><![CDATA[消息一
消息二]]></character>
</chat>''';
      final map =
          ChatMockupAiStreamPreview.tryParseStrictXmlRoleOrContinue(raw);
      expect(map, {
        'action': '旁白',
        'character': '消息一\n消息二',
      });
    });

    test('malformed XML returns null', () {
      expect(
        ChatMockupAiStreamPreview.tryParseStrictXmlDirector('<chat><turn>'),
        isNull,
      );
    });

    test('strict parse succeeds when explanatory text follows </chat>', () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[a]]></action>
    <user><![CDATA[u]]></user>
    <character><![CDATA[c]]></character>
  </turn>
</chat>
以上是生成的对话内容。''';
      final map = ChatMockupAiStreamPreview.tryParseStrictXmlDirector(raw);
      expect(map, isNotNull);
      final turns = map!['turns'] as List;
      expect(turns, hasLength(1));
    });

    test(
        'director two turns with trailing text uses strict parse not field scan bypass',
        () {
      const raw = '''
<chat>
  <turn>
    <action><![CDATA[a1]]></action>
    <user><![CDATA[u1]]></user>
    <character><![CDATA[c1]]></character>
  </turn>
  <turn>
    <action></action>
    <user></user>
    <character>c2</character>
  </turn>
</chat>
说明：共两轮。''';
      final strict = ChatMockupAiStreamPreview.tryParseStrictXmlDirector(raw);
      expect(strict, isNotNull);
      final turns = strict!['turns'] as List;
      expect(turns.length, 2);

      final fieldEvents = ChatMockupAiStreamPreview.scanDirectorFields(raw);
      expect(fieldEvents, isNotEmpty);

      // Strict parse must succeed independently of trailing prose; field scan
      // alone would not enforce turn-count validation during finalize.
      expect(
        ChatMockupAiStreamPreview.preprocessForXmlParse(raw)
            .endsWith('</chat>'),
        isTrue,
      );
      expect(
        ChatMockupAiStreamPreview.preprocessForXmlParse(raw),
        isNot(contains('说明')),
      );
    });
  });
}
