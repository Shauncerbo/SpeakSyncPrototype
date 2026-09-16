import '../models/app_preferences.dart';
import '../models/practice_session.dart';

const initialPreferences = AppPreferences(
  userId: 'demo-user',
  defaultLanguage: 'Mixed Language',
  defaultDuration: '3 minutes',
  liveFeedback: true,
  bodyMonitoring: true,
  cameraAttentionMonitoring: true,
  fillerMonitoring: true,
  paceMonitoring: true,
  alertFrequency: 'Balanced',
);

List<PracticeSession> initialSessions() => [
  PracticeSession(
    id: 'initial-1',
    title: 'Climate Change Speech',
    speechType: 'Persuasive',
    languageMode: 'English–Filipino',
    dateTime: DateTime(2026, 6, 18),
    duration: const Duration(minutes: 6, seconds: 20),
    overallScore: 82,
    paceScore: 84,
    fillerScore: 78,
    postureScore: 86,
    attentionScore: 80,
    fillerCounts: const {'Kuan': 3, 'Ano': 1},
    coachingTips: const [
      'Pause briefly instead of using a filler word.',
      'Keep your eyes near the camera during key points.',
    ],
    textTranscript:
        "Good morning everyone. Today I'm here to talk about climate change. Kuan, it is very important that we address this issue. The global temperatures are rising, and ano, we must act before it is too late.",
    referenceScript:
        "Good morning everyone. Today I'm here to talk about climate change. It is important that we address this issue. Global temperatures are rising, and we must act before it is too late.",
    referenceDocumentName: 'climate-change-speech.txt',
    isPrototypeData: true,
  ),
  PracticeSession(
    id: 'initial-2',
    title: 'Technology and Education',
    speechType: 'Prepared',
    languageMode: 'English',
    dateTime: DateTime(2026, 6, 16),
    duration: const Duration(minutes: 5, seconds: 45),
    overallScore: 76,
    paceScore: 73,
    fillerScore: 75,
    postureScore: 82,
    attentionScore: 74,
    fillerCounts: const {'Um': 2, 'Kuan': 2},
    coachingTips: const [
      'Slow down around important ideas.',
      'Use a steady stance to support your delivery.',
    ],
    textTranscript:
        "Technology has completely revolutionized education. In the past, um, we relied heavily on textbooks. Now, kuan, students have access to the entire world's knowledge at their fingertips.",
    referenceScript:
        "Technology has revolutionized education. In the past, we relied heavily on textbooks. Now students have access to knowledge at their fingertips.",
    referenceDocumentName: 'technology-and-education.txt',
    isPrototypeData: true,
  ),
  PracticeSession(
    id: 'initial-3',
    title: 'Impromptu Practice',
    speechType: 'Impromptu',
    languageMode: 'Mixed Language',
    dateTime: DateTime(2026, 6, 14),
    duration: const Duration(minutes: 4, seconds: 10),
    overallScore: 71,
    paceScore: 70,
    fillerScore: 66,
    postureScore: 78,
    attentionScore: 72,
    fillerCounts: const {'Kuan': 4, 'Ano': 2},
    coachingTips: const [
      'Take one planning breath before answering.',
      'Replace fillers with a quiet pause.',
    ],
    textTranscript:
        "I wasn't expecting this question, but kuan, I think my favorite book is The Alchemist. It teaches us about destiny. Ano, following your personal legend is the main theme, and kuan, it really resonated with me.",
    isPrototypeData: true,
  ),
  PracticeSession(
    id: 'initial-4',
    title: 'Environmental Awareness',
    speechType: 'Prepared',
    languageMode: 'English–Bisaya',
    dateTime: DateTime(2026, 6, 12),
    duration: const Duration(minutes: 5, seconds: 5),
    overallScore: 68,
    paceScore: 72,
    fillerScore: 64,
    postureScore: 69,
    attentionScore: 67,
    fillerCounts: const {'Kuan': 5},
    coachingTips: const [
      'Square your shoulders and keep your upper body relaxed.',
      'Look toward the camera at the end of each thought.',
    ],
    textTranscript:
        "Environmental awareness starts at home. Kuan, turning off the lights when leaving a room is simple. Kuan, recycling plastics is also crucial. We need everyone to participate, kuan, to really make a lasting impact.",
    referenceScript:
        'Environmental awareness starts at home. Turning off the lights when leaving a room is simple. Recycling plastics is also crucial. We need everyone to participate to make a lasting impact.',
    referenceDocumentName: 'environmental-awareness.txt',
    isPrototypeData: true,
  ),
];
