import 'package:flutter/material.dart';

import '../data/automation_routine_store.dart';
import '../domain/automation_routine.dart';

enum _DeviceCategory { all, lighting, climate, security }

enum _CatalogDeviceType { light, fan, door }

class AddDevicesScreen extends StatefulWidget {
  const AddDevicesScreen({
    required this.routine,
    required this.routineStore,
    super.key,
  });

  final AutomationRoutine routine;
  final AutomationRoutineStore routineStore;

  @override
  State<AddDevicesScreen> createState() => _AddDevicesScreenState();
}

class _AddDevicesScreenState extends State<AddDevicesScreen> {
  static const _accentOrange = Color(0xFFFF5A00);

  _DeviceCategory _selectedCategory = _DeviceCategory.all;
  late bool _includeLight;
  late bool _includeFan;
  late bool _includeDoor;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _includeLight = widget.routine.lightAction != BinaryDeviceAction.unchanged;
    _includeFan = widget.routine.fanAction != BinaryDeviceAction.unchanged;
    _includeDoor = widget.routine.doorAction != DoorRoutineAction.unchanged;
  }

  bool _isSelected(_CatalogDeviceType type) => switch (type) {
        _CatalogDeviceType.light => _includeLight,
        _CatalogDeviceType.fan => _includeFan,
        _CatalogDeviceType.door => _includeDoor,
      };

  void _toggleDevice(_CatalogDeviceType type) {
    setState(() {
      switch (type) {
        case _CatalogDeviceType.light:
          _includeLight = !_includeLight;
        case _CatalogDeviceType.fan:
          _includeFan = !_includeFan;
        case _CatalogDeviceType.door:
          _includeDoor = !_includeDoor;
      }
    });
  }

  Future<void> _saveSelection() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final defaults = AutomationRoutine.defaultFor(widget.routine.id);

    final nextLight = _includeLight
        ? (widget.routine.lightAction == BinaryDeviceAction.unchanged
            ? (defaults.lightAction == BinaryDeviceAction.unchanged
                ? BinaryDeviceAction.turnOff
                : defaults.lightAction)
            : widget.routine.lightAction)
        : BinaryDeviceAction.unchanged;

    final nextFan = _includeFan
        ? (widget.routine.fanAction == BinaryDeviceAction.unchanged
            ? (defaults.fanAction == BinaryDeviceAction.unchanged
                ? BinaryDeviceAction.turnOff
                : defaults.fanAction)
            : widget.routine.fanAction)
        : BinaryDeviceAction.unchanged;

    final nextDoor = _includeDoor
        ? (widget.routine.doorAction == DoorRoutineAction.unchanged
            ? (defaults.doorAction == DoorRoutineAction.unchanged
                ? DoorRoutineAction.lockWithSafetyCheck
                : defaults.doorAction)
            : widget.routine.doorAction)
        : DoorRoutineAction.unchanged;

    final updated = widget.routine.copyWith(
      lightAction: nextLight,
      fanAction: nextFan,
      doorAction: nextDoor,
    );

    await widget.routineStore.saveRoutine(updated);
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final canvasColor =
        isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF9F9FB);
    final cardColor = isDark ? colorScheme.surface : const Color(0xFFF1F2F4);

    final catalog = [
      (
        type: _CatalogDeviceType.light,
        category: _DeviceCategory.lighting,
        title: 'Smart Light',
        subtitle: 'Living room · LED control',
        icon: Icons.lightbulb_outline_rounded,
        imageAsset: 'assets/images/welcome_living_room.jpg',
      ),
      (
        type: _CatalogDeviceType.fan,
        category: _DeviceCategory.climate,
        title: 'Bedroom Fan',
        subtitle: 'Bedroom · Power & Speed 1–5',
        icon: Icons.mode_fan_off_outlined,
        imageAsset: 'assets/images/bedroom.jpg',
      ),
      (
        type: _CatalogDeviceType.door,
        category: _DeviceCategory.security,
        title: 'Front Door Lock',
        subtitle: 'Front entry · Safety checked',
        icon: Icons.lock_outline_rounded,
        imageAsset: null,
      ),
    ];

    final visibleCatalog = _selectedCategory == _DeviceCategory.all
        ? catalog
        : catalog.where((item) => item.category == _selectedCategory).toList();

    final selectedCount = [_includeLight, _includeFan, _includeDoor]
        .where((selected) => selected)
        .length;

    return Scaffold(
      backgroundColor: canvasColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CircleIconButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Back',
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Add your devices',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select which smart devices participate in ${widget.routine.title}.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CategoryTile(
                              label: 'All devices',
                              icon: Icons.grid_view_rounded,
                              selected:
                                  _selectedCategory == _DeviceCategory.all,
                              accentColor: _accentOrange,
                              onTap: () => setState(
                                () => _selectedCategory = _DeviceCategory.all,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _CategoryTile(
                              label: 'Lighting',
                              icon: Icons.lightbulb_outline_rounded,
                              selected:
                                  _selectedCategory == _DeviceCategory.lighting,
                              accentColor: _accentOrange,
                              onTap: () => setState(
                                () =>
                                    _selectedCategory = _DeviceCategory.lighting,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _CategoryTile(
                              label: 'Climate',
                              icon: Icons.air_rounded,
                              selected:
                                  _selectedCategory == _DeviceCategory.climate,
                              accentColor: _accentOrange,
                              onTap: () => setState(
                                () =>
                                    _selectedCategory = _DeviceCategory.climate,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _CategoryTile(
                              label: 'Security',
                              icon: Icons.shield_outlined,
                              selected:
                                  _selectedCategory == _DeviceCategory.security,
                              accentColor: _accentOrange,
                              onTap: () => setState(
                                () =>
                                    _selectedCategory = _DeviceCategory.security,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 680 ? 3 : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.86,
                        ),
                        itemCount: visibleCatalog.length,
                        itemBuilder: (context, index) {
                          final item = visibleCatalog[index];
                          final selected = _isSelected(item.type);

                          return _DeviceCatalogCard(
                            title: item.title,
                            subtitle: item.subtitle,
                            icon: item.icon,
                            imageAsset: item.imageAsset,
                            selected: selected,
                            cardColor: cardColor,
                            accentColor: _accentOrange,
                            onTap: () => _toggleDevice(item.type),
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: canvasColor,
                    border: Border(
                      top: BorderSide(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveSelection,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accentOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isSaving
                            ? 'Saving devices…'
                            : 'Save Connected Devices ($selectedCount)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unselectedBg = theme.brightness == Brightness.dark
        ? colorScheme.surface
        : const Color(0xFFF1F2F4);

    return Material(
      color: selected ? accentColor : unselectedBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minWidth: 88, minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCatalogCard extends StatelessWidget {
  const _DeviceCatalogCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.imageAsset,
    required this.selected,
    required this.cardColor,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? imageAsset;
  final bool selected;
  final Color cardColor;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? accentColor
                  : colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected ? accentColor : colorScheme.surface,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: selected
                          ? accentColor
                          : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              Expanded(
                child: Center(
                  child: imageAsset != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 84,
                            height: 84,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(imageAsset!, fit: BoxFit.cover),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.28),
                                  ),
                                ),
                                Icon(icon, size: 32, color: Colors.white),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            size: 32,
                            color: selected
                                ? accentColor
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
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
                maxLines: 2,
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
