import 'package:ai_home_brain/features/automations/data/automation_routine_store.dart';
import 'package:ai_home_brain/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ai_home_brain/features/devices/data/simulated_device_control_service.dart';
import 'package:ai_home_brain/features/devices/domain/door_unlock_authenticator.dart';
import 'package:ai_home_brain/features/family/data/family_management_store.dart';
import 'package:ai_home_brain/features/family/domain/family_member.dart';
import 'package:ai_home_brain/features/family/presentation/family_management_screen.dart';
import 'package:ai_home_brain/features/voice_assistant/domain/voice_command.dart';
import 'package:ai_home_brain/features/voice_assistant/domain/voice_command_interpreter.dart';
import 'package:ai_home_brain/features/voice_assistant/domain/voice_recognition_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDoorAuthenticator implements DoorUnlockAuthenticator {
  @override
  Future<bool> authenticateForDoorUnlock() async => true;
}

class _FakeVoiceRecognitionService implements VoiceRecognitionService {
  _FakeVoiceRecognitionService(this.transcript);

  final String transcript;

  @override
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onError,
  }) async =>
      true;

  @override
  Future<void> listen({
    required void Function(String transcript, bool isFinal) onResult,
  }) async {
    onResult(transcript, true);
  }

  @override
  Future<void> stop() async {}
}

class _FakeVoiceCommandInterpreter implements VoiceCommandInterpreter {
  @override
  Future<VoiceCommand> interpret(String transcript) async {
    final lower = transcript.toLowerCase();
    if (lower.contains('light')) {
      return const VoiceCommand(VoiceAction.turnLightOn);
    }
    if (lower.contains('morning')) {
      return const VoiceCommand(VoiceAction.morningMode);
    }
    if (lower.contains('unlock')) {
      return const VoiceCommand(VoiceAction.unlockDoorBlocked);
    }
    return const VoiceCommand(VoiceAction.unsupported);
  }
}

void main() {
  group('Family domain rules & permissions', () {
    test('Role presets assign expected permissions', () {
      final owner = FamilyPermissions.forRole(FamilyRole.owner);
      expect(owner.canControlDevices, isTrue);
      expect(owner.canRunAutomations, isTrue);
      expect(owner.canUseVoiceCommands, isTrue);
      expect(owner.canUnlockDoor, isTrue);
      expect(owner.canManageFamily, isTrue);

      final adult = FamilyPermissions.forRole(FamilyRole.adult);
      expect(adult.canControlDevices, isTrue);
      expect(adult.canRunAutomations, isTrue);
      expect(adult.canUseVoiceCommands, isTrue);
      expect(adult.canUnlockDoor, isTrue);
      expect(adult.canManageFamily, isFalse);

      final guest = FamilyPermissions.forRole(FamilyRole.guest);
      expect(guest.canControlDevices, isTrue);
      expect(guest.canRunAutomations, isFalse);
      expect(guest.canUseVoiceCommands, isTrue);
      expect(guest.canUnlockDoor, isFalse);
      expect(guest.canManageFamily, isFalse);
    });

    test('Validation helpers reject malformed emails and short names', () {
      expect(validateFamilyEmail(''), isNotNull);
      expect(validateFamilyEmail('not-an-email'), isNotNull);
      expect(validateFamilyEmail('alex@example.com'), isNull);

      expect(validateFamilyDisplayName(''), isNotNull);
      expect(validateFamilyDisplayName('A'), isNotNull);
      expect(validateFamilyDisplayName('Alex'), isNull);
    });

    test('Voice command permission matrix enforces permissions and door block',
        () {
      final ownerPerms = FamilyPermissions.forRole(FamilyRole.owner);
      final guestPerms = FamilyPermissions.forRole(FamilyRole.guest);
      final noVoicePerms = ownerPerms.copyWith(canUseVoiceCommands: false);

      expect(
        evaluateVoiceCommandPermission(
          permissions: ownerPerms,
          action: VoiceAction.turnLightOn,
        ).allowed,
        isTrue,
      );
      expect(
        evaluateVoiceCommandPermission(
          permissions: ownerPerms,
          action: VoiceAction.unlockDoorBlocked,
        ).allowed,
        isFalse,
      );
      expect(
        evaluateVoiceCommandPermission(
          permissions: guestPerms,
          action: VoiceAction.turnLightOn,
        ).allowed,
        isTrue,
      );
      expect(
        evaluateVoiceCommandPermission(
          permissions: guestPerms,
          action: VoiceAction.sleepMode,
        ).allowed,
        isFalse,
      );
      expect(
        evaluateVoiceCommandPermission(
          permissions: noVoicePerms,
          action: VoiceAction.turnLightOn,
        ).allowed,
        isFalse,
      );
    });
  });

  group('FamilyManagementStore lifecycle', () {
    test('Invites, direct adds, permission updates, removals, and owner guard',
        () async {
      final store = FamilyManagementStore();
      addTearDown(store.dispose);

      // Invite member
      final inviteResult = await store.inviteMember(
        displayName: 'Sam Rivera',
        email: 'sam@example.com',
        role: FamilyRole.adult,
        permissions: FamilyPermissions.forRole(FamilyRole.adult),
      );
      expect(inviteResult.success, isTrue);
      expect(inviteResult.inviteCode, isNotNull);
      expect(store.pendingOutgoingInvites.length, 1);

      // Duplicate pending email blocked
      final dupInvite = await store.inviteMember(
        displayName: 'Sam',
        email: 'sam@example.com',
        role: FamilyRole.guest,
        permissions: FamilyPermissions.forRole(FamilyRole.guest),
      );
      expect(dupInvite.success, isFalse);

      // Revoke invite
      final revokeResult = await store.revokeInvite(inviteResult.inviteCode!);
      expect(revokeResult.success, isTrue);
      expect(store.pendingOutgoingInvites, isEmpty);

      // Direct add authorized member
      final addResult = await store.addAuthorizedMember(
        displayName: 'Maya Chen',
        email: 'maya@example.com',
        role: FamilyRole.guest,
        permissions: FamilyPermissions.forRole(FamilyRole.guest),
      );
      expect(addResult.success, isTrue);
      expect(store.members.length, 2);

      final maya =
          store.members.firstWhere((m) => m.email == 'maya@example.com');
      expect(maya.permissions.canRunAutomations, isFalse);

      // Update permissions
      final updateResult = await store.updateMemberPermissions(
        memberId: maya.memberId,
        role: FamilyRole.adult,
        permissions: FamilyPermissions.forRole(FamilyRole.adult),
      );
      expect(updateResult.success, isTrue);
      final updatedMaya =
          store.members.firstWhere((m) => m.memberId == maya.memberId);
      expect(updatedMaya.role, FamilyRole.adult);
      expect(updatedMaya.permissions.canRunAutomations, isTrue);

      // Owner cannot be removed or downgraded
      final ownerRemove = await store.removeMember('local-owner');
      expect(ownerRemove.success, isFalse);
      final ownerDowngrade = await store.updateMemberPermissions(
        memberId: 'local-owner',
        role: FamilyRole.guest,
        permissions: FamilyPermissions.forRole(FamilyRole.guest),
      );
      expect(ownerDowngrade.success, isFalse);

      // Remove authorized member
      final removeResult = await store.removeMember(maya.memberId);
      expect(removeResult.success, isTrue);
      expect(store.members.length, 1);
      expect(store.activities.isNotEmpty, isTrue);
    });
  });

  group('FamilyManagementScreen & Dashboard permission enforcement', () {
    testWidgets(
        'FamilyManagementScreen creates invite, logs activity, and states honest voice identity limitation',
        (WidgetTester tester) async {
      final store = FamilyManagementStore();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: FamilyManagementScreen(store: store),
        ),
      );

      expect(find.text('Authorized users'), findsOneWidget);
      await tester.tap(find.text('Invite family member'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Jordan Lee',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'jordan@example.com',
      );
      await tester.tap(find.text('Create invite'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Jordan Lee'), findsOneWidget);
      expect(find.text('jordan@example.com'), findsOneWidget);

      // Switch to Activity tab
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Invited Jordan Lee'), findsOneWidget);

      // Switch to Security tab and check explicit honest disclosure
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<FamilySectionTab>),
          matching: find.text('Security'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'speaker or voice-print identity verification is NOT implemented',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'Dashboard enforces member permissions on devices, routines, and voice commands and records user activity',
        (WidgetTester tester) async {
      final devices = SimulatedDeviceControlService();
      final routineStore = AutomationRoutineStore();
      addTearDown(routineStore.dispose);

      // Member who can control devices & voice, but NOT run automations or unlock door
      final restrictedStore = FamilyManagementStore(
        initialLocalUid: 'member-1',
        initialLocalName: 'Alex Guest',
        initialLocalEmail: 'alex@example.com',
        initialLocalRole: FamilyRole.guest,
        initialLocalPermissions: const FamilyPermissions(
          canControlDevices: true,
          canRunAutomations: false,
          canUseVoiceCommands: true,
          canUnlockDoor: false,
          canManageFamily: false,
        ),
      );
      addTearDown(restrictedStore.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            isDarkMode: false,
            onThemeToggle: () {},
            accountAction: () {},
            accountLabel: 'alex@example.com',
            deviceControlService: devices,
            doorUnlockAuthenticator: _FakeDoorAuthenticator(),
            voiceRecognitionService:
                _FakeVoiceRecognitionService('Turn on the light'),
            voiceCommandInterpreter: _FakeVoiceCommandInterpreter(),
            routineStore: routineStore,
            familyStore: restrictedStore,
          ),
        ),
      );

      // Scroll down to Recent Activity and confirm initial empty state
      await tester.scrollUntilVisible(
        find.text('No activity recorded yet'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No activity recorded yet'), findsOneWidget);

      // Trying door unlock should be denied (canUnlockDoor: false)
      await tester.scrollUntilVisible(
        find.byTooltip('Unlock door'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Unlock door'));
      await tester.pumpAndSettle();
      expect(devices.state.doorLocked, isTrue);
      expect(
        restrictedStore.activities.first.actionTitle,
        'Blocked door unlock attempt',
      );

      // Trying Sleep scene should be blocked (canRunAutomations: false)
      await tester.scrollUntilVisible(
        find.text('Sleep'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Sleep'));
      await tester.pumpAndSettle();
      expect(devices.state.lightOn, isFalse);
      expect(
        restrictedStore.activities.first.actionTitle,
        'Blocked routine: Sleep Mode',
      );

      // Tapping Talk executes "Turn on the light" (canControlDevices + canUseVoiceCommands: true)
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Talk'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Talk')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Talk'));
      await tester.pumpAndSettle();
      expect(devices.state.lightOn, isTrue);
      expect(
        restrictedStore.activities.first.source,
        ActivitySource.voice,
      );
      expect(
        restrictedStore.activities.first.actorName,
        'Alex Guest',
      );

      // Navigate to Assistant tab and verify account banner & security disclosure
      await tester.tap(find.text('Assistant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Account: Alex Guest (Guest)'), findsOneWidget);
      expect(
        find.textContaining('Speaker/voice-print identity verification is NOT'),
        findsOneWidget,
      );
    });
  });
}
