abstract final class HiveBoxNames {
  static const users = 'users';
  static const appPreferences = 'appPreferences';
  static const speechProfiles = 'speechProfiles';
  static const rehearsalSessions = 'rehearsalSessions';
  static const fillerWordLogs = 'fillerWordLogs';
  static const performanceReports = 'performanceReports';
  static const applicationMetadata = 'applicationMetadata';

  static const legacyUsers = 'usersBox';
}

abstract final class StorageMetadataKeys {
  static const demoDataSeeded = 'demoDataSeededV1';
  static const legacyUsersMigrated = 'legacyUsersMigratedV1';
  static const tutorialCompletedPrefix = 'tutorialCompletedV1';

  static String tutorialCompleted(String userId) =>
      '$tutorialCompletedPrefix::$userId';
}

abstract final class AppUserIds {
  static const demo = 'demo-user';
}
