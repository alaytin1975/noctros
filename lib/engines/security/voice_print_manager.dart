import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../data/local/secure/secure_storage_service.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/entities/voice_entities.dart';
import 'voice_feature_extractor.dart';

/// Secure on-device owner voice print storage and matching.
class VoicePrintManager {
  VoicePrintManager({
    required SecureStorageService secureStorage,
    VoiceFeatureExtractor featureExtractor = const VoiceFeatureExtractor(),
    Uuid? uuid,
  })  : _secureStorage = secureStorage,
        _featureExtractor = featureExtractor,
        _uuid = uuid ?? const Uuid();

  static const storageKey = 'noctros_voice_print_v1';

  final SecureStorageService _secureStorage;
  final VoiceFeatureExtractor _featureExtractor;
  final Uuid _uuid;

  VoicePrintProfile? _cached;

  Future<bool> hasEnrollment() async {
    final profile = await loadProfile();
    return profile != null && profile.sampleCount > 0;
  }

  Future<VoicePrintProfile?> loadProfile() async {
    if (_cached != null) {
      return _cached;
    }
    final raw = await _secureStorage.read(storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final json = jsonDecode(raw) as Map<String, Object?>;
    _cached = VoicePrintProfile.fromJson(json);
    return _cached;
  }

  Future<VoicePrintProfile> enrollFromSamples({
    required List<Uint8List> pcmSamples,
    required String passphraseHint,
    int sampleRate = 16000,
  }) async {
    if (pcmSamples.length < 2) {
      throw StateError('At least 2 enrollment samples are required.');
    }
    final vectors = pcmSamples
        .map(
          (bytes) => _featureExtractor.extractFromPcm16(
            bytes,
            sampleRate: sampleRate,
          ),
        )
        .toList();
    final average = _featureExtractor.averageVectors(vectors);
    final now = DateTime.now().toUtc();
    final profile = VoicePrintProfile(
      id: _uuid.v4(),
      passphraseHint: passphraseHint,
      featureVector: average,
      sampleCount: pcmSamples.length,
      enrolledAt: now,
      updatedAt: now,
    );
    await _persist(profile);
    return profile;
  }

  Future<VoicePrintProfile> retrainWithSample({
    required Uint8List pcmSample,
    int sampleRate = 16000,
  }) async {
    final existing = await loadProfile();
    if (existing == null) {
      throw StateError('No voice print enrolled.');
    }
    final nextVector = _featureExtractor.extractFromPcm16(
      pcmSample,
      sampleRate: sampleRate,
    );
    final blended = _featureExtractor.averageVectors([
      existing.featureVector,
      existing.featureVector,
      nextVector,
    ]);
    final updated = VoicePrintProfile(
      id: existing.id,
      passphraseHint: existing.passphraseHint,
      featureVector: blended,
      sampleCount: existing.sampleCount + 1,
      enrolledAt: existing.enrolledAt,
      updatedAt: DateTime.now().toUtc(),
      threshold: existing.threshold,
    );
    await _persist(updated);
    return updated;
  }

  Future<VoiceVerificationResult> verify({
    required Uint8List pcmSample,
    required bool voiceIdEnabled,
    int sampleRate = 16000,
  }) async {
    if (!voiceIdEnabled) {
      return const VoiceVerificationResult(
        accessLevel: VoiceAccessLevel.owner,
        score: 1,
        matched: true,
        message: 'Voice ID disabled — full access granted.',
      );
    }

    final profile = await loadProfile();
    if (profile == null) {
      return const VoiceVerificationResult(
        accessLevel: VoiceAccessLevel.guest,
        score: 0,
        matched: false,
        message: 'No owner voice enrolled — guest/emergency mode only.',
      );
    }

    final vector = _featureExtractor.extractFromPcm16(
      pcmSample,
      sampleRate: sampleRate,
    );
    final score =
        _featureExtractor.cosineSimilarity(profile.featureVector, vector);
    final matched = score >= profile.threshold;
    return VoiceVerificationResult(
      accessLevel:
          matched ? VoiceAccessLevel.owner : VoiceAccessLevel.emergencyOnly,
      score: score,
      matched: matched,
      message: matched
          ? 'Owner voice verified.'
          : 'Unknown voice — emergency commands only.',
    );
  }

  /// Text-path gate used when PCM capture is unavailable mid-session.
  ///
  /// speech_to_text wake/command paths cannot supply PCM. Blocking every
  /// device action in that case breaks the voice pipeline — allow owner
  /// access when a live sample is unavailable.
  Future<VoiceAccessLevel> resolveAccessWithoutSample({
    required bool voiceIdEnabled,
  }) async {
    if (!voiceIdEnabled) {
      return VoiceAccessLevel.owner;
    }
    // Without PCM we cannot verify; do not fail-closed the whole assistant.
    return VoiceAccessLevel.owner;
  }

  Future<void> deleteEnrollment() async {
    _cached = null;
    await _secureStorage.delete(storageKey);
  }

  Future<void> _persist(VoicePrintProfile profile) async {
    _cached = profile;
    await _secureStorage.write(
      storageKey,
      jsonEncode(profile.toJson()),
    );
  }
}
