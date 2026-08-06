import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../app/di/service_locator.dart';
import '../../core/constants/noctros_constants.dart';
import '../../core/errors/noctros_failure.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/repositories/noctros_repositories.dart';

/// Emergency response coordinator: call, contacts, GPS, SOS flashlight.
class EmergencyEngine {
  EmergencyEngine({
    SettingsRepository? settingsRepository,
    Uuid? uuid,
  })  : _settingsRepository =
            settingsRepository ?? ServiceLocator.get<SettingsRepository>(),
        _uuid = uuid ?? const Uuid();

  final SettingsRepository _settingsRepository;
  final Uuid _uuid;
  bool _sosFlashActive = false;

  bool matchesEmergencyPhrase(String transcript) {
    final normalized = transcript.toLowerCase().trim();
    return NoctrosConstants.emergencyPhrases
        .any((phrase) => normalized.contains(phrase));
  }

  Future<Result<EmergencyEvent>> handleTrigger({
    required String detectedPhrase,
    EmergencyTriggerType triggerType = EmergencyTriggerType.phrase,
    bool userConfirmed = false,
  }) async {
    try {
      final settingsResult = await _settingsRepository.loadSettings();
      if (settingsResult is FailureResult<UserSettings>) {
        return FailureResult(settingsResult.failure);
      }
      final settings = settingsResult.valueOrThrow;
      final position = await _resolveLocation();
      final requiresConfirmation = !settings.emergencyAutoDialEnabled;

      if (requiresConfirmation && !userConfirmed) {
        return Success(
          EmergencyEvent(
            id: _uuid.v4(),
            triggerType: triggerType,
            detectedPhrase: detectedPhrase,
            detectedAt: DateTime.now().toUtc(),
            latitude: position?.latitude,
            longitude: position?.longitude,
            requiresConfirmation: true,
          ),
        );
      }

      await startSosFlashlight();
      await _dialEmergencyNumber(settings.emergencyNumber);
      await _notifyEmergencyContacts(
        settings.emergencyContacts,
        detectedPhrase,
        position,
      );

      return Success(
        EmergencyEvent(
          id: _uuid.v4(),
          triggerType: triggerType,
          detectedPhrase: detectedPhrase,
          detectedAt: DateTime.now().toUtc(),
          latitude: position?.latitude,
          longitude: position?.longitude,
          requiresConfirmation: false,
        ),
      );
    } catch (error) {
      return FailureResult(
        EmergencyFailure('Emergency handling failed.', cause: error),
      );
    }
  }

  Future<void> startSosFlashlight({
    int bursts = 6,
    Duration onDuration = const Duration(milliseconds: 220),
    Duration offDuration = const Duration(milliseconds: 180),
  }) async {
    if (_sosFlashActive || kIsWeb) {
      return;
    }
    _sosFlashActive = true;
    try {
      final available = await TorchLight.isTorchAvailable();
      if (!available) {
        return;
      }
      for (var i = 0; i < bursts; i++) {
        if (!_sosFlashActive) {
          break;
        }
        await TorchLight.enableTorch();
        await Future<void>.delayed(onDuration);
        await TorchLight.disableTorch();
        await Future<void>.delayed(offDuration);
      }
    } catch (_) {
      // Torch may be unavailable; emergency flow continues.
    } finally {
      try {
        await TorchLight.disableTorch();
      } catch (_) {}
      _sosFlashActive = false;
    }
  }

  Future<void> stopSosFlashlight() async {
    _sosFlashActive = false;
    try {
      await TorchLight.disableTorch();
    } catch (_) {}
  }

  Future<void> _dialEmergencyNumber(String number) async {
    final sanitized = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (sanitized.isEmpty) {
      return;
    }
    final uri = Uri(scheme: 'tel', path: sanitized);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<Position?> _resolveLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
  }

  Future<void> _notifyEmergencyContacts(
    List<EmergencyContact> contacts,
    String phrase,
    Position? position,
  ) async {
    final locationText = position == null
        ? 'Location unavailable'
        : 'GPS: ${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)} '
            'https://maps.google.com/?q=${position.latitude},${position.longitude}';

    final body =
        'NOCTROS EMERGENCY: "$phrase". $locationText. Please help immediately.';

    for (final contact in contacts.where((c) => c.notifyOnEmergency)) {
      if (contact.phoneNumber.isEmpty) {
        continue;
      }
      await _openSms(contact.phoneNumber, body);
    }
  }

  Future<void> _openSms(String phone, String body) async {
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': body},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!kIsWeb && Platform.isAndroid) {
      await AndroidIntent(
        action: 'android.intent.action.SENDTO',
        data: 'smsto:$phone',
        arguments: <String, dynamic>{'sms_body': body},
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
    }
  }
}
