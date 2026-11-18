import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_home_brain/app/ai_home_brain_app.dart';
import 'package:ai_home_brain/app/firebase_config.dart';
import 'package:ai_home_brain/features/auth/data/firebase_auth_service.dart';

void main() {
  testWidgets('AiHomeBrainApp renders AuthScreen when unconfigured',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const AiHomeBrainApp(
        authService: null,
        backendMessage: 'Test backend message',
      ),
    );

    expect(find.text('AI Home Brain'), findsOneWidget);
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  test('FirebaseConfig targets the provisioned Firebase project and database',
      () {
    expect(FirebaseConfig.webOptions.projectId, 'shining-talent-pq7xb');
    expect(
      FirebaseConfig.firestoreDatabaseId,
      'ai-studio-remixremixaihome-7e99db73-cdff-435c-97e6-e0808d23e53d',
    );
  });

  test('FirebaseConfig.parseAppletConfig reads values from firebase-applet-config.json',
      () {
    final parsed = FirebaseConfig.parseAppletConfig('''
      {
        "projectId": "custom-project-123",
        "appId": "1:123:web:abc",
        "apiKey": "test-key",
        "authDomain": "custom-project-123.firebaseapp.com",
        "firestoreDatabaseId": "custom-db-id",
        "storageBucket": "custom-project-123.firebasestorage.app",
        "messagingSenderId": "123"
      }
    ''');
    expect(parsed.webOptions.projectId, 'custom-project-123');
    expect(parsed.webOptions.authDomain, 'custom-project-123.firebaseapp.com');
    expect(parsed.webOptions.apiKey, 'test-key');
    expect(parsed.firestoreDatabaseId, 'custom-db-id');
  });

  test('authenticationErrorMessage explains invalid credentials and disabled email auth',
      () {
    expect(
      authenticationErrorMessage(
        FirebaseAuthException(code: 'invalid-credential'),
      ),
      contains('New here? Create an account'),
    );
    expect(
      authenticationErrorMessage(
        FirebaseAuthException(code: 'user-not-found'),
      ),
      contains('Continue with Google'),
    );
    expect(
      authenticationErrorMessage(
        FirebaseAuthException(code: 'operation-not-allowed'),
      ),
      contains('Email and password sign-in is not enabled yet'),
    );
  });
}
