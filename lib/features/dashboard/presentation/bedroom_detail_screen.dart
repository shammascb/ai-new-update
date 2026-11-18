import 'package:flutter/material.dart';

import '../../devices/domain/device_control_service.dart';

class BedroomDetailScreen extends StatefulWidget {
  const BedroomDetailScreen({
    required this.deviceControlService,
    required this.onLightChanged,
    required this.onFanChanged,
    required this.onFanSpeedChanged,
    required this.onDoorLockedChanged,
    required this.onDoorOpenChanged,
    super.key,
  });

  final DeviceControlService deviceControlService;
  final Future<void> Function(bool isOn) onLightChanged;
  final Future<void> Function(bool isOn) onFanChanged;
  final Future<void> Function(int speed) onFanSpeedChanged;
  final Future<void> Function(bool isLocked) onDoorLockedChanged;
  final Future<void> Function(bool isOpen) onDoorOpenChanged;
  @override
  State<BedroomDetailScreen> createState() => _BedroomDetailScreenState();
}

class _BedroomDetailScreenState extends State<BedroomDetailScreen> {
  bool _isDoorActionPending = false;

  Future<void> _setDoorLocked(bool isLocked) async {
    setState(() => _isDoorActionPending = true);
    try {
      await widget.onDoorLockedChanged(isLocked);
    } finally {
      if (mounted) setState(() => _isDoorActionPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const Text('Bedroom'),
        actions: [
          IconButton(
            tooltip: 'Bedroom options',
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Bedroom controls are simulated.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.deviceControlService,
        builder: (context, _) {
          final state = widget.deviceControlService.state;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 224,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/bedroom.jpg',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.02),
                                  Colors.black.withValues(alpha: 0.42),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Lighting',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        state.lightOn ? 'On' : 'Off',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _DetailControlCard(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'Light',
                    subtitle:
                        state.lightOn ? 'On · Simulated' : 'Off · Simulated',
                    trailing: Switch.adaptive(
                      value: state.lightOn,
                      onChanged: widget.onLightChanged,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Fan Speed',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${state.fanSpeed} of 5',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _DetailControlCard(
                    icon: Icons.mode_fan_off_outlined,
                    title: 'Bedroom Fan',
                    subtitle:
                        state.fanOn ? 'On · Simulated' : 'Off · Simulated',
                    trailing: Switch.adaptive(
                      value: state.fanOn,
                      onChanged: widget.onFanChanged,
                    ),
                    footer: Slider(
                      value: state.fanSpeed.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: state.fanSpeed.toString(),
                      onChanged: state.fanOn
                          ? (speed) => widget.onFanSpeedChanged(speed.round())
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Door',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.door_front_door_outlined,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Front Door',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      state.doorLocked
                                          ? 'Locked · Simulated'
                                          : 'Unlocked · Simulated',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _isDoorActionPending
                                    ? null
                                    : () => _setDoorLocked(
                                          !state.doorLocked,
                                        ),
                                icon: _isDoorActionPending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        state.doorLocked
                                            ? Icons.lock_open
                                            : Icons.lock_outline,
                                      ),
                                label: Text(
                                  state.doorLocked ? 'Unlock' : 'Lock',
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 22),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Simulate door open'),
                            subtitle: Text(
                              state.doorOpen
                                  ? 'Door is open'
                                  : 'Door is closed',
                            ),
                            value: state.doorOpen,
                            onChanged: widget.onDoorOpenChanged,
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Unlocking requires phone PIN or biometrics. '
                              'Voice cannot unlock the door.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Device states are simulated; no physical devices are connected.',
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
}

class _DetailControlCard extends StatelessWidget {
  const _DetailControlCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: 4),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
