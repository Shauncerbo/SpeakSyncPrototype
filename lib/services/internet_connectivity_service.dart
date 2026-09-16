import 'dart:async';

import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

abstract interface class InternetConnectivity {
  Future<bool> check();

  Stream<bool> get statusChanges;
}

class InternetConnectivityService implements InternetConnectivity {
  const InternetConnectivityService();

  static final InternetConnection _connection =
      InternetConnection.createInstance(
        checkInterval: const Duration(seconds: 3),
      );

  @override
  Future<bool> check() => _connection.hasInternetAccess;

  @override
  Stream<bool> get statusChanges => _connection.onStatusChange
      .map((status) => status == InternetStatus.connected)
      .distinct();
}
