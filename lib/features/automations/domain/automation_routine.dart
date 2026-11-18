import '../../devices/domain/device_state.dart';

enum RoutineId { sleep, morning, away }

enum BinaryDeviceAction { turnOn, turnOff, unchanged }

enum DoorRoutineAction { lockWithSafetyCheck, keepLocked, unchanged }

enum StepCompletionStatus { completed, verified, skipped, failed }

class PlannedRoutineAction {
  const PlannedRoutineAction({
    required this.deviceLabel,
    required this.actionLabel,
    required this.detail,
    this.isSafetyBlocked = false,
    this.needsConfirmation = false,
  });

  final String deviceLabel;
  final String actionLabel;
  final String detail;
  final bool isSafetyBlocked;
  final bool needsConfirmation;
}

class RoutineStepResult {
  const RoutineStepResult({
    required this.deviceLabel,
    required this.plannedAction,
    required this.status,
    required this.message,
  });

  final String deviceLabel;
  final String plannedAction;
  final StepCompletionStatus status;
  final String message;
}

class RoutineExecutionReport {
  const RoutineExecutionReport({
    required this.routineId,
    required this.routineTitle,
    required this.executedAt,
    required this.steps,
  });

  final RoutineId routineId;
  final String routineTitle;
  final DateTime executedAt;
  final List<RoutineStepResult> steps;

  bool get hasFailures =>
      steps.any((step) => step.status == StepCompletionStatus.failed);

  bool get hasSkipped =>
      steps.any((step) => step.status == StepCompletionStatus.skipped);

  String get overallStatusLabel {
    if (hasFailures) return 'Incomplete';
    if (hasSkipped) return 'Completed with skipped steps';
    return 'Completed';
  }
}

class AutomationRoutine {
  const AutomationRoutine({
    required this.id,
    required this.lightAction,
    required this.fanAction,
    required this.fanSpeed,
    required this.doorAction,
    required this.requireSafetyConfirmation,
  });

  factory AutomationRoutine.defaultFor(RoutineId id) {
    return switch (id) {
      RoutineId.sleep => const AutomationRoutine(
          id: RoutineId.sleep,
          lightAction: BinaryDeviceAction.turnOff,
          fanAction: BinaryDeviceAction.turnOff,
          fanSpeed: 2,
          doorAction: DoorRoutineAction.lockWithSafetyCheck,
          requireSafetyConfirmation: true,
        ),
      RoutineId.morning => const AutomationRoutine(
          id: RoutineId.morning,
          lightAction: BinaryDeviceAction.turnOn,
          fanAction: BinaryDeviceAction.turnOn,
          fanSpeed: 2,
          doorAction: DoorRoutineAction.keepLocked,
          requireSafetyConfirmation: true,
        ),
      RoutineId.away => const AutomationRoutine(
          id: RoutineId.away,
          lightAction: BinaryDeviceAction.turnOff,
          fanAction: BinaryDeviceAction.turnOff,
          fanSpeed: 2,
          doorAction: DoorRoutineAction.lockWithSafetyCheck,
          requireSafetyConfirmation: true,
        ),
    };
  }

  final RoutineId id;
  final BinaryDeviceAction lightAction;
  final BinaryDeviceAction fanAction;
  final int fanSpeed;
  final DoorRoutineAction doorAction;
  final bool requireSafetyConfirmation;

  String get firestoreId => id.name;

  String get title => switch (id) {
        RoutineId.sleep => 'Sleep Mode',
        RoutineId.morning => 'Morning Mode',
        RoutineId.away => 'Away Mode',
      };

  String get modeChipLabel => switch (id) {
        RoutineId.sleep => 'Sleep',
        RoutineId.morning => 'Morning',
        RoutineId.away => 'Away',
      };

  String get subtitle => switch (id) {
        RoutineId.sleep => 'Wind down and secure the home for the night.',
        RoutineId.morning => 'Brighten the room while keeping entry secure.',
        RoutineId.away => 'Power down appliances and secure entry safely.',
      };

  String get lightSummary => switch (lightAction) {
        BinaryDeviceAction.turnOn => 'Turn on light',
        BinaryDeviceAction.turnOff => 'Turn off light',
        BinaryDeviceAction.unchanged => 'Leave light unchanged',
      };

  String get fanSummary => switch (fanAction) {
        BinaryDeviceAction.turnOn => 'Turn on fan (speed $fanSpeed)',
        BinaryDeviceAction.turnOff => 'Turn off fan',
        BinaryDeviceAction.unchanged => 'Leave fan unchanged',
      };

  String get doorSummary => switch (doorAction) {
        DoorRoutineAction.lockWithSafetyCheck => id == RoutineId.sleep
            ? 'Lock the door after confirming it is safe'
            : 'Lock the door after safety checks',
        DoorRoutineAction.keepLocked => 'Keep the door locked',
        DoorRoutineAction.unchanged => 'Leave door unchanged',
      };

  bool needsExplicitSafetyCheck(DeviceState state) {
    if (doorAction == DoorRoutineAction.unchanged) return false;
    if (state.doorOpen || state.doorLocked) return false;
    return requireSafetyConfirmation;
  }

  List<PlannedRoutineAction> buildPlannedActions(DeviceState state) {
    final lightPlan = PlannedRoutineAction(
      deviceLabel: 'Living room light',
      actionLabel: lightSummary,
      detail: switch (lightAction) {
        BinaryDeviceAction.turnOn => state.lightOn
            ? 'Currently ON · Will remain ON'
            : 'Currently OFF · Will turn ON',
        BinaryDeviceAction.turnOff => state.lightOn
            ? 'Currently ON · Will turn OFF'
            : 'Currently OFF · Will remain OFF',
        BinaryDeviceAction.unchanged =>
          'Currently ${state.lightOn ? "ON" : "OFF"} · No change',
      },
    );

    final fanPlan = PlannedRoutineAction(
      deviceLabel: 'Bedroom fan',
      actionLabel: fanSummary,
      detail: switch (fanAction) {
        BinaryDeviceAction.turnOn => state.fanOn
            ? 'Currently ON · Will set speed to $fanSpeed of 5'
            : 'Currently OFF · Will turn ON at speed $fanSpeed of 5',
        BinaryDeviceAction.turnOff => state.fanOn
            ? 'Currently ON · Will turn OFF'
            : 'Currently OFF · Will remain OFF',
        BinaryDeviceAction.unchanged =>
          'Currently ${state.fanOn ? "ON" : "OFF"} · No change',
      },
    );

    final PlannedRoutineAction doorPlan;
    switch (doorAction) {
      case DoorRoutineAction.unchanged:
        doorPlan = PlannedRoutineAction(
          deviceLabel: 'Front door',
          actionLabel: 'Leave door unchanged',
          detail:
              'Currently ${state.doorLocked ? "Locked" : "Unlocked"} · No change',
        );
      case DoorRoutineAction.keepLocked:
        if (state.doorLocked) {
          doorPlan = const PlannedRoutineAction(
            deviceLabel: 'Front door',
            actionLabel: 'Keep the door locked',
            detail: 'Safety check: Already locked · Will remain locked',
          );
        } else if (state.doorOpen) {
          doorPlan = const PlannedRoutineAction(
            deviceLabel: 'Front door',
            actionLabel: 'Keep the door locked',
            detail:
                'Safety check warning: Door sensor is OPEN. Locking will be skipped until closed.',
            isSafetyBlocked: true,
          );
        } else {
          doorPlan = PlannedRoutineAction(
            deviceLabel: 'Front door',
            actionLabel: 'Keep the door locked',
            detail: requireSafetyConfirmation
                ? 'Door is closed & unlocked · Confirm safety check to lock'
                : 'Door is closed & unlocked · Will lock automatically',
            needsConfirmation: requireSafetyConfirmation,
          );
        }
      case DoorRoutineAction.lockWithSafetyCheck:
        if (state.doorOpen) {
          doorPlan = const PlannedRoutineAction(
            deviceLabel: 'Front door',
            actionLabel: doorSummaryStatic,
            detail:
                'Safety check blocked: Door sensor is OPEN. Close the door before locking.',
            isSafetyBlocked: true,
          );
        } else if (state.doorLocked) {
          doorPlan = const PlannedRoutineAction(
            deviceLabel: 'Front door',
            actionLabel: 'Lock the door after safety checks',
            detail: 'Safety check passed: Door is closed and already locked.',
          );
        } else {
          doorPlan = PlannedRoutineAction(
            deviceLabel: 'Front door',
            actionLabel: doorSummary,
            detail: requireSafetyConfirmation
                ? 'Safety check: Door is closed · Confirm below to lock safely'
                : 'Safety check passed: Door is closed · Will lock',
            needsConfirmation: requireSafetyConfirmation,
          );
        }
    }

    return [lightPlan, fanPlan, doorPlan];
  }

  static const doorSummaryStatic = 'Lock the door after safety checks';

  AutomationRoutine copyWith({
    BinaryDeviceAction? lightAction,
    BinaryDeviceAction? fanAction,
    int? fanSpeed,
    DoorRoutineAction? doorAction,
    bool? requireSafetyConfirmation,
  }) {
    return AutomationRoutine(
      id: id,
      lightAction: lightAction ?? this.lightAction,
      fanAction: fanAction ?? this.fanAction,
      fanSpeed: (fanSpeed ?? this.fanSpeed).clamp(1, 5),
      doorAction: doorAction ?? this.doorAction,
      requireSafetyConfirmation:
          requireSafetyConfirmation ?? this.requireSafetyConfirmation,
    );
  }

  Map<String, Object?> toFirestoreMap(String ownerId, Object timestamp) {
    return {
      'ownerId': ownerId,
      'routineId': firestoreId,
      'lightAction': switch (lightAction) {
        BinaryDeviceAction.turnOn => 'turn_on',
        BinaryDeviceAction.turnOff => 'turn_off',
        BinaryDeviceAction.unchanged => 'unchanged',
      },
      'fanAction': switch (fanAction) {
        BinaryDeviceAction.turnOn => 'turn_on',
        BinaryDeviceAction.turnOff => 'turn_off',
        BinaryDeviceAction.unchanged => 'unchanged',
      },
      'fanSpeed': fanSpeed.clamp(1, 5),
      'doorAction': switch (doorAction) {
        DoorRoutineAction.lockWithSafetyCheck => 'lock_with_safety_check',
        DoorRoutineAction.keepLocked => 'keep_locked',
        DoorRoutineAction.unchanged => 'unchanged',
      },
      'requireSafetyConfirmation': requireSafetyConfirmation,
      'updatedAt': timestamp,
    };
  }

  static AutomationRoutine fromFirestoreMap(
    RoutineId fallbackId,
    Map<String, dynamic> data,
  ) {
    final defaults = AutomationRoutine.defaultFor(fallbackId);
    final rawLight = data['lightAction'];
    final rawFan = data['fanAction'];
    final rawFanSpeed = data['fanSpeed'];
    final rawDoor = data['doorAction'];
    final rawConfirm = data['requireSafetyConfirmation'];

    return AutomationRoutine(
      id: fallbackId,
      lightAction: switch (rawLight) {
        'turn_on' => BinaryDeviceAction.turnOn,
        'turn_off' => BinaryDeviceAction.turnOff,
        'unchanged' => BinaryDeviceAction.unchanged,
        _ => defaults.lightAction,
      },
      fanAction: switch (rawFan) {
        'turn_on' => BinaryDeviceAction.turnOn,
        'turn_off' => BinaryDeviceAction.turnOff,
        'unchanged' => BinaryDeviceAction.unchanged,
        _ => defaults.fanAction,
      },
      fanSpeed: rawFanSpeed is int && rawFanSpeed >= 1 && rawFanSpeed <= 5
          ? rawFanSpeed
          : defaults.fanSpeed,
      doorAction: switch (rawDoor) {
        'lock_with_safety_check' => DoorRoutineAction.lockWithSafetyCheck,
        'keep_locked' => DoorRoutineAction.keepLocked,
        'unchanged' => DoorRoutineAction.unchanged,
        _ => defaults.doorAction,
      },
      requireSafetyConfirmation: rawConfirm is bool
          ? rawConfirm
          : defaults.requireSafetyConfirmation,
    );
  }
}
