import 'package:flutter/widgets.dart';

import '../data/dummy_data.dart';
import '../models/app_preferences.dart';
import '../models/practice_session.dart';
import '../models/practice_settings.dart';

class AppState extends ChangeNotifier {
  AppState() : _sessions = initialSessions(), _preferences = initialPreferences;

  List<PracticeSession> _sessions;
  AppPreferences _preferences;
  PracticeSettings? currentSetup;
  PracticeSession? currentReport;

  List<PracticeSession> get sessions => List.unmodifiable(_sessions);
  AppPreferences get preferences => _preferences;

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

  bool saveCurrentReport() {
    final report = currentReport;
    if (report == null || _sessions.any((item) => item.id == report.id)) {
      return false;
    }
    _sessions = [report, ..._sessions];
    notifyListeners();
    return true;
  }

  void updatePreferences(AppPreferences preferences) {
    _preferences = preferences;
    notifyListeners();
  }

  void reset() {
    _sessions = initialSessions();
    _preferences = initialPreferences;
    currentSetup = null;
    currentReport = null;
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
