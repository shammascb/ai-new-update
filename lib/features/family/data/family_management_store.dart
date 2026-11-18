import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../automations/data/automation_routine_store.dart';
import '../../voice_assistant/domain/voice_command.dart';
import '../domain/family_member.dart';

class FamilyOperationResult {
  const FamilyOperationResult({
    required this.success,
    required this.message,
    this.inviteCode,
  });

  final bool success;
  final String message;
  final String? inviteCode;
}

class FamilyManagementStore extends ChangeNotifier {
  FamilyManagementStore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String initialLocalUid = 'local-owner',
    String initialLocalName = 'Home owner',
    String initialLocalEmail = 'owner@home.local',
    FamilyRole initialLocalRole = FamilyRole.owner,
    FamilyPermissions? initialLocalPermissions,
  })  : _firestore = firestore,
        _auth = auth {
    if (_firestore == null) {
      _seedLocalState(
        uid: initialLocalUid,
        displayName: initialLocalName,
        email: initialLocalEmail,
        role: initialLocalRole,
        permissions:
            initialLocalPermissions ?? FamilyPermissions.forRole(initialLocalRole),
      );
    } else {
      _authSub = _auth?.userChanges().listen(_onUserChanged);
      final current = _auth?.currentUser;
      if (current != null) {
        _onUserChanged(current);
      }
    }
  }

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _homeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _outgoingInvitesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingInvitesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activitiesSub;

  String _homeId = 'home_local';
  String _homeName = 'My Smart Home';
  String _homeOwnerId = 'local-owner';
  List<String> _memberUids = ['local-owner'];

  String _currentUid = 'local-owner';
  String _currentName = 'Home owner';
  String _currentEmail = 'owner@home.local';
  bool _currentEmailVerified = true;
  List<String> _currentProviderIds = const ['local'];

  List<FamilyMember> _members = const [];
  List<FamilyInvite> _outgoingInvites = const [];
  List<FamilyInvite> _incomingInvites = const [];
  List<FamilyActivityEntry> _activities = const [];
  bool _isSyncing = false;
  String? _syncNotice;
  Future<bool>? _bootstrapFuture;
  String? _bootstrapUid;
  String? _lastBootstrapErrorDetail;

  String get homeId => _homeId;
  String get homeName => _homeName;
  String get homeOwnerId => _homeOwnerId;
  String get currentUid => _currentUid;
  String get currentName => _currentName;
  String get currentEmail => _currentEmail;
  bool get isEmailVerified => _currentEmailVerified;
  List<String> get currentProviderIds => List.unmodifiable(_currentProviderIds);
  bool get isCloudConnected => _firestore != null;
  bool get isSyncing => _isSyncing;
  String? get syncNotice => _syncNotice;

  List<FamilyMember> get members {
    final activeEmails = {
      for (final m in _members)
        if (m.status == MemberStatus.active) m.email.toLowerCase(),
    };
    return List.unmodifiable(
      _members.where(
        (m) =>
            m.status == MemberStatus.active ||
            !activeEmails.contains(m.email.toLowerCase()),
      ),
    );
  }
  List<FamilyInvite> get outgoingInvites => List.unmodifiable(_outgoingInvites);
  List<FamilyInvite> get pendingOutgoingInvites => List.unmodifiable(
        _outgoingInvites.where((invite) => invite.status == InviteStatus.pending),
      );
  List<FamilyInvite> get incomingInvites => List.unmodifiable(
        _incomingInvites.where((invite) => invite.status == InviteStatus.pending),
      );
  List<FamilyActivityEntry> get activities => List.unmodifiable(_activities);

  FamilyMember? get currentMember {
    for (final member in _members) {
      if (member.uid == _currentUid || member.memberId == _currentUid) {
        return member;
      }
    }
    return null;
  }

  FamilyRole get currentRole => currentMember?.role ?? FamilyRole.owner;

  FamilyPermissions get currentPermissions =>
      currentMember?.permissions ?? FamilyPermissions.forRole(FamilyRole.owner);

  bool get canControlDevices => currentPermissions.canControlDevices;
  bool get canRunAutomations => currentPermissions.canRunAutomations;
  bool get canUseVoiceCommands => currentPermissions.canUseVoiceCommands;
  bool get canUnlockDoor => currentPermissions.canUnlockDoor;
  bool get canManageFamily => currentPermissions.canManageFamily;

  void _seedLocalState({
    required String uid,
    required String displayName,
    required String email,
    required FamilyRole role,
    required FamilyPermissions permissions,
  }) {
    _homeId = 'home_local';
    _homeName = 'My Smart Home';
    _homeOwnerId = role == FamilyRole.owner ? uid : 'local-owner';
    _memberUids = [
      _homeOwnerId,
      if (uid != _homeOwnerId) uid,
    ];
    _currentUid = uid;
    _currentName = displayName;
    _currentEmail = email.toLowerCase();
    _currentEmailVerified = true;
    _currentProviderIds = const ['password'];
    final now = DateTime.now();
    _members = [
      if (uid != _homeOwnerId)
        FamilyMember(
          memberId: _homeOwnerId,
          homeId: _homeId,
          homeOwnerId: _homeOwnerId,
          uid: _homeOwnerId,
          displayName: 'Home owner',
          email: 'owner@home.local',
          role: FamilyRole.owner,
          status: MemberStatus.active,
          permissions: FamilyPermissions.forRole(FamilyRole.owner),
          addedByUid: _homeOwnerId,
          createdAt: now,
          updatedAt: now,
        ),
      FamilyMember(
        memberId: uid,
        homeId: _homeId,
        homeOwnerId: _homeOwnerId,
        uid: uid,
        displayName: displayName,
        email: email.toLowerCase(),
        role: role,
        status: MemberStatus.active,
        permissions: permissions,
        addedByUid: _homeOwnerId,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    _outgoingInvites = const [];
    _incomingInvites = const [];
    _activities = const [];
    _syncNotice = null;
  }

  void _cancelDataListeners() {
    unawaited(_homeSub?.cancel());
    unawaited(_membersSub?.cancel());
    unawaited(_outgoingInvitesSub?.cancel());
    unawaited(_incomingInvitesSub?.cancel());
    unawaited(_activitiesSub?.cancel());
    _homeSub = null;
    _membersSub = null;
    _outgoingInvitesSub = null;
    _incomingInvitesSub = null;
    _activitiesSub = null;
  }

  void _onUserChanged(User? user) {
    _cancelDataListeners();
    _syncNotice = null;

    if (user == null) {
      _members = const [];
      _outgoingInvites = const [];
      _incomingInvites = const [];
      _activities = const [];
      notifyListeners();
      return;
    }

    final rawName = user.displayName?.trim() ?? '';
    final email = (user.email ?? '').trim().toLowerCase();
    final emailPrefix = email.split('@').first.trim();
    final displayName = rawName.isNotEmpty
        ? rawName
        : (emailPrefix.isNotEmpty ? emailPrefix : 'Home member');

    _currentUid = user.uid;
    _currentName = displayName.length > 100
        ? displayName.substring(0, 100)
        : displayName;
    _currentEmail = email.length >= 3 ? email : 'member@home.local';
    _currentEmailVerified = user.emailVerified;
    _currentProviderIds = user.providerData.map((p) => p.providerId).toList();

    final db = _firestore;
    if (db == null) {
      notifyListeners();
      return;
    }

    if (!user.emailVerified) {
      _seedLocalState(
        uid: user.uid,
        displayName: _currentName,
        email: _currentEmail,
        role: FamilyRole.owner,
        permissions: FamilyPermissions.forRole(FamilyRole.owner),
      );
      _currentEmailVerified = false;
      _currentProviderIds =
          user.providerData.map((p) => p.providerId).toList();
      _syncNotice =
          'Verify your email address in Account Security to sync family members and accept household invites.';
      notifyListeners();
      return;
    }

    if (_bootstrapUid == user.uid &&
        (_bootstrapFuture != null ||
            (_homeId != 'home_local' && _homeOwnerId != 'local-owner'))) {
      notifyListeners();
      return;
    }

    unawaited(_startBootstrap(db, user));
  }

  Future<bool> _startBootstrap(
    FirebaseFirestore db,
    User user, {
    bool forceTokenRefresh = false,
  }) {
    if (_bootstrapFuture != null && _bootstrapUid == user.uid) {
      return _bootstrapFuture!;
    }
    _bootstrapUid = user.uid;
    final future = _bootstrapAndSubscribe(
      db,
      user,
      forceTokenRefresh: forceTokenRefresh,
    ).whenComplete(() {
      if (_bootstrapUid == user.uid) {
        _bootstrapFuture = null;
      }
    });
    _bootstrapFuture = future;
    return future;
  }

  Future<bool> _bootstrapAndSubscribe(
    FirebaseFirestore db,
    User user, {
    bool forceTokenRefresh = false,
  }) async {
    _isSyncing = true;
    _lastBootstrapErrorDetail = null;
    notifyListeners();

    var currentPath = 'users/${user.uid}';
    var currentOp = OperationType.get;
    try {
      await user.getIdToken(forceTokenRefresh);
      currentOp = OperationType.write;
      await _ensureUserProfile(db, user);
      if (_auth?.currentUser?.uid != user.uid) return false;

      currentPath = 'users/${user.uid}/membership/current';
      currentOp = OperationType.get;
      final linkSnap = await db
          .collection('users')
          .doc(user.uid)
          .collection('membership')
          .doc('current')
          .get();

      var targetHomeId = '';
      if (linkSnap.exists && linkSnap.data() != null) {
        targetHomeId = (linkSnap.data()!['homeId'] as String?) ?? '';
      }

      final personalHomeId = 'home_${sanitizeFirestoreId(user.uid)}';
      if (targetHomeId.isEmpty) {
        targetHomeId = personalHomeId;
        currentPath = 'homes/$targetHomeId';
        currentOp = OperationType.write;
        await _createPersonalHousehold(db, user, targetHomeId);
      } else {
        currentPath = 'homes/$targetHomeId';
        currentOp = OperationType.get;
        DocumentSnapshot<Map<String, dynamic>>? homeSnap;
        try {
          homeSnap = await db.collection('homes').doc(targetHomeId).get();
        } on FirebaseException catch (readError) {
          if (readError.code == 'permission-denied') {
            homeSnap = null;
          } else {
            rethrow;
          }
        }
        final homeData = homeSnap?.data();
        if (homeSnap != null && homeSnap.exists && homeData != null) {
          final ownerId = (homeData['ownerId'] as String?) ?? '';
          if (ownerId.isNotEmpty) {
            _homeOwnerId = ownerId;
          }
          final rawName = ((homeData['name'] as String?) ?? '').trim();
          if (rawName.isNotEmpty) {
            _homeName = rawName.length > 80 ? rawName.substring(0, 80) : rawName;
          }
          final rawUids = homeData['memberUids'];
          if (rawUids is List) {
            _memberUids = rawUids.whereType<String>().toList();
          }
        } else {
          targetHomeId = personalHomeId;
          currentPath = 'homes/$targetHomeId';
          currentOp = OperationType.write;
          await _createPersonalHousehold(db, user, targetHomeId);
        }
      }

      if (_auth?.currentUser?.uid != user.uid) return false;
      _homeId = targetHomeId;
      if (_homeOwnerId == 'local-owner' || _homeOwnerId.isEmpty) {
        _homeOwnerId = user.uid;
      }
      _subscribeHousehold(db, user, targetHomeId);
      _syncNotice = null;
      _lastBootstrapErrorDetail = null;
      return true;
    } catch (error) {
      handleFirestoreError(
        error: error,
        operationType: currentOp,
        path: currentPath,
        currentUser: user,
      );
      if (error is FirebaseException) {
        _lastBootstrapErrorDetail =
            '${error.code} at $currentPath${error.message != null ? ': ${error.message}' : ''}';
        _syncNotice =
            'Could not sync family settings (${error.code}). Tap Retry to reconnect.';
      } else {
        _lastBootstrapErrorDetail = error.toString();
        _syncNotice = 'Could not sync family settings. Tap Retry to reconnect.';
      }
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> retrySync() async {
    final db = _firestore;
    final user = _auth?.currentUser;
    if (db == null || user == null) return;
    await user.reload();
    final refreshed = _auth?.currentUser ?? user;
    _currentEmailVerified = refreshed.emailVerified;
    if (!refreshed.emailVerified) {
      _syncNotice =
          'Verify your email address in Account Security to sync family members and accept household invites.';
      notifyListeners();
      return;
    }
    _bootstrapUid = null;
    _bootstrapFuture = null;
    await _startBootstrap(db, refreshed, forceTokenRefresh: true);
  }

  Future<String?> _ensureHouseholdReady(
    FirebaseFirestore db,
    User user,
  ) async {
    final inFlight = _bootstrapFuture;
    if (inFlight != null) {
      await inFlight;
    }
    if (_homeId != 'home_local' &&
        _homeId.isNotEmpty &&
        _homeOwnerId != 'local-owner' &&
        _homeOwnerId.isNotEmpty) {
      return null;
    }

    final ok = await _startBootstrap(db, user, forceTokenRefresh: true);
    if (ok &&
        _homeId != 'home_local' &&
        _homeId.isNotEmpty &&
        _homeOwnerId != 'local-owner' &&
        _homeOwnerId.isNotEmpty) {
      return null;
    }
    return _lastBootstrapErrorDetail ?? 'household-not-initialized';
  }

  Future<void> _ensureUserProfile(FirebaseFirestore db, User user) async {
    final userRef = db.collection('users').doc(user.uid);
    final snap = await userRef.get();
    if (!snap.exists) {
      try {
        await userRef.set({
          'uid': user.uid,
          'displayName': _currentName,
          'email': _currentEmail,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (writeError) {
        if (writeError.code == 'permission-denied' ||
            writeError.code == 'already-exists') {
          final serverSnap = await userRef.get(
            const GetOptions(source: Source.server),
          );
          if (!serverSnap.exists) rethrow;
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> _createPersonalHousehold(
    FirebaseFirestore db,
    User user,
    String targetHomeId,
  ) async {
    final homeRef = db.collection('homes').doc(targetHomeId);
    final memberRef = homeRef.collection('members').doc(user.uid);
    final linkRef = db
        .collection('users')
        .doc(user.uid)
        .collection('membership')
        .doc('current');

    DocumentSnapshot<Map<String, dynamic>>? existingHome;
    try {
      existingHome = await homeRef.get();
    } on FirebaseException catch (readError) {
      if (readError.code != 'permission-denied') {
        rethrow;
      }
    }
    final existingHomeData = existingHome?.data();
    if (existingHome != null && existingHome.exists && existingHomeData != null) {
      final ownerId = (existingHomeData['ownerId'] as String?) ?? user.uid;
      final name = ((existingHomeData['name'] as String?) ?? 'My Smart Home').trim();
      _homeOwnerId = ownerId;
      _homeName = name.isEmpty
          ? 'My Smart Home'
          : (name.length > 80 ? name.substring(0, 80) : name);
      final rawUids = existingHomeData['memberUids'];
      if (rawUids is List) {
        _memberUids = rawUids.whereType<String>().toList();
      }
      final memberSnap = await memberRef.get();
      if (!memberSnap.exists && ownerId == user.uid) {
        await memberRef.set({
          'memberId': user.uid,
          'homeId': targetHomeId,
          'homeOwnerId': user.uid,
          'uid': user.uid,
          'displayName': _currentName,
          'email': _currentEmail,
          'role': 'owner',
          'status': 'active',
          'canControlDevices': true,
          'canRunAutomations': true,
          'canUseVoiceCommands': true,
          'canUnlockDoor': true,
          'canManageFamily': true,
          'inviteCode': '',
          'addedByUid': user.uid,
          'viewerUids': [user.uid],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await linkRef.set({
        'uid': user.uid,
        'homeId': targetHomeId,
        'role': ownerId == user.uid ? 'owner' : 'adult',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final batch = db.batch();
    batch.set(homeRef, {
      'homeId': targetHomeId,
      'name': 'My Smart Home',
      'ownerId': user.uid,
      'memberUids': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(memberRef, {
      'memberId': user.uid,
      'homeId': targetHomeId,
      'homeOwnerId': user.uid,
      'uid': user.uid,
      'displayName': _currentName,
      'email': _currentEmail,
      'role': 'owner',
      'status': 'active',
      'canControlDevices': true,
      'canRunAutomations': true,
      'canUseVoiceCommands': true,
      'canUnlockDoor': true,
      'canManageFamily': true,
      'inviteCode': '',
      'addedByUid': user.uid,
      'viewerUids': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(linkRef, {
      'uid': user.uid,
      'homeId': targetHomeId,
      'role': 'owner',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
      _homeOwnerId = user.uid;
      _homeName = 'My Smart Home';
      _memberUids = [user.uid];
    } on FirebaseException catch (batchError) {
      if (batchError.code == 'permission-denied' ||
          batchError.code == 'already-exists') {
        final serverHome = await homeRef.get(
          const GetOptions(source: Source.server),
        );
        final data = serverHome.data();
        if (serverHome.exists && data != null) {
          _homeOwnerId = (data['ownerId'] as String?) ?? user.uid;
          final rawName = ((data['name'] as String?) ?? 'My Smart Home').trim();
          _homeName = rawName.isEmpty
              ? 'My Smart Home'
              : (rawName.length > 80 ? rawName.substring(0, 80) : rawName);
          return;
        }
      }
      rethrow;
    }
  }

  void _subscribeHousehold(
    FirebaseFirestore db,
    User user,
    String targetHomeId,
  ) {
    _cancelDataListeners();

    final homeRef = db.collection('homes').doc(targetHomeId);
    _homeSub = homeRef.snapshots().listen(
      (snapshot) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) return;
        _homeName = (data['name'] as String?) ?? 'My Smart Home';
        _homeOwnerId = (data['ownerId'] as String?) ?? user.uid;
        final rawUids = data['memberUids'];
        if (rawUids is List) {
          _memberUids = rawUids.whereType<String>().toList();
        }
        notifyListeners();
      },
      onError: (Object error) {
        handleFirestoreError(
          error: error,
          operationType: OperationType.get,
          path: 'homes/$targetHomeId',
          currentUser: user,
        );
      },
    );

    _membersSub = homeRef
        .collection('members')
        .where('viewerUids', arrayContains: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        final loaded = snapshot.docs
            .map((doc) => FamilyMember.fromMap(doc.data(), doc.id))
            .toList()
          ..sort((a, b) {
            if (a.isPrimaryOwner != b.isPrimaryOwner) {
              return a.isPrimaryOwner ? -1 : 1;
            }
            return a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                );
          });
        _members = loaded;
        notifyListeners();
      },
      onError: (Object error) {
        handleFirestoreError(
          error: error,
          operationType: OperationType.list,
          path: 'homes/$targetHomeId/members',
          currentUser: user,
        );
      },
    );

    _outgoingInvitesSub = db
        .collection('homeInvites')
        .where('homeOwnerId', isEqualTo: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        final loaded = snapshot.docs
            .map((doc) => FamilyInvite.fromMap(doc.data(), doc.id))
            .where((invite) => invite.homeId == targetHomeId)
            .toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(2000))
                .compareTo(a.createdAt ?? DateTime(2000)),
          );
        _outgoingInvites = loaded;
        notifyListeners();
      },
      onError: (Object error) {
        handleFirestoreError(
          error: error,
          operationType: OperationType.list,
          path: 'homeInvites',
          currentUser: user,
        );
      },
    );

    _incomingInvitesSub = db
        .collection('homeInvites')
        .where('invitedEmail', isEqualTo: _currentEmail)
        .snapshots()
        .listen(
      (snapshot) {
        final loaded = snapshot.docs
            .map((doc) => FamilyInvite.fromMap(doc.data(), doc.id))
            .where((invite) => invite.status == InviteStatus.pending)
            .toList();
        _incomingInvites = loaded;
        notifyListeners();
      },
      onError: (Object error) {
        handleFirestoreError(
          error: error,
          operationType: OperationType.list,
          path: 'homeInvites',
          currentUser: user,
        );
      },
    );

    _activitiesSub = homeRef
        .collection('activityLogs')
        .where('viewerUids', arrayContains: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        final loaded = snapshot.docs
            .map((doc) => FamilyActivityEntry.fromMap(doc.data(), doc.id))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _activities = loaded.take(80).toList();
        notifyListeners();
      },
      onError: (Object error) {
        handleFirestoreError(
          error: error,
          operationType: OperationType.list,
          path: 'homes/$targetHomeId/activityLogs',
          currentUser: user,
        );
      },
    );
  }

  Future<void> refreshAccountSecurityStatus() async {
    final user = _auth?.currentUser;
    if (user == null) return;
    _isSyncing = true;
    notifyListeners();
    try {
      await user.reload();
      final refreshed = _auth?.currentUser ?? user;
      if (refreshed.emailVerified) {
        await refreshed.getIdToken(true);
      }
      _bootstrapUid = null;
      _onUserChanged(refreshed);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<FamilyOperationResult> inviteMember({
    required String displayName,
    required String email,
    required FamilyRole role,
    required FamilyPermissions permissions,
  }) async {
    if (!canManageFamily) {
      return const FamilyOperationResult(
        success: false,
        message: 'Only household owners or family admins can invite members.',
      );
    }
    final nameError = validateFamilyDisplayName(displayName);
    if (nameError != null) {
      return FamilyOperationResult(success: false, message: nameError);
    }
    final emailError = validateFamilyEmail(email);
    if (emailError != null) {
      return FamilyOperationResult(success: false, message: emailError);
    }

    final normalizedEmail = email.trim().toLowerCase();
    final trimmedName = displayName.trim();
    if (role == FamilyRole.owner) {
      return const FamilyOperationResult(
        success: false,
        message: 'Invited members can be assigned Adult or Guest roles.',
      );
    }
    if (_members.any((m) => m.email.toLowerCase() == normalizedEmail)) {
      return const FamilyOperationResult(
        success: false,
        message: 'This email is already in your household.',
      );
    }
    if (pendingOutgoingInvites
        .any((i) => i.invitedEmail.toLowerCase() == normalizedEmail)) {
      return const FamilyOperationResult(
        success: false,
        message: 'A pending invitation already exists for this email.',
      );
    }

    final code = generateInviteCode();
    final safePermissions = permissions.copyWith(
      canManageFamily:
          role == FamilyRole.guest ? false : permissions.canManageFamily,
    );

    final db = _firestore;
    final user = _auth?.currentUser;
    if (db == null || user == null || !user.emailVerified) {
      final now = DateTime.now();
      final invite = FamilyInvite(
        inviteCode: code,
        homeId: _homeId,
        homeName: _homeName,
        homeOwnerId: _homeOwnerId,
        invitedEmail: normalizedEmail,
        displayName: trimmedName,
        role: role,
        permissions: safePermissions,
        status: InviteStatus.pending,
        invitedByUid: _currentUid,
        invitedByName: _currentName,
        createdAt: now,
        updatedAt: now,
      );
      _outgoingInvites = [invite, ..._outgoingInvites];
      await recordActivity(
        actionTitle: 'Invited $trimmedName (${role.label})',
        detail: 'Email: $normalizedEmail · Code: $code',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      notifyListeners();
      return FamilyOperationResult(
        success: true,
        message: 'Invitation created for $normalizedEmail.',
        inviteCode: code,
      );
    }

    final readyError = await _ensureHouseholdReady(db, user);
    if (readyError != null) {
      return FamilyOperationResult(
        success: false,
        message:
            'Could not initialize your household in Firestore ($readyError). Please try again.',
      );
    }

    try {
      await db.collection('homeInvites').doc(code).set({
        'inviteCode': code,
        'homeId': _homeId,
        'homeName': _homeName,
        'homeOwnerId': _homeOwnerId,
        'invitedEmail': normalizedEmail,
        'displayName': trimmedName,
        'role': role.name,
        ...safePermissions.toMap(),
        'status': 'pending',
        'invitedByUid': user.uid,
        'invitedByName': _currentName,
        'acceptedByUid': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await recordActivity(
        actionTitle: 'Invited $trimmedName (${role.label})',
        detail: 'Email: $normalizedEmail · Code: $code',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      return FamilyOperationResult(
        success: true,
        message: 'Invitation created for $normalizedEmail.',
        inviteCode: code,
      );
    } catch (error) {
      handleFirestoreError(
        error: error,
        operationType: OperationType.create,
        path: 'homeInvites/$code',
        currentUser: user,
      );
      final codeDetail = error is FirebaseException ? ' (${error.code})' : '';
      return FamilyOperationResult(
        success: false,
        message:
            'Could not send invitation to Firestore$codeDetail. Please try again.',
      );
    }
  }

  Future<FamilyOperationResult> addAuthorizedMember({
    required String displayName,
    required String email,
    required FamilyRole role,
    required FamilyPermissions permissions,
  }) async {
    if (!canManageFamily) {
      return const FamilyOperationResult(
        success: false,
        message: 'Only household owners or family admins can add authorized users.',
      );
    }
    final nameError = validateFamilyDisplayName(displayName);
    if (nameError != null) {
      return FamilyOperationResult(success: false, message: nameError);
    }
    final emailError = validateFamilyEmail(email);
    if (emailError != null) {
      return FamilyOperationResult(success: false, message: emailError);
    }
    if (role == FamilyRole.owner) {
      return const FamilyOperationResult(
        success: false,
        message: 'Additional members must have the Adult or Guest role.',
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    final trimmedName = displayName.trim();
    if (_members.any((m) => m.email.toLowerCase() == normalizedEmail)) {
      return const FamilyOperationResult(
        success: false,
        message: 'That email is already authorized in this household.',
      );
    }

    final code = generateInviteCode();
    final memberId = 'auth_${sanitizeFirestoreId(code)}';
    final now = DateTime.now();
    final member = FamilyMember(
      memberId: memberId,
      homeId: _homeId,
      homeOwnerId: _homeOwnerId,
      uid: '',
      displayName: trimmedName,
      email: normalizedEmail,
      role: role,
      status: MemberStatus.invited,
      permissions: permissions,
      inviteCode: code,
      addedByUid: _currentUid,
      createdAt: now,
      updatedAt: now,
    );

    final db = _firestore;
    final user = _auth?.currentUser;
    if (db == null || user == null || !user.emailVerified) {
      _members = [..._members, member];
      _outgoingInvites = [
        FamilyInvite(
          inviteCode: code,
          homeId: _homeId,
          homeName: _homeName,
          homeOwnerId: _homeOwnerId,
          invitedEmail: normalizedEmail,
          displayName: trimmedName,
          role: role,
          permissions: permissions,
          status: InviteStatus.pending,
          invitedByUid: _currentUid,
          invitedByName: _currentName,
          createdAt: now,
          updatedAt: now,
        ),
        ..._outgoingInvites,
      ];
      await recordActivity(
        actionTitle: 'Added authorized user $trimmedName (${role.label})',
        detail: 'Email: $normalizedEmail · Join code: $code',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      notifyListeners();
      return FamilyOperationResult(
        success: true,
        message:
            '$trimmedName added as an authorized user. Share code $code so they can link their account on sign-in.',
        inviteCode: code,
      );
    }

    final readyError = await _ensureHouseholdReady(db, user);
    if (readyError != null) {
      return FamilyOperationResult(
        success: false,
        message:
            'Could not initialize your household in Firestore ($readyError). Please try again.',
      );
    }

    try {
      final viewerUids = _effectiveViewerUids(user.uid);
      final batch = db.batch();
      final memberRef =
          db.collection('homes').doc(_homeId).collection('members').doc(memberId);
      final inviteRef = db.collection('homeInvites').doc(code);

      batch.set(memberRef, {
        'memberId': memberId,
        'homeId': _homeId,
        'homeOwnerId': _homeOwnerId,
        'uid': '',
        'displayName': trimmedName,
        'email': normalizedEmail,
        'role': role.name,
        'status': 'invited',
        ...permissions.toMap(),
        'inviteCode': code,
        'addedByUid': user.uid,
        'viewerUids': viewerUids,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(inviteRef, {
        'inviteCode': code,
        'homeId': _homeId,
        'homeName': _homeName,
        'homeOwnerId': _homeOwnerId,
        'invitedEmail': normalizedEmail,
        'displayName': trimmedName,
        'role': role.name,
        ...permissions.toMap(),
        'status': 'pending',
        'invitedByUid': user.uid,
        'invitedByName': _currentName,
        'acceptedByUid': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await recordActivity(
        actionTitle: 'Added authorized user $trimmedName (${role.label})',
        detail: 'Email: $normalizedEmail · Join code: $code',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      return FamilyOperationResult(
        success: true,
        message:
            '$trimmedName authorized. When they sign in as $normalizedEmail, they can accept invite $code.',
        inviteCode: code,
      );
    } catch (error) {
      handleFirestoreError(
        error: error,
        operationType: OperationType.write,
        path: 'homes/$_homeId/members/$memberId',
        currentUser: user,
      );
      final codeDetail = error is FirebaseException ? ' (${error.code})' : '';
      return FamilyOperationResult(
        success: false,
        message: 'Could not add authorized user in Firestore$codeDetail.',
      );
    }
  }

  Future<FamilyOperationResult> updateMemberPermissions({
    required String memberId,
    required FamilyRole role,
    required FamilyPermissions permissions,
  }) async {
    if (!canManageFamily) {
      return const FamilyOperationResult(
        success: false,
        message: 'Only household admins can change member permissions.',
      );
    }
    final index = _members.indexWhere((m) => m.memberId == memberId);
    if (index == -1) {
      return const FamilyOperationResult(
        success: false,
        message: 'Member not found.',
      );
    }
    final target = _members[index];
    if (target.isPrimaryOwner) {
      return const FamilyOperationResult(
        success: false,
        message: 'Primary household owner permissions cannot be downgraded.',
      );
    }
    if (role == FamilyRole.owner) {
      return const FamilyOperationResult(
        success: false,
        message: 'Only one primary owner is supported per household.',
      );
    }

    final db = _firestore;
    final user = _auth?.currentUser;
    if (db == null || user == null || !user.emailVerified) {
      final updated = target.copyWith(
        role: role,
        permissions: permissions,
        updatedAt: DateTime.now(),
      );
      _members = [
        for (final m in _members) m.memberId == memberId ? updated : m,
      ];
      await recordActivity(
        actionTitle: 'Updated permissions for ${target.displayName}',
        detail:
            'Role: ${role.label} · ${permissions.activeLabels.join(", ")}',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      notifyListeners();
      return FamilyOperationResult(
        success: true,
        message: 'Updated permissions for ${target.displayName}.',
      );
    }

    final readyError = await _ensureHouseholdReady(db, user);
    if (readyError != null) {
      return FamilyOperationResult(
        success: false,
        message:
            'Could not initialize your household in Firestore ($readyError). Please try again.',
      );
    }

    try {
      await db
          .collection('homes')
          .doc(_homeId)
          .collection('members')
          .doc(memberId)
          .update({
        'role': role.name,
        ...permissions.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await recordActivity(
        actionTitle: 'Updated permissions for ${target.displayName}',
        detail:
            'Role: ${role.label} · ${permissions.activeLabels.join(", ")}',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      return FamilyOperationResult(
        success: true,
        message: 'Updated permissions for ${target.displayName}.',
      );
    } catch (error) {
      handleFirestoreError(
        error: error,
        operationType: OperationType.update,
        path: 'homes/$_homeId/members/$memberId',
        currentUser: user,
      );
      final codeDetail = error is FirebaseException ? ' (${error.code})' : '';
      return FamilyOperationResult(
        success: false,
        message: 'Could not update member permissions in Firestore$codeDetail.',
      );
    }
  }

  Future<FamilyOperationResult> removeMember(String memberId) async {
    if (!canManageFamily) {
      return const FamilyOperationResult(
        success: false,
        message: 'Only household admins can remove members.',
      );
    }
    final index = _members.indexWhere((m) => m.memberId == memberId);
    if (index == -1) {
      return const FamilyOperationResult(
        success: false,
        message: 'Member not found.',
      );
    }
    final target = _members[index];
    if (target.isPrimaryOwner) {
      return const FamilyOperationResult(
        success: false,
        message: 'The primary household owner cannot be removed.',
      );
    }

    final db = _firestore;
    final user = _auth?.currentUser;
    if (db == null || user == null || !user.emailVerified) {
      _members = _members.where((m) => m.memberId != memberId).toList();
      _memberUids = _memberUids.where((uid) => uid != target.uid).toList();
      await recordActivity(
        actionTitle: 'Removed ${target.displayName} from household',
        detail: 'Revoked access for ${target.email}',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      notifyListeners();
      return FamilyOperationResult(
        success: true,
        message: 'Removed ${target.displayName}.',
      );
    }

    final readyError = await _ensureHouseholdReady(db, user);
    if (readyError != null) {
      return FamilyOperationResult(
        success: false,
        message:
            'Could not initialize your household in Firestore ($readyError). Please try again.',
      );
    }

    try {
      final homeRef = db.collection('homes').doc(_homeId);
      final memberRef = homeRef.collection('members').doc(memberId);
      final batch = db.batch();
      batch.delete(memberRef);

      if (target.uid.isNotEmpty) {
        final nextUids =
            _memberUids.where((uid) => uid != target.uid).toList();
        batch.update(homeRef, {
          'memberUids': nextUids,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        for (final other in _members) {
          if (other.memberId != memberId) {
            batch.update(homeRef.collection('members').doc(other.memberId), {
              'viewerUids': nextUids,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (target.inviteCode.isNotEmpty) {
        batch.delete(db.collection('homeInvites').doc(target.inviteCode));
      }

      await batch.commit();
      await recordActivity(
        actionTitle: 'Removed ${target.displayName} from household',
        detail: 'Revoked access for ${target.email}',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      return FamilyOperationResult(
        success: true,
        message: 'Removed ${target.displayName}.',
      );
    } catch (error) {
      handleFirestoreError(
        error: error,
        operationType: OperationType.delete,
        path: 'homes/$_homeId/members/$memberId',
        currentUser: user,
      );
      final codeDetail = error is FirebaseException ? ' (${error.code})' : '';
      return FamilyOperationResult(
        success: false,
        message: 'Could not remove member from Firestore$codeDetail.',
      );
    }
  }

  Future<FamilyOperationResult> revokeInvite(String inviteCode) async {
    if (!canManageFamily) {
      return const FamilyOperationResult(
        success: false,
        message: 'Only household admins can revoke invitations.',
      );
    }
    final index =
        _outgoingInvites.indexWhere((inv) => inv.inviteCode == inviteCode);
    if (index == -1) {
      return const FamilyOperationResult(
        success: false,
        message: 'Invitation not found.',
      );
    }
    final invite = _outgoingInvites[index];

    final db = _firestore;
    final user = _auth?.currentUser;
    if (db == null || user == null || !user.emailVerified) {
      _outgoingInvites = [
        for (final i in _outgoingInvites)
          i.inviteCode == inviteCode
              ? i.copyWith(status: InviteStatus.revoked, updatedAt: DateTime.now())
              : i,
      ];
      await recordActivity(
        actionTitle: 'Revoked invite for ${invite.invitedEmail}',
        detail: 'Invite code: $inviteCode',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      notifyListeners();
      return const FamilyOperationResult(
        success: true,
        message: 'Invitation revoked.',
      );
    }

    final readyError = await _ensureHouseholdReady(db, user);
    if (readyError != null) {
      return FamilyOperationResult(
        success: false,
        message:
            'Could not initialize your household in Firestore ($readyError). Please try again.',
      );
    }

    try {
      await db.collection('homeInvites').doc(inviteCode).update({
        'status': 'revoked',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await recordActivity(
        actionTitle: 'Revoked invite for ${invite.invitedEmail}',
        detail: 'Invite code: $inviteCode',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      return const FamilyOperationResult(
        success: true,
        message: 'Invitation revoked.',
      );
    } catch (error) {
      handleFirestoreError(
        error: error,
        operationType: OperationType.update,
        path: 'homeInvites/$inviteCode',
        currentUser: user,
      );
      final codeDetail = error is FirebaseException ? ' (${error.code})' : '';
      return FamilyOperationResult(
        success: false,
        message: 'Could not revoke invitation in Firestore$codeDetail.',
      );
    }
  }

  Future<FamilyOperationResult> acceptInviteCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.length < 6 || !RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(code)) {
      return const FamilyOperationResult(
        success: false,
        message: 'Enter a valid invite code.',
      );
    }

    final db = _firestore;
    final user = _auth?.currentUser;
    if (db == null || user == null) {
      final idx =
          _outgoingInvites.indexWhere((i) => i.inviteCode == code && i.status == InviteStatus.pending);
      if (idx == -1) {
        return const FamilyOperationResult(
          success: false,
          message: 'Invite code not found in this local session.',
        );
      }
      final invite = _outgoingInvites[idx];
      _outgoingInvites = [
        for (final i in _outgoingInvites)
          i.inviteCode == code
              ? i.copyWith(
                  status: InviteStatus.accepted,
                  acceptedByUid: _currentUid,
                  updatedAt: DateTime.now(),
                )
              : i,
      ];
      final now = DateTime.now();
      _members = [
        ..._members,
        FamilyMember(
          memberId: 'accepted_$code',
          homeId: invite.homeId,
          homeOwnerId: invite.homeOwnerId,
          uid: 'uid_$code',
          displayName: invite.displayName,
          email: invite.invitedEmail,
          role: invite.role,
          status: MemberStatus.active,
          permissions: invite.permissions,
          inviteCode: code,
          addedByUid: invite.invitedByUid,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      await recordActivity(
        actionTitle: '${invite.displayName} joined household',
        detail: 'Accepted invite $code as ${invite.role.label}',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      notifyListeners();
      return FamilyOperationResult(
        success: true,
        message: '${invite.displayName} joined ${invite.homeName}.',
      );
    }

    if (!user.emailVerified) {
      return const FamilyOperationResult(
        success: false,
        message: 'Verify your email address first before accepting a household invite.',
      );
    }

    try {
      final inviteRef = db.collection('homeInvites').doc(code);
      final inviteSnap = await inviteRef.get();
      final data = inviteSnap.data();
      if (!inviteSnap.exists || data == null) {
        return const FamilyOperationResult(
          success: false,
          message: 'Invite code not found or does not match your signed-in email.',
        );
      }
      final invite = FamilyInvite.fromMap(data, code);
      if (invite.status != InviteStatus.pending) {
        return const FamilyOperationResult(
          success: false,
          message: 'This invite is no longer pending.',
        );
      }
      if (invite.invitedEmail.toLowerCase() != _currentEmail) {
        return FamilyOperationResult(
          success: false,
          message:
              'This invite is restricted to ${invite.invitedEmail}. You are signed in as $_currentEmail.',
        );
      }

      final homeRef = db.collection('homes').doc(invite.homeId);
      final memberRef = homeRef.collection('members').doc(user.uid);
      final linkRef = db
          .collection('users')
          .doc(user.uid)
          .collection('membership')
          .doc('current');

      final batch = db.batch();
      batch.update(inviteRef, {
        'status': 'accepted',
        'acceptedByUid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(memberRef, {
        'memberId': user.uid,
        'homeId': invite.homeId,
        'homeOwnerId': invite.homeOwnerId,
        'uid': user.uid,
        'displayName': _currentName,
        'email': _currentEmail,
        'role': invite.role.name,
        'status': 'active',
        ...invite.permissions.toMap(),
        'inviteCode': code,
        'addedByUid': invite.invitedByUid,
        'viewerUids': [invite.homeOwnerId, user.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(homeRef, {
        'memberUids': FieldValue.arrayUnion([user.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(linkRef, {
        'uid': user.uid,
        'homeId': invite.homeId,
        'role': invite.role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      _homeId = invite.homeId;
      _homeName = invite.homeName;
      _homeOwnerId = invite.homeOwnerId;
      _subscribeHousehold(db, user, invite.homeId);
      await recordActivity(
        actionTitle: '$_currentName joined ${invite.homeName}',
        detail: 'Authenticated account accepted invite $code (${invite.role.label})',
        category: ActivityCategory.family,
        source: ActivitySource.family,
      );
      return FamilyOperationResult(
        success: true,
        message: 'Joined ${invite.homeName} as ${invite.role.label}.',
      );
    } catch (error) {
      handleFirestoreError(
        error: error,
        operationType: OperationType.write,
        path: 'homeInvites/$code',
        currentUser: user,
      );
      return const FamilyOperationResult(
        success: false,
        message: 'Could not accept invitation. Check that your email matches and is verified.',
      );
    }
  }

  VoicePermissionDecision checkVoiceCommandPermission(VoiceAction action) {
    return evaluateVoiceCommandPermission(
      permissions: currentPermissions,
      action: action,
    );
  }

  Future<void> recordActivity({
    required String actionTitle,
    required ActivityCategory category,
    required ActivitySource source,
    String detail = '',
  }) async {
    final safeTitle = actionTitle.trim();
    if (safeTitle.isEmpty) return;
    final clippedTitle =
        safeTitle.length > 160 ? safeTitle.substring(0, 160) : safeTitle;
    final trimmedDetail = detail.trim();
    final clippedDetail = trimmedDetail.length > 320
        ? trimmedDetail.substring(0, 320)
        : trimmedDetail;

    final now = DateTime.now();
    final logId = 'log_${now.microsecondsSinceEpoch}';
    final entry = FamilyActivityEntry(
      logId: logId,
      homeId: _homeId,
      actorUid: _currentUid,
      actorName: _currentName,
      actorEmail: _currentEmail,
      actorRole: currentRole,
      actionTitle: clippedTitle,
      detail: clippedDetail,
      category: category,
      source: source,
      createdAt: now,
    );

    _activities = [entry, ..._activities].take(80).toList();
    notifyListeners();

    final db = _firestore;
    final user = _auth?.currentUser;
    if (db == null || user == null || !user.emailVerified) return;
    if (_homeId == 'home_local' || _homeId.isEmpty) return;

    try {
      final viewerUids = _effectiveViewerUids(user.uid);
      await db
          .collection('homes')
          .doc(_homeId)
          .collection('activityLogs')
          .doc(logId)
          .set({
        'logId': logId,
        'homeId': _homeId,
        'actorUid': user.uid,
        'actorName': _currentName,
        'actorEmail': _currentEmail,
        'actorRole': currentRole.name,
        'actionTitle': clippedTitle,
        'detail': clippedDetail,
        'category': category.name,
        'source': source.name,
        'viewerUids': viewerUids,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      handleFirestoreError(
        error: error,
        operationType: OperationType.create,
        path: 'homes/$_homeId/activityLogs/$logId',
        currentUser: user,
      );
    }
  }

  List<String> _effectiveViewerUids(String currentUserUid) {
    final uids = <String>{
      if (_homeOwnerId.isNotEmpty) _homeOwnerId,
      currentUserUid,
      ..._memberUids.where((u) => u.isNotEmpty),
    }.take(20).toList();
    return uids;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelDataListeners();
    super.dispose();
  }
}
