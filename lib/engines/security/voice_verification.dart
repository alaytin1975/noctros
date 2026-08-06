import 'dart:typed_data';

import '../../core/constants/noctros_constants.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/entities/voice_entities.dart';
import 'voice_print_manager.dart';

/// Authorizes voice commands: owner full access, unknown/guest emergency only.
class VoiceVerification {
  VoiceVerification({required VoicePrintManager voicePrintManager})
      : _voicePrintManager = voicePrintManager;

  final VoicePrintManager _voicePrintManager;

  bool isEmergencyCommand(String transcript) {
    final normalized = transcript.toLowerCase();
    return NoctrosConstants.emergencyPhrases
        .any((phrase) => normalized.contains(phrase));
  }

  Future<VoiceVerificationResult> authorizeCommand({
    required String transcript,
    required bool voiceIdEnabled,
    Uint8List? pcmSample,
  }) async {
    if (isEmergencyCommand(transcript)) {
      return const VoiceVerificationResult(
        accessLevel: VoiceAccessLevel.emergencyOnly,
        score: 1,
        matched: true,
        message: 'Emergency command authorized for any speaker.',
      );
    }

    if (pcmSample != null) {
      return _voicePrintManager.verify(
        pcmSample: pcmSample,
        voiceIdEnabled: voiceIdEnabled,
      );
    }

    final level = await _voicePrintManager.resolveAccessWithoutSample(
      voiceIdEnabled: voiceIdEnabled,
    );
    final allowed = level == VoiceAccessLevel.owner;
    return VoiceVerificationResult(
      accessLevel: level,
      score: allowed ? 1 : 0,
      matched: allowed,
      message: allowed
          ? 'Access granted.'
          : 'Voice ID active — owner verification required. Emergency only.',
    );
  }

  bool canExecuteDeviceAction(VoiceAccessLevel level) {
    return level == VoiceAccessLevel.owner;
  }
}
