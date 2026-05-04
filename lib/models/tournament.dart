/// 대회 분류
/// - associationCup: 협회장기대회 (분담금 + 찬조 적용)
/// - cityCup: 시장기대회 (시 지원 + 찬조)
/// - mediaCup: 언론사 공동주관 대회 (대형 예산 + 찬조)
/// - general: 일반 대회 (라온누리 등)
enum TournamentType {
  associationCup, // 협회장기
  cityCup, // 시장기
  mediaCup, // 언론사후원
  general; // 일반

  String get label {
    switch (this) {
      case TournamentType.associationCup:
        return '협회장기';
      case TournamentType.cityCup:
        return '시장기';
      case TournamentType.mediaCup:
        return '언론사후원';
      case TournamentType.general:
        return '일반';
    }
  }
}

class Tournament {
  final String id;
  final String name;
  final String region; // 주관 지역 (예: '과천시')
  final TournamentType tournamentType;
  final String startDate;
  final String endDate;
  final String venue;
  final String eventType; // '혼복' | '남복' | '여복' | '전체'
  final String targetGrade; // '전체' | 'A급' | 'B급' …
  final int entryFee;
  final String status; // 'upcoming' | 'ongoing' | 'completed'
  final int participantCount;
  final String description;
  final int progressPercent;

  // ── 재정 관련 ────────────────────────────
  final int totalBudget; // 총 예산 (원)
  final int citySupportAmount; // 시·지자체 지원금 (원)
  final String citySupportNote; // 시 지원 항목/조건 메모
  final bool hasClubShare; // 클럽 분담금 적용 여부
  final bool acceptsDonation; // 찬조(개인/기업) 받는 대회 여부

  // ── 연령 그룹 ────────────────────────────
  /// 대회별 연령 그룹 라벨. 예: ['전체', '40대', '45대', '50대', '60대']
  /// 라벨 규칙: "X0대" → [X0, X0+10), "X5대" → [X5, X5+5), "전체" → 모든 연령
  /// TODO: tournament_form_screen에서 편집 가능하도록 UI 연결
  final List<String> ageGroups;

  static const List<String> defaultAgeGroups = [
    '전체',
    '20대',
    '30대',
    '40대',
    '45대',
    '50대',
    '55대',
    '60대',
    '70대',
  ];

  /// 경기장별 코트 수 — venue 필드와 같은 순서, 콤마 구분
  /// 예) venue="과천시민체육관, 과천종합운동장", venueCourts="6,4"
  /// 0 = 사용 안 함 (체크 해제 상태)
  /// 빈 문자열 또는 길이 불일치 시 venueList 길이만큼 기본 4코트 자동 채움
  final String venueCourts;

  /// 각 경기장의 기본 코트 수 (venueCourts가 비었거나 짧을 때 사용)
  static const int defaultCourtsPerVenue = 4;

  const Tournament({
    required this.id,
    required this.name,
    this.region = '',
    this.tournamentType = TournamentType.general,
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
    this.totalBudget = 0,
    this.citySupportAmount = 0,
    this.citySupportNote = '',
    this.hasClubShare = false,
    this.acceptsDonation = false,
    this.ageGroups = defaultAgeGroups,
    this.venueCourts = '',
  });

  // ── 파생 게터 ────────────────────────────

  /// 콤마 구분된 venue 문자열을 trim된 리스트로 파싱
  List<String> get venueList => venue
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// 각 경기장의 코트 수 리스트. venueList 길이에 맞춰 정규화.
  /// venueCourts가 비거나 짧으면 부족한 만큼 defaultCourtsPerVenue로 채움.
  List<int> get venueCourtsList {
    final venues = venueList;
    if (venues.isEmpty) return const [];
    final raw = venueCourts
        .split(',')
        .map((s) => int.tryParse(s.trim()) ?? defaultCourtsPerVenue)
        .toList();
    return List.generate(
      venues.length,
      (i) => i < raw.length ? raw[i] : defaultCourtsPerVenue,
    );
  }

  /// 0이 아닌(=활성) 코트 수의 합
  int get totalActiveCourts =>
      venueCourtsList.fold(0, (s, c) => s + (c > 0 ? c : 0));

  /// 0이 아닌(=활성) 경기장 개수
  int get activeVenueCount => venueCourtsList.where((c) => c > 0).length;

  /// index 번 경기장 활성화 여부 (코트 수 > 0)
  bool isVenueActive(int index) {
    final list = venueCourtsList;
    return index >= 0 && index < list.length && list[index] > 0;
  }

  /// 협회 자체 부담액 (총 예산 − 시 지원금)
  int get associationBurden => totalBudget - citySupportAmount;

  /// 시 지원 비율 (0.0 ~ 1.0)
  double get cityFundingRatio =>
      totalBudget > 0 ? citySupportAmount / totalBudget : 0.0;

  /// 시 지원금 받는 대회인지
  bool get hasCitySupport => citySupportAmount > 0;

  /// 상태 라벨
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

  /// 1,234,567원 형태 포맷
  static String _fmt(int v) {
    final s = v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '$s원';
  }

  String get formattedBudget => _fmt(totalBudget);
  String get formattedCitySupport => _fmt(citySupportAmount);
  String get formattedAssociationBurden => _fmt(associationBurden);

  // ── 부분 업데이트 ────────────────────────
  Tournament copyWith({
    String? name,
    String? region,
    TournamentType? tournamentType,
    String? startDate,
    String? endDate,
    String? venue,
    String? eventType,
    String? targetGrade,
    int? entryFee,
    String? status,
    int? participantCount,
    String? description,
    int? progressPercent,
    int? totalBudget,
    int? citySupportAmount,
    String? citySupportNote,
    bool? hasClubShare,
    bool? acceptsDonation,
    List<String>? ageGroups,
    String? venueCourts,
  }) =>
      Tournament(
        id: id,
        name: name ?? this.name,
        region: region ?? this.region,
        tournamentType: tournamentType ?? this.tournamentType,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        venue: venue ?? this.venue,
        eventType: eventType ?? this.eventType,
        targetGrade: targetGrade ?? this.targetGrade,
        entryFee: entryFee ?? this.entryFee,
        status: status ?? this.status,
        participantCount: participantCount ?? this.participantCount,
        description: description ?? this.description,
        progressPercent: progressPercent ?? this.progressPercent,
        totalBudget: totalBudget ?? this.totalBudget,
        citySupportAmount: citySupportAmount ?? this.citySupportAmount,
        citySupportNote: citySupportNote ?? this.citySupportNote,
        hasClubShare: hasClubShare ?? this.hasClubShare,
        acceptsDonation: acceptsDonation ?? this.acceptsDonation,
        ageGroups: ageGroups ?? this.ageGroups,
        venueCourts: venueCourts ?? this.venueCourts,
      );

  // ── DB 변환 ──────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'region': region,
        'tournament_type': tournamentType.name,
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
        'total_budget': totalBudget,
        'city_support_amount': citySupportAmount,
        'city_support_note': citySupportNote,
        'has_club_share': hasClubShare ? 1 : 0,
        'accepts_donation': acceptsDonation ? 1 : 0,
        'age_groups': ageGroups.join(','),
        'venue_courts': venueCourts,
      };

  factory Tournament.fromMap(Map<String, dynamic> m) => Tournament(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        region: m['region'] ?? '',
        tournamentType: TournamentType.values.firstWhere(
          (t) => t.name == m['tournament_type'],
          orElse: () => TournamentType.general,
        ),
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
        totalBudget: m['total_budget'] ?? 0,
        citySupportAmount: m['city_support_amount'] ?? 0,
        citySupportNote: m['city_support_note'] ?? '',
        hasClubShare: (m['has_club_share'] ?? 0) == 1,
        acceptsDonation: (m['accepts_donation'] ?? 0) == 1,
        ageGroups: () {
          final raw = m['age_groups'];
          if (raw is String && raw.isNotEmpty) {
            return raw
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
          return defaultAgeGroups;
        }(),
        venueCourts: m['venue_courts'] ?? '',
      );
}
