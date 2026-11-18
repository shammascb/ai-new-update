import 'package:flutter/foundation.dart';

@immutable
class DeviceState {
  const DeviceState({
    this.lightOn = false,
    this.fanOn = false,
    this.fanSpeed = 2,
    this.doorLocked = true,
    this.doorOpen = false,
  });

  final bool lightOn;
  final bool fanOn;
  final int fanSpeed;
  final bool doorLocked;
  final bool doorOpen;

  DeviceState copyWith({
    bool? lightOn,
    bool? fanOn,
    int? fanSpeed,
    bool? doorLocked,
    bool? doorOpen,
  }) {
    return DeviceState(
      lightOn: lightOn ?? this.lightOn,
      fanOn: fanOn ?? this.fanOn,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      doorLocked: doorLocked ?? this.doorLocked,
      doorOpen: doorOpen ?? this.doorOpen,
    );
  }
}
