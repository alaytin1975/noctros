import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/noctros_constants.dart';
import '../../../domain/entities/noctros_entities.dart';
import '../../../domain/usecases/trigger_emergency_use_case.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  static const routePath = '/assistant/emergency';
  static const routeName = 'emergency';

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  late final TriggerEmergencyUseCase _triggerEmergencyUseCase;
  EmergencyEvent? _lastEvent;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _triggerEmergencyUseCase = TriggerEmergencyUseCase();
  }

  Future<void> _trigger({
    required String phrase,
    bool confirmed = false,
  }) async {
    setState(() => _isProcessing = true);

    final result = await _triggerEmergencyUseCase.execute(
      detectedPhrase: phrase,
      userConfirmed: confirmed,
    );

    setState(() => _isProcessing = false);

    if (result.isFailure) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failureOrNull?.message ?? 'Emergency failed')),
      );
      return;
    }

    final event = result.valueOrThrow;
    setState(() => _lastEvent = event);

    if (event.requiresConfirmation && !confirmed && mounted) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Confirm emergency response'),
          content: Text(
            'Noctros detected "$phrase". Do you want to notify emergency contacts and share your location?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (shouldProceed == true) {
        await _trigger(phrase: phrase, confirmed: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Assistant')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency mode listens for safety phrases with minimal battery usage.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: NoctrosConstants.emergencyPhrases
                  .map(
                    (phrase) => ActionChip(
                      label: Text(phrase),
                      onPressed:
                          _isProcessing ? null : () => _trigger(phrase: phrase),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            if (_isProcessing) const LinearProgressIndicator(),
            if (_lastEvent != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last emergency event',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Phrase: ${_lastEvent!.detectedPhrase}'),
                      Text('Time: ${_lastEvent!.detectedAt.toLocal()}'),
                      if (_lastEvent!.latitude != null &&
                          _lastEvent!.longitude != null)
                        Text(
                          'Location: ${_lastEvent!.latitude!.toStringAsFixed(5)}, ${_lastEvent!.longitude!.toStringAsFixed(5)}',
                        ),
                      Text(
                        _lastEvent!.requiresConfirmation
                            ? 'Awaiting confirmation'
                            : 'Emergency workflow initiated',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isProcessing
                    ? null
                    : () => _trigger(phrase: 'emergency'),
                icon: const Icon(Icons.emergency),
                label: const Text('Trigger Emergency'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
