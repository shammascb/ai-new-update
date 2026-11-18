import 'package:flutter/material.dart';

import '../../devices/domain/device_control_service.dart';
import '../data/automation_routine_store.dart';
import '../domain/automation_routine.dart';
import '../domain/automation_routine_executor.dart';

Future<RoutineExecutionReport?> showRoutineExecutionDialog({
  required BuildContext context,
  required AutomationRoutine routine,
  required DeviceControlService deviceControlService,
  required AutomationRoutineStore routineStore,
  AutomationRoutineExecutor executor = const AutomationRoutineExecutor(),
}) {
  return showDialog<RoutineExecutionReport>(
    context: context,
    builder: (dialogContext) => _RoutineExecutionDialog(
      routine: routine,
      deviceControlService: deviceControlService,
      routineStore: routineStore,
      executor: executor,
    ),
  );
}

Future<void> showCustomizeRoutineDialog({
  required BuildContext context,
  required AutomationRoutine routine,
  required AutomationRoutineStore routineStore,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _CustomizeRoutineDialog(
      routine: routine,
      routineStore: routineStore,
    ),
  );
}

class _RoutineExecutionDialog extends StatefulWidget {
  const _RoutineExecutionDialog({
    required this.routine,
    required this.deviceControlService,
    required this.routineStore,
    required this.executor,
  });

  final AutomationRoutine routine;
  final DeviceControlService deviceControlService;
  final AutomationRoutineStore routineStore;
  final AutomationRoutineExecutor executor;

  @override
  State<_RoutineExecutionDialog> createState() =>
      _RoutineExecutionDialogState();
}

class _RoutineExecutionDialogState extends State<_RoutineExecutionDialog> {
  bool _safetyConfirmed = false;
  bool _isExecuting = false;
  RoutineExecutionReport? _report;

  Future<void> _execute() async {
    if (_isExecuting) return;
    setState(() => _isExecuting = true);

    final report = await widget.executor.execute(
      routine: widget.routine,
      deviceControlService: widget.deviceControlService,
      doorSafetyConfirmed: _safetyConfirmed,
    );
    widget.routineStore.recordExecutionReport(report);

    if (!mounted) return;
    setState(() {
      _isExecuting = false;
      _report = report;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final report = _report;

    if (report != null) {
      final overallColor = report.hasFailures
          ? colorScheme.error
          : report.hasSkipped
              ? colorScheme.tertiary
              : Colors.green;
      return AlertDialog(
        title: Row(
          children: [
            Icon(
              report.hasFailures
                  ? Icons.error_outline_rounded
                  : report.hasSkipped
                      ? Icons.info_outline_rounded
                      : Icons.check_circle_outline_rounded,
              color: overallColor,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('${report.routineTitle} Status')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: overallColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Overall status: ${report.overallStatusLabel}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: overallColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < report.steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _StepResultTile(step: report.steps[i]),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(report),
            child: const Text('Done'),
          ),
        ],
      );
    }

    final state = widget.deviceControlService.state;
    final plannedActions = widget.routine.buildPlannedActions(state);
    final needsConfirmation = widget.routine.needsExplicitSafetyCheck(state);
    final hasBlockedDoor = plannedActions.any((plan) => plan.isSafetyBlocked);

    return AlertDialog(
      title: Text('Preview ${widget.routine.title}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review the actions below before execution:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < plannedActions.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _PlannedActionTile(plan: plannedActions[i]),
              ],
              if (hasBlockedDoor) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Door sensor reports the front door is OPEN. '
                          'For safety, the door lock step will be skipped unless '
                          'the door is closed first.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (needsConfirmation) ...[
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: CheckboxListTile(
                    value: _safetyConfirmed,
                    onChanged: _isExecuting
                        ? null
                        : (checked) => setState(
                              () => _safetyConfirmed = checked ?? false,
                            ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    title: const Text(
                      'Confirm safety check before locking door',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'I confirm the front door area is clear and it is safe to '
                      'lock the door. (If unchecked, door locking is skipped.)',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExecuting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isExecuting ? null : _execute,
          icon: _isExecuting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(_isExecuting ? 'Running…' : 'Execute Routine'),
        ),
      ],
    );
  }
}

class _PlannedActionTile extends StatelessWidget {
  const _PlannedActionTile({required this.plan});

  final PlannedRoutineAction plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = switch (plan.deviceLabel) {
      'Living room light' => Icons.lightbulb_outline_rounded,
      'Bedroom fan' => Icons.mode_fan_off_outlined,
      _ => Icons.door_front_door_outlined,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: plan.isSafetyBlocked
            ? colorScheme.errorContainer.withValues(alpha: 0.25)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: plan.isSafetyBlocked
              ? colorScheme.error.withValues(alpha: 0.45)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: plan.isSafetyBlocked
                ? colorScheme.error
                : colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${plan.deviceLabel}: ${plan.actionLabel}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plan.detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepResultTile extends StatelessWidget {
  const _StepResultTile({required this.step});

  final RoutineStepResult step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (statusLabel, statusColor, statusIcon) = switch (step.status) {
      StepCompletionStatus.completed => (
          'Completed',
          Colors.green,
          Icons.check_circle_rounded,
        ),
      StepCompletionStatus.verified => (
          'Verified',
          colorScheme.primary,
          Icons.verified_user_rounded,
        ),
      StepCompletionStatus.skipped => (
          'Skipped',
          colorScheme.tertiary,
          Icons.skip_next_rounded,
        ),
      StepCompletionStatus.failed => (
          'Failed',
          colorScheme.error,
          Icons.error_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.deviceLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  step.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomizeRoutineDialog extends StatefulWidget {
  const _CustomizeRoutineDialog({
    required this.routine,
    required this.routineStore,
  });

  final AutomationRoutine routine;
  final AutomationRoutineStore routineStore;

  @override
  State<_CustomizeRoutineDialog> createState() =>
      _CustomizeRoutineDialogState();
}

class _CustomizeRoutineDialogState extends State<_CustomizeRoutineDialog> {
  late BinaryDeviceAction _lightAction;
  late BinaryDeviceAction _fanAction;
  late int _fanSpeed;
  late DoorRoutineAction _doorAction;
  late bool _requireSafetyConfirmation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _lightAction = widget.routine.lightAction;
    _fanAction = widget.routine.fanAction;
    _fanSpeed = widget.routine.fanSpeed;
    _doorAction = widget.routine.doorAction;
    _requireSafetyConfirmation = widget.routine.requireSafetyConfirmation;
  }

  void _applyDefaults() {
    final defaults = AutomationRoutine.defaultFor(widget.routine.id);
    setState(() {
      _lightAction = defaults.lightAction;
      _fanAction = defaults.fanAction;
      _fanSpeed = defaults.fanSpeed;
      _doorAction = defaults.doorAction;
      _requireSafetyConfirmation = defaults.requireSafetyConfirmation;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final updated = widget.routine.copyWith(
      lightAction: _lightAction,
      fanAction: _fanAction,
      fanSpeed: _fanSpeed,
      doorAction: _doorAction,
      requireSafetyConfirmation: _requireSafetyConfirmation,
    );
    await widget.routineStore.saveRoutine(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text('Customize ${widget.routine.title}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Living room light',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<BinaryDeviceAction>(
                key: ValueKey('light-$_lightAction'),
                initialValue: _lightAction,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: BinaryDeviceAction.turnOn,
                    child: Text('Turn on light'),
                  ),
                  DropdownMenuItem(
                    value: BinaryDeviceAction.turnOff,
                    child: Text('Turn off light'),
                  ),
                  DropdownMenuItem(
                    value: BinaryDeviceAction.unchanged,
                    child: Text('Leave light unchanged'),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _lightAction = value);
                      },
              ),
              const SizedBox(height: 16),
              Text(
                'Bedroom fan',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<BinaryDeviceAction>(
                key: ValueKey('fan-$_fanAction'),
                initialValue: _fanAction,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: BinaryDeviceAction.turnOn,
                    child: Text('Turn on fan'),
                  ),
                  DropdownMenuItem(
                    value: BinaryDeviceAction.turnOff,
                    child: Text('Turn off fan'),
                  ),
                  DropdownMenuItem(
                    value: BinaryDeviceAction.unchanged,
                    child: Text('Leave fan unchanged'),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _fanAction = value);
                      },
              ),
              if (_fanAction == BinaryDeviceAction.turnOn) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Fan speed: $_fanSpeed / 5',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _fanSpeed.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '$_fanSpeed',
                        onChanged: _isSaving
                            ? null
                            : (value) => setState(
                                  () => _fanSpeed = value.round(),
                                ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Front door (security)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<DoorRoutineAction>(
                key: ValueKey('door-$_doorAction'),
                initialValue: _doorAction,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: DoorRoutineAction.lockWithSafetyCheck,
                    child: Text('Lock door after safety checks'),
                  ),
                  DropdownMenuItem(
                    value: DoorRoutineAction.keepLocked,
                    child: Text('Keep the door locked'),
                  ),
                  DropdownMenuItem(
                    value: DoorRoutineAction.unchanged,
                    child: Text('Leave door unchanged'),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _doorAction = value);
                      },
              ),
              if (_doorAction != DoorRoutineAction.unchanged) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _requireSafetyConfirmation,
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(
                            () => _requireSafetyConfirmation = value ?? true,
                          ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Require safety confirmation before locking'),
                  subtitle: Text(
                    'Prompts to confirm the doorway is clear if currently unlocked.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'For home safety, automation routines never unlock the front door.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _applyDefaults,
          child: const Text('Reset default'),
        ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
