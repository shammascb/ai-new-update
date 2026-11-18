import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/voice_recognition_service.dart';

class PhoneVoiceRecognitionService implements VoiceRecognitionService {
  PhoneVoiceRecognitionService([SpeechToText? speech])
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onError,
  }) {
    return _speech.initialize(
      onStatus: onStatus,
      onError: (error) => onError(error.errorMsg),
    );
  }

  @override
  Future<void> listen({
    required void Function(String transcript, bool isFinal) onResult,
  }) {
    return _speech.listen(
      onResult: (result) => onResult(result.recognizedWords, result.finalResult),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}
