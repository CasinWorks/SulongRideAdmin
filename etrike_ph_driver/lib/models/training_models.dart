/// Rider protocol training — online module or onsite session.
library;

enum TrainingStatus {
  notStarted,
  inProgress,
  completed,
}

enum TrainingMode {
  online,
  onsite,
}

extension TrainingStatusX on TrainingStatus {
  String get dbValue => switch (this) {
        TrainingStatus.notStarted => 'not_started',
        TrainingStatus.inProgress => 'in_progress',
        TrainingStatus.completed => 'completed',
      };

  String get label => switch (this) {
        TrainingStatus.notStarted => 'Not started',
        TrainingStatus.inProgress => 'In progress',
        TrainingStatus.completed => 'Completed',
      };

  static TrainingStatus fromDb(String? v) => switch (v) {
        'in_progress' => TrainingStatus.inProgress,
        'completed' => TrainingStatus.completed,
        _ => TrainingStatus.notStarted,
      };
}

extension TrainingModeX on TrainingMode {
  String get dbValue => switch (this) {
        TrainingMode.online => 'online',
        TrainingMode.onsite => 'onsite',
      };

  String get label => switch (this) {
        TrainingMode.online => 'Online module',
        TrainingMode.onsite => 'Onsite session',
      };

  static TrainingMode fromDb(String? v) =>
      v == 'onsite' ? TrainingMode.onsite : TrainingMode.online;
}

class DriverTrainingRecord {
  const DriverTrainingRecord({
    required this.driverId,
    required this.status,
    required this.mode,
    this.startedAt,
    this.completedAt,
    this.quizPassedAt,
    this.quizScore,
    this.adminNotes,
  });

  final String driverId;
  final TrainingStatus status;
  final TrainingMode mode;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? quizPassedAt;
  final int? quizScore;
  final String? adminNotes;

  bool get isComplete => status == TrainingStatus.completed;

  factory DriverTrainingRecord.fromJson(Map<String, dynamic> json) =>
      DriverTrainingRecord(
        driverId: json['driver_id']?.toString() ?? '',
        status: TrainingStatusX.fromDb(json['status'] as String?),
        mode: TrainingModeX.fromDb(json['mode'] as String?),
        startedAt: json['started_at'] != null
            ? DateTime.tryParse(json['started_at'].toString())
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'].toString())
            : null,
        quizPassedAt: json['quiz_passed_at'] != null
            ? DateTime.tryParse(json['quiz_passed_at'].toString())
            : null,
        quizScore: (json['quiz_score'] as num?)?.toInt(),
        adminNotes: json['admin_notes'] as String?,
      );
}

class TrainingQuizQuestion {
  const TrainingQuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
}

/// Carmona fleet rider protocol — online training content.
const kTrainingProtocolModules = [
  (
    title: 'Passenger pickup',
    body:
        'Confirm the rider name and destination before starting. Wait at the marked pickup point — do not block traffic.',
    icon: 'pickup',
  ),
  (
    title: 'Safety & conduct',
    body:
        'Drive within speed limits, wear your company ID, keep the e-trike clean, and offer helmets when required.',
    icon: 'safety',
  ),
  (
    title: 'During the trip',
    body:
        'Follow the in-app route. Use chat for updates if delayed. No smoking or personal calls while carrying passengers.',
    icon: 'trip',
  ),
  (
    title: 'Drop-off & payment',
    body:
        'End the trip in the app at the correct drop-off. Confirm cash or in-app payment and thank the rider.',
    icon: 'payment',
  ),
  (
    title: 'Emergencies',
    body:
        'For accidents or medical issues, ensure passenger safety first, then contact Sulong Ride dispatch and follow company SOP.',
    icon: 'emergency',
  ),
];

const kTrainingQuizQuestions = <TrainingQuizQuestion>[
  TrainingQuizQuestion(
    id: 'q1',
    prompt: 'When should you tap "Start trip" in the app?',
    options: [
      'As soon as you accept the booking',
      'After the rider is onboard and you are ready to depart',
      'Only after reaching drop-off',
      'Never — the app starts automatically',
    ],
    correctIndex: 1,
  ),
  TrainingQuizQuestion(
    id: 'q2',
    prompt: 'What must you do before going Online on the map?',
    options: [
      'Complete rider protocol training',
      'Upload OR/CR documents',
      'Nothing — any account can go online',
      'Only clock out from HR',
    ],
    correctIndex: 0,
  ),
  TrainingQuizQuestion(
    id: 'q3',
    prompt: 'How should fares be handled for cash trips?',
    options: [
      'Collect any amount the rider offers',
      'Collect the fare shown in the app and complete the trip in-app',
      'Skip completing the trip in the app for cash',
      'Ask the rider to pay later',
    ],
    correctIndex: 1,
  ),
  TrainingQuizQuestion(
    id: 'q4',
    prompt: 'If your assigned company e-trike has an issue mid-shift, you should:',
    options: [
      'Continue driving until the battery dies',
      'Go offline and report to your operator / dispatch',
      'Swap plates with another unit without telling anyone',
      'Ignore app warnings',
    ],
    correctIndex: 1,
  ),
  TrainingQuizQuestion(
    id: 'q5',
    prompt: 'Time In / Time Out in Driver Hub is for:',
    options: [
      'Going online for trip requests',
      'HR attendance records (separate from going Online)',
      'Uploading documents',
      'Chat with riders',
    ],
    correctIndex: 1,
  ),
];

int scoreTrainingQuiz(Map<String, int> answers) {
  var correct = 0;
  for (final q in kTrainingQuizQuestions) {
    if (answers[q.id] == q.correctIndex) correct++;
  }
  return ((correct / kTrainingQuizQuestions.length) * 100).round();
}

const kTrainingPassScore = 80;
