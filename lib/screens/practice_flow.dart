import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_theme.dart';
import '../models/practice_session.dart';
import '../models/practice_settings.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';
import 'main_shell.dart';

class PracticeSetupScreen extends StatefulWidget {
  const PracticeSetupScreen({super.key});

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String _speechType = 'Prepared';
  String _duration = '3 minutes';
  bool _body = true;
  bool _fillers = true;
  bool _pace = true;
  bool _live = true;

  static const _speechTypes = [
    'Prepared',
    'Impromptu',
    'Informative',
    'Persuasive',
  ];
  static const _durations = [
    '1 minute',
    '3 minutes',
    '5 minutes',
    '10 minutes',
    'No fixed duration',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final settings = PracticeSettings(
      speechTitle: _titleController.text.trim(),
      speechType: _speechType,
      selectedDuration: _duration,
      monitorBodyLanguage: _body,
      monitorFillers: _fillers,
      monitorPace: _pace,
      enableLiveFeedback: _live,
    );
    AppStateScope.of(context, listen: false).setCurrentSetup(settings);
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DeviceCheckScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Practice Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set up your rehearsal',
                    style: TextStyle(
                      color: navy,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Choose the settings that match what you want to practice.',
                    style: TextStyle(
                      color: Color(0xFF617085),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 26),
                  TextFormField(
                    key: const Key('speech_title'),
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Speech title',
                      hintText: 'e.g. Environmental Awareness Speech',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a speech title.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _DropdownField(
                    key: const Key('speech_type'),
                    label: 'Speech type',
                    icon: Icons.category_outlined,
                    value: _speechType,
                    items: _speechTypes,
                    onChanged: (value) => setState(() => _speechType = value),
                  ),
                  const SizedBox(height: 16),
                  const InfoBanner(
                    icon: Icons.language_rounded,
                    title: 'Code-switched speech',
                    message: 'Filler word detection supports English, Filipino, and Bisaya code-switched speech automatically.',
                    color: primaryBlue,
                  ),
                  const SizedBox(height: 16),
                  _DropdownField(
                    key: const Key('duration'),
                    label: 'Target duration',
                    icon: Icons.timer_outlined,
                    value: _duration,
                    items: _durations,
                    onChanged: (value) => setState(() => _duration = value),
                  ),
                  const SizedBox(height: 26),
                  const SectionHeader('Monitoring'),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: const Key('body_monitoring'),
                          title: const Text('Body-language monitoring'),
                          subtitle: const Text('Posture and camera attention'),
                          secondary: const Icon(
                            Icons.accessibility_new_rounded,
                          ),
                          value: _body,
                          onChanged: (value) => setState(() => _body = value),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile(
                          key: const Key('filler_monitoring'),
                          title: const Text('Filler-word monitoring'),
                          subtitle: const Text('Selected localized fillers'),
                          secondary: const Icon(Icons.chat_bubble_outline),
                          value: _fillers,
                          onChanged: (value) =>
                              setState(() => _fillers = value),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile(
                          key: const Key('pace_monitoring'),
                          title: const Text('Speaking-pace monitoring'),
                          subtitle: const Text('Simulated pace feedback'),
                          secondary: const Icon(Icons.speed_rounded),
                          value: _pace,
                          onChanged: (value) => setState(() => _pace = value),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile(
                          key: const Key('setup_live_feedback'),
                          title: const Text('Live feedback'),
                          subtitle: const Text('Subtle coaching alerts'),
                          secondary: const Icon(
                            Icons.tips_and_updates_outlined,
                          ),
                          value: _live,
                          onChanged: (value) => setState(() => _live = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('setup_continue'),
                          onPressed: _continue,
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class DeviceCheckScreen extends StatefulWidget {
  const DeviceCheckScreen({super.key});

  @override
  State<DeviceCheckScreen> createState() => _DeviceCheckScreenState();
}

class _DeviceCheckScreenState extends State<DeviceCheckScreen> {
  bool _checking = false;

  Future<void> _recheck() async {
    if (_checking) return;
    setState(() => _checking = true);
    await Future<void>.delayed(AppTimingScope.of(context).deviceCheckDuration);
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final setup = AppStateScope.of(context).currentSetup;
    return Scaffold(
      appBar: AppBar(title: const Text('Device Check')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You’re almost ready',
                  style: TextStyle(
                    color: navy,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  setup == null
                      ? 'Review the simulated device checks below.'
                      : 'Device check for “${setup.speechTitle}”',
                  style: const TextStyle(
                    color: Color(0xFF617085),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                StatusCard(
                  icon: Icons.videocam_outlined,
                  title: 'Camera',
                  status: _checking ? 'Checking...' : 'Ready',
                  isChecking: _checking,
                ),
                const SizedBox(height: 10),
                StatusCard(
                  icon: Icons.mic_none_rounded,
                  title: 'Microphone',
                  status: _checking ? 'Checking...' : 'Ready',
                  isChecking: _checking,
                ),
                const SizedBox(height: 10),
                StatusCard(
                  icon: Icons.light_mode_outlined,
                  title: 'Lighting',
                  status: _checking ? 'Checking...' : 'Good',
                  isChecking: _checking,
                ),
                const SizedBox(height: 10),
                StatusCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Upper Body',
                  status: _checking ? 'Checking...' : 'Visible',
                  isChecking: _checking,
                ),
                const SizedBox(height: 10),
                StatusCard(
                  icon: Icons.cloud_done_outlined,
                  title: 'Internet for Speech Processing',
                  status: _checking ? 'Checking...' : 'Available',
                  isChecking: _checking,
                ),
                const SizedBox(height: 24),
                const SectionHeader('Before you begin'),
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _Instruction(
                          icon: Icons.face_retouching_natural,
                          text: 'Keep face and upper body visible',
                        ),
                        _Instruction(
                          icon: Icons.volume_down_outlined,
                          text: 'Use a reasonably quiet place',
                        ),
                        _Instruction(
                          icon: Icons.stay_current_portrait_rounded,
                          text: 'Keep phone stable',
                        ),
                        _Instruction(
                          icon: Icons.center_focus_strong_rounded,
                          text: 'Look toward the camera',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const InfoBanner(
                  icon: Icons.science_outlined,
                  title: 'Prototype simulation',
                  message: 'No real camera or microphone analysis is active.',
                  color: accentTeal,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const Key('start_rehearsal'),
                  onPressed: setup == null || _checking
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RehearsalScreen(),
                          ),
                        ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Rehearsal'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _checking
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('recheck'),
                        onPressed: _checking ? null : _recheck,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(_checking ? 'Checking...' : 'Recheck'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: primaryBlue, size: 21),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class RehearsalScreen extends StatefulWidget {
  const RehearsalScreen({super.key});

  @override
  State<RehearsalScreen> createState() => _RehearsalScreenState();
}

class _RehearsalScreenState extends State<RehearsalScreen> {
  Timer? _timer;
  Timer? _alertTimer;
  int _elapsedSeconds = 0;
  bool _paused = false;
  bool _ending = false;
  String _pace = 'Normal';
  String _posture = 'Good';
  int _attention = 82;
  final Map<String, int> _fillers = {};
  String? _alert;
  Color _alertColor = primaryBlue;
  final List<int> _paceHistory = [130];

  int get _fillerTotal =>
      _fillers.values.fold<int>(0, (total, value) => total + value);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused) {
        setState(() {
          _elapsedSeconds++;
          if (_elapsedSeconds % 10 == 0) {
            int newPace = 110 + (DateTime.now().millisecondsSinceEpoch % 40);
            if (_pace == 'Too Fast') {
              newPace = 160 + (DateTime.now().millisecondsSinceEpoch % 20);
            }
            _paceHistory.add(newPace);
          }
        });
      }
    });
  }

  void _showAlert(String message, Color color) {
    _alertTimer?.cancel();
    setState(() {
      _alert = message;
      _alertColor = color;
    });
    _alertTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _alert = null);
    });
  }

  void _addFiller(String filler) {
    setState(() => _fillers[filler] = (_fillers[filler] ?? 0) + 1);
    _showAlert('Filler detected: \'$filler\'', warningOrange);
  }

  void _simulateLocalizedFiller() {
    final fillers = <String>['ano', 'parang', 'kasi', 'kuan', 'kanang', "mura'g", 'bitaw', 'um', 'like'];

    final randomFiller = fillers[DateTime.now().microsecondsSinceEpoch % fillers.length];
    _addFiller(randomFiller);
  }

  void _simulatePoorPosture() {
    setState(() => _posture = 'Needs Correction');
    _showAlert('Adjust your posture', errorRed);
  }

  void _simulateLookingAway() {
    setState(() => _attention = (_attention - 18).clamp(35, 100));
    _showAlert('Look toward the camera', warningOrange);
  }

  void _simulateFastPace() {
    setState(() => _pace = 'Too Fast');
    _showAlert('Slow down slightly', warningOrange);
  }

  void _simulateGoodPerformance() {
    setState(() {
      _pace = 'Normal';
      _posture = 'Good';
      _attention = 90;
    });
    _showAlert('Good delivery', successGreen);
  }

  Future<void> _confirmEnd() async {
    if (_ending) return;
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End rehearsal?'),
        content: const Text('Are you sure you want to end this rehearsal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Rehearsal'),
          ),
          FilledButton(
            key: const Key('confirm_end_session'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: errorRed),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    if (shouldEnd != true || !mounted) return;
    _ending = true;
    _timer?.cancel();
    final state = AppStateScope.of(context, listen: false);
    final setup = state.currentSetup!;
    final overall = _calculateOverall();
    final session = PracticeSession(
      id: 'session-${DateTime.now().microsecondsSinceEpoch}',
      title: setup.speechTitle,
      speechType: setup.speechType,
      dateTime: DateTime.now(),
      duration: Duration(seconds: _elapsedSeconds),
      overallScore: overall,
      paceScore: _pace == 'Normal' ? 94 : 72,
      fillerScore: (100 - _fillerTotal * 7).clamp(0, 100),
      postureScore: _posture == 'Good' ? 95 : 72,
      attentionScore: _attention,
      fillerCounts: Map.unmodifiable(_fillers),
      paceHistory: List.unmodifiable(_paceHistory),
      coachingTips: _buildTips(),
      isPrototypeData: true,
    );
    state.setCurrentReport(session);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AnalyzingScreen()),
    );
  }

  int _calculateOverall() {
    var score = 100 - (_fillerTotal * 3);
    if (_posture != 'Good') score -= 8;
    if (_attention < 70) score -= 70 - _attention;
    if (_pace == 'Too Fast') score -= 8;
    return score.clamp(0, 100);
  }

  List<String> _buildTips() {
    final tips = <String>[];
    if (_fillerTotal > 0) {
      tips.add('Use a short, quiet pause when you need time to think.');
    }
    if (_posture != 'Good') {
      tips.add('Relax your shoulders and keep your upper body centered.');
    }
    if (_attention < 75) {
      tips.add('Look toward the camera at the end of important ideas.');
    }
    if (_pace != 'Normal') {
      tips.add('Slow down slightly and let each key point land.');
    }
    if (tips.isEmpty) {
      tips.add('Keep your steady pace and confident camera focus.');
      tips.add('Add purposeful pauses to make strong ideas stand out.');
    }
    return tips;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alertTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = AppStateScope.of(context).currentSetup!;
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmEnd();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF071526),
        appBar: AppBar(
          backgroundColor: const Color(0xFF071526),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rehearsal',
                style: TextStyle(fontSize: 13, color: Color(0xFF9EB1C7)),
              ),
              Text(
                setup.speechTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '$minutes:$seconds',
                  key: const Key('rehearsal_timer'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: PageFrame(
              maxWidth: 760,
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFF102A46),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFF294966)),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: _CameraGridPainter()),
                          ),
                          const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.videocam_outlined,
                                  color: Color(0xFF9EB1C7),
                                  size: 52,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Camera Preview Simulation',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'No real camera is active',
                                  style: TextStyle(
                                    color: Color(0xFF9EB1C7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 14,
                            top: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xCCB42318),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: Colors.white,
                                    size: 9,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'REC',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 14,
                            bottom: 14,
                            child: _MicActivity(paused: _paused),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _alert == null || !setup.enableLiveFeedback
                        ? const SizedBox(height: 14)
                        : Container(
                            key: ValueKey(_alert),
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: _alertColor.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _alertColor.withValues(alpha: .45),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tips_and_updates_outlined,
                                  color: _alertColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 9),
                                Text(
                                  _alert!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.8,
                    children: [
                      _LiveMetric(
                        label: 'Speaking Pace',
                        value: _pace,
                        icon: Icons.speed_rounded,
                        good: _pace == 'Normal',
                      ),
                      _LiveMetric(
                        label: 'Posture',
                        value: _posture,
                        icon: Icons.accessibility_new_rounded,
                        good: _posture == 'Good',
                      ),
                      _LiveMetric(
                        label: 'Camera Attention',
                        value: '$_attention%',
                        icon: Icons.center_focus_strong,
                        good: _attention >= 70,
                      ),
                      _LiveMetric(
                        key: const Key('filler_metric'),
                        label: 'Fillers Detected',
                        value: '$_fillerTotal',
                        icon: Icons.chat_bubble_outline,
                        good: _fillerTotal == 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      colorScheme: Theme.of(
                        context,
                      ).colorScheme.copyWith(onSurface: Colors.white),
                    ),
                    child: Card(
                      color: const Color(0xFF102A46),
                      child: ExpansionTile(
                        key: const Key('demo_controls'),
                        iconColor: Colors.white,
                        collapsedIconColor: Colors.white,
                        title: const Text(
                          'Prototype Demo Controls',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Trigger simulated AI feedback',
                          style: TextStyle(color: Color(0xFF9EB1C7)),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          14,
                        ),
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _DemoButton(
                                key: const Key('simulate_filler'),
                                label: 'Simulate Filler',
                                onPressed: _simulateLocalizedFiller,
                              ),
                              _DemoButton(
                                key: const Key('simulate_poor_posture'),
                                label: 'Simulate Poor Posture',
                                onPressed: _simulatePoorPosture,
                              ),
                              _DemoButton(
                                key: const Key('simulate_looking_away'),
                                label: 'Simulate Looking Away',
                                onPressed: _simulateLookingAway,
                              ),
                              _DemoButton(
                                key: const Key('simulate_fast_pace'),
                                label: 'Simulate Fast Pace',
                                onPressed: _simulateFastPace,
                              ),
                              _DemoButton(
                                key: const Key('simulate_good'),
                                label: 'Simulate Good Performance',
                                onPressed: _simulateGoodPerformance,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('pause_resume'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF57718C)),
                          ),
                          onPressed: () => setState(() => _paused = !_paused),
                          icon: Icon(
                            _paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                          ),
                          label: Text(_paused ? 'Resume' : 'Pause'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('end_session'),
                          style: FilledButton.styleFrom(
                            backgroundColor: errorRed,
                          ),
                          onPressed: _confirmEnd,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('End Session'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF294966).withValues(alpha: .55)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MicActivity extends StatelessWidget {
  const _MicActivity({required this.paused});
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: paused ? 'Microphone activity paused' : 'Microphone activity',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xCC071526),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            ...List.generate(
              4,
              (index) => Container(
                width: 3,
                height: paused ? 4 : 5.0 + index * 3,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: paused
                      ? const Color(0xFF57718C)
                      : const Color(0xFF67E8F9),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveMetric extends StatelessWidget {
  const _LiveMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.good,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = good ? const Color(0xFF5FE3B3) : const Color(0xFFFFA48A);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF102A46),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF294966)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9EB1C7),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF57718C)),
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key});

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  Timer? _timer;
  Timer? _textTimer;
  int _textIndex = 0;
  final List<String> _steps = [
    'Transcribing audio...',
    'Detecting filler words...',
    'Analyzing posture...',
    'Finalizing report...',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer(AppTimingScope.of(context).analysisDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ReportScreen()),
      );
    });
    _textTimer ??= Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (mounted) {
        setState(() => _textIndex = (_textIndex + 1) % _steps.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: PageFrame(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: .08),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(30),
                    child: const CircularProgressIndicator(
                      strokeWidth: 6,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 34),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _steps[_textIndex],
                      key: ValueKey(_textIndex),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Reviewing speech pace, filler words, posture, and camera attention.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF617085),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'SIMULATED ANALYSIS',
                    style: TextStyle(
                      color: accentTeal,
                      fontSize: 11,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _saved = false;

  void _saveOrView() {
    if (_saved) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MainShell(initialIndex: 2),
        ),
        (route) => false,
      );
      return;
    }
    final saved = AppStateScope.of(context, listen: false).saveCurrentReport();
    setState(() => _saved = saved || _saved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Session saved to Progress.'
              : 'This session is already in Progress.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = AppStateScope.of(context).currentReport;
    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Performance Report')),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const MainShell()),
              (route) => false,
            ),
            child: const Text('Return Home'),
          ),
        ),
      );
    }
    final fillers = report.fillerCounts.entries
        .where((entry) => entry.value > 0)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Report'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'PERFORMANCE SCORE',
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ScoreRing(score: report.overallScore),
                      const SizedBox(height: 16),
                      Text(
                        report.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${formatDate(report.dateTime)} • ${formatDuration(report.duration)}',
                        style: const TextStyle(color: Color(0xFF617085)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accentTeal.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Simulated prototype results',
                          style: TextStyle(
                            color: accentTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const SectionHeader('Delivery breakdown'),
                const SizedBox(height: 12),
                _ScoreRow(
                  icon: Icons.speed_rounded,
                  label: 'Pace',
                  score: report.paceScore,
                  status: report.paceScore >= 80 ? 'Normal' : 'Too Fast',
                ),
                const SizedBox(height: 10),
                _ScoreRow(
                  icon: Icons.chat_bubble_outline,
                  label: 'Filler Control',
                  score: report.fillerScore,
                  status:
                      '${fillers.fold<int>(0, (s, e) => s + e.value)} detected',
                ),
                const SizedBox(height: 10),
                _ScoreRow(
                  icon: Icons.accessibility_new_rounded,
                  label: 'Posture',
                  score: report.postureScore,
                  status: report.postureScore >= 80
                      ? 'Good'
                      : 'Needs Correction',
                  extra: StarRating(rating: (report.postureScore / 20).round()),
                ),
                const SizedBox(height: 10),
                _ScoreRow(
                  icon: Icons.center_focus_strong_rounded,
                  label: 'Camera Attention',
                  score: report.attentionScore,
                  status: '${report.attentionScore}%',
                  extra: StarRating(rating: (report.attentionScore / 20).round()),
                ),
                const SizedBox(height: 28),
                const SectionHeader('Speaking pace'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: PaceLineChart(paceHistory: report.paceHistory),
                  ),
                ),
                const SizedBox(height: 28),
                const SectionHeader('Filler frequencies'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: fillers.isEmpty
                        ? const Text(
                            'No selected filler words were detected during this prototype session.',
                            style: TextStyle(
                              color: Color(0xFF617085),
                              height: 1.45,
                            ),
                          )
                        : FillerBarChart(fillerCounts: Map.fromEntries(fillers)),
                  ),
                ),
                const SizedBox(height: 28),
                const SectionHeader('Coaching tips'),
                const SizedBox(height: 12),
                ...report.coachingTips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InfoBanner(
                      icon: Icons.lightbulb_outline_rounded,
                      title: 'Try this next time',
                      message: tip,
                      color: primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('save_progress'),
                  onPressed: _saveOrView,
                  icon: Icon(
                    _saved
                        ? Icons.insights_rounded
                        : Icons.bookmark_add_outlined,
                  ),
                  label: Text(_saved ? 'View Progress' : 'Save to Progress'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const PracticeSetupScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Practice Again'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const MainShell()),
                    (route) => false,
                  ),
                  child: const SizedBox(
                    width: double.infinity,
                    child: Text('Return Home', textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.icon,
    required this.label,
    required this.score,
    required this.status,
    this.extra,
  });
  final IconData icon;
  final String label;
  final int score;
  final String status;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? successGreen
        : score >= 70
        ? warningOrange
        : errorRed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    status,
                    style: const TextStyle(
                      color: Color(0xFF617085),
                      fontSize: 13,
                    ),
                  ),
                  if (extra != null) ...[
                    const SizedBox(height: 4),
                    extra!,
                  ],
                ],
              ),
            ),
            Text(
              '$score',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
