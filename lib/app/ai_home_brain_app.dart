import 'package:flutter/material.dart';

import '../features/auth/data/firebase_auth_service.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/automations/data/automation_routine_store.dart';
import '../features/devices/data/local_device_unlock_authenticator.dart';
import '../features/devices/data/simulated_device_control_service.dart';
import '../features/devices/data/simulated_device_monitoring_store.dart';
import '../features/devices/domain/device_control_service.dart';
import '../features/devices/domain/device_monitoring.dart';
import '../features/devices/domain/door_unlock_authenticator.dart';
import '../features/family/data/family_management_store.dart';
import '../features/voice_assistant/data/phone_voice_recognition_service.dart';
import '../features/voice_assistant/domain/voice_command_interpreter.dart';
import '../features/voice_assistant/domain/voice_recognition_service.dart';
import 'theme/app_theme.dart';

class AiHomeBrainApp extends StatefulWidget {
  const AiHomeBrainApp({
    required this.authService,
    this.backendMessage,
    this.deviceControlService,
    this.doorUnlockAuthenticator,
    this.voiceRecognitionService,
    this.voiceCommandInterpreter,
    this.routineStore,
    this.familyStore,
    this.monitoringStore,
    super.key,
  });

  final FirebaseAuthService? authService;
  final String? backendMessage;
  final DeviceControlService? deviceControlService;
  final DoorUnlockAuthenticator? doorUnlockAuthenticator;
  final VoiceRecognitionService? voiceRecognitionService;
  final VoiceCommandInterpreter? voiceCommandInterpreter;
  final AutomationRoutineStore? routineStore;
  final FamilyManagementStore? familyStore;
  final DeviceMonitoringStore? monitoringStore;

  @override
  State<AiHomeBrainApp> createState() => _AiHomeBrainAppState();
}

class _AiHomeBrainAppState extends State<AiHomeBrainApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  late final DeviceControlService _deviceControlService;
  late final DoorUnlockAuthenticator _doorUnlockAuthenticator;
  late final VoiceRecognitionService _voiceRecognitionService;
  late final AutomationRoutineStore _routineStore;
  late final FamilyManagementStore _familyStore;
  late final DeviceMonitoringStore _monitoringStore;

  @override
  void initState() {
    super.initState();
    _deviceControlService =
        widget.deviceControlService ?? SimulatedDeviceControlService();
    _doorUnlockAuthenticator =
        widget.doorUnlockAuthenticator ?? LocalDeviceUnlockAuthenticator();
    _voiceRecognitionService =
        widget.voiceRecognitionService ?? PhoneVoiceRecognitionService();
    _routineStore = widget.routineStore ?? AutomationRoutineStore();
    _familyStore = widget.familyStore ?? FamilyManagementStore();
    _monitoringStore = widget.monitoringStore ??
        SimulatedDeviceMonitoringStore(
          deviceControlService: _deviceControlService,
        );
    final controlService = _deviceControlService;
    if (controlService is SimulatedDeviceControlService &&
        widget.deviceControlService == null) {
      controlService.setDeviceOfflineChecker(_monitoringStore.isDeviceOffline);
    }
  }

  @override
  void dispose() {
    if (widget.monitoringStore == null) _monitoringStore.dispose();
    if (widget.deviceControlService == null) _deviceControlService.dispose();
    if (widget.routineStore == null) _routineStore.dispose();
    if (widget.familyStore == null) _familyStore.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Home Brain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: AuthGate(
        authService: widget.authService,
        backendMessage: widget.backendMessage,
        deviceControlService: _deviceControlService,
        doorUnlockAuthenticator: _doorUnlockAuthenticator,
        voiceRecognitionService: _voiceRecognitionService,
        voiceCommandInterpreter: widget.voiceCommandInterpreter,
        routineStore: _routineStore,
        familyStore: _familyStore,
        monitoringStore: _monitoringStore,
        isDarkMode: _themeMode == ThemeMode.dark,
        onThemeToggle: _toggleTheme,
      ),
    );
  }
}
