import 'dart:math';

import '../../voice_assistant/domain/voice_command.dart';

enum FamilyRole { owner, adult, guest }

enum MemberStatus { active, invited }

enum InviteStatus { pending, accepted, revoked }

enum ActivityCategory { device, door, automation, voice, family, security }

enum ActivitySource { dashboard, devices, automations, voice, family }

extension FamilyRoleX on FamilyRole {
  String get label => switch (this) {
        FamilyRole.owner => 'Owner',
        FamilyRole.adult => 'Adult',
        FamilyRole.guest => 'Guest',
      };

  String get description => switch (this) {
        FamilyRole.owner =>
          'Full control over devices, routines, security, and family members.',
        FamilyRole.adult =>
          'Can control devices, run routines, unlock the door, and use voice commands.',
        FamilyRole.guest =>
          'Limited access to basic devices and voice commands without door unlock or admin access.',
      };

  static FamilyRole fromString(String? value) => switch (value) {
        'owner' => FamilyRole.owner,
        'adult' => FamilyRole.adult,
        'guest' => FamilyRole.guest,
        _ => FamilyRole.guest,
      };
}

extension ActivityCategoryX on ActivityCategory {
  String get label => switch (this) {
        ActivityCategory.device => 'Device',
        ActivityCategory.door => 'Door',
        ActivityCategory.automation => 'Routine',
        ActivityCategory.voice => 'Voice',
        ActivityCategory.family => 'Family',
        ActivityCategory.security => 'Security',
      };

  static ActivityCategory fromString(String? value) => switch (value) {
        'device' => ActivityCategory.device,
        'door' => ActivityCategory.door,
        'automation' => ActivityCategory.automation,
        'voice' => ActivityCategory.voice,
        'family' => ActivityCategory.family,
        'security' => ActivityCategory.security,
        _ => ActivityCategory.device,
      };
}

extension ActivitySourceX on ActivitySource {
  String get label => switch (this) {
        ActivitySource.dashboard => 'Dashboard',
        ActivitySource.devices => 'Devices',
        ActivitySource.automations => 'Automations',
        ActivitySource.voice => 'Voice assistant',
        ActivitySource.family => 'Family & security',
      };

  static ActivitySource fromString(String? value) => switch (value) {
        'dashboard' => ActivitySource.dashboard,
        'devices' => ActivitySource.devices,
        'automations' => ActivitySource.automations,
        'voice' => ActivitySource.voice,
        'family' => ActivitySource.family,
        _ => ActivitySource.dashboard,
      };
}

class FamilyPermissions {
  const FamilyPermissions({
    required this.canControlDevices,
    required this.canRunAutomations,
    required this.canUseVoiceCommands,
    required this.canUnlockDoor,
    required this.canManageFamily,
  });

  factory FamilyPermissions.forRole(FamilyRole role) {
    return switch (role) {
      FamilyRole.owner => const FamilyPermissions(
          canControlDevices: true,
          canRunAutomations: true,
          canUseVoiceCommands: true,
          canUnlockDoor: true,
          canManageFamily: true,
        ),
      FamilyRole.adult => const FamilyPermissions(
          canControlDevices: true,
          canRunAutomations: true,
          canUseVoiceCommands: true,
          canUnlockDoor: true,
          canManageFamily: false,
        ),
      FamilyRole.guest => const FamilyPermissions(
          canControlDevices: true,
          canRunAutomations: false,
          canUseVoiceCommands: true,
          canUnlockDoor: false,
          canManageFamily: false,
        ),
    };
  }

  factory FamilyPermissions.fromMap(Map<String, dynamic> data) {
    return FamilyPermissions(
      canControlDevices: data['canControlDevices'] as bool? ?? false,
      canRunAutomations: data['canRunAutomations'] as bool? ?? false,
      canUseVoiceCommands: data['canUseVoiceCommands'] as bool? ?? false,
      canUnlockDoor: data['canUnlockDoor'] as bool? ?? false,
      canManageFamily: data['canManageFamily'] as bool? ?? false,
    );
  }

  final bool canControlDevices;
  final bool canRunAutomations;
  final bool canUseVoiceCommands;
  final bool canUnlockDoor;
  final bool canManageFamily;

  List<String> get activeLabels => [
        if (canControlDevices) 'Devices',
        if (canRunAutomations) 'Automations',
        if (canUseVoiceCommands) 'Voice',
        if (canUnlockDoor) 'Door unlock',
        if (canManageFamily) 'Manage family',
      ];

  FamilyPermissions copyWith({
    bool? canControlDevices,
    bool? canRunAutomations,
    bool? canUseVoiceCommands,
    bool? canUnlockDoor,
    bool? canManageFamily,
  }) {
    return FamilyPermissions(
      canControlDevices: canControlDevices ?? this.canControlDevices,
      canRunAutomations: canRunAutomations ?? this.canRunAutomations,
      canUseVoiceCommands: canUseVoiceCommands ?? this.canUseVoiceCommands,
      canUnlockDoor: canUnlockDoor ?? this.canUnlockDoor,
      canManageFamily: canManageFamily ?? this.canManageFamily,
    );
  }

  Map<String, Object?> toMap() => {
        'canControlDevices': canControlDevices,
        'canRunAutomations': canRunAutomations,
        'canUseVoiceCommands': canUseVoiceCommands,
        'canUnlockDoor': canUnlockDoor,
        'canManageFamily': canManageFamily,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilyPermissions &&
        other.canControlDevices == canControlDevices &&
        other.canRunAutomations == canRunAutomations &&
        other.canUseVoiceCommands == canUseVoiceCommands &&
        other.canUnlockDoor == canUnlockDoor &&
        other.canManageFamily == canManageFamily;
  }

  @override
  int get hashCode => Object.hash(
        canControlDevices,
        canRunAutomations,
        canUseVoiceCommands,
        canUnlockDoor,
        canManageFamily,
      );
}

class FamilyMember {
  const FamilyMember({
    required this.memberId,
    required this.homeId,
    required this.homeOwnerId,
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.status,
    required this.permissions,
    required this.addedByUid,
    this.inviteCode = '',
    this.createdAt,
    this.updatedAt,
  });

  factory FamilyMember.fromMap(Map<String, dynamic> data, String fallbackId) {
    return FamilyMember(
      memberId: (data['memberId'] as String?) ?? fallbackId,
      homeId: (data['homeId'] as String?) ?? '',
      homeOwnerId: (data['homeOwnerId'] as String?) ?? '',
      uid: (data['uid'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? 'Family member',
      email: (data['email'] as String?) ?? '',
      role: FamilyRoleX.fromString(data['role'] as String?),
      status: data['status'] == 'invited'
          ? MemberStatus.invited
          : MemberStatus.active,
      permissions: FamilyPermissions.fromMap(data),
      addedByUid: (data['addedByUid'] as String?) ?? '',
      inviteCode: (data['inviteCode'] as String?) ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  final String memberId;
  final String homeId;
  final String homeOwnerId;
  final String uid;
  final String displayName;
  final String email;
  final FamilyRole role;
  final MemberStatus status;
  final FamilyPermissions permissions;
  final String addedByUid;
  final String inviteCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPrimaryOwner =>
      role == FamilyRole.owner ||
      (uid.isNotEmpty && uid == homeOwnerId);

  FamilyMember copyWith({
    String? uid,
    String? displayName,
    FamilyRole? role,
    MemberStatus? status,
    FamilyPermissions? permissions,
    DateTime? updatedAt,
  }) {
    return FamilyMember(
      memberId: memberId,
      homeId: homeId,
      homeOwnerId: homeOwnerId,
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email,
      role: role ?? this.role,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      addedByUid: addedByUid,
      inviteCode: inviteCode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FamilyInvite {
  const FamilyInvite({
    required this.inviteCode,
    required this.homeId,
    required this.homeName,
    required this.homeOwnerId,
    required this.invitedEmail,
    required this.displayName,
    required this.role,
    required this.permissions,
    required this.status,
    required this.invitedByUid,
    required this.invitedByName,
    this.acceptedByUid = '',
    this.createdAt,
    this.updatedAt,
  });

  factory FamilyInvite.fromMap(Map<String, dynamic> data, String fallbackCode) {
    final statusStr = data['status'] as String?;
    return FamilyInvite(
      inviteCode: (data['inviteCode'] as String?) ?? fallbackCode,
      homeId: (data['homeId'] as String?) ?? '',
      homeName: (data['homeName'] as String?) ?? 'Smart Home',
      homeOwnerId: (data['homeOwnerId'] as String?) ?? '',
      invitedEmail: (data['invitedEmail'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? 'Family member',
      role: FamilyRoleX.fromString(data['role'] as String?),
      permissions: FamilyPermissions.fromMap(data),
      status: switch (statusStr) {
        'accepted' => InviteStatus.accepted,
        'revoked' => InviteStatus.revoked,
        _ => InviteStatus.pending,
      },
      invitedByUid: (data['invitedByUid'] as String?) ?? '',
      invitedByName: (data['invitedByName'] as String?) ?? 'Owner',
      acceptedByUid: (data['acceptedByUid'] as String?) ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  final String inviteCode;
  final String homeId;
  final String homeName;
  final String homeOwnerId;
  final String invitedEmail;
  final String displayName;
  final FamilyRole role;
  final FamilyPermissions permissions;
  final InviteStatus status;
  final String invitedByUid;
  final String invitedByName;
  final String acceptedByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FamilyInvite copyWith({
    InviteStatus? status,
    String? acceptedByUid,
    DateTime? updatedAt,
  }) {
    return FamilyInvite(
      inviteCode: inviteCode,
      homeId: homeId,
      homeName: homeName,
      homeOwnerId: homeOwnerId,
      invitedEmail: invitedEmail,
      displayName: displayName,
      role: role,
      permissions: permissions,
      status: status ?? this.status,
      invitedByUid: invitedByUid,
      invitedByName: invitedByName,
      acceptedByUid: acceptedByUid ?? this.acceptedByUid,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FamilyActivityEntry {
  const FamilyActivityEntry({
    required this.logId,
    required this.homeId,
    required this.actorUid,
    required this.actorName,
    required this.actorEmail,
    required this.actorRole,
    required this.actionTitle,
    required this.detail,
    required this.category,
    required this.source,
    required this.createdAt,
  });

  factory FamilyActivityEntry.fromMap(
    Map<String, dynamic> data,
    String fallbackId,
  ) {
    return FamilyActivityEntry(
      logId: (data['logId'] as String?) ?? fallbackId,
      homeId: (data['homeId'] as String?) ?? '',
      actorUid: (data['actorUid'] as String?) ?? '',
      actorName: (data['actorName'] as String?) ?? 'Family member',
      actorEmail: (data['actorEmail'] as String?) ?? '',
      actorRole: FamilyRoleX.fromString(data['actorRole'] as String?),
      actionTitle: (data['actionTitle'] as String?) ?? '',
      detail: (data['detail'] as String?) ?? '',
      category: ActivityCategoryX.fromString(data['category'] as String?),
      source: ActivitySourceX.fromString(data['source'] as String?),
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }

  final String logId;
  final String homeId;
  final String actorUid;
  final String actorName;
  final String actorEmail;
  final FamilyRole actorRole;
  final String actionTitle;
  final String detail;
  final ActivityCategory category;
  final ActivitySource source;
  final DateTime createdAt;
}

class VoicePermissionDecision {
  const VoicePermissionDecision({
    required this.allowed,
    this.denialReason,
  });

  final bool allowed;
  final String? denialReason;
}

VoicePermissionDecision evaluateVoiceCommandPermission({
  required FamilyPermissions permissions,
  required VoiceAction action,
}) {
  if (action == VoiceAction.unlockDoorBlocked) {
    return const VoicePermissionDecision(
      allowed: false,
      denialReason:
          'Door unlocking is never available by voice. Use the manual Unlock button and confirm with your device security.',
    );
  }
  if (!permissions.canUseVoiceCommands) {
    return const VoicePermissionDecision(
      allowed: false,
      denialReason:
          'Voice commands are disabled for your account by the household administrator.',
    );
  }
  switch (action) {
    case VoiceAction.turnLightOn:
    case VoiceAction.turnLightOff:
    case VoiceAction.turnFanOn:
    case VoiceAction.turnFanOff:
    case VoiceAction.lockDoor:
      if (!permissions.canControlDevices) {
        return const VoicePermissionDecision(
          allowed: false,
          denialReason:
              'Your account does not have permission to control home devices by voice.',
        );
      }
      return const VoicePermissionDecision(allowed: true);
    case VoiceAction.sleepMode:
    case VoiceAction.morningMode:
    case VoiceAction.awayMode:
      if (!permissions.canRunAutomations) {
        return const VoicePermissionDecision(
          allowed: false,
          denialReason:
              'Your account does not have permission to run automation routines by voice.',
        );
      }
      return const VoicePermissionDecision(allowed: true);
    case VoiceAction.openLivingRoom:
    case VoiceAction.openBedroom:
    case VoiceAction.unsupported:
    case VoiceAction.unlockDoorBlocked:
      return const VoicePermissionDecision(allowed: true);
  }
}

String? validateFamilyEmail(String? rawEmail) {
  final email = rawEmail?.trim().toLowerCase() ?? '';
  if (email.isEmpty) return 'Enter an email address.';
  if (email.length > 254 ||
      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validateFamilyDisplayName(String? rawName) {
  final name = rawName?.trim() ?? '';
  if (name.isEmpty) return 'Enter a name.';
  if (name.length < 2) return 'Name must be at least 2 characters.';
  if (name.length > 100) return 'Name must be 100 characters or fewer.';
  return null;
}

String generateInviteCode([Random? random]) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = random ?? Random.secure();
  final buffer = StringBuffer('HB');
  for (var i = 0; i < 6; i++) {
    buffer.write(alphabet[rng.nextInt(alphabet.length)]);
  }
  return buffer.toString();
}

String sanitizeFirestoreId(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  if (cleaned.isEmpty) return 'id_default';
  return cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
}

DateTime? _parseTimestamp(Object? value) {
  if (value is DateTime) return value;
  if (value == null) return null;
  try {
    final dynamic dyn = value;
    final DateTime? dt = dyn.toDate() as DateTime?;
    return dt;
  } catch (_) {
    return null;
  }
}
