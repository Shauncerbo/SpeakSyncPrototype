import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/internet_connectivity_service.dart';

/// Keeps connection notices above the navigator, including dialogs and routes.
class ConnectionNotice extends StatefulWidget {
  const ConnectionNotice({
    super.key,
    required this.connectivity,
    required this.child,
  });

  final InternetConnectivity connectivity;
  final Widget child;

  @override
  State<ConnectionNotice> createState() => _ConnectionNoticeState();
}

class _ConnectionNoticeState extends State<ConnectionNotice> {
  StreamSubscription<bool>? _subscription;
  late final AppLifecycleListener _lifecycle;
  Timer? _dismissTimer;
  bool? _online;
  String? _message;
  int _generation = 0;
  int _eventVersion = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onPause: _stop, onResume: _start);
    _start();
  }

  @override
  void didUpdateWidget(ConnectionNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectivity != widget.connectivity) {
      _stop();
      _start();
    }
  }

  void _start() {
    if (_subscription != null || !mounted) return;
    final generation = ++_generation;
    _subscription = widget.connectivity.statusChanges.listen(
      (online) {
        if (generation != _generation) return;
        _eventVersion++;
        _update(online);
      },
      onError: (Object _) {
        // A monitor error does not prove that the phone is offline.
      },
    );
    unawaited(_refresh(generation, _eventVersion));
  }

  Future<void> _refresh(int generation, int version) async {
    try {
      final online = await widget.connectivity.check();
      if (mounted && generation == _generation && version == _eventVersion) {
        _update(online);
      }
    } catch (_) {
      // Wait for the next reachability result.
    }
  }

  void _update(bool online) {
    if (!mounted || _online == online) return;
    final previous = _online;
    _dismissTimer?.cancel();
    setState(() {
      _online = online;
      _message = online
          ? previous == null
                ? "You're online."
                : "You're back online."
          : "You're offline. Check your internet connection.";
    });
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  void _stop() {
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _dismissTimer?.cancel();
    if (mounted) setState(() => _message = null);
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    _dismissTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _online == true ? successGreen : errorRed;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_message != null)
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const Key('connection_notice'),
                      constraints: const BoxConstraints(maxWidth: 480),
                      margin: const EdgeInsets.only(top: 8),
                      child: Material(
                        color: color,
                        elevation: 4,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _online == true
                                    ? Icons.cloud_done_outlined
                                    : Icons.cloud_off_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _message!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
