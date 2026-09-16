import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app.dart';
import '../core/app_config.dart';
import '../core/app_theme.dart';
import '../models/practice_session.dart';
import '../models/practice_settings.dart';
import '../services/groq_transcription_service.dart';
import '../services/filler_analysis.dart';
import '../services/internet_connectivity_service.dart';
import '../services/rehearsal_audio_recorder.dart';
import '../services/script_comparison_service.dart';
import '../services/speech_document_service.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';
import '../widgets/speaking_pace_card.dart';
import '../widgets/filler_frequency_card.dart';
import 'main_shell.dart';

class PracticeSetupScreen extends StatefulWidget {
  const PracticeSetupScreen({super.key});

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _speechContentController = TextEditingController();
  String? _speechType;
  String? _languageMode;
  String? _duration;
  bool _body = true;
  bool _cameraAttention = true;
  bool _fillers = true;
  bool _pace = true;
  bool _live = true;
  bool _loadedPreferences = false;
  bool _isExtractingDocument = false;
  String? _referenceDocumentName;
  final _documentService = const SpeechDocumentService();

  static const _speechTypes = ['Prepared', 'Persuasive', 'Impromptu'];
  static const _languages = [
    'English',
    'English–Filipino',
    'English–Bisaya',
    'Mixed Language',
  ];
  static const _durations = [
    '1 minute',
    '3 minutes',
    '5 minutes',
    '10 minutes',
    'No fixed duration',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedPreferences) return;
    final preferences = AppStateScope.of(context, listen: false).preferences;
    _body = preferences.bodyMonitoring;
    _cameraAttention = preferences.cameraAttentionMonitoring;
    _fillers = preferences.fillerMonitoring;
    _pace = preferences.paceMonitoring;
    _live = preferences.liveFeedback;
    _loadedPreferences = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _speechContentController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final settings = PracticeSettings(
      speechTitle: _titleController.text.trim(),
      speechContent: _speechContentController.text.trim().isEmpty
          ? null
          : _speechContentController.text.trim(),
      referenceDocumentName: _referenceDocumentName,
      speechType: _speechType!,
      languageMode: _languageMode!,
      selectedDuration: _duration!,
      monitorBodyLanguage: _body,
      monitorCameraAttention: _cameraAttention,
      monitorFillers: _fillers,
      monitorPace: _pace,
      enableLiveFeedback: _live,
    );
    AppStateScope.of(context, listen: false).setCurrentSetup(settings);
    final connectivity = AppTimingScope.of(context).internetConnectivity;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RehearsalScreen(internetConnectivity: connectivity),
      ),
    );
  }

  bool get _requiresReferenceScript =>
      _speechType == 'Prepared' || _speechType == 'Persuasive';

  void _selectSpeechType(String value) {
    setState(() {
      _speechType = value;
      if (value == 'Impromptu') {
        _referenceDocumentName = null;
        _speechContentController.clear();
      }
    });
  }

  Future<void> _chooseSpeechDocument() async {
    if (_isExtractingDocument) return;
    setState(() => _isExtractingDocument = true);
    try {
      final document = await _documentService.pickAndExtract();
      if (document == null || !mounted) return;
      setState(() {
        _referenceDocumentName = document.fileName;
        _speechContentController.text = document.text;
      });
      _formKey.currentState?.validate();
    } on SpeechDocumentException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: errorRed),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the selected speech document.'),
          backgroundColor: errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExtractingDocument = false);
    }
  }

  void _removeSpeechDocument() {
    setState(() {
      _referenceDocumentName = null;
      _speechContentController.clear();
    });
    _formKey.currentState?.validate();
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
                    hint: 'Select speech type',
                    icon: Icons.category_outlined,
                    value: _speechType,
                    items: _speechTypes,
                    onChanged: _selectSpeechType,
                  ),
                  if (_requiresReferenceScript) ...[
                    const SizedBox(height: 16),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reference script',
                              style: TextStyle(
                                color: navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Choose the prepared script you will rehearse. '
                              'SpeakSync will extract its text for comparison.',
                              style: TextStyle(
                                color: Color(0xFF617085),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_referenceDocumentName == null)
                              OutlinedButton.icon(
                                key: const Key('choose_speech_document'),
                                onPressed: _isExtractingDocument
                                    ? null
                                    : _chooseSpeechDocument,
                                icon: _isExtractingDocument
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.upload_file_rounded),
                                label: Text(
                                  _isExtractingDocument
                                      ? 'Reading document...'
                                      : 'Choose TXT or DOCX',
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: accentTeal.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: accentTeal.withValues(alpha: .25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      color: accentTeal,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _referenceDocumentName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: navy,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      key: const Key('remove_speech_document'),
                                      tooltip: 'Remove document',
                                      onPressed: _removeSpeechDocument,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('speech_content'),
                              controller: _speechContentController,
                              minLines: 4,
                              maxLines: 8,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Extracted script text',
                                hintText: 'The extracted text appears here',
                                helperText:
                                    'You may correct extraction mistakes before continuing.',
                                alignLabelWithHint: true,
                              ),
                              validator: (value) {
                                if (_referenceDocumentName == null) {
                                  return 'Please choose your speech document.';
                                }
                                if (value == null || value.trim().isEmpty) {
                                  return 'The reference script cannot be empty.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (_speechType == 'Impromptu') ...[
                    const SizedBox(height: 12),
                    const InfoBanner(
                      icon: Icons.bolt_rounded,
                      title: 'No script needed',
                      message:
                          'Impromptu rehearsal continues without a reference script.',
                      color: accentTeal,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _DropdownField(
                    key: const Key('language_mode'),
                    label: 'Language mode',
                    hint: 'Select language mode',
                    icon: Icons.translate_rounded,
                    value: _languageMode,
                    items: _languages,
                    onChanged: (value) => setState(() => _languageMode = value),
                  ),
                  const SizedBox(height: 16),
                  _DropdownField(
                    key: const Key('duration'),
                    label: 'Target duration',
                    hint: 'Select target duration',
                    icon: Icons.timer_outlined,
                    value: _duration,
                    items: _durations,
                    onChanged: (value) => setState(() => _duration = value),
                  ),
                  const SizedBox(height: 26),
                  const SectionHeader('Detection settings'),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose what the prototype should monitor during rehearsal.',
                    style: TextStyle(color: Color(0xFF617085), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: const Key('body_monitoring'),
                          title: const Text('Posture monitoring'),
                          subtitle: const Text('Upper-body posture and stance'),
                          secondary: const Icon(
                            Icons.accessibility_new_rounded,
                          ),
                          value: _body,
                          onChanged: (value) => setState(() => _body = value),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile(
                          key: const Key('camera_attention_monitoring'),
                          title: const Text('Camera-facing attention'),
                          subtitle: const Text('Looking toward the camera'),
                          secondary: const Icon(Icons.visibility_outlined),
                          value: _cameraAttention,
                          onChanged: (value) =>
                              setState(() => _cameraAttention = value),
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
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      validator: (value) => value == null ? 'Please choose $label.' : null,
    );
  }
}

class DeviceCheckScreen extends StatefulWidget {
  const DeviceCheckScreen({super.key, this.returnToPreview = false});

  final bool returnToPreview;

  @override
  State<DeviceCheckScreen> createState() => _DeviceCheckScreenState();
}

class _DeviceCheckScreenState extends State<DeviceCheckScreen> {
  bool _checking = false;
  int _activeCheck = -1;
  InternetConnectivity? _internetConnectivity;
  StreamSubscription<bool>? _internetSubscription;
  AppLifecycleListener? _lifecycleListener;
  bool? _internetAvailable;
  bool _connectivityInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_connectivityInitialized) return;
    _connectivityInitialized = true;
    _internetConnectivity = AppTimingScope.of(context).internetConnectivity;
    _lifecycleListener = AppLifecycleListener(
      onResume: _resumeInternetMonitoring,
      onPause: _pauseInternetMonitoring,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeChecks());
    });
  }

  Future<void> _initializeChecks() async {
    await _recheck();
    if (!mounted) return;
    _startInternetMonitoring();
  }

  void _startInternetMonitoring() {
    if (_internetSubscription != null) return;
    _internetSubscription = _internetConnectivity!.statusChanges.listen(
      _handleInternetStatus,
    );
  }

  void _pauseInternetMonitoring() {
    final subscription = _internetSubscription;
    _internetSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  void _resumeInternetMonitoring() {
    _startInternetMonitoring();
    unawaited(_refreshInternet());
  }

  Future<void> _recheck() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _activeCheck = 0;
    });
    final stepDuration = AppTimingScope.of(context).deviceCheckDuration;
    for (var index = 0; index < 2; index++) {
      if (!mounted) return;
      setState(() => _activeCheck = index);
      await Future<void>.delayed(stepDuration);
      if (!mounted) return;
    }
    setState(() => _activeCheck = 2);
    final available = await _checkInternet();
    await Future<void>.delayed(stepDuration);
    if (!mounted) return;
    setState(() {
      _internetAvailable = available;
      _checking = false;
      _activeCheck = -1;
    });
  }

  Future<bool> _checkInternet() async {
    try {
      return await _internetConnectivity!.check();
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshInternet() async {
    final available = await _checkInternet();
    if (!mounted) return;
    _handleInternetStatus(available);
  }

  void _handleInternetStatus(bool available) {
    if (!mounted || _internetAvailable == available) return;
    setState(() => _internetAvailable = available);
  }

  String _checkStatus(int index, String readyStatus) {
    if (_checking && _activeCheck == index) return 'Checking...';
    if (_checking && _activeCheck < index) return 'Waiting';
    return readyStatus;
  }

  String get _internetStatus {
    if (_checking && _activeCheck == 2) return 'Checking...';
    if (_checking && _activeCheck < 2) return 'Waiting';
    if (_internetAvailable == null) return 'Checking...';
    return _internetAvailable! ? 'Available' : 'Not available';
  }

  @override
  void dispose() {
    _pauseInternetMonitoring();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = AppStateScope.of(context).currentSetup;
    final selectedMonitoring = setup == null
        ? <String>[]
        : <String>[
            if (setup.monitorFillers) 'Filler words',
            if (setup.monitorPace) 'Speaking pace',
            if (setup.monitorBodyLanguage) 'Posture',
            if (setup.monitorCameraAttention) 'Camera attention',
          ];
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
                  status: _checkStatus(0, 'Ready'),
                  isChecking: _checking && _activeCheck == 0,
                  isPending: _checking && _activeCheck < 0,
                ),
                const SizedBox(height: 10),
                StatusCard(
                  icon: Icons.mic_none_rounded,
                  title: 'Microphone',
                  status: _checkStatus(1, 'Ready'),
                  isChecking: _checking && _activeCheck == 1,
                  isPending: _checking && _activeCheck < 1,
                ),
                const SizedBox(height: 10),
                StatusCard(
                  icon: _internetAvailable == false
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
                  title: 'Internet for Speech Processing',
                  status: _internetStatus,
                  isChecking:
                      (_checking && _activeCheck == 2) ||
                      (!_checking && _internetAvailable == null),
                  isPending: _checking && _activeCheck < 2,
                  isSuccessful: _internetAvailable != false,
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
                InfoBanner(
                  icon: Icons.tune_rounded,
                  title: 'Selected monitoring',
                  message: selectedMonitoring.isEmpty
                      ? 'No detection categories selected.'
                      : selectedMonitoring.join(' • '),
                  color: primaryBlue,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const Key('start_rehearsal'),
                  onPressed:
                      setup == null || _checking || _internetAvailable != true
                      ? null
                      : () {
                          if (widget.returnToPreview) {
                            Navigator.of(context).pop();
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RehearsalScreen(
                                internetConnectivity: _internetConnectivity,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    widget.returnToPreview
                        ? 'Back to Preview'
                        : 'Camera Preview',
                  ),
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

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.busy,
    required this.starting,
    required this.onReady,
    required this.onDeviceCheck,
  });

  final bool busy;
  final bool starting;
  final VoidCallback onReady;
  final VoidCallback onDeviceCheck;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('rehearsal_readiness'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102A43),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF294966)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Get comfortable before you begin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Keep your face and upper body in frame. Adjust your phone, lighting, and posture.',
            style: TextStyle(color: Color(0xFFBDD0E2), height: 1.5),
          ),
          const SizedBox(height: 10),
          const Text(
            'Preview only — no recording or monitoring yet.',
            style: TextStyle(color: accentTeal, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('ready_rehearsal'),
            onPressed: busy ? null : onReady,
            style: FilledButton.styleFrom(
              backgroundColor: accentTeal,
              foregroundColor: navy,
              minimumSize: const Size(double.infinity, 52),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(starting ? 'Starting...' : "I'm Ready"),
          ),
          Center(
            child: TextButton(
              key: const Key('preview_device_check'),
              onPressed: busy ? null : onDeviceCheck,
              child: const Text(
                'Device Check',
                style: TextStyle(color: Color(0xFFBDD0E2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RehearsalScreen extends StatefulWidget {
  const RehearsalScreen({
    super.key,
    this.internetConnectivity,
    this.audioRecorder,
  });

  final InternetConnectivity? internetConnectivity;
  final RehearsalAudioRecorder? audioRecorder;

  @override
  State<RehearsalScreen> createState() => _RehearsalScreenState();
}

class _RehearsalScreenState extends State<RehearsalScreen> {
  Timer? _timer;
  Timer? _alertTimer;
  Timer? _countdownTimer;
  int? _countdown;
  bool _hasStarted = false;
  bool _starting = false;
  bool _checkingReadiness = false;
  int _readinessGeneration = 0;
  bool _leaving = false;
  AppLifecycleListener? _readinessLifecycle;
  late final InternetConnectivity _internetConnectivity;
  int _elapsedSeconds = 0;
  int? _targetDurationSeconds;
  bool _targetDurationLoaded = false;
  bool _thirtySecondWarningShown = false;
  bool _paused = false;
  bool _restarting = false;
  bool _changingMicrophone = false;
  bool _recording = false;
  bool _cameraReady = false;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;
  bool _transcribing = false;
  CameraController? _cameraController;
  String _cameraStatus = 'Waiting for camera permission...';
  String? _audioRecordingError;
  Future<void>? _audioStartFuture;
  bool _ending = false;
  String _pace = 'Normal';
  String _posture = 'Good';
  int _attention = 82;
  final Map<String, int> _fillers = {};
  final Map<String, int> _gestureCounts = {};
  final List<String> _transcriptLines = [];
  late final RehearsalAudioRecorder _audioRecorder;
  final _microphoneLevel = ValueNotifier<double>(0);
  StreamSubscription<double>? _levelSubscription;
  final _transcriptionService = GroqTranscriptionService(
    apiKey: AppConfig.groqApiKey,
  );
  final _scriptComparisonService = const ScriptComparisonService();
  final String _recommendedPosture =
      'Maintain a steady upper-body posture and keep your eyes near the camera.';
  String? _alert;
  Color _alertColor = primaryBlue;
  IconData _alertIcon = Icons.info_outline_rounded;

  final List<String> _transcriptSamples = const [
    'Today I will talk about why practice matters in every presentation, ano.',
    'Using short pauses helps you stay clear parang avoiding filler words.',
    'Make sure your shoulders are relaxed and your voice kuan stays steady.',
    'Keep your eyes toward the camera kanang to build connection with the audience.',
    'Repeat important phrases slowly and with confidence mura\'g like this.',
    'End with a strong closing statement bitaw that ties your ideas together.',
  ];

  int get _fillerTotal =>
      _fillers.values.fold<int>(0, (total, value) => total + value);

  @override
  void initState() {
    super.initState();
    _audioRecorder = widget.audioRecorder ?? RehearsalAudioRecorder();
    _internetConnectivity =
        widget.internetConnectivity ?? const InternetConnectivityService();
    _readinessLifecycle = AppLifecycleListener(
      onInactive: () {
        if (!_hasStarted && !_starting) _cancelCountdown();
      },
    );
    _prepareCamera();
  }

  void _cancelCountdown() {
    _readinessGeneration++;
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _countdown = null;
        _checkingReadiness = false;
      });
    }
  }

  Future<void> _beginCountdown() async {
    if (_hasStarted || _starting || _checkingReadiness || _countdown != null) {
      return;
    }
    final generation = ++_readinessGeneration;
    setState(() => _checkingReadiness = true);
    final online = await _checkInternet();
    if (!mounted || _leaving || generation != _readinessGeneration) return;
    setState(() => _checkingReadiness = false);
    if (!online) {
      _showAlert(
        'Internet is unavailable. Reconnect before starting speech processing.',
        warningOrange,
        icon: Icons.cloud_off_outlined,
      );
      return;
    }
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _leaving) {
        timer.cancel();
        return;
      }
      if (_countdown! > 1) {
        setState(() => _countdown = _countdown! - 1);
      } else {
        timer.cancel();
        setState(() {
          _countdown = null;
          _starting = true;
        });
        _audioStartFuture = _startAfterCountdown();
      }
    });
  }

  Future<void> _startAfterCountdown() async {
    await _startAudioRecording();
    if (!mounted || _leaving) return;
    setState(() {
      _elapsedSeconds = 0;
      _hasStarted = true;
      _starting = false;
    });
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _handleTimerTick(),
    );
  }

  void _leavePreview() {
    if (_hasStarted || _leaving) return;
    _leaving = true;
    _cancelCountdown();
    Navigator.of(context).pop();
  }

  Future<bool> _checkInternet() async {
    try {
      return await _internetConnectivity.check();
    } catch (_) {
      return false;
    }
  }

  Future<void> _startAudioRecording() async {
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    if (!mounted || _leaving) return;
    _microphoneLevel.value = 0;
    if (!AppConfig.hasGroqApiKey) {
      const message = 'Groq transcription is not configured on this device.';
      if (!mounted) return;
      setState(() {
        _recording = false;
        _audioRecordingError = message;
      });
      return;
    }
    try {
      await _audioRecorder.start();
      if (!mounted || _leaving) return;
      _levelSubscription = _audioRecorder.levels.listen(
        (level) {
          if (!mounted) return;
          _microphoneLevel.value =
              _microphoneEnabled && !_ending && !_restarting ? level : 0;
        },
        onError: (Object _) {
          if (mounted) _microphoneLevel.value = 0;
        },
        onDone: () {
          if (mounted) _microphoneLevel.value = 0;
        },
      );
      setState(() {
        _recording = true;
        _microphoneEnabled = true;
        _audioRecordingError = null;
      });
    } on AudioRecordingException catch (error) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _audioRecordingError = error.message;
      });
      _showAlert(error.message, errorRed, icon: Icons.mic_off_rounded);
    } catch (_) {
      if (!mounted) return;
      const message = 'SpeakSync could not start microphone recording.';
      setState(() {
        _recording = false;
        _audioRecordingError = message;
      });
      _showAlert(message, errorRed, icon: Icons.mic_off_rounded);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_targetDurationLoaded) return;
    final selectedDuration = AppStateScope.of(
      context,
      listen: false,
    ).currentSetup?.selectedDuration;
    _targetDurationSeconds = _parseTargetDuration(selectedDuration);
    _targetDurationLoaded = true;
  }

  int get _remainingSeconds {
    final target = _targetDurationSeconds;
    if (target == null) return _elapsedSeconds;
    return (target - _elapsedSeconds).clamp(0, target);
  }

  void _handleTimerTick() {
    if (!mounted || !_hasStarted || _paused || _ending) return;
    final target = _targetDurationSeconds;
    setState(() {
      _elapsedSeconds++;
      if (_recording) _maybeAddTranscriptLine();
    });

    if (target == null) return;
    final remaining = _remainingSeconds;
    if (remaining == 30 && !_thirtySecondWarningShown) {
      _thirtySecondWarningShown = true;
      _showAlert(
        '30 seconds remaining — your rehearsal is almost done',
        warningOrange,
        icon: Icons.timer_outlined,
      );
    }
    if (remaining == 0) {
      _finishRehearsal();
    }
  }

  int? _parseTargetDuration(String? selectedDuration) {
    if (selectedDuration == null || selectedDuration == 'No fixed duration') {
      return null;
    }
    final minutes = int.tryParse(selectedDuration.split(' ').first);
    return minutes == null ? null : minutes * 60;
  }

  void _showAlert(
    String message,
    Color color, {
    IconData icon = Icons.info_outline_rounded,
  }) {
    _alertTimer?.cancel();
    setState(() {
      _alert = message;
      _alertColor = color;
      _alertIcon = icon;
    });
    _alertTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() {
          _alert = null;
        });
      }
    });
  }

  void _simulatePostureAlert() {
    _posture = 'Adjust';
    _showAlert(
      'Posture needs correction',
      warningOrange,
      icon: Icons.accessibility_new_rounded,
    );
  }

  void _simulateCameraAttentionAlert() {
    _attention = 64;
    _showAlert(
      'Look toward the camera',
      warningOrange,
      icon: Icons.visibility_outlined,
    );
  }

  void _simulateFillerAlert() {
    _fillers.update('Kuan', (count) => count + 1, ifAbsent: () => 1);
    _showAlert(
      'Filler word detected',
      warningOrange,
      icon: Icons.chat_bubble_outline_rounded,
    );
  }

  void _simulateFastSpeechAlert() {
    _pace = 'Too Fast';
    _showAlert(
      'Speaking too fast — slow down',
      warningOrange,
      icon: Icons.speed_rounded,
    );
  }

  Future<void> _prepareCamera() async {
    try {
      final cameraStatus = await Permission.camera.request();
      if (!mounted || _leaving) return;
      if (!cameraStatus.isGranted) {
        setState(() {
          _cameraReady = false;
          _cameraStatus = 'Allow camera access to check your framing.';
        });
        return;
      }
      final cameras = await availableCameras();
      if (!mounted || _leaving) return;
      if (cameras.isEmpty) {
        setState(() {
          _cameraReady = false;
          _cameraStatus = 'No camera found on this device.';
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.max,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted || _leaving) return;

      // Use the widest view supported by the device so the speaker can keep
      // their head, hands, and waist visible during rehearsal.
      try {
        final minimumZoom = await _cameraController!.getMinZoomLevel();
        await _cameraController!.setZoomLevel(minimumZoom);
      } catch (_) {
        // Zoom is optional. Browsers and some laptop cameras do not expose
        // zoom controls, so keep using their default (widest) camera feed.
      }

      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _cameraStatus = 'Camera ready';
      });
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (!mounted || _leaving) return;
      setState(() {
        _cameraReady = false;
        _cameraStatus = 'Unable to initialize camera. Error: $e';
      });
    }
  }

  // Reserved for the future recording control. The current UI intentionally
  // exposes only camera and microphone on/off controls.
  // ignore: unused_element
  Future<void> _toggleRecording() async {
    if (!_cameraReady || _cameraController == null) {
      await _prepareCamera();
    }

    if (!_cameraReady || _cameraController == null) {
      _showAlert(
        'Please allow camera and microphone access before recording.',
        errorRed,
      );
      return;
    }

    if (!_recording) {
      try {
        await _cameraController!.startVideoRecording();
        _showAlert('Recording started', successGreen);
      } catch (_) {
        _showAlert('Failed to start recording.', errorRed);
        return;
      }
    } else {
      try {
        await _cameraController!.stopVideoRecording();
        _showAlert('Recording saved locally.', successGreen);
      } catch (_) {
        _showAlert('Failed to stop recording.', errorRed);
      }
    }

    setState(() => _recording = !_recording);
  }

  Future<void> _toggleMicrophone() async {
    if (!_hasStarted || _restarting || _ending || _changingMicrophone) return;
    setState(() => _changingMicrophone = true);
    try {
      await _audioStartFuture;
      if (!mounted) return;
      await _changeMicrophone();
    } finally {
      if (mounted) setState(() => _changingMicrophone = false);
    }
  }

  Future<void> _changeMicrophone() async {
    if (!_audioRecorder.hasStarted) {
      _audioStartFuture = _startAudioRecording();
      await _audioStartFuture;
      return;
    }
    try {
      if (_microphoneEnabled) {
        await _audioRecorder.pause();
        if (mounted) _microphoneLevel.value = 0;
      } else {
        await _audioRecorder.resume();
      }
      if (mounted) {
        setState(() {
          _microphoneEnabled = !_microphoneEnabled;
          _recording = _microphoneEnabled;
        });
      }
    } catch (_) {
      _showAlert(
        'Unable to change the microphone state.',
        errorRed,
        icon: Icons.mic_off_rounded,
      );
    }
  }

  Future<void> _confirmRestart() async {
    if (!_hasStarted ||
        _restarting ||
        _ending ||
        _changingMicrophone ||
        _paused) {
      return;
    }
    setState(() {
      _restarting = true;
      _paused = true;
    });
    var resumeRecording = false;
    try {
      await _audioStartFuture;
      if (!mounted) return;
      // Keep recorded audio and rehearsal time aligned during confirmation.
      if (_microphoneEnabled && _audioRecorder.hasStarted) {
        await _audioRecorder.pause();
        resumeRecording = true;
      }
      if (!mounted) return;
      _microphoneLevel.value = 0;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restart Session'),
          content: const Text(
            'Are you sure you want to restart? Your current progress will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('confirm_restart_session'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restart'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      resumeRecording = false;
      // Track the whole operation so disposal also waits for stop/start.
      _audioStartFuture = _restartRehearsal().catchError((Object _) {
        if (!mounted) return;
        const message = 'Unable to restart the microphone. Please try again.';
        setState(() {
          _recording = false;
          _audioRecordingError = message;
        });
        _showAlert(message, errorRed, icon: Icons.mic_off_rounded);
      });
      await _audioStartFuture;
    } catch (_) {
      if (mounted) {
        _showAlert(
          'Unable to restart the microphone. Please try again.',
          errorRed,
          icon: Icons.mic_off_rounded,
        );
      }
    } finally {
      if (resumeRecording && mounted && _audioRecorder.hasStarted) {
        try {
          await _audioRecorder.resume();
        } catch (_) {
          if (mounted) {
            _showAlert(
              'Unable to resume the microphone. Please try again.',
              errorRed,
              icon: Icons.mic_off_rounded,
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          _restarting = false;
          _paused = false;
        });
      }
    }
  }

  Future<void> _restartRehearsal() async {
    _microphoneLevel.value = 0;
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    await _audioRecorder.discard();
    if (!mounted) return;
    _alertTimer?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _fillers.clear();
      _gestureCounts.clear();
      _transcriptLines.clear();
      _pace = 'Normal';
      _posture = 'Good';
      _attention = 82;
      _thirtySecondWarningShown = false;
      _alert = null;
      _recording = false;
    });
    await _startAudioRecording();
    if (!mounted) return;
    // Give the new attempt a full first second, independent of the old timer.
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _handleTimerTick(),
    );
  }

  Future<void> _toggleCamera() async {
    final controller = _cameraController;
    if (!_cameraReady ||
        controller == null ||
        !controller.value.isInitialized) {
      _showAlert('Camera is not ready yet.', warningOrange);
      return;
    }

    try {
      if (_cameraEnabled) {
        await controller.pausePreview();
      } else {
        await controller.resumePreview();
      }
      if (mounted) setState(() => _cameraEnabled = !_cameraEnabled);
    } on CameraException {
      _showAlert('Unable to change the camera state.', errorRed);
    }
  }

  void _maybeAddTranscriptLine() {
    if (_transcriptLines.length >= _transcriptSamples.length) return;
    if (_elapsedSeconds == 0 || _elapsedSeconds % 5 != 0) return;
    final nextLine = _transcriptSamples[_transcriptLines.length];
    _transcriptLines.add(nextLine);
    final setup = AppStateScope.of(context, listen: false).currentSetup!;

    // Prototype signals stand in for the on-device vision analysis planned for
    // production. They keep the feedback treatment testable without audio.
    if (_transcriptLines.length == 3 && setup.monitorBodyLanguage) {
      _posture = 'Adjust';
      _showAlert(
        'Posture needs correction',
        warningOrange,
        icon: Icons.accessibility_new_rounded,
      );
      return;
    } else if (_transcriptLines.length == 4 && setup.monitorCameraAttention) {
      _attention = 64;
      _showAlert(
        'Look toward the camera',
        warningOrange,
        icon: Icons.visibility_outlined,
      );
      return;
    }

    if (!setup.monitorFillers) return;
    const fillerWords = ['ano', 'parang', 'kuan', 'kanang', 'mura\'g', 'bitaw'];
    final normalizedLine = nextLine.toLowerCase();
    for (final filler in fillerWords) {
      if (normalizedLine.contains(RegExp('\\b${RegExp.escape(filler)}\\b'))) {
        final label = filler[0].toUpperCase() + filler.substring(1);
        _fillers.update(label, (count) => count + 1, ifAbsent: () => 1);
        _showAlert(
          'Filler word detected',
          warningOrange,
          icon: Icons.chat_bubble_outline_rounded,
        );
        return;
      }
    }
  }

  Future<void> _confirmEnd() async {
    if (!_hasStarted) {
      _leavePreview();
      return;
    }
    if (_ending || _restarting || _changingMicrophone || _paused) return;
    setState(() => _paused = true);
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
    if (!mounted) return;
    if (shouldEnd != true) {
      setState(() => _paused = false);
      return;
    }
    await _finishRehearsal();
  }

  Future<void> _finishRehearsal() async {
    if (!_hasStarted || _ending) return;
    _ending = true;
    _microphoneLevel.value = 0;
    _timer?.cancel();
    if (mounted) setState(() => _transcribing = true);
    if (_cameraController?.value.isRecordingVideo == true) {
      try {
        await _cameraController!.stopVideoRecording();
      } catch (_) {
        // Ignore stop errors during cleanup.
      }
    }
    if (!mounted) return;
    final state = AppStateScope.of(context, listen: false);
    final setup = state.currentSetup!;
    final overall = _calculateOverall();
    String? audioPath;
    String? transcript;
    String? transcriptionError;
    try {
      await _audioStartFuture;
      if (!_audioRecorder.hasStarted) {
        throw AudioRecordingException(
          _audioRecordingError ?? 'No rehearsal audio was recorded.',
        );
      }
      audioPath = await _audioRecorder.stop();
      if (audioPath == null || audioPath.trim().isEmpty) {
        throw const AudioRecordingException('No rehearsal audio was recorded.');
      }
      if (!await _checkInternet()) {
        throw const TranscriptionException(
          TranscriptionFailureType.noInternet,
          'No internet connection was available for transcription.',
        );
      }
      transcript = await _transcriptionService.transcribe(audioPath);
    } on AudioRecordingException catch (error) {
      transcriptionError = error.message;
    } on TranscriptionException catch (error) {
      transcriptionError = error.message;
    } catch (_) {
      transcriptionError =
          'Transcription failed. The rehearsal report can still continue.';
    } finally {
      await _audioRecorder.deleteTemporaryFile(audioPath);
    }
    if (!mounted) return;
    final referenceScript = setup.speechContent?.trim();
    final shouldCompareScript =
        (setup.speechType == 'Prepared' || setup.speechType == 'Persuasive') &&
        referenceScript != null &&
        referenceScript.isNotEmpty &&
        transcript != null &&
        transcript.isNotEmpty;
    final comparison = shouldCompareScript
        ? _scriptComparisonService.compare(
            referenceScript: referenceScript,
            transcript: transcript,
          )
        : null;
    final session = PracticeSession(
      id: 'session-${DateTime.now().microsecondsSinceEpoch}',
      title: setup.speechTitle,
      speechType: setup.speechType,
      languageMode: setup.languageMode,
      dateTime: DateTime.now(),
      duration: Duration(seconds: _elapsedSeconds),
      overallScore: overall,
      paceScore: _pace == 'Normal' ? 94 : 72,
      fillerScore: (100 - _fillerTotal * 7).clamp(0, 100),
      postureScore: _posture == 'Good' ? 95 : 72,
      attentionScore: _attention,
      fillerCounts: FillerAnalysis.fromTranscript(
        transcript,
        Duration(seconds: _elapsedSeconds),
      ).counts,
      coachingTips: _buildTips(),
      textTranscript: transcript,
      referenceScript: shouldCompareScript ? referenceScript : null,
      referenceDocumentName: shouldCompareScript
          ? setup.referenceDocumentName
          : null,
      omittedScriptPortions: comparison?.omittedPortions ?? const [],
      addedTranscriptPortions: comparison?.addedPortions ?? const [],
      differentlyDeliveredPortions:
          comparison?.differentlyDeliveredPortions ?? const [],
      transcriptLines: List.unmodifiable(_transcriptLines),
      gestureCounts: Map.unmodifiable(_gestureCounts),
      recommendedPosture: _recommendedPosture,
      isPrototypeData: true,
    );
    state.setCurrentReport(session);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            AnalyzingScreen(transcriptionErrorMessage: transcriptionError),
      ),
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
      tips.add(
        'Try taking a quick breath instead of using a filler word. Silence feels much shorter to the audience than it does to you.',
      );
    }
    if (_posture != 'Good') {
      tips.add(
        'Your posture shifted noticeably during the recording. Plant your feet shoulder-width apart to project more authority and stabilize your frame.',
      );
    }
    if (_attention < 75) {
      tips.add(
        'You broke eye contact with the camera frequently. Try visualizing a single friendly face right behind the lens to maintain a stronger connection.',
      );
    }
    if (_pace != 'Normal') {
      tips.add(
        'Your pacing felt rushed in sections. Practice "chunking" your sentences into smaller phrases and fully stopping at the periods.',
      );
    }
    if (tips.isEmpty) {
      tips.add(
        'Excellent pacing and strong eye contact! Your delivery felt highly polished. For an even greater impact next time, try using hand gestures to emphasize your most important points.',
      );
    }
    return tips;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alertTimer?.cancel();
    _countdownTimer?.cancel();
    _readinessLifecycle?.dispose();
    _levelSubscription?.cancel();
    _microphoneLevel.dispose();
    _cameraController?.dispose();
    unawaited(_disposeAudioRecorder());
    _transcriptionService.dispose();
    super.dispose();
  }

  Future<void> _disposeAudioRecorder() async {
    await _audioStartFuture;
    if (_audioRecorder.hasStarted) await _audioRecorder.cancel();
    await _audioRecorder.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = AppStateScope.of(context).currentSetup!;
    final displayedSeconds = _remainingSeconds;
    final minutes = (displayedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (displayedSeconds % 60).toString().padLeft(2, '0');
    return PopScope(
      canPop: !_hasStarted,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _leaving = true;
          _countdownTimer?.cancel();
          return;
        }
        if (!didPop) _confirmEnd();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF071526),
        appBar: AppBar(
          backgroundColor: const Color(0xFF071526),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: !_hasStarted
              ? IconButton(
                  key: const Key('leave_readiness'),
                  onPressed: _leavePreview,
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hasStarted ? 'Rehearsal' : 'Camera Preview',
                style: const TextStyle(fontSize: 13, color: Color(0xFF9EB1C7)),
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
            if (_hasStarted)
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
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                child: PageFrame(
                  maxWidth: 760,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomCenter,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 28),
                            child: _CameraStage(
                              controller: _cameraController,
                              cameraReady: _cameraReady,
                              cameraEnabled: _cameraEnabled,
                              cameraStatus: _cameraStatus,
                              recording:
                                  _hasStarted &&
                                  _recording &&
                                  !_restarting &&
                                  !_ending,
                            ),
                          ),
                          if (_alert != null &&
                              (!_hasStarted || setup.enableLiveFeedback))
                            Positioned(
                              top: 12,
                              left: 12,
                              right: 12,
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Container(
                                    key: ValueKey(_alert),
                                    width: double.infinity,
                                    constraints: const BoxConstraints(
                                      maxWidth: 360,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xE61A2938),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _alertColor.withValues(
                                          alpha: .55,
                                        ),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x33000000),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _alertIcon,
                                          color: _alertColor,
                                          size: 17,
                                        ),
                                        const SizedBox(width: 7),
                                        Flexible(
                                          child: Text(
                                            _alert!,
                                            maxLines: 2,
                                            softWrap: true,
                                            overflow: TextOverflow.visible,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_hasStarted)
                            Positioned(
                              left: 12,
                              bottom: 48,
                              child: ValueListenableBuilder<double>(
                                valueListenable: _microphoneLevel,
                                builder: (context, level, child) =>
                                    _MicrophoneLevelIndicator(
                                      enabled:
                                          _microphoneEnabled &&
                                          _audioRecorder.hasStarted &&
                                          !_ending,
                                      level: level,
                                    ),
                              ),
                            ),
                          if (_hasStarted)
                            Positioned(
                              bottom: 0,
                              child: _MediaControls(
                                microphoneEnabled: _microphoneEnabled,
                                cameraEnabled: _cameraEnabled,
                                onMicrophonePressed: _toggleMicrophone,
                                onCameraPressed: _toggleCamera,
                              ),
                            ),
                        ],
                      ),
                      if (!_hasStarted) ...[
                        _ReadinessCard(
                          busy:
                              _starting ||
                              _checkingReadiness ||
                              _countdown != null,
                          starting: _starting,
                          onReady: _beginCountdown,
                          onDeviceCheck: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const DeviceCheckScreen(
                                returnToPreview: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_hasStarted) ...[
                        const SizedBox(height: 10),
                        if (setup.enableLiveFeedback) ...[
                          Container(
                            key: const Key('prototype_alert_controls'),
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10243A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF29435E),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Test live alerts',
                                  style: TextStyle(
                                    color: Color(0xFFB9C9D9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (setup.monitorBodyLanguage)
                                      _AlertTestButton(
                                        key: const Key('test_posture_alert'),
                                        icon: Icons.accessibility_new_rounded,
                                        label: 'Posture',
                                        onPressed: _simulatePostureAlert,
                                      ),
                                    if (setup.monitorCameraAttention)
                                      _AlertTestButton(
                                        key: const Key('test_camera_alert'),
                                        icon: Icons.visibility_outlined,
                                        label: 'Camera gaze',
                                        onPressed:
                                            _simulateCameraAttentionAlert,
                                      ),
                                    if (setup.monitorFillers)
                                      _AlertTestButton(
                                        key: const Key('test_filler_alert'),
                                        icon: Icons.chat_bubble_outline_rounded,
                                        label: 'Filler word',
                                        onPressed: _simulateFillerAlert,
                                      ),
                                    if (setup.monitorPace)
                                      _AlertTestButton(
                                        key: const Key(
                                          'test_fast_speech_alert',
                                        ),
                                        icon: Icons.speed_rounded,
                                        label: 'Fast speech',
                                        onPressed: _simulateFastSpeechAlert,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.35,
                          children: [
                            _LiveMetric(
                              label: 'Speaking Pace',
                              value: setup.monitorPace ? _pace : 'Off',
                              icon: Icons.speed_rounded,
                              good: _pace == 'Normal',
                              enabled: setup.monitorPace,
                              progress: _pace == 'Normal' ? .82 : .42,
                              description: _pace == 'Normal'
                                  ? 'Good speaking rhythm'
                                  : 'Slow down slightly',
                            ),
                            _LiveMetric(
                              label: 'Posture',
                              value: setup.monitorBodyLanguage
                                  ? _posture
                                  : 'Off',
                              icon: Icons.accessibility_new_rounded,
                              good: _posture == 'Good',
                              enabled: setup.monitorBodyLanguage,
                              progress: _posture == 'Good' ? .9 : .48,
                              description: _posture == 'Good'
                                  ? 'Upper body is steady'
                                  : 'Straighten your posture',
                            ),
                            _LiveMetric(
                              label: 'Camera Attention',
                              value: setup.monitorCameraAttention
                                  ? '$_attention%'
                                  : 'Off',
                              icon: Icons.center_focus_strong,
                              good: _attention >= 70,
                              enabled: setup.monitorCameraAttention,
                              progress: _attention / 100,
                              description: _attention >= 70
                                  ? 'Strong camera focus'
                                  : 'Look toward the camera',
                            ),
                            _LiveMetric(
                              key: const Key('filler_metric'),
                              label: 'Fillers Detected',
                              value: setup.monitorFillers
                                  ? '$_fillerTotal'
                                  : 'Off',
                              icon: Icons.chat_bubble_outline,
                              good: _fillerTotal == 0,
                              enabled: setup.monitorFillers,
                              progress: (1 - (_fillerTotal / 8)).clamp(0, 1),
                              description: _fillerTotal == 0
                                  ? 'No fillers detected'
                                  : 'Try a quiet pause',
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('restart_session'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Color(0xFF57718C),
                                  ),
                                ),
                                onPressed:
                                    _restarting ||
                                        _ending ||
                                        _changingMicrophone
                                    ? null
                                    : _confirmRestart,
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(
                                  _restarting ? 'Restarting...' : 'Restart',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                key: const Key('end_session'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: errorRed,
                                ),
                                onPressed:
                                    _restarting ||
                                        _ending ||
                                        _changingMicrophone
                                    ? null
                                    : _confirmEnd,
                                icon: const Icon(Icons.stop_rounded),
                                label: const Text('End Session'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_countdown != null)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0x99071526),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Get ready',
                          style: TextStyle(color: Colors.white, fontSize: 22),
                        ),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            '$_countdown',
                            key: const Key('readiness_countdown'),
                            style: const TextStyle(
                              color: accentTeal,
                              fontSize: 88,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const Key('cancel_countdown'),
                          onPressed: _cancelCountdown,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_transcribing)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xD9071526),
                  child: Center(
                    child: Container(
                      key: const Key('transcribing_rehearsal'),
                      margin: const EdgeInsets.all(28),
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF102A43),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFF2D5678)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: accentTeal),
                          SizedBox(height: 20),
                          Text(
                            'Transcribing rehearsal...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Keep this screen open while SpeakSync processes your audio.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFB9C9D9),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraStage extends StatelessWidget {
  const _CameraStage({
    required this.controller,
    required this.cameraReady,
    required this.cameraEnabled,
    required this.cameraStatus,
    required this.recording,
  });

  final CameraController? controller;
  final bool cameraReady;
  final bool cameraEnabled;
  final String cameraStatus;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final activeController = controller;
    if (cameraReady &&
        activeController != null &&
        activeController.value.isInitialized) {
      return ValueListenableBuilder<CameraValue>(
        valueListenable: activeController,
        builder: (context, value, child) {
          if (!cameraEnabled) {
            return _buildFrame(
              aspectRatio: 9 / 16,
              preview: const _CameraOffView(),
              showRecordingBadge: false,
            );
          }

          final previewAspectRatio = _previewAspectRatio(value);
          final cameraFeed = kIsWeb
              ? activeController.buildPreview()
              : CameraPreview(activeController);
          final portraitPreview = FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewAspectRatio * 1000,
              height: 1000,
              child: cameraFeed,
            ),
          );
          return _buildFrame(
            aspectRatio: 9 / 16,
            preview: portraitPreview,
            showRecordingBadge: recording,
          );
        },
      );
    }

    return _buildFrame(
      aspectRatio: 9 / 16,
      showRecordingBadge: false,
      preview: ColoredBox(
        color: const Color(0xFF102A46),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_outlined,
                  color: Color(0xFF9EB1C7),
                  size: 52,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Camera preview will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  cameraStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9EB1C7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _previewAspectRatio(CameraValue value) {
    // Browser webcams already report the orientation in their raw aspect
    // ratio. Inverting that feed to match the narrow browser window crops it
    // heavily and looks like digital zoom.
    if (kIsWeb) {
      return value.aspectRatio.isFinite && value.aspectRatio > 0
          ? value.aspectRatio
          : 4 / 3;
    }

    final orientation = value.isRecordingVideo
        ? value.recordingOrientation ?? value.deviceOrientation
        : value.previewPauseOrientation ??
              value.lockedCaptureOrientation ??
              value.deviceOrientation;
    final isLandscape =
        orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    final ratio = isLandscape ? value.aspectRatio : 1 / value.aspectRatio;
    return ratio.isFinite && ratio > 0 ? ratio : 3 / 4;
  }

  Widget _buildFrame({
    required double aspectRatio,
    required Widget preview,
    bool showRecordingBadge = true,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Semantics(
            label: 'Live rehearsal camera. Keep your face and waist visible.',
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF071526),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF294966)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: const Color(0xFF071526),
                    child: SizedBox.expand(child: preview),
                  ),
                  if (showRecordingBadge)
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 9),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraOffView extends StatelessWidget {
  const _CameraOffView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF071526),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_rounded,
              color: Color(0xFF9EB1C7),
              size: 48,
            ),
            SizedBox(height: 10),
            Text(
              'Camera off',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicrophoneLevelIndicator extends StatelessWidget {
  const _MicrophoneLevelIndicator({required this.enabled, required this.level});

  final bool enabled;
  final double level;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? successGreen : const Color(0xFF8A99A8);
    return Semantics(
      label: enabled ? 'Microphone active' : 'Microphone inactive',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xD9142535),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.mic_rounded : Icons.mic_off_rounded,
              color: color,
              size: 15,
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(5, (index) {
                  // A volume meter: each bar has a higher input threshold.
                  final movement = enabled
                      ? (level * 5 - index).clamp(0.0, 1.0)
                      : 0.0;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: 2.5,
                    height: 4 + (movement * 12),
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              enabled ? 'Mic active' : 'Mic off',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaControls extends StatelessWidget {
  const _MediaControls({
    required this.microphoneEnabled,
    required this.cameraEnabled,
    required this.onMicrophonePressed,
    required this.onCameraPressed,
  });

  final bool microphoneEnabled;
  final bool cameraEnabled;
  final VoidCallback onMicrophonePressed;
  final VoidCallback onCameraPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF102A46),
      elevation: 10,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF57718C)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MediaControlButton(
              key: const Key('toggle_microphone'),
              enabled: microphoneEnabled,
              enabledIcon: Icons.mic_rounded,
              disabledIcon: Icons.mic_off_rounded,
              enabledLabel: 'Turn microphone off',
              disabledLabel: 'Turn microphone on',
              onPressed: onMicrophonePressed,
            ),
            const SizedBox(width: 6),
            _MediaControlButton(
              key: const Key('toggle_camera'),
              enabled: cameraEnabled,
              enabledIcon: Icons.videocam_rounded,
              disabledIcon: Icons.videocam_off_rounded,
              enabledLabel: 'Turn camera off',
              disabledLabel: 'Turn camera on',
              onPressed: onCameraPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaControlButton extends StatelessWidget {
  const _MediaControlButton({
    super.key,
    required this.enabled,
    required this.enabledIcon,
    required this.disabledIcon,
    required this.enabledLabel,
    required this.disabledLabel,
    required this.onPressed,
  });

  final bool enabled;
  final IconData enabledIcon;
  final IconData disabledIcon;
  final String enabledLabel;
  final String disabledLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = enabled ? enabledLabel : disabledLabel;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: enabled ? const Color(0xFF245B86) : errorRed,
            foregroundColor: Colors.white,
            minimumSize: const Size(46, 46),
          ),
          icon: Icon(enabled ? enabledIcon : disabledIcon),
        ),
      ),
    );
  }
}

class _AlertTestButton extends StatelessWidget {
  const _AlertTestButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD8E5F1),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        visualDensity: VisualDensity.compact,
        side: const BorderSide(color: Color(0xFF45627E)),
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
    required this.enabled,
    required this.progress,
    required this.description,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool good;
  final bool enabled;
  final double progress;
  final String description;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? const Color(0xFF8A99A8)
        : good
        ? const Color(0xFF5FE3B3)
        : const Color(0xFFFFA24C);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF102A46),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF294966)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC3D0DE),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  enabled ? '● LIVE' : 'OFF',
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            enabled ? description : 'Monitoring disabled',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF91A5BA), fontSize: 9.5),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: enabled ? progress : 0,
              minHeight: 4,
              color: color,
              backgroundColor: const Color(0xFF294966),
            ),
          ),
        ],
      ),
    );
  }
}

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, this.transcriptionErrorMessage});

  final String? transcriptionErrorMessage;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer(AppTimingScope.of(context).analysisDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ReportScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
                  const Text(
                    'Preparing your performance report...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: navy,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
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
                  if (widget.transcriptionErrorMessage != null) ...[
                    InfoBanner(
                      icon: Icons.warning_amber_rounded,
                      title: 'Transcript unavailable',
                      message: widget.transcriptionErrorMessage!,
                      color: warningOrange,
                    ),
                    const SizedBox(height: 20),
                  ],
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
  bool _saving = false;

  Future<void> _saveOrView() async {
    if (_saved) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MainShell(initialIndex: 1),
        ),
        (route) => false,
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await AppStateScope.of(
        context,
        listen: false,
      ).saveCurrentReport();
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Session saved to Progress.'
                : 'This session is already in Progress.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save this session: $error')),
      );
    }
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
    final fillerAnalysis = report.fillerAnalysis;
    final fillers = fillerAnalysis.counts.entries
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
                SpeakingPaceCard(pace: report.speakingPace),
                const SizedBox(height: 10),
                FillerFrequencyCard(analysis: fillerAnalysis),
                const SizedBox(height: 10),
                _ScoreRow(
                  icon: Icons.accessibility_new_rounded,
                  label: 'Posture',
                  score: report.postureScore,
                  status: report.postureScore >= 80
                      ? 'Good'
                      : 'Needs Correction',
                ),
                const SizedBox(height: 10),
                _ScoreRow(
                  icon: Icons.center_focus_strong_rounded,
                  label: 'Camera Attention',
                  score: report.attentionScore,
                  status: '${report.attentionScore}%',
                ),
                const SizedBox(height: 28),
                const SectionHeader('Filler frequencies'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: fillers.isEmpty
                        ? Text(
                            fillerAnalysis.hasTranscript
                                ? 'No listed filler words were found in the transcript.'
                                : 'Filler detection requires a transcript.',
                            style: const TextStyle(
                              color: Color(0xFF617085),
                              height: 1.45,
                            ),
                          )
                        : Column(
                            children: fillers
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 7,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 17,
                                          backgroundColor: warningOrange
                                              .withValues(alpha: .1),
                                          foregroundColor: warningOrange,
                                          child: Text(
                                            '${entry.value}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            entry.key,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          entry.value == 1
                                              ? '1 time'
                                              : '${entry.value} times',
                                          style: const TextStyle(
                                            color: Color(0xFF617085),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
                if (report.textTranscript != null) ...[
                  const SizedBox(height: 28),
                  const SectionHeader('Text transcript'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        report.textTranscript!,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          height: 1.5,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
                if (report.referenceScript?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 28),
                  ScriptComparisonSummary(
                    documentName: report.referenceDocumentName,
                    omittedPortions: report.omittedScriptPortions,
                    addedPortions: report.addedTranscriptPortions,
                    differentlyDeliveredPortions:
                        report.differentlyDeliveredPortions,
                  ),
                ],
                const SizedBox(height: 28),
                const SectionHeader('Recommended posture'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      report.recommendedPosture,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        height: 1.5,
                        fontSize: 15,
                      ),
                    ),
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
                  onPressed: _saving ? null : _saveOrView,
                  icon: Icon(
                    _saved
                        ? Icons.insights_rounded
                        : Icons.bookmark_add_outlined,
                  ),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : _saved
                        ? 'View Progress'
                        : 'Save to Progress',
                  ),
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
  });
  final IconData icon;
  final String label;
  final int score;
  final String status;

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
