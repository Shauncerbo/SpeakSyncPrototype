import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'auth_service.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';
import 'storage/hive_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AuthService authService;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    authService = FirebaseAuthService();
  } catch (_) {
    authService = const UnavailableAuthService();
  }

  final repository = HiveRepository();
  AppState appState;
  try {
    await repository.initializeStorage();
    appState = AppState(repository: repository, useDemoData: false);
  } catch (error) {
    appState = AppState(
      initialStorageError: error.toString(),
      useDemoData: false,
    );
  }
  await appState.initialize();

  runApp(SpeakSyncApp(appState: appState, authService: authService));
}
