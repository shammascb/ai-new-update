import 'package:flutter/foundation.dart';

abstract final class DeviceIds {
  static const livingRoomLight = 'living_room_light';
  static const bedroomFan = 'bedroom_fan';
  static const frontDoorLock = 'front_door_lock';
}

enum DeviceKind { light, fan, doorLock }

enum DeviceConnectivity { online, offline, degraded }

extension DeviceConnectivityX on DeviceConnectivity {
  String get label => switch (this) {
        DeviceConnectivity.online => 'Online',
        DeviceConnectivity.offline => 'Offline',
        DeviceConnectivity.degraded => 'Degraded',
      };
}

enum DeviceCommandStatus { succeeded, failed }

extension DeviceCommandStatusX on DeviceCommandStatus {
  String get label => switch (this) {
        DeviceCommandStatus.succeeded => 'Succeeded',
        DeviceCommandStatus.failed => 'Failed',
      };
}

enum DeviceCommandSource {
  dashboard,
  devicesTab,
  automation,
  voice,
  esp32Sync,
}

extension DeviceCommandSourceX on DeviceCommandSource {
  String get label => switch (this) {
        DeviceCommandSource.dashboard => 'Dashboard',
        DeviceCommandSource.devicesTab => 'Devices tab',
        DeviceCommandSource.automation => 'Automation',
        DeviceCommandSource.voice => 'Voice',
        DeviceCommandSource.esp32Sync => 'ESP32 sync',
      };
}

@immutable
class MonitoredDevice {
  const MonitoredDevice({
    required this.deviceId,
    required this.name,
    required this.room,
    required this.kind,
    required this.connectivity,
    required this.currentStateLabel,
    required this.lastCommunicationAt,
    required this.endpointHint,
    this.rssiDbm,
    this.firmwareVersion,
    this.lastError,
  });

  final String deviceId;
  final String name;
  final String room;
  final DeviceKind kind;
  final DeviceConnectivity connectivity;
  final String currentStateLabel;
  final DateTime lastCommunicationAt;
  final String endpointHint;
  final int? rssiDbm;
  final String? firmwareVersion;
  final String? lastError;

  bool get isOnline => connectivity == DeviceConnectivity.online;

  MonitoredDevice copyWith({
    DeviceConnectivity? connectivity,
    String? currentStateLabel,
    DateTime? lastCommunicationAt,
    String? endpointHint,
    int? rssiDbm,
    String? firmwareVersion,
    String? lastError,
    bool clearLastError = false,
  }) {
    return MonitoredDevice(
      deviceId: deviceId,
      name: name,
      room: room,
      kind: kind,
      connectivity: connectivity ?? this.connectivity,
      currentStateLabel: currentStateLabel ?? this.currentStateLabel,
      lastCommunicationAt: lastCommunicationAt ?? this.lastCommunicationAt,
      endpointHint: endpointHint ?? this.endpointHint,
      rssiDbm: rssiDbm ?? this.rssiDbm,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

@immutable
class DeviceCommandLog {
  const DeviceCommandLog({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.command,
    required this.status,
    required this.source,
    required this.timestamp,
    this.latencyMs,
    this.errorMessage,
  });

  final String id;
  final String deviceId;
  final String deviceName;
  final String command;
  final DeviceCommandStatus status;
  final DeviceCommandSource source;
  final DateTime timestamp;
  final int? latencyMs;
  final String? errorMessage;

  bool get isFailed => status == DeviceCommandStatus.failed;
}

@immutable
class DeviceConnectionError {
  const DeviceConnectionError({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.code,
    required this.message,
    required this.occurredAt,
    this.resolved = false,
  });

  final String id;
  final String deviceId;
  final String deviceName;
  final String code;
  final String message;
  final DateTime occurredAt;
  final bool resolved;

  DeviceConnectionError copyWith({bool? resolved}) {
    return DeviceConnectionError(
      id: id,
      deviceId: deviceId,
      deviceName: deviceName,
      code: code,
      message: message,
      occurredAt: occurredAt,
      resolved: resolved ?? this.resolved,
    );
  }
}

/// JSON-serializable status frame representing future ESP32 telemetry updates
/// delivered over MQTT, WebSocket, HTTP polling, or BLE.
@immutable
class Esp32StatusPayload {
  const Esp32StatusPayload({
    required this.deviceId,
    required this.online,
    required this.reportedState,
    required this.timestamp,
    this.rssiDbm,
    this.firmwareVersion,
    this.errorCode,
    this.errorMessage,
  });

  factory Esp32StatusPayload.fromJson(Map<String, Object?> json) {
    final rawState = json['reportedState'];
    final parsedState = <String, Object?>{};
    if (rawState is Map) {
      for (final entry in rawState.entries) {
        parsedState[entry.key.toString()] = entry.value;
      }
    }
    final rawTimestamp = json['timestamp'];
    DateTime parsedTime;
    if (rawTimestamp is String) {
      parsedTime = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else if (rawTimestamp is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else {
      parsedTime = DateTime.now();
    }

    return Esp32StatusPayload(
      deviceId: (json['deviceId'] as String?) ?? '',
      online: (json['online'] as bool?) ?? false,
      reportedState: parsedState,
      timestamp: parsedTime,
      rssiDbm: (json['rssiDbm'] as num?)?.toInt(),
      firmwareVersion: json['firmwareVersion'] as String?,
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  final String deviceId;
  final bool online;
  final Map<String, Object?> reportedState;
  final DateTime timestamp;
  final int? rssiDbm;
  final String? firmwareVersion;
  final String? errorCode;
  final String? errorMessage;

  Map<String, Object?> toJson() => {
        'deviceId': deviceId,
        'online': online,
        'reportedState': reportedState,
        'timestamp': timestamp.toIso8601String(),
        if (rssiDbm != null) 'rssiDbm': rssiDbm,
        if (firmwareVersion != null) 'firmwareVersion': firmwareVersion,
        if (errorCode != null) 'errorCode': errorCode,
        if (errorMessage != null) 'errorMessage': errorMessage,
      };
}

/// Clean transport contract for future ESP32 firmware status updates.
/// Replace [SimulatedEsp32Gateway] with an MQTT, WebSocket, or HTTP gateway
/// without modifying [DeviceMonitoringStore] or UI screens.
abstract interface class Esp32StatusGateway {
  Stream<Esp32StatusPayload> get statusUpdates;

  Future<void> requestDeviceRefresh(String deviceId);

  Future<void> publishCommand({
    required String deviceId,
    required String command,
    required Map<String, Object?> payload,
  });

  void dispose();
}

abstract class DeviceMonitoringStore extends ChangeNotifier {
  List<MonitoredDevice> get devices;
  List<DeviceCommandLog> get commandHistory;
  List<DeviceCommandLog> get failedCommands;
  List<DeviceConnectionError> get connectionErrors;
  List<DeviceConnectionError> get activeConnectionErrors;
  bool get isSimulationMode;
  bool get isRefreshing;
  DateTime? get lastGlobalSyncAt;

  int get onlineCount;
  int get offlineCount;

  MonitoredDevice? deviceById(String deviceId);
  bool isDeviceOffline(String deviceId);

  Future<void> refreshAllDevices();
  Future<void> refreshDevice(String deviceId);

  void applyEsp32StatusUpdate(Esp32StatusPayload payload);

  void recordCommand({
    required String deviceId,
    required String command,
    required DeviceCommandStatus status,
    required DeviceCommandSource source,
    int? latencyMs,
    String? errorMessage,
  });

  void recordConnectionError({
    required String deviceId,
    required String code,
    required String message,
  });

  void resolveConnectionError(String errorId);

  void simulateDeviceConnectivity(
    String deviceId, {
    required bool online,
    String? errorCode,
    String? errorMessage,
  });
}
