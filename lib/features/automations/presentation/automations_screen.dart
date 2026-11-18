import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../devices/domain/device_control_service.dart';
import '../data/automation_routine_store.dart';
import '../domain/automation_routine.dart';
import 'routine_detail_screen.dart';
import 'routine_dialogs.dart';

class AutomationsScreen extends StatelessWidget {
  const AutomationsScreen({
    required this.routineStore,
    required this.deviceControlService,
    required this.activeModeLabel,
    required this.onModeActivated,
    this.onBackToHome,
    this.canRunAutomations = true,
    this.onRoutineDenied,
    this.onRoutineExecuted,
    super.key,
  });

  final AutomationRoutineStore routineStore;
  final DeviceControlService deviceControlService;
  final String activeModeLabel;
  final ValueChanged<String> onModeActivated;
  final VoidCallback? onBackToHome;
  final bool canRunAutomations;
  final ValueChanged<AutomationRoutine>? onRoutineDenied;
  final void Function(AutomationRoutine routine, RoutineExecutionReport report)?
      onRoutineExecuted;

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

  void _openRoutineDetail(BuildContext context, RoutineId id) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RoutineDetailScreen(
            routineId: id,
            routineStore: routineStore,
            deviceControlService: deviceControlService,
            onModeActivated: onModeActivated,
            canRunAutomations: canRunAutomations,
            onRoutineDenied: onRoutineDenied,
            onRoutineExecuted: onRoutineExecuted,
          ),
        ),
      ),
    );
  }

  Future<void> _showQuickCustomizePicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customize a Routine',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose which routine to configure or add devices to.',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              for (final id in RoutineId.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFF5A00).withValues(alpha: 0.14),
                    child: Icon(
                      switch (id) {
                        RoutineId.sleep => Icons.nights_stay_outlined,
                        RoutineId.morning => Icons.wb_sunny_outlined,
                        RoutineId.away => Icons.directions_walk_outlined,
                      },
                      color: const Color(0xFFFF5A00),
                    ),
                  ),
                  title: Text(
                    routineStore.routineFor(id).title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${routineStore.routineFor(id).lightSummary} · '
                    '${routineStore.routineFor(id).fanSummary}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openRoutineDetail(context, id);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLatestReportSheet(
    BuildContext context,
    RoutineExecutionReport report,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final badgeColor = report.hasFailures
        ? colorScheme.error
        : report.hasSkipped
            ? colorScheme.tertiary
            : Colors.green;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Latest Execution Status',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      report.overallStatusLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  report.routineTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < report.steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        switch (report.steps[i].status) {
                          StepCompletionStatus.completed =>
                            Icons.check_circle_outline_rounded,
                          StepCompletionStatus.verified =>
                            Icons.verified_user_outlined,
                          StepCompletionStatus.skipped =>
                            Icons.skip_next_outlined,
                          StepCompletionStatus.failed =>
                            Icons.error_outline_rounded,
                        },
                        size: 20,
                        color: switch (report.steps[i].status) {
                          StepCompletionStatus.completed => Colors.green,
                          StepCompletionStatus.verified => colorScheme.primary,
                          StepCompletionStatus.skipped => colorScheme.tertiary,
                          StepCompletionStatus.failed => colorScheme.error,
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${report.steps[i].deviceLabel}: '
                          '${report.steps[i].message}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Close'),
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

    return AnimatedBuilder(
      animation: Listenable.merge([routineStore, deviceControlService]),
      builder: (context, _) {
        final state = deviceControlService.state;
        final syncNotice = routineStore.syncNotice;
        final lastReport = routineStore.lastReport;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 780;

            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/welcome_living_room.jpg',
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.52),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isWide ? 32 : 20,
                          14,
                          isWide ? 32 : 20,
                          20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (onBackToHome != null)
                                  Material(
                                    color: Colors.white,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      tooltip: 'Back to Home',
                                      onPressed: onBackToHome,
                                      icon: const Icon(
                                        Icons.chevron_left_rounded,
                                        color: Colors.black87,
                                      ),
                                      constraints:
                                          const BoxConstraints.tightFor(
                                        width: 44,
                                        height: 44,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                if (routineStore.isSyncing)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 10),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                if (lastReport != null)
                                  TextButton.icon(
                                    onPressed: () => _showLatestReportSheet(
                                      context,
                                      lastReport,
                                    ),
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.16),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                    icon: Icon(
                                      lastReport.hasFailures
                                          ? Icons.error_outline_rounded
                                          : lastReport.hasSkipped
                                              ? Icons.info_outline_rounded
                                              : Icons
                                                  .check_circle_outline_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      '${lastReport.routineTitle}: '
                                      '${lastReport.overallStatusLabel}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(top: 20, bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Smart Routines',
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Control your home\ncomfortably',
                                      style: theme.textTheme.headlineLarge
                                          ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        height: 1.12,
                                        letterSpacing: -0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 460),
                                      child: Text(
                                        'Tap a routine card to customize connected '
                                        'devices, or toggle the switch to preview '
                                        'actions and run safely.',
                                        style:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Light ${state.lightOn ? "ON" : "OFF"}  ·  '
                                      'Fan ${state.fanOn ? "ON (Speed ${state.fanSpeed})" : "OFF"}  ·  '
                                      'Door ${state.doorLocked ? "Locked" : "Unlocked"} '
                                      '(${state.doorOpen ? "Open" : "Closed"})',
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.72),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (syncNotice != null) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              syncNotice,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: const Color(0xFFFFB78A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: routineStore.isSyncing
                                                ? null
                                                : () => unawaited(
                                                      routineStore.retrySync(),
                                                    ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            child: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final id in RoutineId.values) ...[
                                    Expanded(
                                      child: SizedBox(
                                        height: 162,
                                        child: _HeroRoutineCard(
                                          routine: routineStore.routineFor(id),
                                          isActive: activeModeLabel ==
                                              routineStore
                                                  .routineFor(id)
                                                  .modeChipLabel,
                                          onTapCard: () =>
                                              _openRoutineDetail(context, id),
                                          onToggleSwitch: () => unawaited(
                                            _previewAndRun(
                                              context,
                                              routineStore.routineFor(id),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  SizedBox(
                                    width: 96,
                                    height: 162,
                                    child: _DashedAddRoutineTile(
                                      onTap: () => unawaited(
                                        _showQuickCustomizePicker(context),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              SizedBox(
                                height: 162,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final id in RoutineId.values) ...[
                                      SizedBox(
                                        width: 212,
                                        child: _HeroRoutineCard(
                                          routine: routineStore.routineFor(id),
                                          isActive: activeModeLabel ==
                                              routineStore
                                                  .routineFor(id)
                                                  .modeChipLabel,
                                          onTapCard: () =>
                                              _openRoutineDetail(context, id),
                                          onToggleSwitch: () => unawaited(
                                            _previewAndRun(
                                              context,
                                              routineStore.routineFor(id),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    SizedBox(
                                      width: 92,
                                      child: _DashedAddRoutineTile(
                                        onTap: () => unawaited(
                                          _showQuickCustomizePicker(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HeroRoutineCard extends StatelessWidget {
  const _HeroRoutineCard({
    required this.routine,
    required this.isActive,
    required this.onTapCard,
    required this.onToggleSwitch,
  });

  final AutomationRoutine routine;
  final bool isActive;
  final VoidCallback onTapCard;
  final VoidCallback onToggleSwitch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = [
      if (routine.lightAction != BinaryDeviceAction.unchanged)
        routine.lightSummary,
      if (routine.fanAction != BinaryDeviceAction.unchanged)
        routine.fanSummary,
      if (routine.doorAction != DoorRoutineAction.unchanged)
        routine.doorSummary,
    ].join(', ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: isActive
              ? Colors.white.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onTapCard,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Switch.adaptive(
                        value: isActive,
                        onChanged: (_) => onToggleSwitch(),
                        activeTrackColor: const Color(0xFFFF5A00),
                        activeThumbColor: Colors.white,
                        inactiveTrackColor: Colors.black87,
                        inactiveThumbColor: Colors.white,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    routine.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary.isEmpty
                        ? 'Tap to add connected devices'
                        : summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black.withValues(alpha: 0.65),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedAddRoutineTile extends StatelessWidget {
  const _DashedAddRoutineTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRoundedRectPainter(
        color: Colors.white.withValues(alpha: 0.42),
        radius: 22,
      ),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: const Tooltip(
            message: 'Customize routine devices',
            child: Center(
              child: Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    const dashLength = 6.0;
    const gapLength = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
