import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/app_preferences.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';
import '../login.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _update(BuildContext context, AppPreferences preferences) async {
    try {
      await AppStateScope.of(
        context,
        listen: false,
      ).updatePreferences(preferences);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Settings saved.'),
            duration: Duration(milliseconds: 900),
          ),
        );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save settings: $error')),
      );
    }
  }

  Future<void> _privacy(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: accentTeal),
            SizedBox(width: 10),
            Text('Privacy Details'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogPoint('Camera and microphone are used during rehearsal.'),
            _DialogPoint('Reports stay inside the prototype.'),
            _DialogPoint('No cloud upload or automatic sharing.'),
            _DialogPoint('You can reset all dummy data in Settings.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _savedData(BuildContext context) {
    final state = AppStateScope.of(context, listen: false);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.storage_outlined, color: primaryBlue),
        title: const Text('Saved rehearsal data'),
        content: Text(
          '${state.sessions.length} rehearsal sessions are currently available, '
          'using ${state.totalPracticeTime.inMinutes} minutes of prototype practice data.\n\n'
          'These rehearsal reports and your preferences are stored locally on this device using Hive.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear prototype data?'),
        content: const Text(
          'This will permanently remove all prototype rehearsal sessions, '
          'reports, and filler-word logs from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: errorRed),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await AppStateScope.of(context, listen: false).clearPrototypeData();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prototype data has been cleared.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to clear prototype data: $error')),
      );
    }
  }

  Future<void> _restoreDemoData(BuildContext context) async {
    try {
      final restored = await AppStateScope.of(
        context,
        listen: false,
      ).restoreDemoData();
      if (!context.mounted) return;
      final message = restored == 0
          ? 'All demo sessions are already available.'
          : '$restored demo session${restored == 1 ? '' : 's'} restored.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to restore demo sessions: $error')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of SpeakSync?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: errorRed),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _help(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help and Instructions'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Start a practice from Home.\n\n'
            '2. Choose your speech and monitoring settings.\n\n'
            '3. Use the demo controls during rehearsal to simulate feedback.\n\n'
            '4. End the session to review and save your report.',
            style: TextStyle(height: 1.45),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferences = AppStateScope.of(context).preferences;
    return SafeArea(
      child: SingleChildScrollView(
        child: PageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SpeakSyncLogo(size: 40),
              const SizedBox(height: 28),
              const Text(
                'Settings & Privacy',
                style: TextStyle(
                  color: navy,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage monitoring, feedback, and local data.',
                style: TextStyle(color: Color(0xFF617085), fontSize: 15),
              ),
              const SizedBox(height: 26),
              const SectionHeader('Monitoring'),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _PreferenceSwitch(
                      key: const Key('settings_body_monitoring'),
                      icon: Icons.accessibility_new_rounded,
                      title: 'Posture monitoring',
                      subtitle: 'Monitor upper-body posture and stance',
                      value: preferences.bodyMonitoring,
                      onChanged: (value) => _update(
                        context,
                        preferences.copyWith(bodyMonitoring: value),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _PreferenceSwitch(
                      key: const Key('settings_camera_attention'),
                      icon: Icons.visibility_outlined,
                      title: 'Camera-facing attention',
                      subtitle: 'Remind me when I look away',
                      value: preferences.cameraAttentionMonitoring,
                      onChanged: (value) => _update(
                        context,
                        preferences.copyWith(cameraAttentionMonitoring: value),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _PreferenceSwitch(
                      key: const Key('settings_filler_monitoring'),
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Filler-word monitoring',
                      subtitle: 'Track selected Filipino-Bisaya fillers',
                      value: preferences.fillerMonitoring,
                      onChanged: (value) => _update(
                        context,
                        preferences.copyWith(fillerMonitoring: value),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _PreferenceSwitch(
                      key: const Key('settings_pace_monitoring'),
                      icon: Icons.speed_rounded,
                      title: 'Speaking-pace monitoring',
                      subtitle: 'Track speech that is too fast or too slow',
                      value: preferences.paceMonitoring,
                      onChanged: (value) => _update(
                        context,
                        preferences.copyWith(paceMonitoring: value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader('Feedback'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: Column(
                    children: [
                      _PreferenceSwitch(
                        key: const Key('settings_live_feedback'),
                        icon: Icons.tips_and_updates_outlined,
                        title: 'Real-time coaching alerts',
                        subtitle:
                            'Show silent feedback over the camera preview',
                        value: preferences.liveFeedback,
                        onChanged: (value) => _update(
                          context,
                          preferences.copyWith(liveFeedback: value),
                        ),
                      ),
                      const Divider(height: 1, indent: 8, endIndent: 8),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                        child: DropdownButtonFormField<String>(
                          initialValue: preferences.alertFrequency,
                          decoration: const InputDecoration(
                            labelText: 'Alert frequency',
                            helperText:
                                'How often coaching reminders may appear',
                            prefixIcon: Icon(
                              Icons.notifications_active_outlined,
                            ),
                          ),
                          items: const ['Low', 'Balanced', 'Frequent']
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: preferences.liveFeedback
                              ? (value) {
                                  if (value != null) {
                                    _update(
                                      context,
                                      preferences.copyWith(
                                        alertFrequency: value,
                                      ),
                                    );
                                  }
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader('Data & privacy'),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      key: const Key('view_privacy'),
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('View Privacy Details'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _privacy(context),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('Saved rehearsal data'),
                      subtitle: Text(
                        '${AppStateScope.of(context).sessions.length} sessions stored in this prototype',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _savedData(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader('Support'),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.help_outline_rounded),
                      title: const Text('Help and Instructions'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _help(context),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('About SpeakSync'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AboutScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader('Account actions'),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.restore_rounded,
                        color: primaryBlue,
                      ),
                      title: const Text('Restore Demo Sessions'),
                      subtitle: const Text(
                        'Bring back the four sample rehearsals',
                      ),
                      onTap: () => _restoreDemoData(context),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_sweep_outlined,
                        color: errorRed,
                      ),
                      title: const Text(
                        'Clear Prototype Data',
                        style: TextStyle(color: errorRed),
                      ),
                      onTap: () => _reset(context),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.logout_rounded,
                        color: errorRed,
                      ),
                      title: const Text(
                        'Log out',
                        style: TextStyle(color: errorRed),
                      ),
                      onTap: () => _logout(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      secondary: Icon(
        icon,
        color: value ? accentTeal : const Color(0xFF7A8798),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _DialogPoint extends StatelessWidget {
  const _DialogPoint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: successGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame(
            child: Column(
              children: [
                const SizedBox(height: 24),
                const SpeakSyncLogo(size: 80, showName: false),
                const SizedBox(height: 22),
                const Text(
                  'SpeakSync',
                  style: TextStyle(
                    color: navy,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Prototype version 1.0.0',
                  style: TextStyle(
                    color: accentTeal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 30),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROJECT TITLE',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'SpeakSync: An AI-Assisted Speech and Body Language Rehearsal App with Localized Filipino-Bisaya Filler Word Detection',
                          style: TextStyle(
                            color: navy,
                            fontSize: 18,
                            height: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'TARGET USERS',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Senior High School students'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const InfoBanner(
                  icon: Icons.science_outlined,
                  title: 'Front-end prototype',
                  message:
                      'This front-end prototype uses simulated data and does not yet perform real AI analysis.',
                  color: warningOrange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
