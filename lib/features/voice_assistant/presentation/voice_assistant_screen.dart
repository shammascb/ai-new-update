import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/voice_command.dart';

class VoiceAssistantScreen extends StatelessWidget {
  const VoiceAssistantScreen({
    required this.isListening,
    required this.isInterpreting,
    required this.isExecuting,
    required this.recognizedSpeech,
    required this.command,
    required this.requiresDoorConfirmation,
    required this.error,
    required this.actionResult,
    required this.onListenPressed,
    required this.onExecuteCommand,
    required this.onCancelConfirmation,
    required this.onClear,
    required this.onOpenRooms,
    required this.onOpenLivingRoom,
    required this.onOpenBedroom,
    this.accountName,
    this.roleLabel,
    this.voiceEnabled = true,
    this.onOpenFamilySecurity,
    super.key,
  });

  final bool isListening;
  final bool isInterpreting;
  final bool isExecuting;
  final String recognizedSpeech;
  final VoiceCommand? command;
  final bool requiresDoorConfirmation;
  final String? error;
  final String? actionResult;
  final VoidCallback onListenPressed;
  final VoidCallback onExecuteCommand;
  final VoidCallback onCancelConfirmation;
  final VoidCallback onClear;
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenLivingRoom;
  final VoidCallback onOpenBedroom;
  final String? accountName;
  final String? roleLabel;
  final bool voiceEnabled;
  final VoidCallback? onOpenFamilySecurity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = !voiceEnabled
        ? 'Voice commands disabled for this account'
        : isListening
            ? 'Listening…'
            : isInterpreting
                ? 'Understanding your request…'
                : isExecuting
                    ? 'Working on it…'
                    : 'Tap the microphone to speak';
    final accountText = accountName == null || accountName!.trim().isEmpty
        ? 'Signed-in account'
        : roleLabel == null || roleLabel!.trim().isEmpty
            ? accountName!
            : '$accountName ($roleLabel)';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1715), Color(0xFF07100F), Color(0xFF050807)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            final orbSize = math
                .min(
                  270.0,
                  math.min(
                    math.max(160.0, constraints.maxWidth - 40),
                    constraints.maxHeight * (compact ? 0.28 : 0.34),
                  ),
                )
                .toDouble();

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      compact ? 12 : 20,
                      20,
                      12,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Voice assistant',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: voiceEnabled
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFFF8A80)
                                      .withValues(alpha: 0.45),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    voiceEnabled
                                        ? Icons.verified_user_outlined
                                        : Icons.mic_off_rounded,
                                    size: 16,
                                    color: voiceEnabled
                                        ? const Color(0xFF73E6C7)
                                        : const Color(0xFFFF8A80),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Account: $accountText',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (onOpenFamilySecurity != null)
                                    TextButton(
                                      onPressed: onOpenFamilySecurity,
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF73E6C7),
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      child: const Text('Security'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                voiceEnabled
                                    ? 'Commands are logged under your signed-in account. '
                                        'Speaker/voice-print identity verification is NOT '
                                        'implemented; door unlock via voice is disabled.'
                                    : 'A household admin disabled voice commands for this '
                                        'account. You can still review permissions in Security.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 18),
                        _VoiceOrb(
                          isActive: isListening || isInterpreting,
                          size: orbSize,
                        ),
                        SizedBox(height: compact ? 12 : 20),
                        Text(
                          status,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say “Open living room” or “Open bedroom”, '
                          'or choose a room below.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onOpenLivingRoom,
                                icon: const Icon(
                                  Icons.weekend_outlined,
                                  size: 18,
                                ),
                                label: const Text('Living Room'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white30),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onOpenBedroom,
                                icon: const Icon(Icons.bed_outlined, size: 18),
                                label: const Text('Bedroom'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white30),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (recognizedSpeech.isNotEmpty ||
                            error != null ||
                            command != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Column(
                              children: [
                                if (recognizedSpeech.isNotEmpty)
                                  _AssistantMessage(
                                    title: 'I heard',
                                    message: '“$recognizedSpeech”',
                                  ),
                                if (command != null) ...[
                                  const SizedBox(height: 10),
                                  _AssistantMessage(
                                    title: 'Requested action',
                                    message: command!.description,
                                  ),
                                ],
                                if (error != null) ...[
                                  const SizedBox(height: 10),
                                  _AssistantMessage(
                                    title: 'Could not complete',
                                    message: error!,
                                    isError: true,
                                  ),
                                ],
                                if (actionResult != null) ...[
                                  const SizedBox(height: 10),
                                  _AssistantMessage(
                                    title: 'Status',
                                    message: actionResult!,
                                  ),
                                ],
                                if (requiresDoorConfirmation &&
                                    command?.isExecutable == true) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: isExecuting
                                              ? null
                                              : onExecuteCommand,
                                          child: Text(
                                            isExecuting
                                                ? 'Working…'
                                                : 'Confirm and lock',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton(
                                        onPressed: isExecuting
                                            ? null
                                            : onCancelConfirmation,
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Voice commands cannot unlock the door.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: onOpenRooms,
                          icon: const Icon(Icons.meeting_room_outlined),
                          label: const Text('Rooms'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, compact ? 8 : 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        tooltip: !voiceEnabled
                            ? 'Voice commands disabled for this account'
                            : isListening
                                ? 'Stop listening'
                                : 'Start listening',
                        onPressed:
                            isExecuting || !voiceEnabled ? null : onListenPressed,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF73E6C7),
                          foregroundColor: const Color(0xFF06201A),
                          disabledBackgroundColor: Colors.white12,
                          disabledForegroundColor: Colors.white38,
                          fixedSize: const Size(64, 64),
                        ),
                        icon: Icon(
                          !voiceEnabled
                              ? Icons.mic_off_rounded
                              : isListening
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton.outlined(
                        tooltip: 'Clear voice response',
                        onPressed: isExecuting ? null : onClear,
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white70,
                          fixedSize: const Size(52, 52),
                          side: const BorderSide(color: Colors.white24),
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({
    required this.title,
    required this.message,
    this.isError = false,
  });

  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError
              ? const Color(0xFFFF7777).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF73E6C7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            style: TextStyle(
              color: isError ? const Color(0xFFFFA0A0) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceOrb extends StatefulWidget {
  const _VoiceOrb({required this.isActive, required this.size});

  final bool isActive;
  final double size;

  @override
  State<_VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<_VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final pulse = _animationController.value;
        return Transform.scale(
          scale: widget.isActive ? 0.98 + pulse * 0.04 : 1,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _VoiceOrbPainter(
                phase: pulse,
                color: widget.isActive
                    ? const Color(0xFF69F0CB)
                    : const Color(0xFF36B99A),
              ),
              child: Center(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF1E806D), Color(0xFF0D302A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF50D6B6)
                            .withValues(alpha: widget.isActive ? 0.42 : 0.22),
                        blurRadius: 38,
                        spreadRadius: 8,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Color(0xFF9CF7DF),
                    size: 54,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VoiceOrbPainter extends CustomPainter {
  const _VoiceOrbPainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide * 0.18;
    for (var index = 0; index < 5; index++) {
      final radius = baseRadius + index * size.shortestSide * 0.055 + phase * 6;
      final opacity = (0.32 - index * 0.045).clamp(0.08, 0.32);
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = index == 0 ? 1.4 : 0.8;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_VoiceOrbPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
