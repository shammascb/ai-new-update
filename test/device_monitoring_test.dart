import 'package:ai_home_brain/features/automations/data/automation_routine_store.dart';
import 'package:ai_home_brain/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ai_home_brain/features/devices/data/simulated_device_control_service.dart';
import 'package:ai_home_brain/features/devices/data/simulated_device_monitoring_store.dart';
import 'package:ai_home_brain/features/devices/data/simulated_esp32_gateway.dart';
import 'package:ai_home_brain/features/devices/domain/device_control_exception.dart';
import 'package:ai_home_brain/features/devices/domain/device_monitoring.dart';
import 'package:ai_home_brain/features/devices/domain/door_unlock_authenticator.dart';
import 'package:ai_home_brain/features/devices/presentation/device_monitoring_screen.dart';
import 'package:ai_home_brain/features/family/data/family_management_store.dart';
import 'package:ai_home_brain/features/voice_assistant/domain/voice_recognition_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDoorAuthenticator implements DoorUnlockAuthenticator {
  @override
  Future<bool> authenticateForDoorUnlock() async => true;
}

class _FakeVoiceRecognitionService implements VoiceRecognitionService {
  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  }) async =>
      true;

  @override
  Future<void> listen({
    required void Function(String transcript, bool isFinal) onResult,
  }) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  group('Device monitoring & ESP32 gateway contract', () {
    test('Esp32StatusPayload serializes and parses cleanly', () {
      final now = DateTime.utc(2026, 11, 17, 10, 30, 0);
      final payload = Esp32StatusPayload(
        deviceId: DeviceIds.livingRoomLight,
        online: false,
        reportedState: const {'lightOn': true},
        timestamp: now,
        rssiDbm: -88,
        firmwareVersion: 'esp32-1.2.0',
        errorCode: 'ERR_MQTT_LOST',
        errorMessage: 'Lost Wi-Fi connection',
      );

      final parsed = Esp32StatusPayload.fromJson(payload.toJson());
      expect(parsed.deviceId, DeviceIds.livingRoomLight);
      expect(parsed.online, isFalse);
      expect(parsed.reportedState['lightOn'], isTrue);
      expect(parsed.timestamp.toUtc(), now);
      expect(parsed.rssiDbm, -88);
      expect(parsed.firmwareVersion, 'esp32-1.2.0');
      expect(parsed.errorCode, 'ERR_MQTT_LOST');
      expect(parsed.errorMessage, 'Lost Wi-Fi connection');
    });

    test('SimulatedDeviceMonitoringStore ingests Esp32StatusGateway stream updates',
        () async {
      final control = SimulatedDeviceControlService();
      final gateway = SimulatedEsp32Gateway(deviceControlService: control);
      final store = SimulatedDeviceMonitoringStore(
        deviceControlService: control,
        esp32Gateway: gateway,
        seedInitialTelemetry: false,
      );
      control.setDeviceOfflineChecker(store.isDeviceOffline);
      addTearDown(() {
        store.dispose();
        gateway.dispose();
        control.dispose();
      });

      expect(store.onlineCount, 3);
      expect(store.offlineCount, 0);

      // Push an ESP32 offline status frame via the gateway stream
      gateway.emitSimulatedUpdate(
        Esp32StatusPayload(
          deviceId: DeviceIds.bedroomFan,
          online: false,
          reportedState: const {'fanOn': false, 'fanSpeed': 2},
          timestamp: DateTime.now(),
          errorCode: 'ERR_HEARTBEAT_TIMEOUT',
          errorMessage: 'ESP32 node did not respond to keepalive.',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.onlineCount, 2);
      expect(store.offlineCount, 1);
      expect(store.isDeviceOffline(DeviceIds.bedroomFan), isTrue);
      expect(store.activeConnectionErrors.length, 1);
      expect(
        store.activeConnectionErrors.first.code,
        'ERR_HEARTBEAT_TIMEOUT',
      );

      // Attempting a command on the offline device throws DeviceControlException
      await expectLater(
        () => control.setFan(true),
        throwsA(isA<DeviceControlException>()),
      );

      // Bring node back online via ESP32 status packet
      gateway.emitSimulatedUpdate(
        Esp32StatusPayload(
          deviceId: DeviceIds.bedroomFan,
          online: true,
          reportedState: const {'fanOn': true, 'fanSpeed': 4},
          timestamp: DateTime.now(),
          rssiDbm: -55,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.onlineCount, 3);
      expect(store.activeConnectionErrors, isEmpty);
      expect(
        store.deviceById(DeviceIds.bedroomFan)?.currentStateLabel,
        'ON · Speed 4/5',
      );
    });
  });

  group('DeviceMonitoringScreen & Dashboard integration', () {
    testWidgets(
        'DeviceMonitoringScreen displays online/offline, communication time, state, commands, failed commands, and connection errors',
        (WidgetTester tester) async {
      final control = SimulatedDeviceControlService();
      final store = SimulatedDeviceMonitoringStore(
        deviceControlService: control,
      );
      control.setDeviceOfflineChecker(store.isDeviceOffline);
      addTearDown(() {
        store.dispose();
        control.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceMonitoringScreen(store: store),
        ),
      );

      expect(find.text('Device Monitoring'), findsOneWidget);
      expect(find.text('Living Room Light'), findsOneWidget);
      expect(find.text('Bedroom Fan'), findsOneWidget);
      expect(find.text('Front Entry Door'), findsOneWidget);
      expect(find.text('Online'), findsNWidgets(4));
      expect(find.text('Last communication'), findsNWidgets(3));
      expect(find.text('Current state'), findsNWidgets(3));

      // Toggle Living Room Light offline in simulation
      await tester.tap(find.text('Simulate offline').first);
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsNWidgets(2));

      // Switch to Commands tab and filter Failed commands
      await tester.tap(find.textContaining('Commands ('));
      await tester.pumpAndSettle();
      expect(find.text('Command history'), findsOneWidget);

      await tester.tap(find.textContaining('Failed ('));
      await tester.pumpAndSettle();
      expect(find.text('Set Fan Speed 4'), findsOneWidget);

      // Switch to Errors tab and resolve active error
      await tester.tap(find.textContaining('Errors ('));
      await tester.pumpAndSettle();
      expect(find.textContaining('Failed commands ('), findsOneWidget);
      expect(find.textContaining('Connection errors ('), findsOneWidget);
      expect(find.text('Resolve'), findsAtLeastNWidgets(1));

      ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resolve').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Resolved ·'), findsAtLeastNWidgets(1));
    });

    testWidgets(
        'Dashboard records device commands & failures into DeviceMonitoringScreen',
        (WidgetTester tester) async {
      final control = SimulatedDeviceControlService();
      final monitoring = SimulatedDeviceMonitoringStore(
        deviceControlService: control,
      );
      control.setDeviceOfflineChecker(monitoring.isDeviceOffline);
      final routineStore = AutomationRoutineStore();
      final familyStore = FamilyManagementStore();
      addTearDown(() {
        monitoring.dispose();
        routineStore.dispose();
        familyStore.dispose();
        control.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            isDarkMode: false,
            onThemeToggle: () {},
            accountAction: () {},
            accountLabel: 'owner@home.local',
            deviceControlService: control,
            doorUnlockAuthenticator: _FakeDoorAuthenticator(),
            voiceRecognitionService: _FakeVoiceRecognitionService(),
            voiceCommandInterpreter: null,
            routineStore: routineStore,
            familyStore: familyStore,
            monitoringStore: monitoring,
          ),
        ),
      );

      // Toggle Living room light on dashboard -> logs succeeded command
      await tester.tap(find.byKey(const ValueKey('light-power-toggle')));
      await tester.pumpAndSettle();
      expect(monitoring.commandHistory.first.command, 'Light ON');
      expect(
        monitoring.commandHistory.first.status,
        DeviceCommandStatus.succeeded,
      );

      // Dismiss SnackBar before tapping toggle again
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Mark Living Room Light offline, then try turning it off -> logs failed command + connection error
      monitoring.simulateDeviceConnectivity(
        DeviceIds.livingRoomLight,
        online: false,
      );
      await tester.tap(find.byKey(const ValueKey('light-power-toggle')));
      await tester.pumpAndSettle();
      expect(monitoring.commandHistory.first.command, 'Light OFF');
      expect(
        monitoring.commandHistory.first.status,
        DeviceCommandStatus.failed,
      );
      expect(
        monitoring.activeConnectionErrors.first.deviceId,
        DeviceIds.livingRoomLight,
      );

      // Open Device Monitoring via AppBar button
      await tester.tap(find.byTooltip('Device Monitoring'));
      await tester.pumpAndSettle();
      expect(find.text('Device Monitoring'), findsOneWidget);
      expect(find.text('Offline'), findsNWidgets(2));
    });
  });
}
