import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/communication_entities.dart';
import '../../../domain/entities/noctros_enums.dart';
import '../../providers/communication_providers.dart';
import '../../widgets/contact_avatar.dart';

class ActiveCallArgs {
  const ActiveCallArgs({
    required this.call,
    required this.contactId,
  });

  final CallRecord call;
  final String contactId;
}

class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key, required this.args});

  static const routePath = '/calls/active';
  static const routeName = 'activeCall';

  final ActiveCallArgs args;

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen>
    with SingleTickerProviderStateMixin {
  late final DateTime _startedAt;
  late final AnimationController _pulse;
  Timer? _ticker;
  int _elapsedSeconds = 0;
  bool _muted = false;
  bool _speaker = true;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _endCall() async {
    await ref.read(callsControllerProvider.notifier).endCall(
          callId: widget.args.call.id,
          durationSeconds: _elapsedSeconds,
        );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(callsControllerProvider).contactsById;
    final contact = contacts[widget.args.contactId];
    final theme = Theme.of(context);
    final isVideo = widget.args.call.kind == CallKind.video;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final glow = 0.35 + (_pulse.value * 0.35);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(
                    const Color(0xFF0B1420),
                    theme.colorScheme.primary,
                    glow * 0.35,
                  )!,
                  const Color(0xFF071018),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: Column(
                  children: [
                    Text(
                      isVideo ? 'Video call' : 'Noctros Call',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    if (contact != null)
                      Transform.scale(
                        scale: 1 + (_pulse.value * 0.04),
                        child: ContactAvatar(contact: contact, size: 120),
                      )
                    else
                      const CircleAvatar(
                        radius: 60,
                        child: Icon(Icons.person, size: 48),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      contact?.displayName ?? 'Unknown',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatElapsed(_elapsedSeconds),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallControl(
                          icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          label: _muted ? 'Unmute' : 'Mute',
                          onTap: () => setState(() => _muted = !_muted),
                        ),
                        _CallControl(
                          icon: _speaker
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          label: 'Speaker',
                          onTap: () => setState(() => _speaker = !_speaker),
                        ),
                        _CallControl(
                          icon: Icons.call_end_rounded,
                          label: 'End',
                          danger: true,
                          onTap: _endCall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatElapsed(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remain = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remain';
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: danger ? const Color(0xFFE5484D) : Colors.white24,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white70,
              ),
        ),
      ],
    );
  }
}
