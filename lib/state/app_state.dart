import 'package:flutter/widgets.dart';

import '../data/dummy_data.dart';
import '../models/app_preferences.dart';
import '../models/practice_session.dart';
import '../models/practice_settings.dart';
import '../models/user_model.dart';
import '../storage/hive_box_names.dart';
import '../storage/hive_repository.dart';

class AppState extends ChangeNotifier {
  AppState({
    HiveRepository? repository,
    String? initialStorageError,
    bool useDemoData = true,
  }) : _repository = repository,
       _useDemoData = useDemoData,
       _sessions = repository == null && useDemoData ? initialSessions() : [],
       _preferences = initialPreferences,
       _activeUserId = repository == null && useDemoData
           ? AppUserIds.demo
           : null,
       _storageError = initialStorageError,
       _isLoading = repository != null;

  final HiveRepository? _repository;
  final bool _useDemoData;
  List<PracticeSession> _sessions;
  AppPreferences _preferences;
  String? _activeUserId;
  User? _currentUserProfile;
  bool _isLoading;
  bool _tutorialCompleted = true;
  String? _storageError;
  PracticeSettings? currentSetup;
  PracticeSession? currentReport;

  List<PracticeSession> get sessions => List.unmodifiable(_sessions);
  AppPreferences get preferences => _preferences;
  String? get activeUserId => _activeUserId;
  User? get currentUserProfile => _currentUserProfile;
  bool get isDemoUser => _activeUserId == AppUserIds.demo;
  bool get hasAuthenticatedUser =>
      _activeUserId != null && _activeUserId != AppUserIds.demo;
  bool get isLoading => _isLoading;
  bool get shouldShowFirstLoginTutorial =>
      hasAuthenticatedUser && !_tutorialCompleted;
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
      if (_useDemoData) {
        _activeUserId = AppUserIds.demo;
        _currentUserProfile = repository.getUserProfile(AppUserIds.demo);
        _preferences =
            repository.getPreferences(AppUserIds.demo) ?? initialPreferences;
        _sessions = repository.getPracticeSessions(AppUserIds.demo);
      } else {
        _activeUserId = null;
        _currentUserProfile = null;
        _preferences = initialPreferences;
        _sessions = [];
      }
      _storageError = null;
    } catch (error) {
      _storageError = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int? get averageScore {
    final scores = _sessions
        .map((item) => item.validatedOverallScore)
        .whereType<int>()
        .toList();
    if (scores.isEmpty) return null;
    return (scores.fold<int>(0, (sum, score) => sum + score) / scores.length)
        .round();
  }

  Duration get totalPracticeTime =>
      _sessions.fold(Duration.zero, (total, item) => total + item.duration);

  Future<void> activateAuthenticatedUser({
    required String userId,
    required String email,
    String? displayName,
    String? firstName,
    String? middleName,
    String? lastName,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedUserId.isEmpty || normalizedUserId == AppUserIds.demo) {
      throw const StorageException('A valid Firebase UID is required');
    }
    if (normalizedEmail.isEmpty) {
      throw const StorageException('The authenticated account has no email');
    }

    // Clear the previous account synchronously before any storage work so its
    // sessions can never flash while another account is being activated.
    _activeUserId = normalizedUserId;
    _currentUserProfile = null;
    _sessions = [];
    currentSetup = null;
    currentReport = null;
    _preferences = initialPreferences.copyWith(userId: normalizedUserId);
    _tutorialCompleted = true;
    _isLoading = true;
    notifyListeners();

    final names = _resolveNames(
      displayName: displayName,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
    );
    final repository = _repository;
    try {
      if (repository == null) {
        _currentUserProfile = User(
          userId: normalizedUserId,
          firstName: names.firstName,
          middleName: names.middleName,
          lastName: names.lastName,
          email: normalizedEmail,
          createdAt: DateTime.now(),
        );
        _storageError ??=
            'Local storage is unavailable. New results will not persist after the app closes.';
        return;
      }

      var profile = repository.getUserProfile(normalizedUserId);
      if (profile == null) {
        profile = User(
          userId: normalizedUserId,
          firstName: names.firstName,
          middleName: names.middleName,
          lastName: names.lastName,
          email: normalizedEmail,
          createdAt: DateTime.now(),
        );
        await repository.saveUserProfile(profile);
      }
      var userPreferences = repository.getPreferences(normalizedUserId);
      if (userPreferences == null) {
        userPreferences = initialPreferences.copyWith(userId: normalizedUserId);
        await repository.savePreferences(userPreferences);
      }
      _currentUserProfile = profile;
      _preferences = userPreferences;
      _sessions = repository.getPracticeSessions(normalizedUserId);
      _tutorialCompleted = repository.hasCompletedTutorial(normalizedUserId);
      _storageError = null;
    } catch (error) {
      _sessions = [];
      _storageError = error.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearAuthenticatedUser() {
    _activeUserId = null;
    _currentUserProfile = null;
    _sessions = [];
    _preferences = initialPreferences;
    _tutorialCompleted = true;
    currentSetup = null;
    currentReport = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markFirstLoginTutorialCompleted() async {
    final userId = _activeUserId;
    if (userId == null || userId == AppUserIds.demo) return;
    _tutorialCompleted = true;
    notifyListeners();
    try {
      await _repository?.markTutorialCompleted(userId);
    } catch (error) {
      _storageError = error.toString();
      notifyListeners();
    }
  }

  static ({String firstName, String? middleName, String lastName})
  _resolveNames({
    String? displayName,
    String? firstName,
    String? middleName,
    String? lastName,
  }) {
    final explicitFirst = firstName?.trim() ?? '';
    final explicitLast = lastName?.trim() ?? '';
    if (explicitFirst.isNotEmpty && explicitLast.isNotEmpty) {
      final middle = middleName?.trim();
      return (
        firstName: explicitFirst,
        middleName: middle?.isEmpty == true ? null : middle,
        lastName: explicitLast,
      );
    }
    final parts = (displayName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return (
        firstName: parts.first,
        middleName: parts.length > 2
            ? parts.sublist(1, parts.length - 1).join(' ')
            : null,
        lastName: parts.last,
      );
    }
    return (
      firstName: parts.isEmpty ? 'Student' : parts.first,
      middleName: null,
      lastName: 'Speaker',
    );
  }

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
      final userId = _activeUserId;
      if (userId == null) {
        throw const StorageException(
          'Sign in before saving a rehearsal report',
        );
      }
      final saved = await repository.saveCompletedRehearsal(
        practiceSession: report,
        settings: currentSetup,
        userId: userId,
      );
      _sessions = repository.getPracticeSessions(userId);
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
    final activeUserId = _activeUserId;
    if (activeUserId != null && preferences.userId != activeUserId) {
      throw const StorageException(
        'Preferences cannot be saved for another user',
      );
    }
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
    if (!isDemoUser) {
      throw const StorageException(
        'Prototype data controls are available only for the demo profile',
      );
    }
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
    if (!isDemoUser) {
      throw const StorageException(
        'Demo sessions cannot be added to a student account',
      );
    }
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
