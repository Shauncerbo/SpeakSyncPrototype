import 'package:flutter/widgets.dart';

import '../data/dummy_data.dart';
import '../models/app_preferences.dart';
import '../models/practice_session.dart';
import '../models/practice_settings.dart';
import '../storage/hive_repository.dart';

class AppState extends ChangeNotifier {
  AppState({HiveRepository? repository, String? initialStorageError})
    : _repository = repository,
      _sessions = repository == null ? initialSessions() : [],
      _preferences = initialPreferences,
      _storageError = initialStorageError,
      _isLoading = repository != null;

  final HiveRepository? _repository;
  List<PracticeSession> _sessions;
  AppPreferences _preferences;
  bool _isLoading;
  String? _storageError;
  PracticeSettings? currentSetup;
  PracticeSession? currentReport;

  List<PracticeSession> get sessions => List.unmodifiable(_sessions);
  AppPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get storageError => _storageError;

  Future<void> initialize() async {
    final repository = _repository;
    if (repository == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      await repository.seedDemoDataOnce(
        sessions: initialSessions(),
        preferences: initialPreferences,
      );
      _preferences =
          repository.getPreferences(initialPreferences.userId) ??
          initialPreferences;
      _sessions = repository.getPracticeSessions(initialPreferences.userId);
      _storageError = null;
    } catch (error) {
      _storageError = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int get averageScore {
    if (_sessions.isEmpty) return 0;
    return (_sessions.fold<int>(0, (sum, item) => sum + item.overallScore) /
            _sessions.length)
        .round();
  }

  Duration get totalPracticeTime =>
      _sessions.fold(Duration.zero, (total, item) => total + item.duration);

  void setCurrentSetup(PracticeSettings settings) {
    currentSetup = settings;
    notifyListeners();
  }

  void setCurrentReport(PracticeSession session) {
    currentReport = session;
    notifyListeners();
  }

  Future<bool> saveCurrentReport() async {
    final report = currentReport;
    if (report == null || _sessions.any((item) => item.id == report.id)) {
      return false;
    }
    final repository = _repository;
    if (repository == null) {
      _sessions = [report, ..._sessions];
      notifyListeners();
      return true;
    }

    try {
      final saved = await repository.saveCompletedRehearsal(
        practiceSession: report,
        settings: currentSetup,
      );
      _sessions = repository.getPracticeSessions(preferences.userId);
      _storageError = null;
      notifyListeners();
      return saved;
    } catch (error) {
      _storageError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updatePreferences(AppPreferences preferences) async {
    final previous = _preferences;
    _preferences = preferences;
    notifyListeners();
    try {
      await _repository?.savePreferences(preferences);
      _storageError = null;
    } catch (error) {
      _preferences = previous;
      _storageError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearPrototypeData() async {
    try {
      if (_repository == null) {
        _sessions = [];
      } else {
        await _repository.clearPrototypeData();
        _sessions = _repository.getPracticeSessions(preferences.userId);
      }
      currentSetup = null;
      currentReport = null;
      _storageError = null;
      notifyListeners();
    } catch (error) {
      _storageError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<int> restoreDemoData() async {
    try {
      final repository = _repository;
      int restored;
      if (repository == null) {
        final existingIds = _sessions.map((session) => session.id).toSet();
        final missing = initialSessions()
            .where((session) => !existingIds.contains(session.id))
            .toList();
        _sessions = [..._sessions, ...missing];
        restored = missing.length;
      } else {
        restored = await repository.restoreDemoData(
          sessions: initialSessions(),
          preferences: initialPreferences,
        );
        _sessions = repository.getPracticeSessions(preferences.userId);
      }
      _storageError = null;
      notifyListeners();
      return restored;
    } catch (error) {
      _storageError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearStorageError() {
    if (_storageError == null) return;
    _storageError = null;
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppState of(BuildContext context, {bool listen = true}) {
    if (listen) {
      return context
          .dependOnInheritedWidgetOfExactType<AppStateScope>()!
          .notifier!;
    }
    return context.getInheritedWidgetOfExactType<AppStateScope>()!.notifier!;
  }
}
