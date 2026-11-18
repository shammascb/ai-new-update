import 'dart:async';

import '../domain/device_control_service.dart';
import '../domain/device_monitoring.dart';
import '../domain/device_state.dart';
import 'simulated_esp32_gateway.dart';

class SimulatedDeviceMonitoringStore extends DeviceMonitoringStore {
  SimulatedDeviceMonitoringStore({
    required DeviceControlService deviceControlService,
    Esp32StatusGateway? esp32Gateway,
    bool seedInitialTelemetry = true,
  })  : _deviceControlService = deviceControlService,
        _gateway = esp32Gateway ??
            SimulatedEsp32Gateway(deviceControlService: deviceControlService),
        _ownsGateway = esp32Gateway == null {
    final now = DateTime.now();
    _lastGlobalSyncAt = now;
    _devices = _buildInitialDevices(deviceControlService.state, now);

    if (seedInitialTelemetry) {
      _seedSimulatedHistory(now);
    }

    _deviceControlService.addListener(_onDeviceStateChanged);
    _gatewaySub = _gateway.statusUpdates.listen(applyEsp32StatusUpdate);
  }

  final DeviceControlService _deviceControlService;
  final Esp32StatusGateway _gateway;
  final bool _ownsGateway;
  StreamSubscription<Esp32StatusPayload>? _gatewaySub;

  late List<MonitoredDevice> _devices;
  final List<DeviceCommandLog> _commandHistory = [];
  final List<DeviceConnectionError> _connectionErrors = [];
  bool _isRefreshing = false;
  DateTime? _lastGlobalSyncAt;
  int _sequence = 0;

  @override
  List<MonitoredDevice> get devices => List.unmodifiable(_devices);

  @override
  List<DeviceCommandLog> get commandHistory => List.unmodifiable(_commandHistory);

  @override
  List<DeviceCommandLog> get failedCommands => List.unmodifiable(
        _commandHistory.where((entry) => entry.isFailed),
      );

  @override
  List<DeviceConnectionError> get connectionErrors =>
      List.unmodifiable(_connectionErrors);

  @override
  List<DeviceConnectionError> get activeConnectionErrors => List.unmodifiable(
        _connectionErrors.where((error) => !error.resolved),
      );

  @override
  bool get isSimulationMode => _gateway is SimulatedEsp32Gateway;

  @override
  bool get isRefreshing => _isRefreshing;

  @override
  DateTime? get lastGlobalSyncAt => _lastGlobalSyncAt;

  @override
  int get onlineCount => _devices.where((d) => d.isOnline).length;

  @override
  int get offlineCount => _devices.where((d) => !d.isOnline).length;

  @override
  MonitoredDevice? deviceById(String deviceId) {
    for (final device in _devices) {
      if (device.deviceId == deviceId) return device;
    }
    return null;
  }

  @override
  bool isDeviceOffline(String deviceId) {
    final device = deviceById(deviceId);
    if (device == null) return false;
    return device.connectivity == DeviceConnectivity.offline;
  }

  List<MonitoredDevice> _buildInitialDevices(DeviceState state, DateTime now) {
    return [
      MonitoredDevice(
        deviceId: DeviceIds.livingRoomLight,
        name: 'Living Room Light',
        room: 'Living room',
        kind: DeviceKind.light,
        connectivity: DeviceConnectivity.online,
        currentStateLabel: _formatLightState(state.lightOn),
        lastCommunicationAt: now.subtract(const Duration(seconds: 18)),
        endpointHint: 'esp32-living-01 · Simulated',
        rssiDbm: -56,
        firmwareVersion: 'esp32-sim-1.0',
      ),
      MonitoredDevice(
        deviceId: DeviceIds.bedroomFan,
        name: 'Bedroom Fan',
        room: 'Bedroom',
        kind: DeviceKind.fan,
        connectivity: DeviceConnectivity.online,
        currentStateLabel: _formatFanState(state.fanOn, state.fanSpeed),
        lastCommunicationAt: now.subtract(const Duration(seconds: 42)),
        endpointHint: 'esp32-bedroom-02 · Simulated',
        rssiDbm: -63,
        firmwareVersion: 'esp32-sim-1.0',
      ),
      MonitoredDevice(
        deviceId: DeviceIds.frontDoorLock,
        name: 'Front Entry Door',
        room: 'Front entry',
        kind: DeviceKind.doorLock,
        connectivity: DeviceConnectivity.online,
        currentStateLabel:
            _formatDoorState(state.doorLocked, state.doorOpen),
        lastCommunicationAt: now.subtract(const Duration(seconds: 9)),
        endpointHint: 'esp32-entry-03 · Simulated',
        rssiDbm: -51,
        firmwareVersion: 'esp32-sim-1.0',
      ),
    ];
  }

  void _seedSimulatedHistory(DateTime now) {
    _commandHistory.addAll([
      DeviceCommandLog(
        id: _nextId('cmd'),
        deviceId: DeviceIds.frontDoorLock,
        deviceName: 'Front Entry Door',
        command: 'Verify front door locked',
        status: DeviceCommandStatus.succeeded,
        source: DeviceCommandSource.esp32Sync,
        timestamp: now.subtract(const Duration(minutes: 2)),
        latencyMs: 38,
      ),
      DeviceCommandLog(
        id: _nextId('cmd'),
        deviceId: DeviceIds.bedroomFan,
        deviceName: 'Bedroom Fan',
        command: 'Set Fan Speed 4',
        status: DeviceCommandStatus.failed,
        source: DeviceCommandSource.dashboard,
        timestamp: now.subtract(const Duration(minutes: 9)),
        latencyMs: 2500,
        errorMessage:
            'Simulated ACK timeout from esp32-bedroom-02 after 2500 ms.',
      ),
      DeviceCommandLog(
        id: _nextId('cmd'),
        deviceId: DeviceIds.livingRoomLight,
        deviceName: 'Living Room Light',
        command: 'Sync initial light state',
        status: DeviceCommandStatus.succeeded,
        source: DeviceCommandSource.esp32Sync,
        timestamp: now.subtract(const Duration(minutes: 14)),
        latencyMs: 42,
      ),
    ]);

    _connectionErrors.add(
      DeviceConnectionError(
        id: _nextId('err'),
        deviceId: DeviceIds.bedroomFan,
        deviceName: 'Bedroom Fan',
        code: 'ERR_WIFI_RSSI_DROP',
        message:
            'Simulated packet drop (-84 dBm) caused a delayed ACK on esp32-bedroom-02.',
        occurredAt: now.subtract(const Duration(minutes: 9)),
        resolved: false,
      ),
    );
  }

  String _nextId(String prefix) {
    _sequence += 1;
    return '${prefix}_$_sequence';
  }

  void _onDeviceStateChanged() {
    final state = _deviceControlService.state;
    final now = DateTime.now();
    _devices = [
      for (final device in _devices)
        switch (device.deviceId) {
          DeviceIds.livingRoomLight => device.copyWith(
              currentStateLabel: _formatLightState(state.lightOn),
              lastCommunicationAt: device.isOnline ? now : null,
            ),
          DeviceIds.bedroomFan => device.copyWith(
              currentStateLabel: _formatFanState(state.fanOn, state.fanSpeed),
              lastCommunicationAt: device.isOnline ? now : null,
            ),
          DeviceIds.frontDoorLock => device.copyWith(
              currentStateLabel:
                  _formatDoorState(state.doorLocked, state.doorOpen),
              lastCommunicationAt: device.isOnline ? now : null,
            ),
          _ => device,
        },
    ];
    notifyListeners();
  }

  @override
  Future<void> refreshAllDevices() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      for (final device in _devices) {
        await _gateway.requestDeviceRefresh(device.deviceId);
      }
      _lastGlobalSyncAt = DateTime.now();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  @override
  Future<void> refreshDevice(String deviceId) async {
    await _gateway.requestDeviceRefresh(deviceId);
    _lastGlobalSyncAt = DateTime.now();
    notifyListeners();
  }

  /// Applies an incoming [Esp32StatusPayload] packet (simulated now, or from
  /// a real ESP32 MQTT/WebSocket/HTTP transport in the future).
  @override
  void applyEsp32StatusUpdate(Esp32StatusPayload payload) {
    final index = _devices.indexWhere((d) => d.deviceId == payload.deviceId);
    if (index == -1) return;

    final existing = _devices[index];
    final gateway = _gateway;
    if (gateway is SimulatedEsp32Gateway) {
      gateway.setSimulatedOnline(payload.deviceId, payload.online);
    }

    final nextStateLabel = _stateLabelFromPayload(
      deviceId: payload.deviceId,
      reportedState: payload.reportedState,
      fallback: existing.currentStateLabel,
    );

    final connectivity = !payload.online
        ? DeviceConnectivity.offline
        : (payload.errorCode != null
            ? DeviceConnectivity.degraded
            : DeviceConnectivity.online);

    final updated = existing.copyWith(
      connectivity: connectivity,
      currentStateLabel: nextStateLabel,
      lastCommunicationAt: payload.timestamp,
      rssiDbm: payload.rssiDbm ?? existing.rssiDbm,
      firmwareVersion: payload.firmwareVersion ?? existing.firmwareVersion,
      lastError: payload.errorMessage,
      clearLastError: payload.online && payload.errorMessage == null,
    );

    _devices = [
      for (var i = 0; i < _devices.length; i++) i == index ? updated : _devices[i],
    ];
    _lastGlobalSyncAt = payload.timestamp;

    if (!payload.online || payload.errorCode != null) {
      recordConnectionError(
        deviceId: payload.deviceId,
        code: payload.errorCode ?? 'ERR_NODE_OFFLINE',
        message: payload.errorMessage ??
            '${existing.name} reported offline via ESP32 status update.',
      );
    } else {
      for (var i = 0; i < _connectionErrors.length; i++) {
        final err = _connectionErrors[i];
        if (err.deviceId == payload.deviceId && !err.resolved) {
          _connectionErrors[i] = err.copyWith(resolved: true);
        }
      }
      notifyListeners();
    }
  }

  @override
  void recordCommand({
    required String deviceId,
    required String command,
    required DeviceCommandStatus status,
    required DeviceCommandSource source,
    int? latencyMs,
    String? errorMessage,
  }) {
    final device = deviceById(deviceId);
    final deviceName = device?.name ?? deviceId;
    final now = DateTime.now();

    _commandHistory.insert(
      0,
      DeviceCommandLog(
        id: _nextId('cmd'),
        deviceId: deviceId,
        deviceName: deviceName,
        command: command,
        status: status,
        source: source,
        timestamp: now,
        latencyMs: latencyMs ?? (status == DeviceCommandStatus.succeeded ? 44 : 2500),
        errorMessage: errorMessage,
      ),
    );
    if (_commandHistory.length > 60) {
      _commandHistory.removeRange(60, _commandHistory.length);
    }

    if (device != null && status == DeviceCommandStatus.succeeded) {
      _devices = [
        for (final item in _devices)
          item.deviceId == deviceId
              ? item.copyWith(lastCommunicationAt: now, clearLastError: true)
              : item,
      ];
    } else if (status == DeviceCommandStatus.failed &&
        errorMessage != null &&
        errorMessage.isNotEmpty) {
      recordConnectionError(
        deviceId: deviceId,
        code: 'ERR_COMMAND_FAILED',
        message: errorMessage,
      );
      return;
    }

    notifyListeners();
  }

  @override
  void recordConnectionError({
    required String deviceId,
    required String code,
    required String message,
  }) {
    final device = deviceById(deviceId);
    final deviceName = device?.name ?? deviceId;
    final now = DateTime.now();

    _connectionErrors.insert(
      0,
      DeviceConnectionError(
        id: _nextId('err'),
        deviceId: deviceId,
        deviceName: deviceName,
        code: code,
        message: message,
        occurredAt: now,
        resolved: false,
      ),
    );
    if (_connectionErrors.length > 40) {
      _connectionErrors.removeRange(40, _connectionErrors.length);
    }

    if (device != null) {
      _devices = [
        for (final item in _devices)
          item.deviceId == deviceId
              ? item.copyWith(lastError: message)
              : item,
      ];
    }
    notifyListeners();
  }

  @override
  void resolveConnectionError(String errorId) {
    final index = _connectionErrors.indexWhere((e) => e.id == errorId);
    if (index == -1) return;
    final target = _connectionErrors[index];
    _connectionErrors[index] = target.copyWith(resolved: true);

    final stillHasActiveForDevice = _connectionErrors.any(
      (e) => e.deviceId == target.deviceId && !e.resolved,
    );
    if (!stillHasActiveForDevice) {
      _devices = [
        for (final item in _devices)
          item.deviceId == target.deviceId
              ? item.copyWith(clearLastError: true)
              : item,
      ];
    }
    notifyListeners();
  }

  @override
  void simulateDeviceConnectivity(
    String deviceId, {
    required bool online,
    String? errorCode,
    String? errorMessage,
  }) {
    final gateway = _gateway;
    final device = deviceById(deviceId);
    if (device == null) return;

    final payload = Esp32StatusPayload(
      deviceId: deviceId,
      online: online,
      reportedState: const {},
      timestamp: DateTime.now(),
      rssiDbm: online ? -57 : null,
      firmwareVersion: device.firmwareVersion ?? 'esp32-sim-1.0',
      errorCode: online ? null : (errorCode ?? 'ERR_HEARTBEAT_TIMEOUT'),
      errorMessage: online
          ? null
          : (errorMessage ??
              '${device.name} marked offline in simulation (${device.endpointHint}).'),
    );

    if (gateway is SimulatedEsp32Gateway) {
      gateway.emitSimulatedUpdate(payload);
    } else {
      applyEsp32StatusUpdate(payload);
    }
  }

  String _formatLightState(bool lightOn) => lightOn ? 'ON' : 'OFF';

  String _formatFanState(bool fanOn, int speed) =>
      fanOn ? 'ON · Speed $speed/5' : 'OFF · Speed $speed/5';

  String _formatDoorState(bool locked, bool open) =>
      '${locked ? "Locked" : "Unlocked"} · ${open ? "Door open" : "Door closed"}';

  String _stateLabelFromPayload({
    required String deviceId,
    required Map<String, Object?> reportedState,
    required String fallback,
  }) {
    if (reportedState.isEmpty) return fallback;
    switch (deviceId) {
      case DeviceIds.livingRoomLight:
        final lightOn = reportedState['lightOn'];
        if (lightOn is bool) return _formatLightState(lightOn);
      case DeviceIds.bedroomFan:
        final fanOn = reportedState['fanOn'];
        final fanSpeed = reportedState['fanSpeed'];
        if (fanOn is bool || fanSpeed is num) {
          final current = _deviceControlService.state;
          return _formatFanState(
            fanOn is bool ? fanOn : current.fanOn,
            fanSpeed is num ? fanSpeed.toInt() : current.fanSpeed,
          );
        }
      case DeviceIds.frontDoorLock:
        final locked = reportedState['doorLocked'];
        final open = reportedState['doorOpen'];
        if (locked is bool || open is bool) {
          final current = _deviceControlService.state;
          return _formatDoorState(
            locked is bool ? locked : current.doorLocked,
            open is bool ? open : current.doorOpen,
          );
        }
    }
    return fallback;
  }

  @override
  void dispose() {
    _deviceControlService.removeListener(_onDeviceStateChanged);
    unawaited(_gatewaySub?.cancel());
    if (_ownsGateway) {
      _gateway.dispose();
    }
    super.dispose();
  }
}
