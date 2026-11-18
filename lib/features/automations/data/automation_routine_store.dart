import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/automation_routine.dart';

enum OperationType { create, update, delete, list, get, write }

String handleFirestoreError({
  required Object error,
  required OperationType operationType,
  required String? path,
  required User? currentUser,
}) {
  final info = <String, Object?>{
    'error': error.toString(),
    'operationType': operationType.name,
    'path': path,
    'authInfo': {
      'userId': currentUser?.uid,
      'email': currentUser?.email,
      'emailVerified': currentUser?.emailVerified,
      'isAnonymous': currentUser?.isAnonymous,
      'tenantId': currentUser?.tenantId,
      'providerInfo': currentUser?.providerData
              .map((p) => {'providerId': p.providerId, 'email': p.email})
              .toList() ??
          const <Map<String, Object?>>[],
    },
  };
  final encoded = jsonEncode(info);
  debugPrint('Firestore Error: $encoded');
  return encoded;
}

class AutomationRoutineStore extends ChangeNotifier {
  AutomationRoutineStore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore,
        _auth = auth {
    _routines = {
      for (final id in RoutineId.values) id: AutomationRoutine.defaultFor(id),
    };
    if (_firestore != null) {
      unawaited(testConnection());
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
  final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _routineSubs = [];

  late Map<RoutineId, AutomationRoutine> _routines;
  RoutineExecutionReport? _lastReport;
  bool _isSyncing = false;
  String? _syncNotice;
  String? _ensuredProfileUid;
  Future<bool>? _ensuringProfileFuture;
  String? _lastProfileErrorDetail;

  Map<RoutineId, AutomationRoutine> get routines =>
      Map.unmodifiable(_routines);
  AutomationRoutine routineFor(RoutineId id) =>
      _routines[id] ?? AutomationRoutine.defaultFor(id);
  RoutineExecutionReport? get lastReport => _lastReport;
  bool get isSyncing => _isSyncing;
  String? get syncNotice => _syncNotice;

  Future<void> testConnection() async {
    final db = _firestore;
    if (db == null) return;
    try {
      await db
          .collection('test')
          .doc('connection')
          .get(const GetOptions(source: Source.server));
    } catch (error) {
      if (error.toString().contains('the client is offline')) {
        debugPrint('Please check your Firebase configuration.');
      }
    }
  }

  void _cancelRoutineListeners() {
    for (final sub in _routineSubs) {
      unawaited(sub.cancel());
    }
    _routineSubs.clear();
  }

  void _onUserChanged(User? user) {
    _cancelRoutineListeners();
    _syncNotice = null;
    _ensuredProfileUid = null;
    _ensuringProfileFuture = null;
    _lastProfileErrorDetail = null;

    if (user == null) {
      _routines = {
        for (final id in RoutineId.values) id: AutomationRoutine.defaultFor(id),
      };
      _lastReport = null;
      notifyListeners();
      return;
    }

    final db = _firestore;
    if (db == null) return;

    if (!user.emailVerified) {
      _syncNotice =
          'Customizations are active for this session. Verify your email to sync across devices.';
      notifyListeners();
      return;
    }

    unawaited(_ensureParentAndSubscribe(db, user));
  }

  Future<void> _ensureParentAndSubscribe(
    FirebaseFirestore db,
    User user,
  ) async {
    _cancelRoutineListeners();
    await _ensureUserProfileExists(db, user);
    if (_auth?.currentUser?.uid != user.uid) return;

    final routinesRef =
        db.collection('users').doc(user.uid).collection('routines');

    for (final id in RoutineId.values) {
      final docPath = 'users/${user.uid}/routines/${id.name}';
      final sub = routinesRef.doc(id.name).snapshots().listen(
        (snapshot) {
          final data = snapshot.data();
          final updatedRoutine = snapshot.exists && data != null
              ? AutomationRoutine.fromFirestoreMap(id, data)
              : AutomationRoutine.defaultFor(id);
          _routines = {
            ..._routines,
            id: updatedRoutine,
          };
          _syncNotice = null;
          notifyListeners();
        },
        onError: (Object error) {
          final message = handleFirestoreError(
            error: error,
            operationType: OperationType.get,
            path: docPath,
            currentUser: user,
          );
          _syncNotice = error is FirebaseException
              ? 'Could not load saved routines from Firestore (${error.code}).'
              : 'Could not load saved routines from Firestore.';
          debugPrint(message);
          notifyListeners();
        },
      );
      _routineSubs.add(sub);
    }
  }

  Future<bool> _ensureUserProfileExists(
    FirebaseFirestore db,
    User user,
  ) {
    if (_ensuredProfileUid == user.uid) {
      return Future.value(true);
    }
    final inFlight = _ensuringProfileFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _runEnsureUserProfile(db, user).whenComplete(() {
      _ensuringProfileFuture = null;
    });
    _ensuringProfileFuture = future;
    return future;
  }

  Future<bool> _runEnsureUserProfile(
    FirebaseFirestore db,
    User user,
  ) async {
    final path = 'users/${user.uid}';
    final userRef = db.collection('users').doc(user.uid);
    final rawDisplay = user.displayName?.trim() ?? '';
    final emailPrefix = (user.email ?? '').split('@').first.trim();
    final displayName = rawDisplay.isNotEmpty
        ? rawDisplay
        : (emailPrefix.isNotEmpty ? emailPrefix : 'Home member');
    final safeName =
        displayName.length > 100 ? displayName.substring(0, 100) : displayName;
    final trimmedEmail = user.email?.trim() ?? '';
    final rawEmail =
        trimmedEmail.length >= 3 ? trimmedEmail : 'member@local.app';
    final safeEmail =
        rawEmail.length > 254 ? rawEmail.substring(0, 254) : rawEmail;

    try {
      await user.getIdToken();
      final snap = await userRef.get();
      if (!snap.exists) {
        try {
          await userRef.set({
            'uid': user.uid,
            'displayName': safeName,
            'email': safeEmail,
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
      _ensuredProfileUid = user.uid;
      _lastProfileErrorDetail = null;
      return true;
    } catch (error) {
      handleFirestoreError(
        error: error,
        operationType: OperationType.write,
        path: path,
        currentUser: user,
      );
      if (error is FirebaseException) {
        _lastProfileErrorDetail =
            '${error.code}${error.message != null ? ": ${error.message}" : ""}';
      } else {
        _lastProfileErrorDetail = error.toString();
      }
      return false;
    }
  }

  Future<void> retrySync() async {
    final db = _firestore;
    final user = _auth?.currentUser;
    if (db == null || user == null) return;

    _ensuredProfileUid = null;
    _lastProfileErrorDetail = null;
    _isSyncing = true;
    notifyListeners();

    try {
      await user.reload();
      final refreshedUser = _auth?.currentUser ?? user;
      if (!refreshedUser.emailVerified) {
        _syncNotice =
            'Customizations are active for this session. Verify your email to persist to Firestore.';
        return;
      }
      await refreshedUser.getIdToken(true);
      final ok = await _ensureUserProfileExists(db, refreshedUser);
      if (ok) {
        _syncNotice = null;
        await _ensureParentAndSubscribe(db, refreshedUser);
      } else {
        final detail = _lastProfileErrorDetail;
        _syncNotice = detail == null
            ? 'Saved locally; could not verify Firestore user profile.'
            : 'Saved locally; could not verify Firestore user profile ($detail).';
      }
    } catch (error) {
      _syncNotice = error is FirebaseException
          ? 'Saved locally; Firestore retry failed (${error.code}).'
          : 'Saved locally; Firestore retry failed.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> saveRoutine(AutomationRoutine routine) async {
    _routines = {
      ..._routines,
      routine.id: routine,
    };
    notifyListeners();

    final db = _firestore;
    final user = _auth?.currentUser;
    if (db == null || user == null) return;
    if (!user.emailVerified) {
      _syncNotice =
          'Saved for this session. Verify your email to persist to Firestore.';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    notifyListeners();

    final path = 'users/${user.uid}/routines/${routine.firestoreId}';
    try {
      final parentOk = await _ensureUserProfileExists(db, user);
      if (!parentOk) {
        final detail = _lastProfileErrorDetail;
        _syncNotice = detail == null
            ? 'Saved locally; could not verify Firestore user profile.'
            : 'Saved locally; could not verify Firestore user profile ($detail).';
        return;
      }

      final docRef = db
          .collection('users')
          .doc(user.uid)
          .collection('routines')
          .doc(routine.firestoreId);
      final payload =
          routine.toFirestoreMap(user.uid, FieldValue.serverTimestamp());
      final updatePayload = <String, Object?>{
        'lightAction': payload['lightAction'],
        'fanAction': payload['fanAction'],
        'fanSpeed': payload['fanSpeed'],
        'doorAction': payload['doorAction'],
        'requireSafetyConfirmation': payload['requireSafetyConfirmation'],
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final existing = await docRef.get();
      if (existing.exists) {
        await docRef.update(updatePayload);
      } else {
        try {
          await docRef.set(payload);
        } on FirebaseException catch (error) {
          if (error.code == 'permission-denied' ||
              error.code == 'already-exists') {
            await docRef.update(updatePayload);
          } else {
            rethrow;
          }
        }
      }
      _syncNotice = null;
    } catch (error) {
      handleFirestoreError(
        error: error,
        operationType: OperationType.write,
        path: path,
        currentUser: user,
      );
      _syncNotice = error is FirebaseException
          ? 'Saved locally; Firestore sync failed (${error.code}).'
          : 'Saved locally; Firestore sync failed.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> resetRoutine(RoutineId id) {
    return saveRoutine(AutomationRoutine.defaultFor(id));
  }

  void recordExecutionReport(RoutineExecutionReport report) {
    _lastReport = report;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelRoutineListeners();
    super.dispose();
  }
}
