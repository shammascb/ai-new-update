import 'dart:async';

import 'package:flutter/material.dart';

import '../../devices/domain/device_control_service.dart';
import '../data/automation_routine_store.dart';
import '../domain/automation_routine.dart';
import 'add_devices_screen.dart';
import 'routine_dialogs.dart';

class RoutineDetailScreen extends StatelessWidget {
  const RoutineDetailScreen({
    required this.routineId,
    required this.routineStore,
    required this.deviceControlService,
    required this.onModeActivated,
    this.canRunAutomations = true,
    this.onRoutineDenied,
    this.onRoutineExecuted,
    super.key,
  });

  final RoutineId routineId;
  final AutomationRoutineStore routineStore;
  final DeviceControlService deviceControlService;
  final ValueChanged<String> onModeActivated;
  final bool canRunAutomations;
  final ValueChanged<AutomationRoutine>? onRoutineDenied;
  final void Function(AutomationRoutine routine, RoutineExecutionReport report)?
      onRoutineExecuted;

  static const _accentOrange = Color(0xFFFF5A00);

  Future<void> _openAddDevices(
    BuildContext context,
    AutomationRoutine routine,
  ) async {
    await Navigator.of(context).push<AutomationRoutine>(
      MaterialPageRoute<AutomationRoutine>(
        builder: (_) => AddDevicesScreen(
          routine: routine,
          routineStore: routineStore,
        ),
      ),
    );
  }

  Future<void> _previewAndRun(
    BuildContext context,
    AutomationRoutine routine,
  ) async {
    if (!canRunAutomations) {
      onRoutineDenied?.call(routine);
      if (onRoutineDenied == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Permission denied: your account cannot run automation routines.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      return;
    }

    final report = await showRoutineExecutionDialog(
      context: context,
      routine: routine,
      deviceControlService: deviceControlService,
      routineStore: routineStore,
    );
    if (report != null) {
      onModeActivated(routine.modeChipLabel);
      onRoutineExecuted?.call(routine, report);
    }
  }

  Future<void> _toggleLight(AutomationRoutine routine, bool turnOn) {
    return routineStore.saveRoutine(
      routine.copyWith(
        lightAction:
            turnOn ? BinaryDeviceAction.turnOn : BinaryDeviceAction.turnOff,
      ),
    );
  }

  Future<void> _toggleFan(AutomationRoutine routine, bool turnOn) {
    return routineStore.saveRoutine(
      routine.copyWith(
        fanAction:
            turnOn ? BinaryDeviceAction.turnOn : BinaryDeviceAction.turnOff,
      ),
    );
  }

  Future<void> _showFanOptionsSheet(
    BuildContext context,
    AutomationRoutine routine,
  ) async {
    var fanAction = routine.fanAction;
    var speed = routine.fanSpeed;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bedroom Fan Configuration',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Turn fan ON during routine'),
                  subtitle: Text(
                    fanAction == BinaryDeviceAction.turnOn
                        ? 'Turns fan ON at speed $speed'
                        : 'Turns fan OFF',
                  ),
                  value: fanAction == BinaryDeviceAction.turnOn,
                  onChanged: (value) => setModalState(
                    () => fanAction = value
                        ? BinaryDeviceAction.turnOn
                        : BinaryDeviceAction.turnOff,
                  ),
                ),
                if (fanAction == BinaryDeviceAction.turnOn) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Target speed: $speed of 5',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Expanded(
                        child: Slider(
                          value: speed.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '$speed',
                          onChanged: (value) =>
                              setModalState(() => speed = value.round()),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () async {
                      await routineStore.saveRoutine(
                        routine.copyWith(fanAction: fanAction, fanSpeed: speed),
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDoorSecuritySheet(
    BuildContext context,
    AutomationRoutine routine,
  ) async {
    var doorAction = routine.doorAction;
    var requireConfirmation = routine.requireSafetyConfirmation;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Front Door Safety Settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Routines never unlock the front door.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                RadioGroup<DoorRoutineAction>(
                  groupValue: doorAction,
                  onChanged: (value) {
                    if (value != null) setModalState(() => doorAction = value);
                  },
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<DoorRoutineAction>(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Lock after safety checks'),
                        subtitle: Text('Verifies sensor closed before locking'),
                        value: DoorRoutineAction.lockWithSafetyCheck,
                      ),
                      RadioListTile<DoorRoutineAction>(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Keep the door locked'),
                        subtitle: Text('Verifies door remains locked safely'),
                        value: DoorRoutineAction.keepLocked,
                      ),
                    ],
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require safety confirmation prompt'),
                  value: requireConfirmation,
                  onChanged: (value) =>
                      setModalState(() => requireConfirmation = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () async {
                      await routineStore.saveRoutine(
                        routine.copyWith(
                          doorAction: doorAction,
                          requireSafetyConfirmation: requireConfirmation,
                        ),
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final canvasColor =
        isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF9F9FB);
    final cardColor = isDark ? colorScheme.surface : const Color(0xFFF1F2F4);

    return Scaffold(
      backgroundColor: canvasColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: AnimatedBuilder(
              animation: Listenable.merge([routineStore, deviceControlService]),
              builder: (context, _) {
                final routine = routineStore.routineFor(routineId);
                final lastReport = routineStore.lastReport;
                final matchingReport =
                    lastReport?.routineId == routine.id ? lastReport : null;

                final cards = <Widget>[
                  if (routine.lightAction != BinaryDeviceAction.unchanged)
                    _RoutineDeviceTile(
                      title: 'Smart Light',
                      subtitle: routine.lightAction == BinaryDeviceAction.turnOn
                          ? 'Living room · Turn ON'
                          : 'Living room · Turn OFF',
                      icon: Icons.lightbulb_outline_rounded,
                      isEnabled:
                          routine.lightAction == BinaryDeviceAction.turnOn,
                      cardColor: cardColor,
                      onToggle: (value) =>
                          unawaited(_toggleLight(routine, value)),
                      onTap: () => unawaited(
                        _toggleLight(
                          routine,
                          routine.lightAction != BinaryDeviceAction.turnOn,
                        ),
                      ),
                    ),
                  if (routine.fanAction != BinaryDeviceAction.unchanged)
                    _RoutineDeviceTile(
                      title: 'Bedroom Fan',
                      subtitle: routine.fanAction == BinaryDeviceAction.turnOn
                          ? 'Bedroom · ON (Speed ${routine.fanSpeed})'
                          : 'Bedroom · Turn OFF',
                      icon: Icons.mode_fan_off_outlined,
                      isEnabled: routine.fanAction == BinaryDeviceAction.turnOn,
                      cardColor: cardColor,
                      onToggle: (value) =>
                          unawaited(_toggleFan(routine, value)),
                      onTap: () =>
                          unawaited(_showFanOptionsSheet(context, routine)),
                    ),
                  if (routine.doorAction != DoorRoutineAction.unchanged)
                    _RoutineDeviceTile(
                      title: 'Front Door Lock',
                      subtitle: routine.doorAction == DoorRoutineAction.keepLocked
                          ? 'Front entry · Keep locked'
                          : 'Front entry · Safety lock',
                      icon: Icons.lock_outline_rounded,
                      isEnabled: true,
                      cardColor: cardColor,
                      onToggle: (_) =>
                          unawaited(_showDoorSecuritySheet(context, routine)),
                      onTap: () =>
                          unawaited(_showDoorSecuritySheet(context, routine)),
                    ),
                ];

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          Row(
                            children: [
                              Material(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.55),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'Back',
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  constraints: const BoxConstraints.tightFor(
                                    width: 44,
                                    height: 44,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () =>
                                    unawaited(routineStore.resetRoutine(routine.id)),
                                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                                label: const Text('Reset default'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            routine.title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            routine.subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (routineStore.syncNotice != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      routineStore.syncNotice!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: routineStore.isSyncing
                                        ? null
                                        : () => unawaited(
                                              routineStore.retrySync(),
                                            ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Connected devices',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Material(
                                color: _accentOrange,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'Add your devices',
                                  onPressed: () => unawaited(
                                    _openAddDevices(context, routine),
                                  ),
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                  ),
                                  constraints: const BoxConstraints.tightFor(
                                    width: 44,
                                    height: 44,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (cards.isEmpty)
                            Card(
                              color: cardColor,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.devices_other_outlined,
                                      size: 32,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'No devices selected for this routine yet.',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    FilledButton.icon(
                                      onPressed: () => unawaited(
                                        _openAddDevices(context, routine),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _accentOrange,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Add devices'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns =
                                    constraints.maxWidth >= 680 ? 3 : 2;
                                const spacing = 12.0;
                                final itemWidth =
                                    (constraints.maxWidth -
                                            spacing * (columns - 1)) /
                                        columns;
                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: [
                                    for (final card in cards)
                                      SizedBox(width: itemWidth, child: card),
                                  ],
                                );
                              },
                            ),
                          if (matchingReport != null) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Last Execution Status',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _InlineCompletionSummary(report: matchingReport),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                      decoration: BoxDecoration(
                        color: canvasColor,
                        border: Border(
                          top: BorderSide(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: () =>
                              unawaited(_previewAndRun(context, routine)),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accentOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text(
                            'Preview & Execute Routine',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutineDeviceTile extends StatelessWidget {
  const _RoutineDeviceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isEnabled,
    required this.cardColor,
    required this.onToggle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isEnabled;
  final Color cardColor;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surfaceContainerHighest
                          : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: isEnabled,
                    onChanged: onToggle,
                    activeTrackColor: isDark ? colorScheme.primary : Colors.black,
                    activeThumbColor: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineCompletionSummary extends StatelessWidget {
  const _InlineCompletionSummary({required this.report});

  final RoutineExecutionReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = report.hasFailures
        ? colorScheme.error
        : report.hasSkipped
            ? colorScheme.tertiary
            : Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  report.hasFailures
                      ? Icons.error_outline_rounded
                      : report.hasSkipped
                          ? Icons.info_outline_rounded
                          : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: ${report.overallStatusLabel}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < report.steps.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Text(
                '${report.steps[i].deviceLabel} · ${report.steps[i].message}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
