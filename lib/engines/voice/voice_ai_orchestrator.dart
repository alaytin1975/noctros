import 'dart:async';

import '../../domain/entities/noctros_entities.dart';
import '../../domain/entities/noctros_enums.dart';
import '../../domain/entities/voice_entities.dart';
import '../../domain/repositories/noctros_repositories.dart';
import '../../domain/usecases/handle_user_command_use_case.dart';
import '../security/voice_verification.dart';
import 'speech_recognition_service.dart';
import 'speech_synthesis_service.dart';
import 'voice_engine.dart';
import 'voice_session_manager.dart';
import 'wake_word_engine.dart';

/// Asynchronous voice pipeline:
/// Wake → STT → Voice ID → Intent/AI Orchestrator → Device Action → TTS
class VoiceAiOrchestrator {
  VoiceAiOrchestrator({
    required VoiceEngine voiceEngine,
    required VoiceVerification voiceVerification,
    required HandleUserCommandUseCase handleUserCommandUseCase,
    required SettingsRepository settingsRepository,
  })  : _voiceEngine = voiceEngine,
        _voiceVerification = voiceVerification,
        _handleUserCommandUseCase = handleUserCommandUseCase,
        _settingsRepository = settingsRepository;

  final VoiceEngine _voiceEngine;
  final VoiceVerification _voiceVerification;
  final HandleUserCommandUseCase _handleUserCommandUseCase;
  final SettingsRepository _settingsRepository;

  final _events = StreamController<VoicePipelineEvent>.broadcast();
  bool _pipelineBusy = false;

  Stream<VoicePipelineEvent> get events => _events.stream;
  SpeechRecognitionService get stt => _voiceEngine.speechRecognition;
  SpeechSynthesisService get tts => _voiceEngine.speechSynthesis;
  WakeWordEngine get wakeWord => _voiceEngine.wakeWordEngine;
  VoiceSessionManager get sessions => _voiceEngine.sessionManager;

  Future<void> onWakeWord({
    required String wakeWord,
    required String conversationId,
    required Future<bool> Function(String confirmationMessage) confirmAction,
    void Function(String route)? navigate,
  }) async {
    if (_pipelineBusy) {
      return;
    }
    _pipelineBusy = true;
    try {
      _emit('wake', 'Wake word detected: $wakeWord');
      await _voiceEngine.stopWakeWordListening();
      await _voiceEngine.interruptSpeech();

      final settings = await _loadSettings();
      final isEmergencyWake = _voiceVerification.isEmergencyCommand(wakeWord);
      if (isEmergencyWake) {
        sessions.setState(VoiceSessionState.emergency);
        _emit('emergency', wakeWord, isEmergency: true, transcript: wakeWord);
        navigate?.call('/emergency');
        if (settings.ttsEnabled) {
          await tts.speak('Emergency mode activated.');
        }
        return;
      }

      navigate?.call('/chat');
      sessions.setState(VoiceSessionState.listening);
      // Silent acknowledgement — no TTS beep/chime on wake.
      _emit('listening', 'Listening for command');

      final transcript = await stt.recognizeOnceWithFallback(
        listenFor: const Duration(seconds: 10),
      );
      if (transcript == null || transcript.isEmpty) {
        _emit('error', 'I did not catch that.');
        if (settings.ttsEnabled) {
          sessions.setState(VoiceSessionState.speaking);
          await tts.speak('I did not catch that.');
        }
        return;
      }

      sessions.setState(VoiceSessionState.processing);
      await processTranscript(
        transcript: transcript,
        conversationId: conversationId,
        confirmAction: confirmAction,
        navigate: navigate,
      );
    } finally {
      _pipelineBusy = false;
      final settings = await _loadSettings();
      if (settings.wakeWordEnabled) {
        // Caller should restart wake listening after pipeline.
      }
    }
  }

  Future<VoicePipelineEvent?> processTranscript({
    required String transcript,
    required String conversationId,
    required Future<bool> Function(String confirmationMessage) confirmAction,
    void Function(String route)? navigate,
  }) async {
    final settings = await _loadSettings();
    _emit('recognized', 'Heard command', transcript: transcript);

    sessions.setState(VoiceSessionState.verifying);
    final verification = await _voiceVerification.authorizeCommand(
      transcript: transcript,
      voiceIdEnabled: settings.voiceIdEnabled,
    );

    if (verification.accessLevel == VoiceAccessLevel.emergencyOnly &&
        _voiceVerification.isEmergencyCommand(transcript)) {
      sessions.setState(VoiceSessionState.emergency);
      _emit(
        'emergency',
        verification.message,
        isEmergency: true,
        transcript: transcript,
      );
      navigate?.call('/emergency');
      if (settings.ttsEnabled) {
        await tts.speak('Emergency mode. Help is on the way.');
      }
      return VoicePipelineEvent(
        stage: 'emergency',
        message: verification.message,
        transcript: transcript,
        isEmergency: true,
      );
    }

    if (!_voiceVerification.canExecuteDeviceAction(verification.accessLevel) &&
        settings.voiceIdEnabled) {
      sessions.update(
        sessions.session.copyWith(
          state: VoiceSessionState.idle,
          accessDenied: true,
          finalTranscript: transcript,
        ),
      );
      _emit('denied', verification.message, transcript: transcript);
      if (settings.ttsEnabled) {
        await tts.speak(
          'Voice not recognized. Only emergency commands are allowed.',
        );
      }
      return VoicePipelineEvent(
        stage: 'denied',
        message: verification.message,
        transcript: transcript,
      );
    }

    sessions.setState(VoiceSessionState.processing);
    _emit('orchestrating', 'Routing command', transcript: transcript);

    var result = await _handleUserCommandUseCase.execute(
      conversationId: conversationId,
      userMessage: transcript,
    );

    if (result.isSuccess &&
        result.valueOrThrow.kind == HandleCommandKind.needsConfirmation) {
      final pending = result.valueOrThrow;
      final allowed = await confirmAction(
        pending.confirmationMessage ??
            pending.pendingIntent?.displaySummary ??
            'Allow this action?',
      );
      if (!allowed) {
        if (settings.ttsEnabled) {
          await tts.speak('Okay, cancelled.');
        }
        return const VoicePipelineEvent(
          stage: 'cancelled',
          message: 'User cancelled',
        );
      }
      result = await _handleUserCommandUseCase.execute(
        conversationId: conversationId,
        userMessage: pending.pendingUserMessage ?? transcript,
        userConfirmed: true,
        confirmedIntent: pending.pendingIntent,
      );
    }

    if (result.isFailure) {
      final message = result.failureOrNull?.message ?? 'Something went wrong.';
      _emit('error', message, transcript: transcript);
      if (settings.ttsEnabled) {
        await tts.speak(message);
      }
      return VoicePipelineEvent(stage: 'error', message: message);
    }

    final handled = result.valueOrThrow;
    final reply = handled.assistantMessage?.content ?? 'Done.';
    _emit('response', reply, transcript: transcript);
    sessions.setState(VoiceSessionState.speaking);
    if (settings.ttsEnabled) {
      await tts.speak(reply);
    }
    sessions.setState(VoiceSessionState.idle);
    return VoicePipelineEvent(
      stage: 'response',
      message: reply,
      transcript: transcript,
    );
  }

  Future<UserSettings> _loadSettings() async {
    final result = await _settingsRepository.loadSettings();
    if (result.isSuccess) {
      return result.valueOrThrow;
    }
    return UserSettings.defaults();
  }

  void _emit(
    String stage,
    String message, {
    String? transcript,
    bool isEmergency = false,
  }) {
    if (!_events.isClosed) {
      _events.add(
        VoicePipelineEvent(
          stage: stage,
          message: message,
          transcript: transcript,
          isEmergency: isEmergency,
        ),
      );
    }
  }

  Future<void> dispose() async {
    await _events.close();
  }
}
