import 'dart:async';
import 'dart:io';

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
import '../services/live_filler_feedback_service.dart';
import '../services/internet_connectivity_service.dart';
import '../services/rehearsal_audio_recorder.dart';
import '../services/screen_awake_service.dart';
import '../services/ambient_noise_service.dart';
import '../services/camera_framing.dart';
import '../services/camera_framing_warning_controller.dart';
import '../services/camera_framing_summary.dart';
import '../widgets/live_feedback_overlay.dart';
import '../services/posture_analysis.dart';
import '../services/face_attention.dart';
import '../services/posture_landmarker_service.dart';
import '../services/posture_performance.dart';
import '../services/posture_warning_controller.dart';
import '../services/script_comparison_service.dart';
import '../services/speech_document_service.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';
import '../widgets/speaking_pace_card.dart';
import '../widgets/filler_frequency_card.dart';
import '../widgets/pose_landmark_overlay.dart';
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
    if (_isExtractingDocument) return;
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DeviceCheckScreen()));
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
      if (document == null || !mounted || !_requiresReferenceScript) return;
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
                                      : 'Choose PDF, DOCX, or TXT',
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
                                      key: const Key('replace_speech_document'),
                                      tooltip: 'Replace document',
                                      onPressed: _isExtractingDocument
                                          ? null
                                          : _chooseSpeechDocument,
                                      icon: const Icon(
                                        Icons.swap_horiz_rounded,
                                      ),
                                    ),
                                    IconButton(
                                      key: const Key('remove_speech_document'),
                                      tooltip: 'Remove document',
                                      onPressed: _isExtractingDocument
                                          ? null
                                          : _removeSpeechDocument,
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
                    'Choose what to monitor during rehearsal.',
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
                          subtitle: const Text(
                            'Estimated head direction, not eye contact (Android)',
                          ),
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
            if (setup.monitorCameraAttention) 'Head direction',
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

double _cameraFrameWidth(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  if (size.width <= size.height) return 430;
  final usableHeight =
      size.height -
      MediaQuery.paddingOf(context).vertical -
      kToolbarHeight -
      80;
  return (usableHeight.clamp(140.0, 405.0) * 16 / 9).clamp(0.0, 720.0);
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.busy,
    required this.starting,
    required this.onReady,
    required this.onDeviceCheck,
    required this.noiseChecking,
    required this.noiseResult,
  });

  final bool busy;
  final bool starting;
  final VoidCallback onReady;
  final VoidCallback onDeviceCheck;
  final bool noiseChecking;
  final AmbientNoiseResult? noiseResult;

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
            'Rehearsal has not started. Noise samples are not saved or uploaded.',
            style: TextStyle(color: accentTeal, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _AmbientNoiseStatus(checking: noiseChecking, result: noiseResult),
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

class _AmbientNoiseStatus extends StatelessWidget {
  const _AmbientNoiseStatus({required this.checking, required this.result});

  final bool checking;
  final AmbientNoiseResult? result;

  @override
  Widget build(BuildContext context) {
    final level = result?.level;
    final firstCheck = checking && result == null;
    final label = firstCheck
        ? 'Checking...'
        : switch (level) {
            AmbientNoiseLevel.quiet => 'Quiet',
            AmbientNoiseLevel.moderate => 'Moderate',
            AmbientNoiseLevel.noisy => 'Noisy',
            null => result == null ? 'Not checked' : 'Unavailable',
          };
    final message = firstCheck
        ? 'Stay silent for about 3 seconds while we listen to the room.'
        : switch (level) {
            AmbientNoiseLevel.quiet => 'Quiet enough to begin.',
            AmbientNoiseLevel.moderate =>
              'Some background noise. A quieter spot may help.',
            AmbientNoiseLevel.noisy =>
              'Try a quieter place. You can still continue.',
            null =>
              result?.message ?? 'Check your surroundings before starting.',
          };
    final color = firstCheck || level == AmbientNoiseLevel.quiet
        ? accentTeal
        : warningOrange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.graphic_eq_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ambient noise: $label',
                key: const Key('ambient_noise_status'),
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(message, style: const TextStyle(color: Color(0xFFBDD0E2))),
        const SizedBox(height: 6),
        const Text(
          'Updates automatically before rehearsal. Stay silent to check the room.',
          style: TextStyle(color: Color(0xFFBDD0E2), fontSize: 12),
        ),
      ],
    );
  }
}

class RehearsalScreen extends StatefulWidget {
  const RehearsalScreen({
    super.key,
    this.internetConnectivity,
    this.audioRecorder,
    this.ambientNoiseService,
    this.liveTranscriptionService,
    this.liveChunkTemporaryDirectory,
    this.liveFeedbackFactory,
    this.screenAwakeController,
    this.postureLandmarker,
    this.postureThresholds = const PostureThresholds(),
    this.posturePerformanceConfig = const PosturePerformanceConfig(),
  });

  final InternetConnectivity? internetConnectivity;
  final RehearsalAudioRecorder? audioRecorder;
  final AmbientNoiseService? ambientNoiseService;
  final GroqTranscriptionService? liveTranscriptionService;
  final Future<Directory> Function()? liveChunkTemporaryDirectory;
  final ScreenAwakeController? screenAwakeController;
  final PostureLandmarker? postureLandmarker;
  final PostureThresholds postureThresholds;
  final PosturePerformanceConfig posturePerformanceConfig;
  final LiveFillerFeedbackService Function(
    GroqTranscriptionService,
    void Function(String)?,
    void Function(LivePaceUpdate)?,
    Duration,
  )?
  liveFeedbackFactory;

  @override
  State<RehearsalScreen> createState() => _RehearsalScreenState();
}

class _RehearsalScreenState extends State<RehearsalScreen> {
  Timer? _timer;
  Timer? _alertTimer;
  Timer? _performanceAlertTimer;
  Timer? _countdownTimer;
  int? _countdown;
  bool _hasStarted = false;
  bool _starting = false;
  bool _checkingReadiness = false;
  int _readinessGeneration = 0;
  bool _leaving = false;
  AppLifecycleListener? _readinessLifecycle;
  late final InternetConnectivity _internetConnectivity;
  late final ScreenAwakeController _screenAwakeController;
  bool _screenAwake = false;
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
  String? _livePaceLabel;
  double? _livePaceWpm;
  int? _lastLivePaceUpdateSeconds;
  // Display freshness only: final WPM and live rolling-average math are unchanged.
  static const _livePaceValidity = Duration(seconds: 30);
  String _posture = 'Position yourself';
  bool _postureStreamActive = false;
  bool _postureLandmarkerInitialized = false;
  bool _visualStarting = false;
  int _lastNativeFrameTimestamp = 0;
  int _postureGeneration = 0;
  late final PostureLandmarker _postureLandmarker;
  late final PostureSessionTracker _postureTracker;
  late final CameraFramingTracker _cameraFramingTracker;
  late final CameraFramingSummaryTracker _framingSummary;
  late final PostureWarningController _postureWarningController;
  final CameraFramingWarningController _framingWarningController =
      CameraFramingWarningController();
  final PostureWarningController _faceMissingWarningController =
      PostureWarningController();
  final ValueNotifier<CameraFramingState?> _framingWarning = ValueNotifier(
    null,
  );
  final ValueNotifier<PostureWarningType?> _faceMissingWarning = ValueNotifier(
    null,
  );
  late final PoseFrameGate _postureFrameGate;
  final PosePerformanceDiagnostics _postureDiagnostics =
      PosePerformanceDiagnostics();
  Timer? _postureDiagnosticsTimer;
  final ValueNotifier<String> _postureStatus = ValueNotifier(
    'Position yourself',
  );
  final ValueNotifier<PoseOverlayFrame?> _poseOverlayFrame = ValueNotifier(
    null,
  );
  final ValueNotifier<bool> _showPoseLandmarks = ValueNotifier(false);
  final ValueNotifier<CameraFramingState> _cameraFramingStatus = ValueNotifier(
    CameraFramingState.unavailable,
  );
  final ValueNotifier<PostureWarningType?> _postureWarning = ValueNotifier(
    null,
  );
  final Stopwatch _postureClock = Stopwatch();
  final FaceAttentionTracker _faceTracker = FaceAttentionTracker();
  final FaceAttentionWarningController _faceWarningController =
      FaceAttentionWarningController();
  final ValueNotifier<FaceAttentionState> _faceStatus = ValueNotifier(
    FaceAttentionState.unavailable,
  );
  final ValueNotifier<bool> _faceWarning = ValueNotifier(false);
  Timer? _faceWatchdog;
  final Map<String, int> _gestureCounts = {};
  late final RehearsalAudioRecorder _audioRecorder;
  GroqTranscriptionService? _liveTranscriber;
  LiveFillerFeedbackService? _liveFillerFeedback;
  StreamSubscription<Uint8List>? _liveChunksSubscription;
  late final AmbientNoiseService _ambientNoise;
  AmbientNoiseResult? _noiseResult;
  bool _noiseChecking = false;
  bool _noiseAllowed = false;
  bool _previewInForeground = true;
  bool _cameraPreparationComplete = false;
  int _noiseGeneration = 0;
  Timer? _noiseRefreshTimer;
  final _microphoneLevel = ValueNotifier<double>(0);
  StreamSubscription<double>? _levelSubscription;
  final _transcriptionService = GroqTranscriptionService(
    apiKey: AppConfig.groqApiKey,
    prompt: GroqTranscriptionService.fillerAwarePrompt,
  );
  String? _alert;
  String? _performanceAlert;
  Color _alertColor = primaryBlue;
  IconData _alertIcon = Icons.info_outline_rounded;

  @override
  void initState() {
    super.initState();
    _audioRecorder = widget.audioRecorder ?? RehearsalAudioRecorder();
    _ambientNoise = widget.ambientNoiseService ?? AmbientNoiseService();
    _internetConnectivity =
        widget.internetConnectivity ?? const InternetConnectivityService();
    _screenAwakeController =
        widget.screenAwakeController ?? const ScreenAwakeService();
    _postureLandmarker =
        widget.postureLandmarker ?? MethodChannelPostureLandmarker();
    _postureTracker = PostureSessionTracker(
      thresholds: widget.postureThresholds,
    );
    _cameraFramingTracker = CameraFramingTracker();
    _framingSummary = CameraFramingSummaryTracker(
      maximumSampleGap: widget.postureThresholds.maximumSampleGap,
    );
    _postureWarningController = PostureWarningController();
    _postureFrameGate = PoseFrameGate(
      minimumInterval: widget.posturePerformanceConfig.analysisInterval,
    );
    _readinessLifecycle = AppLifecycleListener(
      onInactive: () {
        if (!_hasStarted && !_starting) _cancelCountdown(resumeNoise: false);
      },
      onPause: () {
        if (_hasStarted) {
          unawaited(_disableScreenAwake());
          unawaited(_stopPostureAnalysis(closeLandmarker: false));
        }
        if (!_hasStarted) {
          _previewInForeground = false;
          unawaited(_stopAmbientNoise());
        }
      },
      onResume: () {
        _previewInForeground = true;
        if (_hasStarted && !_ending) {
          unawaited(_enableScreenAwake());
          unawaited(_startPostureAnalysis());
        }
        unawaited(_resumeAmbientNoise());
      },
    );
    // Avoid overlapping camera and microphone permission prompts.
    unawaited(
      _prepareCamera().then((_) {
        _cameraPreparationComplete = true;
        return _resumeAmbientNoise();
      }),
    );
  }

  bool get _canSampleNoise =>
      mounted &&
      !_leaving &&
      !_hasStarted &&
      !_starting &&
      !_checkingReadiness &&
      _countdown == null &&
      _previewInForeground &&
      _cameraPreparationComplete &&
      ModalRoute.of(context)?.isCurrent != false;

  Future<void> _stopAmbientNoise() {
    _noiseAllowed = false;
    _noiseGeneration++;
    _noiseRefreshTimer?.cancel();
    _postureDiagnosticsTimer?.cancel();
    return _ambientNoise.stop();
  }

  Future<void> _resumeAmbientNoise() async {
    if (!_canSampleNoise) return;
    if (_noiseChecking) await _stopAmbientNoise();
    _noiseRefreshTimer?.cancel();
    if (!_canSampleNoise) return;
    _noiseAllowed = true;
    await _checkAmbientNoise();
  }

  Future<void> _checkAmbientNoise() async {
    if (!_canSampleNoise || _noiseChecking || !_noiseAllowed) {
      return;
    }
    final generation = _noiseGeneration;
    setState(() {
      _noiseChecking = true;
    });
    final result = await _ambientNoise.check();
    if (!mounted || _leaving) return;
    setState(() {
      _noiseChecking = false;
      // An interrupted refresh must not replace a completed Noisy result
      // just before the continue-anyway confirmation is evaluated.
      if (generation == _noiseGeneration) _noiseResult = result;
    });
    if (_canSampleNoise && _noiseAllowed && generation == _noiseGeneration) {
      _noiseRefreshTimer = Timer(
        result.level == null
            ? _ambientNoise.config.errorRetryDelay
            : _ambientNoise.config.refreshDelay,
        () => unawaited(_checkAmbientNoise()),
      );
    }
  }

  void _cancelCountdown({bool resumeNoise = true}) {
    _readinessGeneration++;
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _countdown = null;
        _checkingReadiness = false;
      });
    }
    if (resumeNoise) unawaited(_resumeAmbientNoise());
  }

  Future<void> _beginCountdown() async {
    if (_hasStarted || _starting || _checkingReadiness || _countdown != null) {
      return;
    }
    final generation = ++_readinessGeneration;
    setState(() => _checkingReadiness = true);
    await _stopAmbientNoise();
    if (!mounted || _leaving || generation != _readinessGeneration) return;
    if (_noiseResult?.level == AmbientNoiseLevel.noisy) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Noisy environment'),
          content: const Text(
            'Background noise may affect your transcript. Move somewhere quieter, or continue anyway.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              key: const Key('continue_noisy_rehearsal'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue anyway'),
            ),
          ],
        ),
      );
      if (!mounted || _leaving) return;
      if (generation != _readinessGeneration) {
        unawaited(_resumeAmbientNoise());
        return;
      }
      if (proceed != true) {
        setState(() => _checkingReadiness = false);
        unawaited(_resumeAmbientNoise());
        return;
      }
    }
    final online = await _checkInternet();
    if (!mounted || _leaving || generation != _readinessGeneration) return;
    setState(() => _checkingReadiness = false);
    if (!online) {
      unawaited(_resumeAmbientNoise());
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
    _resetPostureSession();
    _postureClock
      ..reset()
      ..start();
    setState(() {
      _elapsedSeconds = 0;
      _hasStarted = true;
      _starting = false;
    });
    unawaited(_enableScreenAwake());
    unawaited(_startPostureAnalysis());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _handleTimerTick(),
    );
  }

  void _leavePreview() {
    if (_hasStarted || _leaving) return;
    _leaving = true;
    _cancelCountdown();
    unawaited(_disableScreenAwake());
    Navigator.of(context).pop();
  }

  Future<void> _enableScreenAwake() async {
    if (_screenAwake) return;
    try {
      await _screenAwakeController.enable();
      _screenAwake = true;
    } catch (_) {
      // Screen timeout is non-critical; rehearsal must keep running.
    }
  }

  Future<void> _disableScreenAwake() async {
    _screenAwake = false;
    try {
      await _screenAwakeController.disable();
    } catch (_) {
      // Never block navigation or cleanup on a platform wakelock error.
    }
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
    // An injected transcriber is used by deterministic widget tests. Normal
    // app runs still require GROQ_API_KEY before recording can begin.
    if (!AppConfig.hasGroqApiKey && widget.liveTranscriptionService == null) {
      const message = 'Groq transcription is not configured on this device.';
      if (!mounted) return;
      setState(() {
        _recording = false;
        _audioRecordingError = message;
      });
      return;
    }
    try {
      final setup = AppStateScope.of(context, listen: false).currentSetup!;
      final useLiveChunks =
          setup.enableLiveFeedback &&
          (setup.monitorFillers || setup.monitorPace);
      await _audioRecorder.start(enableLiveChunks: useLiveChunks);
      if (!mounted || _leaving) return;
      if (useLiveChunks) _startLiveFillerFeedback();
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

  void _startLiveFillerFeedback() {
    try {
      final setup = AppStateScope.of(context, listen: false).currentSetup!;
      final transcriber =
          widget.liveTranscriptionService ??
          GroqTranscriptionService(
            apiKey: AppConfig.groqApiKey,
            timeout: const Duration(seconds: 8),
          );
      void onFiller(String word) {
        if (!mounted ||
            !_hasStarted ||
            _ending ||
            _paused ||
            _restarting ||
            !_microphoneEnabled) {
          return;
        }
        _showPerformanceAlert('Filler detected: $word');
      }

      void onPace(LivePaceUpdate update) {
        if (!mounted ||
            !_hasStarted ||
            _ending ||
            _paused ||
            _restarting ||
            !_microphoneEnabled) {
          return;
        }
        setState(() {
          _livePaceLabel = update.classification;
          _livePaceWpm = update.wordsPerMinute;
          _lastLivePaceUpdateSeconds = _elapsedSeconds;
        });
      }

      final fillerCallback = setup.monitorFillers ? onFiller : null;
      final paceCallback = setup.monitorPace ? onPace : null;

      final feedback =
          widget.liveFeedbackFactory?.call(
            transcriber,
            fillerCallback,
            paceCallback,
            _audioRecorder.chunkDuration,
          ) ??
          LiveFillerFeedbackService(
            transcriber: transcriber,
            temporaryDirectory: widget.liveChunkTemporaryDirectory,
            onFiller: fillerCallback,
            onPace: paceCallback,
            chunkDuration: _audioRecorder.chunkDuration,
          );
      _liveTranscriber = transcriber;
      _liveFillerFeedback = feedback;
      _liveChunksSubscription = _audioRecorder.chunks.listen(feedback.accept);
    } catch (_) {
      // Live feedback is optional. The full recording remains available.
      _liveTranscriber?.dispose();
      _liveTranscriber = null;
      _liveFillerFeedback = null;
    }
  }

  Future<void> _stopLiveFillerFeedback() async {
    final feedback = _liveFillerFeedback;
    final transcriber = _liveTranscriber;
    final subscription = _liveChunksSubscription;
    _liveFillerFeedback = null;
    _liveTranscriber = null;
    _liveChunksSubscription = null;
    _livePaceLabel = null;
    _livePaceWpm = null;
    _lastLivePaceUpdateSeconds = null;
    await subscription?.cancel();
    try {
      await feedback?.stop();
    } finally {
      transcriber?.dispose();
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
      final lastPace = _lastLivePaceUpdateSeconds;
      if (lastPace != null &&
          _elapsedSeconds - lastPace >= _livePaceValidity.inSeconds) {
        _livePaceLabel = null;
        _livePaceWpm = null;
        _lastLivePaceUpdateSeconds = null;
      }
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

  void _showPerformanceAlert(String message) {
    _performanceAlertTimer?.cancel();
    setState(() => _performanceAlert = message);
    _performanceAlertTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _performanceAlert = null);
    });
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
        // `max` sent multi-megapixel YUV buffers across the platform channel
        // for each pose request. `high` keeps a sharp preview while avoiding
        // that unnecessary bandwidth on physical phones.
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
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

  Future<void> _startPostureAnalysis() async {
    if (!mounted || _ending || _paused || _visualStarting) return;
    final setup = AppStateScope.of(context, listen: false).currentSetup;
    if (!shouldRunPostureAnalysis(
      monitoringEnabled:
          setup?.monitorBodyLanguage == true ||
          setup?.monitorCameraAttention == true,
      rehearsalStarted: _hasStarted,
      cameraReady: _cameraReady,
      cameraEnabled: _cameraEnabled,
    )) {
      return;
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    _visualStarting = true;
    final generation = _postureGeneration;

    try {
      final landmarker = _postureLandmarker;
      if (landmarker is CameraLandmarkerMonitoring) {
        await (landmarker as CameraLandmarkerMonitoring)
            .configureMonitoring(
              pose: setup?.monitorBodyLanguage == true,
              face: setup?.monitorCameraAttention == true,
            )
            .timeout(const Duration(seconds: 5));
      }
      if (!_postureLandmarkerInitialized) {
        await _postureLandmarker.initialize().timeout(
          const Duration(seconds: 5),
        );
        _postureLandmarkerInitialized = true;
      }
      if (!mounted) {
        await _postureLandmarker.close().timeout(const Duration(seconds: 3));
        _postureLandmarkerInitialized = false;
        return;
      }
      if (generation != _postureGeneration ||
          _ending ||
          _paused ||
          !_cameraEnabled) {
        return;
      }
      if (!controller.value.isStreamingImages) {
        await controller.startImageStream(_handlePostureCameraImage);
      }
      if (!mounted || generation != _postureGeneration) {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
        return;
      }
      _postureStreamActive = true;
      _faceWatchdog?.cancel();
      _faceWatchdog = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!mounted || _ending || !_postureStreamActive) return;
        _faceTracker.expire(_postureClock.elapsed);
        _faceStatus.value = _faceTracker.status;
        if (_faceTracker.status == FaceAttentionState.unavailable) {
          _faceWarningController.reset();
          _faceWarning.value = false;
        }
      });
      _postureDiagnostics.start();
      if (kDebugMode) {
        _postureDiagnosticsTimer?.cancel();
        _postureDiagnosticsTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => debugPrint(
            _postureDiagnostics.summary(
              skippedFrames: _postureFrameGate.skippedFrames,
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('Posture analysis unavailable: $error');
      if (!mounted) return;
      _postureStreamActive = false;
      _posture = 'Unavailable';
      _postureStatus.value = _posture;
      _poseOverlayFrame.value = null;
      _interruptFaceAnalysis();
    } finally {
      _visualStarting = false;
      if (mounted &&
          !_ending &&
          !_paused &&
          _cameraEnabled &&
          generation != _postureGeneration) {
        unawaited(_startPostureAnalysis());
      }
    }
  }

  Future<void> _stopPostureAnalysis({bool closeLandmarker = false}) async {
    _postureGeneration++;
    _postureStreamActive = false;
    _faceWatchdog?.cancel();
    _faceWatchdog = null;
    _interruptFaceAnalysis();
    if (kDebugMode && _postureDiagnostics.processedFrames > 0) {
      debugPrint(
        _postureDiagnostics.summary(
          skippedFrames: _postureFrameGate.skippedFrames,
        ),
      );
    }
    _postureFrameGate.reset();
    _postureDiagnostics.reset();
    _postureDiagnosticsTimer?.cancel();
    _postureDiagnosticsTimer = null;
    _poseOverlayFrame.value = null;
    _showPoseLandmarks.value = false;
    _resetPostureWarning();
    _cameraFramingTracker.reset();
    _framingSummary.interrupt();
    _cameraFramingStatus.value = CameraFramingState.unavailable;
    _framingWarningController.reset();
    _framingWarning.value = null;
    final controller = _cameraController;
    if (controller?.value.isStreamingImages == true) {
      try {
        await controller!.stopImageStream();
      } catch (_) {
        // Camera cleanup is best-effort and must never block the rehearsal.
      }
    }
    // Configuration may have loaded Face even when Pose initialization failed.
    if (closeLandmarker) {
      try {
        await _postureLandmarker.close().timeout(const Duration(seconds: 3));
      } catch (_) {
        // Native cleanup is best-effort.
      }
      _postureLandmarkerInitialized = false;
    }
  }

  void _resetPostureSession() {
    _faceTracker.reset();
    _faceWarningController.reset();
    _faceStatus.value = FaceAttentionState.unavailable;
    _faceWarning.value = false;
    _postureTracker.reset();
    _cameraFramingTracker.reset();
    _framingSummary.reset();
    _framingWarningController.reset();
    _framingWarning.value = null;
    _faceMissingWarningController.reset();
    _faceMissingWarning.value = null;
    _postureWarningController.reset();
    _postureFrameGate.reset();
    _postureDiagnostics.reset();
    _poseOverlayFrame.value = null;
    _showPoseLandmarks.value = false;
    _cameraFramingStatus.value = CameraFramingState.unavailable;
    _postureWarning.value = null;
    _posture = 'Position yourself';
    _postureStatus.value = _posture;
  }

  void _resetPostureWarning() {
    final update = _postureWarningController.reset();
    if (update.changed || _postureWarning.value != null) {
      _postureWarning.value = null;
    }
  }

  void _handlePostureCameraImage(CameraImage image) {
    if (!_postureStreamActive || _paused || _ending || !_cameraEnabled) {
      return;
    }
    if (!_postureFrameGate.tryAcquire(_postureClock.elapsed)) return;
    final generation = _postureGeneration;
    unawaited(_analyzePostureFrame(image, generation));
  }

  void _interruptFaceAnalysis() {
    _faceTracker.interrupt();
    _faceMissingWarningController.reset();
    _faceMissingWarning.value = null;
    _faceWarningController.reset();
    _faceStatus.value = FaceAttentionState.unavailable;
    _faceWarning.value = false;
  }

  Future<void> _analyzePostureFrame(CameraImage image, int generation) async {
    try {
      final controller = _cameraController;
      if (controller == null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final timestamp = now <= _lastNativeFrameTimestamp
          ? _lastNativeFrameTimestamp + 1
          : now;
      _lastNativeFrameTimestamp = timestamp;
      final sampleTime = _postureClock.elapsed;
      final result = await _postureLandmarker
          .analyze(
            image: image,
            rotationDegrees: cameraImageRotationDegrees(
              controller.description,
              controller.value.deviceOrientation,
            ),
            mirrorHorizontally:
                controller.description.lensDirection ==
                CameraLensDirection.front,
            timestampMilliseconds: timestamp,
            maximumInferenceDimension:
                widget.posturePerformanceConfig.maximumInferenceDimension,
          )
          .timeout(const Duration(seconds: 3));
      if (!mounted ||
          generation != _postureGeneration ||
          !_postureStreamActive ||
          _ending) {
        return;
      }
      _postureDiagnostics.recordProcessed(
        processingDuration: result.processingDuration,
        conversionDuration: result.conversionDuration,
        inferenceDuration: result.inferenceDuration,
      );
      final setup = AppStateScope.of(context, listen: false).currentSetup!;
      if (setup.monitorCameraAttention) {
        final fresh =
            _postureClock.elapsed - sampleTime <=
            _faceTracker.thresholds.maximumSampleGap;
        final faceState = _faceTracker.addFrame(
          fresh ? result.face : null,
          sampleTime,
        );
        _faceStatus.value = faceState;
        _faceMissingWarning.value = _faceMissingWarningController
            .update(
              faceState == FaceAttentionState.unavailable
                  ? PostureWarningSignal.unavailable
                  : PostureWarningSignal.good,
              sampleTime,
            )
            .warning;
        _faceWarning.value = _faceWarningController.update(
          faceState,
          sampleTime,
          liveAlertsEnabled: setup.enableLiveFeedback,
        );
      }
      if (!setup.monitorBodyLanguage) return;
      final landmarks = result.landmarks;
      _poseOverlayFrame.value = landmarks == null
          ? null
          : PoseOverlayFrame(
              landmarks: landmarks,
              imageWidth: result.inferenceWidth,
              imageHeight: result.inferenceHeight,
              mirrorHorizontally:
                  controller.description.lensDirection ==
                  CameraLensDirection.front,
            );
      final frameClassification = _postureTracker.analyzer
          .analyze(landmarks)
          .classification;
      final status = _postureTracker.addFrame(landmarks, _postureClock.elapsed);
      final label = switch (status) {
        PostureDisplayStatus.good => 'Good',
        PostureDisplayStatus.adjust => 'Adjust',
        PostureDisplayStatus.positionYourself => 'Position yourself',
      };
      if (_posture != label) {
        _posture = label;
        _postureStatus.value = label;
      }
      final warningSignal =
          frameClassification == PostureFrameClassification.invalid
          ? PostureWarningSignal.unavailable
          : status == PostureDisplayStatus.adjust
          ? PostureWarningSignal.adjust
          : PostureWarningSignal.good;
      final warningUpdate = _postureWarningController.update(
        warningSignal,
        _postureClock.elapsed,
      );
      if (warningUpdate.changed) {
        _postureWarning.value = warningUpdate.warning;
      }

      final framing = _cameraFramingTracker.update(landmarks).state;
      _framingSummary.addFrame(framing, _postureClock.elapsed);
      _framingWarning.value = _framingWarningController.update(
        framing,
        _postureClock.elapsed,
      );
      if (_cameraFramingStatus.value != framing) {
        _cameraFramingStatus.value = framing;
      }
    } catch (_) {
      // A dropped/invalid frame is not bad posture. Keep the rehearsal alive
      // and let subsequent camera frames recover. Avoid frame-loop log spam.
      if (mounted && generation == _postureGeneration) _interruptFaceAnalysis();
      if (generation == _postureGeneration) _framingSummary.interrupt();
    } finally {
      if (generation == _postureGeneration) _postureFrameGate.complete();
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
          if (!_microphoneEnabled) {
            _livePaceLabel = null;
            _livePaceWpm = null;
            _lastLivePaceUpdateSeconds = null;
            _performanceAlertTimer?.cancel();
            _performanceAlert = null;
          }
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
    await _stopPostureAnalysis();
    _resetPostureSession();
    _postureClock
      ..reset()
      ..start();
    _microphoneLevel.value = 0;
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    await _audioRecorder.discard();
    await _stopLiveFillerFeedback();
    if (!mounted) return;
    _alertTimer?.cancel();
    _performanceAlertTimer?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _gestureCounts.clear();
      _livePaceLabel = null;
      _livePaceWpm = null;
      _lastLivePaceUpdateSeconds = null;
      _thirtySecondWarningShown = false;
      _alert = null;
      _performanceAlert = null;
      _recording = false;
    });
    await _startAudioRecording();
    if (!mounted) return;
    unawaited(_startPostureAnalysis());
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
        await _stopPostureAnalysis();
        await controller.pausePreview();
      } else {
        await controller.resumePreview();
      }
      if (mounted) {
        setState(() => _cameraEnabled = !_cameraEnabled);
        if (_cameraEnabled) unawaited(_startPostureAnalysis());
      }
    } on CameraException {
      _showAlert('Unable to change the camera state.', errorRed);
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
    // Releasing the platform wake lock must not delay report generation.
    unawaited(_disableScreenAwake());
    _microphoneLevel.value = 0;
    _timer?.cancel();
    _postureClock.stop();
    await _stopPostureAnalysis(closeLandmarker: true);
    final postureSummary = _postureTracker.summary;
    final posturePercentage = postureSummary.acceptablePercentage;
    final postureScore = posturePercentage?.round();
    final faceSummary = _faceTracker.summary;
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
      await _stopLiveFillerFeedback();
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
      await _stopLiveFillerFeedback();
      await _audioRecorder.deleteTemporaryFile(audioPath);
    }
    if (!mounted) return;
    final referenceScript = setup.speechContent?.trim();
    final shouldCompareScript =
        (setup.speechType == 'Prepared' || setup.speechType == 'Persuasive') &&
        referenceScript != null &&
        referenceScript.isNotEmpty;
    ScriptComparisonResult? comparison;
    if (shouldCompareScript) {
      try {
        comparison = await compute(
          ScriptComparisonService.compareInput,
          <String, String?>{
            'reference': referenceScript,
            'transcript': transcript,
          },
        );
      } catch (_) {
        comparison = const ScriptComparisonResult(
          status: 'failed',
          totalReferenceWords: 0,
          matchedReferenceWords: 0,
        );
      }
    }
    if (!mounted) return;
    final session = PracticeSession(
      id: 'session-${DateTime.now().microsecondsSinceEpoch}',
      title: setup.speechTitle,
      speechType: setup.speechType,
      languageMode: setup.languageMode,
      dateTime: DateTime.now(),
      duration: Duration(seconds: _elapsedSeconds),
      monitorPace: setup.monitorPace,
      monitorFillers: setup.monitorFillers,
      monitorBodyLanguage: setup.monitorBodyLanguage,
      monitorCameraAttention: setup.monitorCameraAttention,
      cameraFramingMilliseconds: setup.monitorBodyLanguage
          ? _framingSummary.milliseconds
          : null,
      overallScore: null,
      paceScore: null,
      fillerScore: null,
      postureScore: postureScore,
      goodPostureSeconds: postureScore == null
          ? null
          : postureSummary.acceptableDuration.inSeconds,
      validPostureSeconds: postureSummary.validDuration.inSeconds,
      attentionScore: setup.monitorCameraAttention
          ? faceSummary.percentage?.round()
          : null,
      cameraFacingSeconds:
          setup.monitorCameraAttention && faceSummary.percentage != null
          ? faceSummary.facingDuration.inSeconds
          : null,
      validFaceAnalysisMilliseconds: setup.monitorCameraAttention
          ? faceSummary.validDuration.inMilliseconds
          : null,
      fillerCounts: FillerAnalysis.fromTranscript(
        transcript,
        Duration(seconds: _elapsedSeconds),
      ).counts,
      // UI/storage derive coaching from final measured data, not prototype scores.
      coachingTips: const [],
      textTranscript: transcript,
      referenceScript: shouldCompareScript ? referenceScript : null,
      referenceDocumentName: shouldCompareScript
          ? setup.referenceDocumentName
          : null,
      omittedScriptPortions: comparison?.omittedPortions ?? const [],
      addedTranscriptPortions: comparison?.addedPortions ?? const [],
      differentlyDeliveredPortions:
          comparison?.differentlyDeliveredPortions ?? const [],
      totalScriptWords: comparison?.totalReferenceWords,
      matchedScriptWords: comparison?.matchedReferenceWords,
      scriptComparisonStatus: comparison?.status,
      gestureCounts: Map.unmodifiable(_gestureCounts),
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

  @override
  void dispose() {
    _timer?.cancel();
    _alertTimer?.cancel();
    _performanceAlertTimer?.cancel();
    _countdownTimer?.cancel();
    _readinessLifecycle?.dispose();
    _noiseRefreshTimer?.cancel();
    _levelSubscription?.cancel();
    _microphoneLevel.dispose();
    _postureClock.stop();
    unawaited(_disposeCameraAndPosture());
    unawaited(_ambientNoise.dispose());
    unawaited(_stopLiveFillerFeedback());
    unawaited(_disableScreenAwake());
    unawaited(_disposeAudioRecorder());
    _transcriptionService.dispose();
    super.dispose();
  }

  Future<void> _disposeAudioRecorder() async {
    await _audioStartFuture;
    if (_audioRecorder.hasStarted) await _audioRecorder.cancel();
    await _audioRecorder.dispose();
  }

  Future<void> _disposeCameraAndPosture() async {
    await _stopPostureAnalysis(closeLandmarker: true);
    await _cameraController?.dispose();
    _postureStatus.dispose();
    _poseOverlayFrame.dispose();
    _showPoseLandmarks.dispose();
    _cameraFramingStatus.dispose();
    _postureWarning.dispose();
    _framingWarning.dispose();
    _faceMissingWarning.dispose();
    _faceStatus.dispose();
    _faceWarning.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = AppStateScope.of(context).currentSetup!;
    final displayedSeconds = _remainingSeconds;
    final minutes = (displayedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (displayedSeconds % 60).toString().padLeft(2, '0');
    final livePaceEnabled = setup.enableLiveFeedback && setup.monitorPace;
    final paceValue = !setup.monitorPace
        ? 'Off'
        : livePaceEnabled
        ? (_livePaceLabel == null ? 'Listening...' : 'Pace: $_livePaceLabel')
        : 'After session';
    final paceIsGood = livePaceEnabled
        ? _livePaceLabel == null || _livePaceLabel == 'Target'
        : false;
    final paceDescription = livePaceEnabled
        ? (_livePaceWpm == null
              ? 'Analyzing recent speech'
              : '${_livePaceWpm!.toStringAsFixed(0)} WPM recent average')
        : 'Live pace is off; final WPM uses your full transcript';
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
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _cameraFrameWidth(context),
                          ),
                          child: Stack(
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
                                  showPoseLandmarks: _showPoseLandmarks,
                                  poseOverlayFrames: _poseOverlayFrame,
                                  feedback: LiveFeedbackOverlay(
                                    enabled:
                                        !_ending &&
                                        !_paused &&
                                        !_restarting &&
                                        (!_hasStarted ||
                                            setup.enableLiveFeedback),
                                    visualEnabled:
                                        _hasStarted && _cameraEnabled,
                                    monitorBodyLanguage:
                                        setup.monitorBodyLanguage,
                                    monitorCameraAttention:
                                        setup.monitorCameraAttention,
                                    faceWarning: _faceWarning,
                                    faceMissingWarning: _faceMissingWarning,
                                    postureWarning: _postureWarning,
                                    framingWarning: _framingWarning,
                                    systemMessage: _alert,
                                    systemColor: _alertColor,
                                    systemIcon: _alertIcon,
                                    temporaryMessage: _performanceAlert,
                                    temporaryColor: warningOrange,
                                    temporaryIcon:
                                        Icons.chat_bubble_outline_rounded,
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
                        ),
                      ),
                      if (!_hasStarted) ...[
                        _ReadinessCard(
                          busy:
                              _starting ||
                              _checkingReadiness ||
                              _countdown != null,
                          starting: _starting,
                          noiseChecking: _noiseChecking,
                          noiseResult: _noiseResult,
                          onReady: _beginCountdown,
                          onDeviceCheck: () async {
                            final generation = ++_readinessGeneration;
                            setState(() => _checkingReadiness = true);
                            await _stopAmbientNoise();
                            if (!context.mounted ||
                                _leaving ||
                                generation != _readinessGeneration) {
                              return;
                            }
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const DeviceCheckScreen(
                                  returnToPreview: true,
                                ),
                              ),
                            );
                            if (mounted && !_leaving) {
                              setState(() => _checkingReadiness = false);
                              unawaited(_resumeAmbientNoise());
                            }
                          },
                        ),
                      ],
                      if (_hasStarted) ...[
                        const SizedBox(height: 10),
                        if (kDebugMode && setup.monitorBodyLanguage) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10243A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF29435E),
                              ),
                            ),
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _showPoseLandmarks,
                              builder: (context, show, child) =>
                                  PoseOverlayDebugToggle(
                                    value: show,
                                    onChanged: (value) {
                                      _showPoseLandmarks.value = value;
                                    },
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ResponsiveCardGrid(
                          spacing: 10,
                          children: [
                            _LiveMetric(
                              key: const Key('live_pace_metric'),
                              label: 'Speaking Pace',
                              value: paceValue,
                              icon: Icons.speed_rounded,
                              good: paceIsGood,
                              enabled:
                                  livePaceEnabled && _livePaceLabel != null,
                              progress: null,
                              description: paceDescription,
                            ),
                            ValueListenableBuilder<String>(
                              valueListenable: _postureStatus,
                              builder: (context, posture, child) => _LiveMetric(
                                label: 'Posture',
                                value: setup.monitorBodyLanguage
                                    ? posture
                                    : 'Off',
                                icon: Icons.accessibility_new_rounded,
                                good: posture == 'Good',
                                enabled: setup.monitorBodyLanguage,
                                progress: posture == 'Good'
                                    ? .9
                                    : posture == 'Adjust'
                                    ? .48
                                    : 0,
                                description: switch (posture) {
                                  'Good' => 'Upper body is steady',
                                  'Adjust' => 'Straighten your posture',
                                  'Unavailable' =>
                                    'Posture analysis is unavailable',
                                  _ => 'Keep shoulders and hips visible',
                                },
                              ),
                            ),
                            ValueListenableBuilder<CameraFramingState>(
                              valueListenable: _cameraFramingStatus,
                              builder: (context, framing, child) => _LiveMetric(
                                key: const Key('camera_position_metric'),
                                label: 'Camera Position',
                                value: setup.monitorBodyLanguage
                                    ? cameraFramingLabel(framing)
                                    : 'Off',
                                icon: Icons.fit_screen_rounded,
                                good: framing == CameraFramingState.proper,
                                enabled: setup.monitorBodyLanguage,
                                progress: switch (framing) {
                                  CameraFramingState.tooClose => .2,
                                  CameraFramingState.proper => .5,
                                  CameraFramingState.tooFar => .8,
                                  CameraFramingState.unavailable => 0,
                                },
                                description: switch (framing) {
                                  CameraFramingState.tooClose =>
                                    'Move slightly farther away',
                                  CameraFramingState.proper =>
                                    'Upper body is framed well',
                                  CameraFramingState.tooFar =>
                                    'Move slightly closer',
                                  CameraFramingState.unavailable =>
                                    'Keep shoulders and hips visible',
                                },
                              ),
                            ),
                            ValueListenableBuilder<FaceAttentionState>(
                              valueListenable: _faceStatus,
                              builder: (context, face, child) => _LiveMetric(
                                key: const Key('camera_attention_metric'),
                                label: 'Head Direction',
                                value: setup.monitorCameraAttention
                                    ? faceAttentionLabel(face)
                                    : 'Off',
                                icon: Icons.center_focus_strong,
                                good: face == FaceAttentionState.facingCamera,
                                enabled:
                                    setup.monitorCameraAttention &&
                                    face != FaceAttentionState.unavailable,
                                progress: null,
                                description:
                                    'Estimated head orientation, not eye contact',
                              ),
                            ),
                            _LiveMetric(
                              key: const Key('filler_metric'),
                              label: 'Fillers Detected',
                              value: setup.monitorFillers
                                  ? 'After session'
                                  : 'Off',
                              icon: Icons.chat_bubble_outline,
                              good: false,
                              enabled: setup.monitorFillers,
                              progress: null,
                              description:
                                  'Final totals use your full transcript',
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
                  child: ScrollableCenter(
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
                  child: ScrollableCenter(
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
    required this.showPoseLandmarks,
    required this.poseOverlayFrames,
    required this.feedback,
  });

  final CameraController? controller;
  final bool cameraReady;
  final bool cameraEnabled;
  final String cameraStatus;
  final bool recording;
  final ValueListenable<bool> showPoseLandmarks;
  final ValueListenable<PoseOverlayFrame?> poseOverlayFrames;
  final Widget feedback;

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
              context: context,
              aspectRatio:
                  MediaQuery.orientationOf(context) == Orientation.landscape
                  ? 16 / 9
                  : 9 / 16,
              preview: const _CameraOffView(),
              showRecordingBadge: false,
            );
          }

          final previewAspectRatio = _previewAspectRatio(value);
          final cameraFeed = kIsWeb
              ? activeController.buildPreview()
              : CameraPreview(activeController);
          final portraitPreview = FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: previewAspectRatio * 1000,
              height: 1000,
              child: cameraFeed,
            ),
          );
          return _buildFrame(
            context: context,
            aspectRatio:
                MediaQuery.orientationOf(context) == Orientation.landscape
                ? 16 / 9
                : 9 / 16,
            preview: portraitPreview,
            showRecordingBadge: recording,
          );
        },
      );
    }

    return _buildFrame(
      context: context,
      aspectRatio: MediaQuery.orientationOf(context) == Orientation.landscape
          ? 16 / 9
          : 9 / 16,
      showRecordingBadge: false,
      preview: ColoredBox(
        color: const Color(0xFF102A46),
        child: Center(
          child: SingleChildScrollView(
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
    required BuildContext context,
    required double aspectRatio,
    required Widget preview,
    bool showRecordingBadge = true,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _cameraFrameWidth(context)),
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
                  ValueListenableBuilder<bool>(
                    valueListenable: showPoseLandmarks,
                    builder: (context, show, child) => show
                        ? PoseLandmarkOverlay(frames: poseOverlayFrames)
                        : const SizedBox.shrink(),
                  ),
                  Positioned.fill(child: feedback),
                  if (showRecordingBadge)
                    Positioned(
                      right: 14,
                      bottom: 14,
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
            minimumSize: const Size(48, 48),
          ),
          icon: Icon(enabled ? enabledIcon : disabledIcon),
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
    required this.enabled,
    required this.progress,
    required this.description,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool good;
  final bool enabled;
  final double? progress;
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
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF91A5BA), fontSize: 9.5),
          ),
          if (progress != null) ...[
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
          child: ScrollableCenter(
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
                    'PREPARING RESULTS',
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
        .where((entry) => report.monitorFillers && entry.value > 0)
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
                      ScoreRing(score: report.validatedOverallScore),
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
                        child: Text(
                          report.isDemoSession
                              ? 'Demo example, not student results'
                              : 'Measured feedback · Overall not scored',
                          style: const TextStyle(
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
                SpeakingPaceCard(
                  pace: report.speakingPace,
                  enabled: report.monitorPace,
                ),
                const SizedBox(height: 10),
                FillerFrequencyCard(
                  analysis: fillerAnalysis,
                  enabled: report.monitorFillers,
                ),
                const SizedBox(height: 10),
                _ScoreRow(
                  icon: Icons.accessibility_new_rounded,
                  label: 'Acceptable posture time',
                  score: report.measuredPosturePercentage,
                  status: !report.monitorBodyLanguage
                      ? 'Monitoring off for this rehearsal'
                      : report.postureAnalysisUnavailable
                      ? 'Unavailable — not enough visible pose data'
                      : 'Fraction of visible pose time · prototype thresholds',
                ),
                const SizedBox(height: 10),
                _ScoreRow(
                  icon: Icons.center_focus_strong_rounded,
                  label: 'Estimated camera-facing time',
                  score: report.measuredAttentionPercentage,
                  status: !report.monitorCameraAttention
                      ? 'Monitoring off for this rehearsal'
                      : report.measuredAttentionPercentage == null
                      ? 'Unavailable — insufficient valid face analysis'
                      : 'Percentage of valid face-analysis time, not eye contact',
                ),
                const SizedBox(height: 28),
                const SectionHeader('Filler frequencies'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: fillers.isEmpty
                        ? Text(
                            !report.monitorFillers
                                ? 'Filler monitoring was off for this rehearsal.'
                                : fillerAnalysis.hasTranscript
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
                if (report.hasScriptComparison) ...[
                  const SizedBox(height: 28),
                  ScriptComparisonSummary(
                    documentName: report.referenceDocumentName,
                    result: report.scriptComparison!,
                  ),
                ],
                const SizedBox(height: 28),
                const SectionHeader('Upper-body feedback'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      report.postureCoachingRecommendation,
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
                ...report.measuredCoachingTips.map(
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
  final int? score;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = score == null ? const Color(0xFF617085) : accentTeal;
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
              score == null ? '—' : '$score%',
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
