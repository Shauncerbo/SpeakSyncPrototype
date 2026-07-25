import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../state/app_state.dart';
import 'home_screen.dart';
import 'practice_flow.dart';
import 'progress_screens.dart';
import 'settings_screens.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 2);
  }

  void _select(int value) {
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final pages = <Widget>[
      HomeScreen(onViewProgress: () => setState(() => _index = 1)),
      const ProgressScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (state.storageError != null)
                  MaterialBanner(
                    content: Text(
                      'Some saved data could not be loaded. '
                      '${state.storageError}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: state.clearStorageError,
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                Expanded(
                  child: IndexedStack(index: _index, children: pages),
                ),
              ],
            ),
      floatingActionButton: !state.isLoading && _index == 0
          ? FloatingActionButton(
              key: const Key('quick_start_practice'),
              tooltip: 'Start Practice',
              backgroundColor: const Color(0xFF48DCEB),
              foregroundColor: navy,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PracticeSetupScreen(),
                ),
              ),
              child: const Icon(Icons.mic_rounded),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
