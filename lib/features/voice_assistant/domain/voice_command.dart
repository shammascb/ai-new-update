enum VoiceAction {
  sleepMode,
  morningMode,
  awayMode,
  turnLightOn,
  turnLightOff,
  turnFanOn,
  turnFanOff,
  lockDoor,
  unlockDoorBlocked,
  openLivingRoom,
  openBedroom,
  unsupported,
}

class VoiceCommand {
  const VoiceCommand(this.action);

  factory VoiceCommand.fromModelAction(String action) {
    return VoiceCommand(
      switch (action) {
        'sleep_mode' => VoiceAction.sleepMode,
        'morning_mode' => VoiceAction.morningMode,
        'away_mode' => VoiceAction.awayMode,
        'turn_light_on' => VoiceAction.turnLightOn,
        'turn_light_off' => VoiceAction.turnLightOff,
        'turn_fan_on' => VoiceAction.turnFanOn,
        'turn_fan_off' => VoiceAction.turnFanOff,
        'lock_door' => VoiceAction.lockDoor,
        'unlock_door' => VoiceAction.unlockDoorBlocked,
        'open_living_room' => VoiceAction.openLivingRoom,
        'open_bedroom' => VoiceAction.openBedroom,
        _ => VoiceAction.unsupported,
      },
    );
  }

  final VoiceAction action;

  bool get requiresConfirmation => action == VoiceAction.lockDoor;

  bool get isExecutable =>
      action != VoiceAction.unlockDoorBlocked &&
      action != VoiceAction.openLivingRoom &&
      action != VoiceAction.openBedroom &&
      action != VoiceAction.unsupported;

  String get description => switch (action) {
        VoiceAction.sleepMode =>
          'Sleep routine: turn the light and fan off; leave the door unchanged.',
        VoiceAction.morningMode =>
          'Morning routine: turn the light on and fan off; leave the door '
              'unchanged.',
        VoiceAction.awayMode =>
          'Away routine: turn the light and fan off. If the door is closed, '
              'ask before locking; if open, do not lock.',
        VoiceAction.turnLightOn => 'Turn the simulated light on.',
        VoiceAction.turnLightOff => 'Turn the simulated light off.',
        VoiceAction.turnFanOn => 'Turn the simulated fan on.',
        VoiceAction.turnFanOff => 'Turn the simulated fan off.',
        VoiceAction.lockDoor => 'Lock the simulated door.',
        VoiceAction.unlockDoorBlocked =>
          'Door unlocking is never available by voice. Use the manual Unlock '
              'button and confirm with your phone PIN or biometrics.',
        VoiceAction.openLivingRoom => 'Open the Living Room controls.',
        VoiceAction.openBedroom => 'Open the Bedroom controls.',
        VoiceAction.unsupported =>
          'I did not recognize that command. Try a supported device, routine, '
              'or room command.',
      };
}

VoiceCommand? resolveRoomNavigationCommand(String transcript) {
  final normalized = transcript
      .toLowerCase()
      .replaceAll("don't", 'do not')
      .replaceAll('dont', 'do not')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (RegExp(r'\b(dont|do not|never|not)\b').hasMatch(normalized) ||
      !RegExp(r'\b(open|show|go|navigate|take)\b').hasMatch(normalized)) {
    return null;
  }

  if (RegExp(r'\bliving room\b').hasMatch(normalized)) {
    return const VoiceCommand(VoiceAction.openLivingRoom);
  }
  if (RegExp(r'\bbedroom\b').hasMatch(normalized)) {
    return const VoiceCommand(VoiceAction.openBedroom);
  }
  return null;
}
