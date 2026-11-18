import 'package:ai_home_brain/features/automations/data/automation_routine_store.dart';
import 'package:ai_home_brain/features/automations/domain/automation_routine.dart';
import 'package:ai_home_brain/features/automations/domain/automation_routine_executor.dart';
import 'package:ai_home_brain/features/automations/presentation/automations_screen.dart';
import 'package:ai_home_brain/features/devices/data/simulated_device_control_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutomationRoutine defaults and executor', () {
    test('Sleep, Morning, and Away have expected default configurations', () {
      final sleep = AutomationRoutine.defaultFor(RoutineId.sleep);
      expect(sleep.lightAction, BinaryDeviceAction.turnOff);
      expect(sleep.fanAction, BinaryDeviceAction.turnOff);
      expect(sleep.doorAction, DoorRoutineAction.lockWithSafetyCheck);

      final morning = AutomationRoutine.defaultFor(RoutineId.morning);
      expect(morning.lightAction, BinaryDeviceAction.turnOn);
      expect(morning.fanAction, BinaryDeviceAction.turnOn);
      expect(morning.doorAction, DoorRoutineAction.keepLocked);

      final away = AutomationRoutine.defaultFor(RoutineId.away);
      expect(away.lightAction, BinaryDeviceAction.turnOff);
      expect(away.fanAction, BinaryDeviceAction.turnOff);
      expect(away.doorAction, DoorRoutineAction.lockWithSafetyCheck);
    });

    test('Sleep Mode blocks door lock when door sensor is open', () async {
      final devices = SimulatedDeviceControlService();
      await devices.setLight(true);
      await devices.setFan(true);
      await devices.setDoorLocked(false);
      await devices.setDoorOpen(true);

      final sleep = AutomationRoutine.defaultFor(RoutineId.sleep);
      final planned = sleep.buildPlannedActions(devices.state);
      expect(planned.last.isSafetyBlocked, isTrue);

      final report = await const AutomationRoutineExecutor().execute(
        routine: sleep,
        deviceControlService: devices,
        doorSafetyConfirmed: true,
      );

      expect(devices.state.lightOn, isFalse);
      expect(devices.state.fanOn, isFalse);
      expect(devices.state.doorLocked, isFalse);
      expect(report.overallStatusLabel, 'Completed with skipped steps');
      expect(report.steps[2].status, StepCompletionStatus.skipped);
    });

    test('Away Mode skips lock without safety confirmation, locks when confirmed',
        () async {
      final devices = SimulatedDeviceControlService();
      await devices.setLight(true);
      await devices.setFan(true);
      await devices.setDoorLocked(false);
      await devices.setDoorOpen(false);

      final away = AutomationRoutine.defaultFor(RoutineId.away);

      final unconfirmedReport = await const AutomationRoutineExecutor().execute(
        routine: away,
        deviceControlService: devices,
        doorSafetyConfirmed: false,
      );
      expect(devices.state.doorLocked, isFalse);
      expect(
        unconfirmedReport.steps[2].status,
        StepCompletionStatus.skipped,
      );

      final confirmedReport = await const AutomationRoutineExecutor().execute(
        routine: away,
        deviceControlService: devices,
        doorSafetyConfirmed: true,
      );
      expect(devices.state.doorLocked, isTrue);
      expect(confirmedReport.overallStatusLabel, 'Completed');
      expect(confirmedReport.steps[2].status, StepCompletionStatus.completed);
    });

    test('Morning Mode turns on light and fan and verifies door remains locked',
        () async {
      final devices = SimulatedDeviceControlService();
      await devices.setLight(false);
      await devices.setFan(false);
      await devices.setDoorLocked(true);

      final morning = AutomationRoutine.defaultFor(RoutineId.morning);
      final report = await const AutomationRoutineExecutor().execute(
        routine: morning,
        deviceControlService: devices,
        doorSafetyConfirmed: true,
      );

      expect(devices.state.lightOn, isTrue);
      expect(devices.state.fanOn, isTrue);
      expect(devices.state.fanSpeed, morning.fanSpeed);
      expect(devices.state.doorLocked, isTrue);
      expect(report.overallStatusLabel, 'Completed');
      expect(report.steps[2].status, StepCompletionStatus.verified);
    });

    test('AutomationRoutineStore supports customizing and resetting routines',
        () async {
      final store = AutomationRoutineStore();
      addTearDown(store.dispose);

      final customMorning = store.routineFor(RoutineId.morning).copyWith(
            fanSpeed: 5,
            lightAction: BinaryDeviceAction.unchanged,
          );
      await store.saveRoutine(customMorning);

      expect(store.routineFor(RoutineId.morning).fanSpeed, 5);
      expect(
        store.routineFor(RoutineId.morning).lightAction,
        BinaryDeviceAction.unchanged,
      );

      await store.resetRoutine(RoutineId.morning);
      expect(store.routineFor(RoutineId.morning).fanSpeed, 2);
      expect(
        store.routineFor(RoutineId.morning).lightAction,
        BinaryDeviceAction.turnOn,
      );
    });
  });

  testWidgets(
      'AutomationsScreen supports 3-screen customization, preview before execution, and completion status',
      (WidgetTester tester) async {
    final devices = SimulatedDeviceControlService();
    await devices.setLight(true);
    await devices.setFan(true);
    await devices.setDoorLocked(true);

    final store = AutomationRoutineStore();
    addTearDown(() {
      store.dispose();
      devices.dispose();
    });

    var activatedMode = 'Home';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AutomationsScreen(
            routineStore: store,
            deviceControlService: devices,
            activeModeLabel: activatedMode,
            onModeActivated: (mode) => activatedMode = mode,
          ),
        ),
      ),
    );

    expect(find.text('Smart Routines'), findsOneWidget);
    expect(find.text('Sleep Mode'), findsOneWidget);
    expect(find.text('Morning Mode'), findsOneWidget);

    // Navigate from Screen 1 card to Screen 2 (RoutineDetailScreen).
    await tester.tap(find.text('Sleep Mode'));
    await tester.pumpAndSettle();

    expect(find.text('Connected devices'), findsOneWidget);
    expect(find.text('Smart Light'), findsOneWidget);
    expect(find.text('Bedroom Fan'), findsOneWidget);
    expect(find.text('Front Door Lock'), findsOneWidget);

    // Navigate from Screen 2 orange '+' button to Screen 3 (AddDevicesScreen).
    await tester.tap(find.byTooltip('Add your devices'));
    await tester.pumpAndSettle();

    expect(find.text('Add your devices'), findsOneWidget);
    expect(find.text('Lighting'), findsOneWidget);
    expect(find.text('Climate'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);

    await tester.tap(find.text('Save Connected Devices (3)'));
    await tester.pumpAndSettle();

    // Preview & Execute Routine from Screen 2.
    await tester.tap(find.text('Preview & Execute Routine'));
    await tester.pumpAndSettle();

    expect(find.text('Preview Sleep Mode'), findsOneWidget);
    expect(
      find.text('Review the actions below before execution:'),
      findsOneWidget,
    );

    await tester.tap(find.text('Execute Routine'));
    await tester.pumpAndSettle();

    expect(find.text('Sleep Mode Status'), findsOneWidget);
    expect(find.text('Overall status: Completed'), findsOneWidget);
    expect(devices.state.lightOn, isFalse);
    expect(devices.state.fanOn, isFalse);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(activatedMode, 'Sleep');
    expect(find.text('Last Execution Status'), findsOneWidget);
  });
}
