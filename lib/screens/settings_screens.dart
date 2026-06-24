import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/app_preferences.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _update(BuildContext context, AppPreferences preferences) {
    AppStateScope.of(context, listen: false).updatePreferences(preferences);
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
            _DialogPoint('No real recording'),
            _DialogPoint('No backend'),
            _DialogPoint('No cloud upload'),
            _DialogPoint('Dummy data only'),
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

  Future<void> _reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset prototype data?'),
        content: const Text(
          'This will restore the initial dummy sessions and default preferences.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: errorRed),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    AppStateScope.of(context, listen: false).reset();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prototype data has been reset.')),
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
                'Adjust your default practice experience.',
                style: TextStyle(color: Color(0xFF617085), fontSize: 15),
              ),
              const SizedBox(height: 26),
              const SectionHeader('Practice preferences'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: preferences.defaultLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Default language',
                        ),
                        items:
                            const [
                                  'English',
                                  'English–Filipino',
                                  'English–Bisaya',
                                  'Mixed Language',
                                ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _update(
                              context,
                              preferences.copyWith(defaultLanguage: value),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: preferences.defaultDuration,
                        decoration: const InputDecoration(
                          labelText: 'Default duration',
                        ),
                        items:
                            const [
                                  '1 minute',
                                  '3 minutes',
                                  '5 minutes',
                                  '10 minutes',
                                  'No fixed duration',
                                ]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _update(
                              context,
                              preferences.copyWith(defaultDuration: value),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        key: const Key('settings_live_feedback'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Live feedback'),
                        value: preferences.liveFeedback,
                        onChanged: (value) => _update(
                          context,
                          preferences.copyWith(liveFeedback: value),
                        ),
                      ),
                      SwitchListTile(
                        key: const Key('settings_vibration_feedback'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Vibration feedback'),
                        value: preferences.vibrationFeedback,
                        onChanged: (value) => _update(
                          context,
                          preferences.copyWith(vibrationFeedback: value),
                        ),
                      ),
                      SwitchListTile(
                        key: const Key('settings_body_monitoring'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Body-language monitoring'),
                        value: preferences.bodyMonitoring,
                        onChanged: (value) => _update(
                          context,
                          preferences.copyWith(bodyMonitoring: value),
                        ),
                      ),
                      SwitchListTile(
                        key: const Key('settings_filler_monitoring'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Filler-word monitoring'),
                        value: preferences.fillerMonitoring,
                        onChanged: (value) => _update(
                          context,
                          preferences.copyWith(fillerMonitoring: value),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const InfoBanner(
                icon: Icons.shield_outlined,
                title: 'Privacy by design',
                message:
                    'The planned final system will process visual body-language information on the device. This prototype does not record or upload real audio or video.',
                color: accentTeal,
              ),
              const SizedBox(height: 18),
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
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.restart_alt_rounded,
                        color: errorRed,
                      ),
                      title: const Text(
                        'Reset Prototype Data',
                        style: TextStyle(color: errorRed),
                      ),
                      onTap: () => _reset(context),
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
          Text(text),
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
