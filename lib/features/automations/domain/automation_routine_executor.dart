import '../../devices/domain/device_control_exception.dart';
import '../../devices/domain/device_control_service.dart';
import 'automation_routine.dart';

class AutomationRoutineExecutor {
  const AutomationRoutineExecutor();

  Future<RoutineExecutionReport> execute({
    required AutomationRoutine routine,
    required DeviceControlService deviceControlService,
    required bool doorSafetyConfirmed,
  }) async {
    final results = <RoutineStepResult>[];

    // 1. Living room light
    switch (routine.lightAction) {
      case BinaryDeviceAction.turnOn:
        try {
          await deviceControlService.setLight(true);
          results.add(
            const RoutineStepResult(
              deviceLabel: 'Living room light',
              plannedAction: 'Turn on light',
              status: StepCompletionStatus.completed,
              message: 'Light turned ON (simulated).',
            ),
          );
        } on DeviceControlException catch (error) {
          results.add(
            RoutineStepResult(
              deviceLabel: 'Living room light',
              plannedAction: 'Turn on light',
              status: StepCompletionStatus.failed,
              message: 'Failed to turn on light: ${error.message}',
            ),
          );
        }
      case BinaryDeviceAction.turnOff:
        try {
          await deviceControlService.setLight(false);
          results.add(
            const RoutineStepResult(
              deviceLabel: 'Living room light',
              plannedAction: 'Turn off light',
              status: StepCompletionStatus.completed,
              message: 'Light turned OFF (simulated).',
            ),
          );
        } on DeviceControlException catch (error) {
          results.add(
            RoutineStepResult(
              deviceLabel: 'Living room light',
              plannedAction: 'Turn off light',
              status: StepCompletionStatus.failed,
              message: 'Failed to turn off light: ${error.message}',
            ),
          );
        }
      case BinaryDeviceAction.unchanged:
        results.add(
          RoutineStepResult(
            deviceLabel: 'Living room light',
            plannedAction: 'Leave light unchanged',
            status: StepCompletionStatus.skipped,
            message:
                'Left unchanged (${deviceControlService.state.lightOn ? "ON" : "OFF"}).',
          ),
        );
    }

    // 2. Bedroom fan
    switch (routine.fanAction) {
      case BinaryDeviceAction.turnOn:
        try {
          await deviceControlService.setFan(true);
          await deviceControlService.setFanSpeed(routine.fanSpeed);
          results.add(
            RoutineStepResult(
              deviceLabel: 'Bedroom fan',
              plannedAction: 'Turn on fan (speed ${routine.fanSpeed})',
              status: StepCompletionStatus.completed,
              message:
                  'Fan turned ON at speed ${routine.fanSpeed} of 5 (simulated).',
            ),
          );
        } on DeviceControlException catch (error) {
          results.add(
            RoutineStepResult(
              deviceLabel: 'Bedroom fan',
              plannedAction: 'Turn on fan (speed ${routine.fanSpeed})',
              status: StepCompletionStatus.failed,
              message: 'Failed to turn on fan: ${error.message}',
            ),
          );
        }
      case BinaryDeviceAction.turnOff:
        try {
          await deviceControlService.setFan(false);
          results.add(
            const RoutineStepResult(
              deviceLabel: 'Bedroom fan',
              plannedAction: 'Turn off fan',
              status: StepCompletionStatus.completed,
              message: 'Fan turned OFF (simulated).',
            ),
          );
        } on DeviceControlException catch (error) {
          results.add(
            RoutineStepResult(
              deviceLabel: 'Bedroom fan',
              plannedAction: 'Turn off fan',
              status: StepCompletionStatus.failed,
              message: 'Failed to turn off fan: ${error.message}',
            ),
          );
        }
      case BinaryDeviceAction.unchanged:
        results.add(
          RoutineStepResult(
            deviceLabel: 'Bedroom fan',
            plannedAction: 'Leave fan unchanged',
            status: StepCompletionStatus.skipped,
            message:
                'Left unchanged (${deviceControlService.state.fanOn ? "ON" : "OFF"}).',
          ),
        );
    }

    // 3. Front door with safety checks
    final state = deviceControlService.state;
    switch (routine.doorAction) {
      case DoorRoutineAction.unchanged:
        results.add(
          RoutineStepResult(
            deviceLabel: 'Front door',
            plannedAction: 'Leave door unchanged',
            status: StepCompletionStatus.skipped,
            message:
                'Left unchanged (${state.doorLocked ? "Locked" : "Unlocked"}).',
          ),
        );
      case DoorRoutineAction.keepLocked:
        if (state.doorLocked) {
          results.add(
            const RoutineStepResult(
              deviceLabel: 'Front door',
              plannedAction: 'Keep the door locked',
              status: StepCompletionStatus.verified,
              message: 'Verified: Front door is locked and remains locked.',
            ),
          );
        } else if (state.doorOpen) {
          results.add(
            const RoutineStepResult(
              deviceLabel: 'Front door',
              plannedAction: 'Keep the door locked',
              status: StepCompletionStatus.skipped,
              message:
                  'Safety check failed: Front door sensor is open, so it could not be locked.',
            ),
          );
        } else if (routine.requireSafetyConfirmation && !doorSafetyConfirmed) {
          results.add(
            const RoutineStepResult(
              deviceLabel: 'Front door',
              plannedAction: 'Keep the door locked',
              status: StepCompletionStatus.skipped,
              message:
                  'Safety confirmation not provided; front door remains unlocked.',
            ),
          );
        } else {
          try {
            await deviceControlService.setDoorLocked(true);
            results.add(
              const RoutineStepResult(
                deviceLabel: 'Front door',
                plannedAction: 'Keep the door locked',
                status: StepCompletionStatus.completed,
                message: 'Front door locked and kept secure (simulated).',
              ),
            );
          } on DeviceControlException catch (error) {
            results.add(
              RoutineStepResult(
                deviceLabel: 'Front door',
                plannedAction: 'Keep the door locked',
                status: StepCompletionStatus.failed,
                message: 'Failed to lock door: ${error.message}',
              ),
            );
          }
        }
      case DoorRoutineAction.lockWithSafetyCheck:
        if (state.doorOpen) {
          results.add(
            RoutineStepResult(
              deviceLabel: 'Front door',
              plannedAction: routine.doorSummary,
              status: StepCompletionStatus.skipped,
              message:
                  'Safety check blocked lock: Front door sensor reports the door is open.',
            ),
          );
        } else if (state.doorLocked) {
          results.add(
            RoutineStepResult(
              deviceLabel: 'Front door',
              plannedAction: routine.doorSummary,
              status: StepCompletionStatus.verified,
              message:
                  'Safety check passed: Front door is closed and already locked.',
            ),
          );
        } else if (routine.requireSafetyConfirmation && !doorSafetyConfirmed) {
          results.add(
            RoutineStepResult(
              deviceLabel: 'Front door',
              plannedAction: routine.doorSummary,
              status: StepCompletionStatus.skipped,
              message:
                  'Skipped: Safety confirmation was not checked, so the door remains unlocked.',
            ),
          );
        } else {
          try {
            await deviceControlService.setDoorLocked(true);
            results.add(
              RoutineStepResult(
                deviceLabel: 'Front door',
                plannedAction: routine.doorSummary,
                status: StepCompletionStatus.completed,
                message:
                    'Safety check passed: Front door locked (simulated).',
              ),
            );
          } on DeviceControlException catch (error) {
            results.add(
              RoutineStepResult(
                deviceLabel: 'Front door',
                plannedAction: routine.doorSummary,
                status: StepCompletionStatus.failed,
                message: 'Failed to lock door: ${error.message}',
              ),
            );
          }
        }
    }

    return RoutineExecutionReport(
      routineId: routine.id,
      routineTitle: routine.title,
      executedAt: DateTime.now(),
      steps: results,
    );
  }
}
