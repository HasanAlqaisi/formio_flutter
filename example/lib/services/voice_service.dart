/// VoiceService — Text-to-Speech and Speech-to-Text wrapper.
///
/// Manages flutter_tts and speech_to_text lifecycle, providing
/// a simple API for speaking questions and listening for answers.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Current state of the voice system.
enum VoiceState { idle, speaking, listening, processing }

class VoiceService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  VoiceState _state = VoiceState.idle;
  bool _sttAvailable = false;
  String _lastRecognizedText = '';
  double _soundLevel = 0.0;
  String _selectedLocaleId = 'tr_TR';
  VoidCallback? _onSilence;

  /// Current voice state.
  VoiceState get state => _state;

  /// Whether speech-to-text is available.
  bool get isSttAvailable => _sttAvailable;

  /// Last recognized text from STT.
  String get lastRecognizedText => _lastRecognizedText;

  /// Current sound level (0.0 to ~10.0) for visual feedback.
  double get soundLevel => _soundLevel;

  /// Whether the service is currently busy (speaking or listening).
  bool get isBusy => _state != VoiceState.idle;

  /// Initialize TTS and STT engines.
  Future<void> initialize() async {
    // ── TTS Setup ──
    await _tts.setLanguage(_selectedLocaleId);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _state = VoiceState.idle;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      if (kDebugMode) print('🔊 TTS Error: $msg');
      _state = VoiceState.idle;
      notifyListeners();
    });

    // ── STT Setup ──
    _sttAvailable = await _stt.initialize(
      onError: (errorNotification) {
        if (kDebugMode) print('🎤 STT Error: ${errorNotification.errorMsg}');
        _state = VoiceState.idle;
        notifyListeners();
      },
      onStatus: (status) {
        if (kDebugMode) print('🎤 STT Status: $status');
        if (status == 'done' || status == 'notListening') {
          if (_state == VoiceState.listening) {
            // Listening ended — check if anything was recognized
            if (_lastRecognizedText.trim().isEmpty) {
              // No speech detected → silence timeout
              if (kDebugMode) print('🎤 Silence detected, no speech');
              _onSilence?.call();
            }
            _state = VoiceState.idle;
            notifyListeners();
          }
        }
      },
    );

    if (kDebugMode) {
      print('🔊 TTS initialized');
      print('🎤 STT available: $_sttAvailable');

      // List available locales for debugging
      final locales = await _stt.locales();
      for (final locale in locales) {
        if (locale.localeId.startsWith('tr')) {
          print('🎤 Found Turkish locale: ${locale.localeId} - ${locale.name}');
          _selectedLocaleId = locale.localeId;
        }
      }
    }
  }

  /// Speak the given text using TTS.
  Future<void> speak(String text) async {
    if (_state == VoiceState.listening) {
      await stopListening();
    }

    _state = VoiceState.speaking;
    notifyListeners();

    await _tts.speak(text);
  }

  /// Stop TTS if currently speaking.
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _state = VoiceState.idle;
    notifyListeners();
  }

  /// Start listening for user speech.
  ///
  /// [onResult] is called when a final recognition result is available.
  /// [onSilence] is called when listening ends with no speech detected.
  Future<void> startListening({
    required ValueChanged<String> onResult,
    VoidCallback? onSilence,
  }) async {
    if (!_sttAvailable) {
      if (kDebugMode) print('🎤 STT not available');
      return;
    }

    if (_state == VoiceState.speaking) {
      await stopSpeaking();
      // Small delay to ensure TTS has fully stopped
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _lastRecognizedText = '';
    _state = VoiceState.listening;
    _onSilence = onSilence;
    notifyListeners();

    await _stt.listen(
      onResult: (SpeechRecognitionResult result) {
        _lastRecognizedText = result.recognizedWords;
        notifyListeners();

        if (result.finalResult) {
          _state = VoiceState.processing;
          notifyListeners();
          onResult(result.recognizedWords);
        }
      },
      // Allow very long speech — no hard cutoff
      listenFor: const Duration(minutes: 5),
      // Stop after 5 seconds of silence (user finished speaking)
      pauseFor: const Duration(seconds: 5),
      localeId: _selectedLocaleId,
      onSoundLevelChange: (level) {
        _soundLevel = level;
        notifyListeners();
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        autoPunctuation: true,
      ),
    );
  }

  /// Stop listening for speech.
  Future<void> stopListening() async {
    await _stt.stop();
    _state = VoiceState.idle;
    notifyListeners();
  }

  /// Cancel any ongoing operations.
  Future<void> cancel() async {
    await _tts.stop();
    await _stt.cancel();
    _state = VoiceState.idle;
    _soundLevel = 0.0;
    notifyListeners();
  }

  /// Set the state back to idle (for external state management).
  void setIdle() {
    _state = VoiceState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.cancel();
    super.dispose();
  }
}
