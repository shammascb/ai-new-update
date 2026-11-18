import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/ai_home_brain_app.dart';
import 'app/firebase_config.dart';
import 'features/auth/data/firebase_auth_service.dart';
import 'features/automations/data/automation_routine_store.dart';
import 'features/family/data/family_management_store.dart';
import 'features/voice_assistant/data/firebase_voice_command_interpreter.dart';
import 'features/voice_assistant/domain/voice_command_interpreter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseAuthService? authService;
  VoiceCommandInterpreter? voiceCommandInterpreter;
  AutomationRoutineStore? routineStore;
  FamilyManagementStore? familyStore;
  String? backendMessage;

  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
    backendMessage = FirebaseConfig.setupMessage;
  } else {
    try {
      final resolvedConfig = await FirebaseConfig.loadAppletConfig();
      if (kIsWeb) {
        await Firebase.initializeApp(options: resolvedConfig.webOptions);
      } else {
        await Firebase.initializeApp();
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
        );
      }
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: resolvedConfig.firestoreDatabaseId,
      );
      if (kIsWeb) {
        firestore.settings = const Settings(
          persistenceEnabled: false,
          webExperimentalForceLongPolling: true,
        );
      }
      authService = FirebaseAuthService(auth);
      voiceCommandInterpreter = FirebaseVoiceCommandInterpreter();
      routineStore = AutomationRoutineStore(
        firestore: firestore,
        auth: auth,
      );
      familyStore = FamilyManagementStore(
        firestore: firestore,
        auth: auth,
      );
    } on FirebaseException catch (error) {
      backendMessage =
          'Firebase could not start (${error.code}). Check your project '
          'configuration and try again.';
    }
  }

  runApp(
    AiHomeBrainApp(
      authService: authService,
      backendMessage: backendMessage,
      voiceCommandInterpreter: voiceCommandInterpreter,
      routineStore: routineStore,
      familyStore: familyStore,
    ),
  );
}
