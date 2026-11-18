import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/device_monitoring.dart';

enum DeviceMonitoringTab { overview, commands, errors }

enum CommandHistoryFilter { all, succeeded, failed }

class DeviceMonitoringScreen extends StatefulWidget {
  const DeviceMonitoringScreen({
    required this.store,
    this.initialTab = DeviceMonitoringTab.overview,
    super.key,
  });

  final DeviceMonitoringStore store;
  final DeviceMonitoringTab initialTab;

  @override
  State<DeviceMonitoringScreen> createState() => _DeviceMonitoringScreenState();
}

class _DeviceMonitoringScreenState extends State<DeviceMonitoringScreen> {
  late DeviceMonitoringTab _selectedTab = widget.initialTab;
  CommandHistoryFilter _commandFilter = CommandHistoryFilter.all;
  String? _selectedDeviceFilter;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _refreshAll() async {
    await widget.store.refreshAllDevices();
    _showSnack('Simulated ESP32 status refresh completed.');
  }

  Future<void> _pingDevice(MonitoredDevice device) async {
    await widget.store.refreshDevice(device.deviceId);
    _showSnack(
      device.isOnline
          ? '${device.name} responded (${device.rssiDbm ?? -58} dBm).'
          : '${device.name} is offline; timeout recorded.',
    );
  }

  Future<void> _openEsp32PacketSimulator() async {
    final devices = widget.store.devices;
    if (devices.isEmpty) return;

    var selectedId = devices.first.deviceId;
    var simulateOnline = true;
    final rssiController = TextEditingController(text: '-59');
    final errorCodeController =
        TextEditingController(text: 'ERR_HEARTBEAT_TIMEOUT');
    final errorMessageController = TextEditingController(
      text: 'ESP32 node missed 3 consecutive MQTT keepalives.',
    );

    final payload = await showDialog<Esp32StatusPayload>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Simulate ESP32 status update'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send a JSON status frame through Esp32StatusGateway to test '
                    'future ESP32 telemetry handling.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    decoration: const InputDecoration(
                      labelText: 'Target device',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final d in devices)
                        DropdownMenuItem(
                          value: d.deviceId,
                          child: Text(d.name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Report node online'),
                    subtitle: Text(
                      simulateOnline
                          ? 'Device will report Online with updated heartbeat'
                          : 'Device will report Offline and log a connection error',
                    ),
                    value: simulateOnline,
                    onChanged: (value) =>
                        setDialogState(() => simulateOnline = value),
                  ),
                  if (simulateOnline) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: rssiController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Wi-Fi RSSI (dBm)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: errorCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Error code',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: errorMessageController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Connection error message',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final rssi = int.tryParse(rssiController.text.trim()) ?? -59;
                Navigator.of(dialogContext).pop(
                  Esp32StatusPayload.fromJson({
                    'deviceId': selectedId,
                    'online': simulateOnline,
                    'reportedState': <String, Object?>{},
                    'timestamp': DateTime.now().toIso8601String(),
                    'rssiDbm': simulateOnline ? rssi : null,
                    'firmwareVersion': 'esp32-sim-1.0',
                    'errorCode': simulateOnline
                        ? null
                        : (errorCodeController.text.trim().isEmpty
                            ? 'ERR_NODE_OFFLINE'
                            : errorCodeController.text.trim()),
                    'errorMessage': simulateOnline
                        ? null
                        : (errorMessageController.text.trim().isEmpty
                            ? 'ESP32 node unreachable.'
                            : errorMessageController.text.trim()),
                  }),
                );
              },
              child: const Text('Send update'),
            ),
          ],
        ),
      ),
    );

    rssiController.dispose();
    errorCodeController.dispose();
    errorMessageController.dispose();

    if (payload == null || !mounted) return;
    widget.store.applyEsp32StatusUpdate(payload);
    _showSnack(
      payload.online
          ? 'Applied online ESP32 status update for ${payload.deviceId}.'
          : 'Applied offline ESP32 status update for ${payload.deviceId}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Monitoring'),
        actions: [
          IconButton(
            tooltip: 'Simulate ESP32 update',
            onPressed: _openEsp32PacketSimulator,
            icon: const Icon(Icons.sensors_rounded),
          ),
          IconButton(
            tooltip: 'Refresh device status',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final store = widget.store;
          final horizontalPadding =
              MediaQuery.sizeOf(context).width >= 700 ? 32.0 : 18.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  32,
                ),
                children: [
                  _TelemetrySummaryStrip(store: store),
                  const SizedBox(height: 12),
                  _SimulationNoticeRow(
                    store: store,
                    onSimulatePacket: _openEsp32PacketSimulator,
                    onRefreshAll: _refreshAll,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<DeviceMonitoringTab>(
                    segments: [
                      const ButtonSegment(
                        value: DeviceMonitoringTab.overview,
                        label: Text('Overview'),
                        icon: Icon(Icons.monitor_heart_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: DeviceMonitoringTab.commands,
                        label: Text('Commands (${store.commandHistory.length})'),
                        icon: const Icon(Icons.history_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: DeviceMonitoringTab.errors,
                        label: Text(
                          'Errors (${store.activeConnectionErrors.length})',
                        ),
                        icon: const Icon(Icons.error_outline_rounded, size: 18),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (selection) =>
                        setState(() => _selectedTab = selection.first),
                  ),
                  const SizedBox(height: 18),
                  switch (_selectedTab) {
                    DeviceMonitoringTab.overview => _buildOverview(context, store),
                    DeviceMonitoringTab.commands =>
                      _buildCommandsTab(context, store),
                    DeviceMonitoringTab.errors => _buildErrorsTab(context, store),
                  },
                  const SizedBox(height: 20),
                  Text(
                    'Simulated telemetry active · Real ESP32 hardware updates '
                    'plug directly into Esp32StatusGateway without UI changes.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverview(BuildContext context, DeviceMonitoringStore store) {
    final theme = Theme.of(context);
    final recentCommands = store.commandHistory.take(4).toList();
    final failedCount = store.failedCommands.length;
    final activeErrors = store.activeConnectionErrors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monitored devices',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < store.devices.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _MonitoredDeviceCard(
            device: store.devices[i],
            onPing: () => _pingDevice(store.devices[i]),
            onToggleSimulatedConnectivity: (online) {
              store.simulateDeviceConnectivity(
                store.devices[i].deviceId,
                online: online,
              );
              _showSnack(
                online
                    ? '${store.devices[i].name} brought back online (simulated).'
                    : '${store.devices[i].name} set offline (simulated). '
                        'Commands to this device will now fail.',
              );
            },
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent command history',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _selectedTab = DeviceMonitoringTab.commands),
              child: Text('All commands · $failedCount failed'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recentCommands.isEmpty)
          const _EmptyStateCard(
            icon: Icons.history_rounded,
            title: 'No device commands recorded yet',
            description:
                'Control a device from Home, Devices, Automations, or Voice to inspect execution logs.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < recentCommands.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  _CommandLogTile(entry: recentCommands[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                'Connection errors',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _selectedTab = DeviceMonitoringTab.errors),
              child: const Text('Inspect errors'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (activeErrors.isEmpty)
          const _EmptyStateCard(
            icon: Icons.check_circle_outline_rounded,
            title: 'No active connection errors',
            description:
                'All simulated ESP32 nodes are responding within expected heartbeat intervals.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < activeErrors.take(3).length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  _ConnectionErrorTile(
                    error: activeErrors[i],
                    onResolve: () =>
                        store.resolveConnectionError(activeErrors[i].id),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCommandsTab(BuildContext context, DeviceMonitoringStore store) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final devices = store.devices;

    final filtered = store.commandHistory.where((entry) {
      if (_commandFilter == CommandHistoryFilter.succeeded && entry.isFailed) {
        return false;
      }
      if (_commandFilter == CommandHistoryFilter.failed && !entry.isFailed) {
        return false;
      }
      if (_selectedDeviceFilter != null &&
          entry.deviceId != _selectedDeviceFilter) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Command history',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${store.commandHistory.length} total · '
          '${store.failedCommands.length} failed',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: Text('All (${store.commandHistory.length})'),
              selected: _commandFilter == CommandHistoryFilter.all,
              onSelected: (_) =>
                  setState(() => _commandFilter = CommandHistoryFilter.all),
            ),
            ChoiceChip(
              label: Text(
                'Succeeded (${store.commandHistory.length - store.failedCommands.length})',
              ),
              selected: _commandFilter == CommandHistoryFilter.succeeded,
              onSelected: (_) => setState(
                () => _commandFilter = CommandHistoryFilter.succeeded,
              ),
            ),
            ChoiceChip(
              label: Text('Failed (${store.failedCommands.length})'),
              selected: _commandFilter == CommandHistoryFilter.failed,
              onSelected: (_) =>
                  setState(() => _commandFilter = CommandHistoryFilter.failed),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          key: ValueKey('cmd-device-filter-$_selectedDeviceFilter'),
          initialValue: _selectedDeviceFilter,
          decoration: const InputDecoration(
            labelText: 'Filter by device',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All devices'),
            ),
            for (final d in devices)
              DropdownMenuItem<String?>(
                value: d.deviceId,
                child: Text(d.name),
              ),
          ],
          onChanged: (value) => setState(() => _selectedDeviceFilter = value),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          const _EmptyStateCard(
            icon: Icons.filter_list_off_rounded,
            title: 'No matching commands',
            description:
                'Change the status or device filter, or issue a device command to log an entry.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  _CommandLogTile(entry: filtered[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildErrorsTab(BuildContext context, DeviceMonitoringStore store) {
    final theme = Theme.of(context);
    final failed = store.failedCommands;
    final errors = store.connectionErrors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Failed commands (${failed.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (failed.isEmpty)
          const _EmptyStateCard(
            icon: Icons.check_circle_outline_rounded,
            title: 'No failed commands',
            description:
                'Toggle a device offline in Overview and send a command to see failed execution handling.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < failed.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  _CommandLogTile(entry: failed[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 22),
        Text(
          'Connection errors (${errors.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (errors.isEmpty)
          const _EmptyStateCard(
            icon: Icons.wifi_tethering_rounded,
            title: 'No connection errors',
            description: 'No ESP32 heartbeat or transport errors have occurred.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < errors.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  _ConnectionErrorTile(
                    error: errors[i],
                    onResolve: errors[i].resolved
                        ? null
                        : () => store.resolveConnectionError(errors[i].id),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TelemetrySummaryStrip extends StatelessWidget {
  const _TelemetrySummaryStrip({required this.store});

  final DeviceMonitoringStore store;

  @override
  Widget build(BuildContext context) {
    final total = store.devices.length;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final metrics = [
              _SummaryMetric(
                label: 'Online',
                value: '${store.onlineCount}/$total',
                tone: store.onlineCount == total
                    ? Colors.green
                    : colorScheme.primary,
              ),
              _SummaryMetric(
                label: 'Offline',
                value: '${store.offlineCount}',
                tone: store.offlineCount > 0
                    ? colorScheme.error
                    : colorScheme.onSurface,
              ),
              _SummaryMetric(
                label: 'Failed cmds',
                value: '${store.failedCommands.length}',
                tone: store.failedCommands.isNotEmpty
                    ? colorScheme.tertiary
                    : colorScheme.onSurface,
              ),
              _SummaryMetric(
                label: 'Active errors',
                value: '${store.activeConnectionErrors.length}',
                tone: store.activeConnectionErrors.isNotEmpty
                    ? colorScheme.error
                    : colorScheme.onSurface,
              ),
            ];

            if (compact) {
              return Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  for (final m in metrics)
                    SizedBox(
                      width: (constraints.maxWidth - 20) / 2,
                      child: m,
                    ),
                ],
              );
            }

            return Row(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  Expanded(child: metrics[i]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: tone,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SimulationNoticeRow extends StatelessWidget {
  const _SimulationNoticeRow({
    required this.store,
    required this.onSimulatePacket,
    required this.onRefreshAll,
  });

  final DeviceMonitoringStore store;
  final VoidCallback onSimulatePacket;
  final VoidCallback onRefreshAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final syncLabel = store.lastGlobalSyncAt == null
        ? 'Not synced yet'
        : _formatClockAndRelative(store.lastGlobalSyncAt!);

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(
          'Simulated ESP32 states · Last sync: $syncLabel',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onSimulatePacket,
              icon: const Icon(Icons.sensors_rounded, size: 17),
              label: const Text('Simulate ESP32 update'),
            ),
            FilledButton.tonalIcon(
              onPressed: store.isRefreshing ? null : onRefreshAll,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(store.isRefreshing ? 'Syncing…' : 'Ping all'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MonitoredDeviceCard extends StatelessWidget {
  const _MonitoredDeviceCard({
    required this.device,
    required this.onPing,
    required this.onToggleSimulatedConnectivity,
  });

  final MonitoredDevice device;
  final VoidCallback onPing;
  final ValueChanged<bool> onToggleSimulatedConnectivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final deviceIcon = switch (device.kind) {
      DeviceKind.light => Icons.lightbulb_outline_rounded,
      DeviceKind.fan => Icons.mode_fan_off_outlined,
      DeviceKind.doorLock => Icons.door_front_door_outlined,
    };

    final statusColor = switch (device.connectivity) {
      DeviceConnectivity.online => Colors.green,
      DeviceConnectivity.degraded => colorScheme.tertiary,
      DeviceConnectivity.offline => colorScheme.error,
    };
    final statusIcon = switch (device.connectivity) {
      DeviceConnectivity.online => Icons.cloud_done_outlined,
      DeviceConnectivity.degraded => Icons.warning_amber_rounded,
      DeviceConnectivity.offline => Icons.cloud_off_outlined,
    };

    final rssiText =
        device.rssiDbm != null ? ' · ${device.rssiDbm} dBm' : '';
    final commText = _formatClockAndRelative(device.lastCommunicationAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(deviceIcon, color: colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${device.room} · ${device.endpointHint}$rssiText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 17, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      device.connectivity.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current state',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.currentStateLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last communication',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      commText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (device.lastError != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      device.lastError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onPing,
                  icon: const Icon(Icons.network_ping_rounded, size: 16),
                  label: const Text('Ping'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      onToggleSimulatedConnectivity(!device.isOnline),
                  icon: Icon(
                    device.isOnline
                        ? Icons.wifi_off_rounded
                        : Icons.wifi_rounded,
                    size: 16,
                  ),
                  label: Text(
                    device.isOnline ? 'Simulate offline' : 'Bring online',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandLogTile extends StatelessWidget {
  const _CommandLogTile({required this.entry});

  final DeviceCommandLog entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final failed = entry.isFailed;
    final tone = failed ? colorScheme.error : Colors.green;
    final latencyText =
        entry.latencyMs != null ? ' · ${entry.latencyMs} ms' : '';

    return ListTile(
      leading: Icon(
        failed ? Icons.cancel_outlined : Icons.check_circle_outline_rounded,
        color: tone,
      ),
      title: Text(
        entry.command,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.deviceName} · ${entry.status.label} · '
            '${entry.source.label}$latencyText · '
            '${_formatClockAndRelative(entry.timestamp)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (entry.errorMessage != null) ...[
            const SizedBox(height: 3),
            Text(
              entry.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionErrorTile extends StatelessWidget {
  const _ConnectionErrorTile({
    required this.error,
    this.onResolve,
  });

  final DeviceConnectionError error;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = error.resolved ? colorScheme.onSurfaceVariant : colorScheme.error;

    return ListTile(
      leading: Icon(
        error.resolved
            ? Icons.check_circle_outline_rounded
            : Icons.wifi_tethering_error_rounded,
        color: tone,
      ),
      title: Text(
        '${error.deviceName} · ${error.code}',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${error.message}\n'
        '${error.resolved ? "Resolved" : "Active error"} · '
        '${_formatClockAndRelative(error.occurredAt)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: error.resolved ? colorScheme.onSurfaceVariant : colorScheme.error,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      isThreeLine: true,
      trailing: onResolve == null
          ? null
          : TextButton(
              onPressed: onResolve,
              child: const Text('Resolve'),
            ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatClockAndRelative(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final ss = dt.second.toString().padLeft(2, '0');
  final diff = DateTime.now().difference(dt);
  final relative = diff.inSeconds < 5
      ? 'Just now'
      : diff.inSeconds < 60
          ? '${diff.inSeconds}s ago'
          : diff.inMinutes < 60
              ? '${diff.inMinutes}m ago'
              : '${diff.inHours}h ago';
  return '$hh:$mm:$ss ($relative)';
}
