import 'package:flutter/foundation.dart';

/// Stage-by-stage debug logging for the voice pipeline.
abstract final class VoicePipelineLog {
  static const _tag = 'NoctrosVoice';

  static void stage(String stage, [String? detail]) {
    final message =
        detail == null || detail.isEmpty ? stage : '$stage | $detail';
    debugPrint('[$_tag] $message');
  }

  static void fail(String stage, Object reason) {
    debugPrint('[$_tag] FAIL $stage | $reason');
  }
}
