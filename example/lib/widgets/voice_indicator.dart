/// Animated voice indicator widget.
///
/// Shows a pulsating wave animation when listening for speech,
/// and a static indicator when idle.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/voice_service.dart';

class VoiceIndicator extends StatefulWidget {
  final VoiceState voiceState;
  final double soundLevel;

  const VoiceIndicator({
    super.key,
    required this.voiceState,
    this.soundLevel = 0.0,
  });

  @override
  State<VoiceIndicator> createState() => _VoiceIndicatorState();
}

class _VoiceIndicatorState extends State<VoiceIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.voiceState == VoiceState.idle) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _getBackgroundColor(theme).withAlpha(230),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _getBackgroundColor(theme).withAlpha(50),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(theme),
              const SizedBox(width: 10),
              _buildWaveBars(theme),
              const SizedBox(width: 10),
              Text(
                _getStatusText(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIcon(ThemeData theme) {
    final icon = switch (widget.voiceState) {
      VoiceState.speaking => Icons.volume_up_rounded,
      VoiceState.listening => Icons.mic_rounded,
      VoiceState.processing => Icons.hourglass_top_rounded,
      VoiceState.idle => Icons.mic_none_rounded,
    };

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = widget.voiceState == VoiceState.listening
            ? 1.0 + (_pulseController.value * 0.2)
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: Icon(icon, color: Colors.white, size: 20),
        );
      },
    );
  }

  Widget _buildWaveBars(ThemeData theme) {
    return SizedBox(
      width: 40,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) {
          return AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              final phase = index * 0.2;
              final amplitude = widget.voiceState == VoiceState.listening
                  ? (widget.soundLevel.clamp(0.0, 10.0) / 10.0) * 0.6 + 0.4
                  : 0.5;
              final height = 4.0 +
                  (math.sin(_waveController.value * 2 * math.pi +
                          phase * math.pi) *
                      8.0 *
                      amplitude);
              return Container(
                width: 3,
                height: height.abs().clamp(3.0, 18.0),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(200),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Color _getBackgroundColor(ThemeData theme) {
    return switch (widget.voiceState) {
      VoiceState.speaking => theme.colorScheme.tertiary,
      VoiceState.listening => theme.colorScheme.error,
      VoiceState.processing => theme.colorScheme.secondary,
      VoiceState.idle => theme.colorScheme.surfaceContainerHighest,
    };
  }

  String _getStatusText() {
    return switch (widget.voiceState) {
      VoiceState.speaking => 'Konuşuyor...',
      VoiceState.listening => 'Dinliyor...',
      VoiceState.processing => 'İşleniyor...',
      VoiceState.idle => '',
    };
  }
}
