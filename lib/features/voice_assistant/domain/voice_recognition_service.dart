import 'package:flutter/foundation.dart';

abstract interface class VoiceRecognitionService {
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onError,
  });

  Future<void> listen({
    required void Function(String transcript, bool isFinal) onResult,
  });

  Future<void> stop();
}
