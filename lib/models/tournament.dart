class Tournament {
  final String id;
  final String name;
  final String startDate;
  final String endDate;
  final String venue;
  final String eventType;
  final String targetGrade;
  final int entryFee;
  final String status;
  final int participantCount;
  final String description;
  final int progressPercent;

  const Tournament({
    required this.id,
    required this.name,
    this.startDate = '',
    this.endDate = '',
    this.venue = '',
    this.eventType = '혼복',
    this.targetGrade = '전체',
    this.entryFee = 0,
    this.status = 'upcoming',
    this.participantCount = 0,
    this.description = '',
    this.progressPercent = 0,
  });

  String get statusLabel {
    switch (status) {
      case 'ongoing':
        return '진행중';
      case 'upcoming':
        return '예정';
      case 'completed':
        return '완료';
      default:
        return status;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'start_date': startDate,
        'end_date': endDate,
        'venue': venue,
        'event_type': eventType,
        'target_grade': targetGrade,
        'entry_fee': entryFee,
        'status': status,
        'participant_count': participantCount,
        'description': description,
        'progress_percent': progressPercent,
      };

  factory Tournament.fromMap(Map<String, dynamic> m) => Tournament(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        startDate: m['start_date'] ?? '',
        endDate: m['end_date'] ?? '',
        venue: m['venue'] ?? '',
        eventType: m['event_type'] ?? '혼복',
        targetGrade: m['target_grade'] ?? '전체',
        entryFee: m['entry_fee'] ?? 0,
        status: m['status'] ?? 'upcoming',
        participantCount: m['participant_count'] ?? 0,
        description: m['description'] ?? '',
        progressPercent: m['progress_percent'] ?? 0,
      );
}
