import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../family/data/family_management_store.dart';
import '../../family/domain/family_member.dart';
import '../data/firebase_auth_service.dart';

class ProfileDialog extends StatefulWidget {
  const ProfileDialog({
    required this.user,
    required this.authService,
    this.familyStore,
    this.onOpenFamilyManagement,
    super.key,
  });

  final User user;
  final FirebaseAuthService authService;
  final FamilyManagementStore? familyStore;
  final VoidCallback? onOpenFamilyManagement;

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  bool _isSigningOut = false;
  String? _error;

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _error = null;
    });
    try {
      await widget.authService.signOut();
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = authenticationErrorMessage(error);
        _isSigningOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final store = widget.familyStore;

    return AlertDialog(
      title: const Text('Your profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.user.displayName ?? 'Home member',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            widget.user.email ?? 'No email address',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.user.emailVerified
                ? 'Firebase account · Email verified'
                : 'Firebase account · Email not verified',
            style: theme.textTheme.bodySmall?.copyWith(
              color: widget.user.emailVerified
                  ? Colors.green
                  : colorScheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (store != null) ...[
            const SizedBox(height: 8),
            Text(
              'Household: ${store.homeName} (${store.currentRole.label})',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Permissions: ${store.currentPermissions.activeLabels.join(", ")}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        if (widget.onOpenFamilyManagement != null)
          TextButton(
            onPressed: _isSigningOut ? null : widget.onOpenFamilyManagement,
            child: const Text('Family & security'),
          ),
        TextButton(
          onPressed: _isSigningOut ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.tonal(
          onPressed: _isSigningOut ? null : _signOut,
          child: _isSigningOut
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign out'),
        ),
      ],
    );
  }
}
