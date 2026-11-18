import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

class ResolvedFirebaseConfig {
  const ResolvedFirebaseConfig({
    required this.webOptions,
    required this.firestoreDatabaseId,
  });

  final FirebaseOptions webOptions;
  final String firestoreDatabaseId;
}

abstract final class FirebaseConfig {
  static const setupMessage =
      'Firebase Authentication is not connected yet. Firebase is Google’s '
      'service for securely creating and checking accounts. Connect this app '
      'to your Firebase project to enable sign-in. Until then, the app will '
      'not create or accept accounts.';

  static const firestoreDatabaseId =
      'ai-studio-remixremixaihome-7e99db73-cdff-435c-97e6-e0808d23e53d';

  static const webOptions = FirebaseOptions(
    apiKey: 'AIzaSyCIWR8o9aMs2wjTSBWsfzRch07zrcQ2yNo',
    appId: '1:756700079445:web:a1589686ab61799cf3fbdc',
    messagingSenderId: '756700079445',
    projectId: 'shining-talent-pq7xb',
    authDomain: 'shining-talent-pq7xb.firebaseapp.com',
    storageBucket: 'shining-talent-pq7xb.firebasestorage.app',
  );

  static ResolvedFirebaseConfig parseAppletConfig(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      return const ResolvedFirebaseConfig(
        webOptions: webOptions,
        firestoreDatabaseId: firestoreDatabaseId,
      );
    }

    String readString(String key, String fallback) {
      final value = decoded[key];
      if (value is String &&
          value.trim().isNotEmpty &&
          value.trim() != 'remixed-project-id') {
        return value.trim();
      }
      return fallback;
    }

    final projectId = readString('projectId', webOptions.projectId);
    final apiKey = readString('apiKey', webOptions.apiKey);
    final appId = readString('appId', webOptions.appId);
    final messagingSenderId =
        readString('messagingSenderId', webOptions.messagingSenderId);
    final authDomain = readString(
      'authDomain',
      webOptions.authDomain ?? '$projectId.firebaseapp.com',
    );
    final storageBucket = readString(
      'storageBucket',
      webOptions.storageBucket ?? '$projectId.firebasestorage.app',
    );
    final measurementIdRaw = decoded['measurementId'];
    final measurementId =
        measurementIdRaw is String && measurementIdRaw.trim().isNotEmpty
            ? measurementIdRaw.trim()
            : null;
    final databaseId = readString('firestoreDatabaseId', firestoreDatabaseId);

    return ResolvedFirebaseConfig(
      webOptions: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
        measurementId: measurementId,
      ),
      firestoreDatabaseId: databaseId,
    );
  }

  static Future<ResolvedFirebaseConfig> loadAppletConfig({
    AssetBundle? bundle,
  }) async {
    try {
      final rawJson =
          await (bundle ?? rootBundle).loadString('firebase-applet-config.json');
      return parseAppletConfig(rawJson);
    } catch (_) {
      return const ResolvedFirebaseConfig(
        webOptions: webOptions,
        firestoreDatabaseId: firestoreDatabaseId,
      );
    }
  }
}
