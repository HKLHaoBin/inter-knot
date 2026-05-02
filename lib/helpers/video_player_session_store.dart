import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:inter_knot/helpers/box.dart';

const int kVideoPlayerSessionRecordVersion = 1;

String videoPlayerSessionStorageKey(int discussionNumber) =>
    'video_player_session_$discussionNumber';

/// Fingerprint of the work's published [chatMockup] + [ai] so we don't resume after an author update.
String computeVideoPayloadSourceHash(Map<String, dynamic> decodedPayload) {
  final chat = decodedPayload['chatMockup'];
  final ai = decodedPayload['ai'];
  final canonical = jsonEncode(<String, dynamic>{
    'ai': ai,
    'chatMockup': chat,
  });
  return sha256.convert(utf8.encode(canonical)).toString();
}

class VideoPlayerSessionRecord {
  const VideoPlayerSessionRecord({
    required this.version,
    required this.discussionNumber,
    required this.updatedAtMs,
    required this.chatMockup,
    required this.sourceHash,
  });

  final int version;
  final int discussionNumber;
  final int updatedAtMs;
  final Map<String, dynamic> chatMockup;
  final String sourceHash;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'discussionNumber': discussionNumber,
        'updatedAtMs': updatedAtMs,
        'chatMockup': chatMockup,
        'sourceHash': sourceHash,
      };

  static VideoPlayerSessionRecord? tryParse(dynamic raw) {
    if (raw == null) {
      return null;
    }
    Map<String, dynamic>? map;
    if (raw is String) {
      if (raw.isEmpty) {
        return null;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          map = decoded;
        }
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      map = raw;
    }
    if (map == null) {
      return null;
    }
    final version = map['version'];
    final discussionNumber = map['discussionNumber'];
    final updatedAtMs = map['updatedAtMs'];
    final chatMockup = map['chatMockup'];
    final sourceHash = map['sourceHash'];
    if (version is! int ||
        discussionNumber is! int ||
        updatedAtMs is! int ||
        chatMockup is! Map ||
        sourceHash is! String) {
      return null;
    }
    if (version != kVideoPlayerSessionRecordVersion) {
      return null;
    }
    return VideoPlayerSessionRecord(
      version: version,
      discussionNumber: discussionNumber,
      updatedAtMs: updatedAtMs,
      chatMockup: Map<String, dynamic>.from(chatMockup),
      sourceHash: sourceHash,
    );
  }
}

VideoPlayerSessionRecord? readVideoPlayerSession(int discussionNumber) {
  final key = videoPlayerSessionStorageKey(discussionNumber);
  return VideoPlayerSessionRecord.tryParse(box.read(key));
}

Future<void> writeVideoPlayerSession(VideoPlayerSessionRecord record) async {
  final key = videoPlayerSessionStorageKey(record.discussionNumber);
  await box.write(key, jsonEncode(record.toJson()));
}

Future<void> clearVideoPlayerSession(int discussionNumber) async {
  await box.remove(videoPlayerSessionStorageKey(discussionNumber));
}
