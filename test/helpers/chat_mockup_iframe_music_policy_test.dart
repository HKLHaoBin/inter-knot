import 'package:flutter_test/flutter_test.dart';
import 'package:inter_knot/helpers/chat_mockup_iframe_music_policy.dart';

void main() {
  group('chatMockupNeteaseOutchainEmbedInnerHeight', () {
    test('official-style height=32 maps to ~52 outer (chrome, not raw 32)', () {
      expect(chatMockupNeteaseOutchainEmbedInnerHeight(32), 52);
    });

    test('small query height is floored for usable controls', () {
      expect(chatMockupNeteaseOutchainEmbedInnerHeight(10), 52);
    });

    test('large query height is capped for mockup layout', () {
      expect(chatMockupNeteaseOutchainEmbedInnerHeight(2000), 720);
    });
  });

  group('chatMockupIframeMusicEmbedInnerHeight', () {
    test('parses Netease outchain URL height through mapping', () {
      const url =
          'https://music.163.com/outchain/player?type=2&id=1&auto=1&height=32';
      expect(chatMockupIframeMusicEmbedInnerHeight(url), 52);
    });
  });
}
