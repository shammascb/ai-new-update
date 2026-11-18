import 'package:flutter/material.dart';

import '../../auth/data/firebase_auth_service.dart';
import '../data/family_management_store.dart';
import '../domain/family_member.dart';
import 'family_dialogs.dart';

enum FamilySectionTab { members, activity, security }

class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({
    required this.store,
    this.authService,
    this.initialTab = FamilySectionTab.members,
    super.key,
  });

  final FamilyManagementStore store;
  final FirebaseAuthService? authService;
  final FamilySectionTab initialTab;

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen> {
  late FamilySectionTab _selectedTab = widget.initialTab;
  String _selectedActorFilter = 'all';
  ActivityCategory? _selectedCategoryFilter;
  bool _sendingSecurityEmail = false;

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

  Future<void> _openInviteOrAdd(bool isDirectAdd) async {
    final result = await showInviteOrAddMemberDialog(
      context: context,
      store: widget.store,
      isDirectAdd: isDirectAdd,
    );
    if (!mounted || result == null) return;
    _showSnack(result.message);
  }

  Future<void> _openJoinDialog() async {
    final result = await showJoinHouseholdDialog(
      context: context,
      store: widget.store,
    );
    if (!mounted || result == null) return;
    _showSnack(result.message);
  }

  Future<void> _openEditPermissions(FamilyMember member) async {
    final result = await showEditMemberPermissionsDialog(
      context: context,
      store: widget.store,
      member: member,
    );
    if (!mounted || result == null) return;
    _showSnack(result.message);
  }

  Future<void> _removeMember(FamilyMember member) async {
    final result = await showRemoveMemberConfirmDialog(
      context: context,
      store: widget.store,
      member: member,
    );
    if (!mounted || result == null) return;
    _showSnack(result.message);
  }

  Future<void> _revokeInvite(FamilyInvite invite) async {
    final result = await widget.store.revokeInvite(invite.inviteCode);
    if (!mounted) return;
    _showSnack(result.message);
  }

  Future<void> _acceptPendingInvite(FamilyInvite invite) async {
    final result = await widget.store.acceptInviteCode(invite.inviteCode);
    if (!mounted) return;
    _showSnack(result.message);
  }

  Future<void> _sendVerificationEmail() async {
    final authService = widget.authService;
    if (authService == null || _sendingSecurityEmail) return;
    setState(() => _sendingSecurityEmail = true);
    try {
      await authService.sendEmailVerification();
      await widget.store.recordActivity(
        actionTitle: 'Requested verification email',
        detail: 'Sent to ${widget.store.currentEmail}',
        category: ActivityCategory.security,
        source: ActivitySource.family,
      );
      _showSnack(
        'Verification email sent to ${widget.store.currentEmail}. Check your inbox and tap Refresh.',
      );
    } catch (error) {
      _showSnack('Could not send verification email: $error');
    } finally {
      if (mounted) setState(() => _sendingSecurityEmail = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final authService = widget.authService;
    if (authService == null || _sendingSecurityEmail) return;
    setState(() => _sendingSecurityEmail = true);
    try {
      await authService.sendPasswordReset(widget.store.currentEmail);
      await widget.store.recordActivity(
        actionTitle: 'Requested password reset email',
        detail: 'Sent to ${widget.store.currentEmail}',
        category: ActivityCategory.security,
        source: ActivitySource.family,
      );
      _showSnack(
        'Password reset email sent to ${widget.store.currentEmail}.',
      );
    } catch (error) {
      _showSnack('Could not send password reset email: $error');
    } finally {
      if (mounted) setState(() => _sendingSecurityEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family & Security'),
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final horizontalPadding =
              MediaQuery.sizeOf(context).width >= 700 ? 32.0 : 18.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  32,
                ),
                children: [
                  SegmentedButton<FamilySectionTab>(
                    segments: const [
                      ButtonSegment(
                        value: FamilySectionTab.members,
                        label: Text('Members'),
                        icon: Icon(Icons.group_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: FamilySectionTab.activity,
                        label: Text('Activity'),
                        icon: Icon(Icons.history_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: FamilySectionTab.security,
                        label: Text('Security'),
                        icon: Icon(Icons.verified_user_outlined, size: 18),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (selection) =>
                        setState(() => _selectedTab = selection.first),
                  ),
                  if (widget.store.syncNotice != null) ...[
                    const SizedBox(height: 14),
                    Card(
                      color: colorScheme.tertiaryContainer.withValues(alpha: 0.55),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.store.syncNotice!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                            if (widget.store.isCloudConnected)
                              TextButton(
                                onPressed: widget.store.isSyncing
                                    ? null
                                    : () => widget.store.retrySync(),
                                child: const Text('Retry'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  switch (_selectedTab) {
                    FamilySectionTab.members => _buildMembersTab(context),
                    FamilySectionTab.activity => _buildActivityTab(context),
                    FamilySectionTab.security => _buildSecurityTab(context),
                  },
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMembersTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final store = widget.store;
    final members = store.members;
    final pendingInvites = store.pendingOutgoingInvites;
    final incomingInvites = store.incomingInvites;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                      child: Icon(
                        Icons.home_outlined,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.homeName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${members.length} authorized · '
                            '${pendingInvites.length} pending invite'
                            '${pendingInvites.length == 1 ? '' : 's'} · '
                            'Your role: ${store.currentRole.label}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (store.canManageFamily) ...[
                      FilledButton.icon(
                        onPressed: () => _openInviteOrAdd(false),
                        icon: const Icon(Icons.mail_outline_rounded, size: 18),
                        label: const Text('Invite family member'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _openInviteOrAdd(true),
                        icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                        label: const Text('Add authorized user'),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: _openJoinDialog,
                      icon: const Icon(Icons.vpn_key_outlined, size: 18),
                      label: const Text('Join with invite code'),
                    ),
                  ],
                ),
                if (!store.canManageFamily) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Only household owners or admins with family management '
                    'permission can add, edit, or remove members.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (incomingInvites.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Invitations for your account',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final invite in incomingInvites) ...[
            Card(
              color: colorScheme.primaryContainer.withValues(alpha: 0.45),
              child: ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined),
                title: Text('Join ${invite.homeName} as ${invite.role.label}'),
                subtitle: Text(
                  'Invited by ${invite.invitedByName} · Code ${invite.inviteCode}',
                ),
                trailing: FilledButton(
                  onPressed: () => _acceptPendingInvite(invite),
                  child: const Text('Accept'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 22),
        Text(
          'Authorized users',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < members.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _MemberCard(
            member: members[i],
            isCurrentUser: members[i].uid == store.currentUid ||
                members[i].memberId == store.currentUid,
            canManage: store.canManageFamily && !members[i].isPrimaryOwner,
            onEditPermissions: () => _openEditPermissions(members[i]),
            onRemove: () => _removeMember(members[i]),
          ),
        ],
        const SizedBox(height: 22),
        Text(
          'Pending invitations',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (pendingInvites.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No pending invitations. Invite a family member so they can '
                'sign in from their own account and use voice commands with '
                'assigned permissions.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (var i = 0; i < pendingInvites.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${pendingInvites[i].displayName} · '
                                '${pendingInvites[i].role.label}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                pendingInvites[i].invitedEmail,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pendingInvites[i].inviteCode,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Permissions: ${pendingInvites[i].permissions.activeLabels.join(", ")}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => copyInviteCodeWithNotice(
                            context,
                            pendingInvites[i].inviteCode,
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy code'),
                        ),
                        if (store.canManageFamily)
                          TextButton.icon(
                            onPressed: () => _revokeInvite(pendingInvites[i]),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.error,
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Revoke'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
      ],
    );
  }

  Widget _buildActivityTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activities = widget.store.activities;

    final actors = <String, String>{};
    for (final entry in activities) {
      actors[entry.actorUid] = entry.actorName;
    }
    for (final member in widget.store.members) {
      if (member.uid.isNotEmpty) {
        actors.putIfAbsent(member.uid, () => member.displayName);
      }
    }

    final filtered = activities.where((entry) {
      if (_selectedActorFilter != 'all' &&
          entry.actorUid != _selectedActorFilter) {
        return false;
      }
      if (_selectedCategoryFilter != null &&
          entry.category != _selectedCategoryFilter) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User activity history',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Actions performed from authenticated family accounts across '
          'devices, automations, voice commands, and member management.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('actor-filter-$_selectedActorFilter'),
          initialValue: actors.containsKey(_selectedActorFilter)
              ? _selectedActorFilter
              : 'all',
          decoration: const InputDecoration(
            labelText: 'Filter by family member',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('All members'),
            ),
            for (final entry in actors.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _selectedActorFilter = value);
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _selectedCategoryFilter == null,
              onSelected: (_) => setState(() => _selectedCategoryFilter = null),
            ),
            for (final cat in ActivityCategory.values)
              ChoiceChip(
                label: Text(cat.label),
                selected: _selectedCategoryFilter == cat,
                onSelected: (_) => setState(
                  () => _selectedCategoryFilter =
                      _selectedCategoryFilter == cat ? null : cat,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'No activity entries recorded yet for this filter. Toggle a '
                'device, run a routine, issue a voice command, or update family '
                'access to log user-attributed history.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  _ActivityHistoryRow(entry: filtered[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSecurityTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final store = widget.store;
    final perms = store.currentPermissions;
    final usesPassword = store.currentProviderIds.contains('password');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      store.isEmailVerified
                          ? Icons.verified_user_rounded
                          : Icons.gpp_maybe_outlined,
                      color: store.isEmailVerified
                          ? Colors.green
                          : colorScheme.tertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Account security',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (store.isEmailVerified
                                ? Colors.green
                                : colorScheme.tertiary)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        store.isEmailVerified ? 'Verified' : 'Unverified',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: store.isEmailVerified
                              ? Colors.green
                              : colorScheme.tertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SecurityRow(label: 'Signed-in user', value: store.currentName),
                const SizedBox(height: 6),
                _SecurityRow(label: 'Email', value: store.currentEmail),
                const SizedBox(height: 6),
                _SecurityRow(
                  label: 'Sign-in method',
                  value: store.currentProviderIds.isEmpty
                      ? 'Firebase Auth'
                      : store.currentProviderIds.join(', '),
                ),
                const SizedBox(height: 6),
                _SecurityRow(
                  label: 'Household role',
                  value: '${store.currentRole.label} · ${store.homeName}',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!store.isEmailVerified && widget.authService != null)
                      FilledButton.icon(
                        onPressed:
                            _sendingSecurityEmail ? null : _sendVerificationEmail,
                        icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                        label: const Text('Send verification email'),
                      ),
                    if (widget.authService != null)
                      OutlinedButton.icon(
                        onPressed: store.isSyncing
                            ? null
                            : () => store.refreshAccountSecurityStatus(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh status'),
                      ),
                    if (usesPassword && widget.authService != null)
                      OutlinedButton.icon(
                        onPressed:
                            _sendingSecurityEmail ? null : _sendPasswordReset,
                        icon: const Icon(Icons.lock_reset_rounded, size: 18),
                        label: const Text('Send password reset'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your assigned permissions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _PermissionStatusLine(
                  label: 'Control lights and fan',
                  allowed: perms.canControlDevices,
                ),
                _PermissionStatusLine(
                  label: 'Run automation routines',
                  allowed: perms.canRunAutomations,
                ),
                _PermissionStatusLine(
                  label: 'Voice commands (from your authenticated account)',
                  allowed: perms.canUseVoiceCommands,
                ),
                _PermissionStatusLine(
                  label: 'Manual door unlock (with device confirmation)',
                  allowed: perms.canUnlockDoor,
                ),
                _PermissionStatusLine(
                  label: 'Manage family members & invites',
                  allowed: perms.canManageFamily,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.record_voice_over_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice command identity & limitations',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Family members can issue voice commands when signed into '
                        'their own authenticated accounts, and actions are logged '
                        'under that account. However, speaker or voice-print '
                        'identity verification is NOT implemented—this app cannot '
                        'verify who spoke into the microphone. Keep your device '
                        'locked when unattended; door unlocking remains disabled '
                        'for all voice commands.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.isCurrentUser,
    required this.canManage,
    required this.onEditPermissions,
    required this.onRemove,
  });

  final FamilyMember member;
  final bool isCurrentUser;
  final bool canManage;
  final VoidCallback onEditPermissions;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final initial = member.displayName.trim().isEmpty
        ? '?'
        : member.displayName.trim()[0].toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                  foregroundColor: colorScheme.primary,
                  child: Text(
                    initial,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrentUser
                            ? '${member.displayName} (You)'
                            : member.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    member.role.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Status: ${member.status == MemberStatus.active ? 'Active account' : 'Authorized · Awaiting sign-in'}'
              '${member.inviteCode.isNotEmpty && member.status == MemberStatus.invited ? ' (Code: ${member.inviteCode})' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Permissions: ${member.permissions.activeLabels.isEmpty ? 'Read-only' : member.permissions.activeLabels.join(' · ')}',
              style: theme.textTheme.bodySmall,
            ),
            if (canManage) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEditPermissions,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Permissions'),
                  ),
                  TextButton.icon(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    icon: const Icon(Icons.person_remove_outlined, size: 16),
                    label: const Text('Remove'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityHistoryRow extends StatelessWidget {
  const _ActivityHistoryRow({required this.entry});

  final FamilyActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = switch (entry.category) {
      ActivityCategory.device => Icons.lightbulb_outline_rounded,
      ActivityCategory.door => Icons.door_front_door_outlined,
      ActivityCategory.automation => Icons.auto_awesome_outlined,
      ActivityCategory.voice => Icons.mic_none_rounded,
      ActivityCategory.family => Icons.group_outlined,
      ActivityCategory.security => Icons.verified_user_outlined,
    };

    final timeLabel = _formatTimestamp(entry.createdAt);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
        child: Icon(icon, color: colorScheme.primary, size: 20),
      ),
      title: Text(
        entry.actionTitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.detail.isNotEmpty)
            Text(
              entry.detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            '${entry.actorName} (${entry.actorRole.label}) · '
            '${entry.source.label} · $timeLabel',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      isThreeLine: entry.detail.isNotEmpty,
    );
  }
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionStatusLine extends StatelessWidget {
  const _PermissionStatusLine({
    required this.label,
    required this.allowed,
  });

  final String label;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            allowed ? Icons.check_circle_outline : Icons.block_outlined,
            size: 18,
            color: allowed ? Colors.green : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: allowed
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTimestamp(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  final month = dt.month.toString().padLeft(2, '0');
  final day = dt.day.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}
