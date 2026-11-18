import '../domain/device_control_exception.dart';
import '../domain/device_control_service.dart';
import '../domain/device_monitoring.dart';
import '../domain/device_state.dart';

class SimulatedDeviceControlService extends DeviceControlService {
  SimulatedDeviceControlService({
    bool Function(String deviceId)? isDeviceOffline,
  }) : _isDeviceOffline = isDeviceOffline;

  DeviceState _state = const DeviceState();
  bool Function(String deviceId)? _isDeviceOffline;

  void setDeviceOfflineChecker(bool Function(String deviceId)? checker) {
    _isDeviceOffline = checker;
  }

  @override
  DeviceState get state => _state;

  void _requireOnline(String deviceId, String label) {
    if (_isDeviceOffline?.call(deviceId) ?? false) {
      throw DeviceControlException(
        '$label is currently offline (simulated ESP32 unreachable).',
      );
    }
  }

  @override
  Future<void> setLight(bool isOn) async {
    _requireOnline(DeviceIds.livingRoomLight, 'Living Room Light');
    _update(_state.copyWith(lightOn: isOn));
  }

  @override
  Future<void> setFan(bool isOn) async {
    _requireOnline(DeviceIds.bedroomFan, 'Bedroom Fan');
    _update(_state.copyWith(fanOn: isOn));
  }

  @override
  Future<void> setFanSpeed(int speed) async {
    if (speed < 1 || speed > 5) {
      throw RangeError.range(speed, 1, 5, 'speed');
    }
    _requireOnline(DeviceIds.bedroomFan, 'Bedroom Fan');
    _update(_state.copyWith(fanSpeed: speed));
  }

  @override
  Future<void> setDoorLocked(bool isLocked) async {
    _requireOnline(DeviceIds.frontDoorLock, 'Front Entry Door');
    _update(_state.copyWith(doorLocked: isLocked));
  }

  @override
  Future<void> setDoorOpen(bool isOpen) async {
    _requireOnline(DeviceIds.frontDoorLock, 'Front Entry Door');
    _update(_state.copyWith(doorOpen: isOpen));
  }

  void _update(DeviceState state) {
    _state = state;
    notifyListeners();
  }
}
