import 'package:flutter/foundation.dart';

import 'device_state.dart';

abstract class DeviceControlService extends ChangeNotifier {
  DeviceState get state;

  Future<void> setLight(bool isOn);
  Future<void> setFan(bool isOn);
  Future<void> setFanSpeed(int speed);
  Future<void> setDoorLocked(bool isLocked);
  Future<void> setDoorOpen(bool isOpen);
}
