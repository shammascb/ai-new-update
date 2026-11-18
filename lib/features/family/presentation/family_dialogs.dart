import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/family_management_store.dart';
import '../domain/family_member.dart';

Future<FamilyOperationResult?> showInviteOrAddMemberDialog({
  required BuildContext context,
  required FamilyManagementStore store,
  required bool isDirectAdd,
}) {
  return showDialog<FamilyOperationResult>(
    context: context,
    builder: (dialogContext) => _MemberFormDialog(
      store: store,
      isDirectAdd: isDirectAdd,
    ),
  );
}

Future<FamilyOperationResult?> showEditMemberPermissionsDialog({
  required BuildContext context,
  required FamilyManagementStore store,
  required FamilyMember member,
}) {
  return showDialog<FamilyOperationResult>(
    context: context,
    builder: (dialogContext) => _EditPermissionsDialog(
      store: store,
      member: member,
    ),
  );
}

Future<FamilyOperationResult?> showJoinHouseholdDialog({
  required BuildContext context,
  required FamilyManagementStore store,
}) {
  return showDialog<FamilyOperationResult>(
    context: context,
    builder: (dialogContext) => _JoinHouseholdDialog(store: store),
  );
}

Future<FamilyOperationResult?> showRemoveMemberConfirmDialog({
  required BuildContext context,
  required FamilyManagementStore store,
  required FamilyMember member,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove authorized user'),
      content: Text(
        'Remove ${member.displayName} (${member.email}) from ${store.homeName}? '
        'They will immediately lose access to household controls and voice actions.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true) return null;
  return store.removeMember(member.memberId);
}

class _MemberFormDialog extends StatefulWidget {
  const _MemberFormDialog({
    required this.store,
    required this.isDirectAdd,
  });

  final FamilyManagementStore store;
  final bool isDirectAdd;

  @override
  State<_MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<_MemberFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  FamilyRole _role = FamilyRole.adult;
  late FamilyPermissions _permissions =
      FamilyPermissions.forRole(FamilyRole.adult);
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _selectRole(FamilyRole role) {
    setState(() {
      _role = role;
      _permissions = FamilyPermissions.forRole(role);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = widget.isDirectAdd
        ? await widget.store.addAuthorizedMember(
            displayName: _nameController.text,
            email: _emailController.text,
            role: _role,
            permissions: _permissions,
          )
        : await widget.store.inviteMember(
            displayName: _nameController.text,
            email: _emailController.text,
            role: _role,
            permissions: _permissions,
          );

    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop(result);
    } else {
      setState(() {
        _submitting = false;
        _error = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.isDirectAdd ? 'Add authorized user' : 'Invite family member';

    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isDirectAdd
                      ? 'Authorize a family member and choose what they can control from their signed-in account.'
                      : 'Create an invitation tied to their email address and assigned permissions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: validateFamilyDisplayName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: validateFamilyEmail,
                ),
                const SizedBox(height: 14),
                Text(
                  'Role preset',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<FamilyRole>(
                  segments: const [
                    ButtonSegment(
                      value: FamilyRole.adult,
                      label: Text('Adult'),
                      icon: Icon(Icons.person_outline_rounded, size: 17),
                    ),
                    ButtonSegment(
                      value: FamilyRole.guest,
                      label: Text('Guest'),
                      icon: Icon(Icons.badge_outlined, size: 17),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: _submitting
                      ? null
                      : (selection) => _selectRole(selection.first),
                ),
                const SizedBox(height: 12),
                _PermissionSwitches(
                  permissions: _permissions,
                  allowAdminToggle: _role == FamilyRole.adult,
                  enabled: !_submitting,
                  onChanged: (next) => setState(() => _permissions = next),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(
            _submitting
                ? 'Saving…'
                : widget.isDirectAdd
                    ? 'Add user'
                    : 'Create invite',
          ),
        ),
      ],
    );
  }
}

class _EditPermissionsDialog extends StatefulWidget {
  const _EditPermissionsDialog({
    required this.store,
    required this.member,
  });

  final FamilyManagementStore store;
  final FamilyMember member;

  @override
  State<_EditPermissionsDialog> createState() => _EditPermissionsDialogState();
}

class _EditPermissionsDialogState extends State<_EditPermissionsDialog> {
  late FamilyRole _role;
  late FamilyPermissions _permissions;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _role = widget.member.role == FamilyRole.owner
        ? FamilyRole.adult
        : widget.member.role;
    _permissions = widget.member.permissions;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.store.updateMemberPermissions(
      memberId: widget.member.memberId,
      role: _role,
      permissions: _permissions,
    );
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop(result);
    } else {
      setState(() {
        _saving = false;
        _error = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Permissions · ${widget.member.displayName}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.member.email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<FamilyRole>(
                segments: const [
                  ButtonSegment(
                    value: FamilyRole.adult,
                    label: Text('Adult'),
                  ),
                  ButtonSegment(
                    value: FamilyRole.guest,
                    label: Text('Guest'),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: _saving
                    ? null
                    : (selection) {
                        final role = selection.first;
                        setState(() {
                          _role = role;
                          _permissions = FamilyPermissions.forRole(role);
                        });
                      },
              ),
              const SizedBox(height: 12),
              _PermissionSwitches(
                permissions: _permissions,
                allowAdminToggle: _role == FamilyRole.adult,
                enabled: !_saving,
                onChanged: (next) => setState(() => _permissions = next),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save permissions'),
        ),
      ],
    );
  }
}

class _JoinHouseholdDialog extends StatefulWidget {
  const _JoinHouseholdDialog({required this.store});

  final FamilyManagementStore store;

  @override
  State<_JoinHouseholdDialog> createState() => _JoinHouseholdDialogState();
}

class _JoinHouseholdDialogState extends State<_JoinHouseholdDialog> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.store.acceptInviteCode(_codeController.text);
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop(result);
    } else {
      setState(() {
        _submitting = false;
        _error = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join household with code'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the invite code sent to ${widget.store.currentEmail} to link your authenticated account.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Invite code (e.g. HB7K9M2P)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Joining…' : 'Join household'),
        ),
      ],
    );
  }
}

class _PermissionSwitches extends StatelessWidget {
  const _PermissionSwitches({
    required this.permissions,
    required this.allowAdminToggle,
    required this.enabled,
    required this.onChanged,
  });

  final FamilyPermissions permissions;
  final bool allowAdminToggle;
  final bool enabled;
  final ValueChanged<FamilyPermissions> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Control lights & fan'),
          value: permissions.canControlDevices,
          onChanged: enabled
              ? (val) => onChanged(permissions.copyWith(canControlDevices: val))
              : null,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Run automation routines'),
          value: permissions.canRunAutomations,
          onChanged: enabled
              ? (val) => onChanged(permissions.copyWith(canRunAutomations: val))
              : null,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Use voice commands (own account)'),
          subtitle: const Text(
            'Runs under their signed-in account; no speaker identity verification.',
          ),
          value: permissions.canUseVoiceCommands,
          onChanged: enabled
              ? (val) =>
                  onChanged(permissions.copyWith(canUseVoiceCommands: val))
              : null,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Manual door unlock'),
          subtitle: const Text(
            'Requires device confirmation; voice unlock stays blocked.',
          ),
          value: permissions.canUnlockDoor,
          onChanged: enabled
              ? (val) => onChanged(permissions.copyWith(canUnlockDoor: val))
              : null,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Manage family & invites'),
          value: allowAdminToggle ? permissions.canManageFamily : false,
          onChanged: enabled && allowAdminToggle
              ? (val) => onChanged(permissions.copyWith(canManageFamily: val))
              : null,
        ),
      ],
    );
  }
}

Future<void> copyInviteCodeWithNotice(
  BuildContext context,
  String inviteCode,
) async {
  await Clipboard.setData(ClipboardData(text: inviteCode));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Copied invite code $inviteCode'),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
