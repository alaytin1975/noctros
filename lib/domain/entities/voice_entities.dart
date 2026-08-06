import 'noctros_enums.dart';

class VoicePrintProfile {
  const VoicePrintProfile({
    required this.id,
    required this.passphraseHint,
    required this.featureVector,
    required this.sampleCount,
    required this.enrolledAt,
    required this.updatedAt,
    this.threshold = 0.78,
  });

  final String id;
  final String passphraseHint;
  final List<double> featureVector;
  final int sampleCount;
  final DateTime enrolledAt;
  final DateTime updatedAt;
  final double threshold;

  Map<String, Object?> toJson() => {
        'id': id,
        'passphraseHint': passphraseHint,
        'featureVector': featureVector,
        'sampleCount': sampleCount,
        'enrolledAt': enrolledAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'threshold': threshold,
      };

  factory VoicePrintProfile.fromJson(Map<String, Object?> json) {
    return VoicePrintProfile(
      id: json['id']! as String,
      passphraseHint: json['passphraseHint'] as String? ?? '',
      featureVector: (json['featureVector'] as List<Object?>)
          .map((value) => (value as num).toDouble())
          .toList(),
      sampleCount: json['sampleCount'] as int? ?? 0,
      enrolledAt: DateTime.parse(json['enrolledAt']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.78,
    );
  }
}

class VoiceVerificationResult {
  const VoiceVerificationResult({
    required this.accessLevel,
    required this.score,
    required this.matched,
    this.message = '',
  });

  final VoiceAccessLevel accessLevel;
  final double score;
  final bool matched;
  final String message;
}

class VoicePipelineEvent {
  const VoicePipelineEvent({
    required this.stage,
    required this.message,
    this.transcript,
    this.isEmergency = false,
  });

  final String stage;
  final String message;
  final String? transcript;
  final bool isEmergency;
}
