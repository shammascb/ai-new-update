import 'voice_command.dart';

class VoiceCommandInterpretationException implements Exception {
  const VoiceCommandInterpretationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class VoiceCommandInterpreter {
  Future<VoiceCommand> interpret(String transcript);
}
