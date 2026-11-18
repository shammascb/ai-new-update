import 'dart:async';

import '../domain/device_control_service.dart';
import '../domain/device_monitoring.dart';

/// Simulated implementation of [Esp32StatusGateway] that emits [Esp32StatusPayload]
/// frames over a broadcast stream using the same contract a future ESP32
/// MQTT/WebSocket/HTTP client will fulfill.
class SimulatedEsp32Gateway implements Esp32StatusGateway {
  SimulatedEsp32Gateway({required DeviceControlService deviceControlService})
      : _deviceControlService = deviceControlService;

  final DeviceControlService _deviceControlService;
  final StreamController<Esp32StatusPayload> _controller =
      StreamController<Esp32StatusPayload>.broadcast();
  final Map<String, bool> _simulatedOnlineOverrides = {};

  @override
  Stream<Esp32StatusPayload> get statusUpdates => _controller.stream;

  void setSimulatedOnline(String deviceId, bool online) {
    _simulatedOnlineOverrides[deviceId] = online;
  }

  void emitSimulatedUpdate(Esp32StatusPayload payload) {
    _simulatedOnlineOverrides[payload.deviceId] = payload.online;
    if (!_controller.isClosed) {
      _controller.add(payload);
    }
  }

  @override
  Future<void> requestDeviceRefresh(String deviceId) async {
    final online = _simulatedOnlineOverrides[deviceId] ?? true;
    final state = _deviceControlService.state;
    final reportedState = switch (deviceId) {
      DeviceIds.livingRoomLight => <String, Object?>{'lightOn': state.lightOn},
      DeviceIds.bedroomFan => <String, Object?>{
          'fanOn': state.fanOn,
          'fanSpeed': state.fanSpeed,
        },
      DeviceIds.frontDoorLock => <String, Object?>{
          'doorLocked': state.doorLocked,
          'doorOpen': state.doorOpen,
        },
      _ => <String, Object?>{},
    };

    emitSimulatedUpdate(
      Esp32StatusPayload(
        deviceId: deviceId,
        online: online,
        reportedState: reportedState,
        timestamp: DateTime.now(),
        rssiDbm: online ? -58 : null,
        firmwareVersion: 'esp32-sim-1.0',
        errorCode: online ? null : 'ERR_HEARTBEAT_TIMEOUT',
        errorMessage: online
            ? null
            : 'Simulated ESP32 node did not respond to status ping.',
      ),
    );
  }

  @override
  Future<void> publishCommand({
    required String deviceId,
    required String command,
    required Map<String, Object?> payload,
  }) async {
    final online = _simulatedOnlineOverrides[deviceId] ?? true;
    if (!online) {
      throw StateError('Simulated ESP32 node $deviceId is offline.');
    }
  }

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}
