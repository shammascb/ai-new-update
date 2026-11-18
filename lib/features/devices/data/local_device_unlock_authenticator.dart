import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../domain/door_unlock_authenticator.dart';

class LocalDeviceUnlockAuthenticator implements DoorUnlockAuthenticator {
  LocalDeviceUnlockAuthenticator([LocalAuthentication? localAuth])
      : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> authenticateForDoorUnlock() async {
    if (kIsWeb) return true;
    return _localAuth.authenticate(
      localizedReason: 'Confirm to simulate unlocking the front door.',
      biometricOnly: false,
      sensitiveTransaction: true,
      persistAcrossBackgrounding: true,
    );
  }
}
