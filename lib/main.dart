import 'package:flutter/material.dart';

import 'app.dart';
import 'state/app_state.dart';
import 'storage/hive_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = HiveRepository();
  AppState appState;
  try {
    await repository.initializeStorage();
    appState = AppState(repository: repository);
  } catch (error) {
    appState = AppState(initialStorageError: error.toString());
  }

  runApp(SpeakSyncApp(appState: appState));
  await appState.initialize();
}
