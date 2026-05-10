import 'venue.dart';

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
  /// 콤마 구분 다중 종별. 예: '혼복' 또는 '혼복,남복,여복'.
  /// legacy '전체' 는 fromMap 단계에서 '혼복,남복,여복' 으로 자동 변환.
  final String eventType;
  /// 콤마 구분 다중 급수. 예: 'A조' 또는 'A조,B조,C조'.
  /// legacy 'A급'/'B급'/.../'초심' 은 fromMap 에서 '조' 표기로 자동 변환.
  /// legacy '전체' 는 모든 개별 급수 풀어서 저장.
  final String targetGrade;
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
  /// 대회별 연령 그룹 라벨. 예: ['전체', '40', '45', '50', '60']
  /// 라벨 규칙: 5세 단위 — 라벨 N → [N, N+5)
  /// 옛 형식("20대"/"45대")은 fromMap 단계에서 '대'를 strip하여 호환.
  final List<String> ageGroups;

  static const List<String> defaultAgeGroups = [
    '전체',
    '20',
    '30',
    '40',
    '50',
    '60',
    '70',
  ];

  // ── 급수 그룹 ────────────────────────────
  /// 대회별 급수 그룹 라벨. 예: ['전체', 'A조', 'B조', 'C조', 'D조', '초심조']
  /// '전체'는 마스터 토글 표식. 나머지는 Player.grade 와 1:1 매칭.
  final List<String> gradeGroups;

  static const List<String> defaultGradeGroups = [
    '전체',
    'A조',
    'B조',
    'C조',
    'D조',
    '초심조',
  ];

  // ── 경기장 (Venue 모델로 통합) ──────────────
  /// 대회 경기장 목록. 각 Venue 는 name/address/courts/id/colorHex 보유.
  /// 영속화 시 toMap 에서 'venues' (신규) 와 'venue'/'venue_addresses'/'venue_courts'
  /// (레거시 콤마 문자열) 를 모두 출력하여 backward compatibility 유지.
  final List<Venue> venues;

  /// 각 경기장의 기본 코트 수 (legacy 문자열 파싱 시 사용)
  static const int defaultCourtsPerVenue = 4;

  // ── 경기장 배정 매트릭스 ────────────────────
  /// 키: `"<event>|<ageLabel>|<grade>"` (예: `"혼복|40|A조"`). 값: `Venue.id`.
  /// 화면(`BracketScreen`) 의 `_assignMap` 을 영속화하기 위한 직렬화 형태.
  /// 빈 맵이면 화면 진입 시 모든 셀이 첫 경기장으로 폴백된다.
  final Map<String, String> assignMap;

  Tournament({
    required this.id,
    required this.name,
    this.region = '',
    this.tournamentType = TournamentType.general,
    this.startDate = '',
    this.endDate = '',
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
    this.gradeGroups = defaultGradeGroups,
    String venue = '',
    String venueAddresses = '',
    String venueCourts = '',
    List<Venue>? venues,
    this.assignMap = const {},
  }) : venues = venues ?? _parseLegacy(venue, venueAddresses, venueCourts);

  /// legacy 콤마 문자열 → List<Venue>
  static List<Venue> _parseLegacy(
      String venue, String addresses, String courts) {
    final names = venue
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) return <Venue>[];
    final addrList = addresses.split(',').map((s) => s.trim()).toList();
    final courtList = courts
        .split(',')
        .map((s) => int.tryParse(s.trim()) ?? defaultCourtsPerVenue)
        .toList();
    return List.generate(
      names.length,
      (i) => Venue(
        id: 'v${i + 1}',
        name: names[i],
        address: i < addrList.length ? addrList[i] : '',
        courts: i < courtList.length ? courtList[i] : defaultCourtsPerVenue,
        colorHex: Venue.defaultColors[i % Venue.defaultColors.length],
      ),
    );
  }

  // ── 종별/급수 다중값 헬퍼 ─────────────────
  static const List<String> allEventTypes = ['혼복', '남복', '여복'];

  /// 대상급수 마스터 라벨(가나다 정렬 무시, 표시 순서)
  static const List<String> allTargetGrades = [
    'A조',
    'B조',
    'C조',
    'D조',
    '초심조',
  ];

  /// 콤마 구분 eventType → List<String>. 빈 값이면 ['혼복'] fallback.
  List<String> get eventTypeList {
    final raw = eventType.trim();
    if (raw.isEmpty) return ['혼복'];
    if (raw == '전체') return List.of(allEventTypes);
    final parts = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => allEventTypes.contains(s))
        .toList();
    return parts.isEmpty ? ['혼복'] : parts;
  }

  /// 콤마 구분 targetGrade → List<String>.
  /// 'A조'/'B조'/... 기본 라벨 외에 사용자 정의 급수(자강조, E조 등)도
  /// 그대로 보존되어 반환된다. legacy 'A급'/'초심' 등은 정규화 후 노출.
  /// 빈 값/'전체' 는 기본 급수 전체로 fallback.
  List<String> get targetGradeList {
    final raw = targetGrade.trim();
    if (raw.isEmpty || raw == '전체') return List.of(allTargetGrades);
    final parts = raw
        .split(',')
        .map((s) => _normalizeGradeLabel(s.trim()))
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? List.of(allTargetGrades) : parts;
  }

  // ── 레거시 호환 게터 ──────────────────────
  /// 콤마 + 공백 구분 venue 이름 문자열 (legacy)
  String get venue => venues.map((v) => v.name).join(', ');

  /// 콤마 + 공백 구분 venue 주소 문자열 (legacy)
  String get venueAddresses => venues.map((v) => v.address).join(', ');

  /// 콤마 구분 venue 코트 수 문자열 (legacy)
  String get venueCourts => venues.map((v) => v.courts.toString()).join(',');

  // ── 파생 게터 ────────────────────────────
  List<String> get venueList => venues.map((v) => v.name).toList();
  List<String> get venueAddressList => venues.map((v) => v.address).toList();
  List<int> get venueCourtsList => venues.map((v) => v.courts).toList();

  /// 0이 아닌(=활성) 코트 수의 합
  int get totalActiveCourts =>
      venues.fold(0, (s, v) => s + (v.courts > 0 ? v.courts : 0));

  /// 0이 아닌(=활성) 경기장 개수
  int get activeVenueCount => venues.where((v) => v.courts > 0).length;

  /// index 번 경기장 활성화 여부 (코트 수 > 0)
  bool isVenueActive(int index) =>
      index >= 0 && index < venues.length && venues[index].courts > 0;

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
  /// venues 가 주어지면 그것을 사용. 아니면 legacy 문자열 (venue/venueAddresses/venueCourts)
  /// 로 재구성. 두 경로 모두 미지정이면 현재 venues 유지.
  Tournament copyWith({
    String? name,
    String? region,
    TournamentType? tournamentType,
    String? startDate,
    String? endDate,
    String? venue,
    String? venueAddresses,
    String? venueCourts,
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
    List<String>? gradeGroups,
    List<Venue>? venues,
    Map<String, String>? assignMap,
  }) =>
      Tournament(
        id: id,
        name: name ?? this.name,
        region: region ?? this.region,
        tournamentType: tournamentType ?? this.tournamentType,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
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
        gradeGroups: gradeGroups ?? this.gradeGroups,
        // venues 가 명시적으로 주어졌으면 우선 적용. legacy 문자열 인자도 병행 가능.
        venue: venue ?? this.venue,
        venueAddresses: venueAddresses ?? this.venueAddresses,
        venueCourts: venueCourts ?? this.venueCourts,
        venues: venues ?? this.venues,
        assignMap: assignMap ?? this.assignMap,
      );

  // ── DB 변환 ──────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'region': region,
        'tournament_type': tournamentType.name,
        'start_date': startDate,
        'end_date': endDate,
        // legacy 문자열 (호환성 유지)
        'venue': venue,
        'venue_courts': venueCourts,
        'venue_addresses': venueAddresses,
        // 신규 venues 리스트
        'venues': venues.map((v) => v.toMap()).toList(),
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
        'grade_groups': gradeGroups.join(','),
        'assign_map': assignMap,
      };

  /// fromMap 단계에서 target_grade 컬럼을 읽을 때 라벨/'전체' 정규화.
  /// 3단계: 'A급'→'A조' 변환. 4단계 준비: '전체'/빈 값/콤마 구분 모두 보존.
  /// (4단계에서 '전체' → 풀어쓰기 마이그레이션은 별도 처리)
  static String _normalizeTargetGradeRead(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '전체';
    if (s == '전체') return '전체';
    final parts = s
        .split(',')
        .map((e) => _normalizeGradeLabel(e.trim()))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '전체';
    return parts.join(',');
  }

  /// 'A급'/'B급'/'C급'/'D급' → 'A조'/'B조'/'C조'/'D조',
  /// '초심' → '초심조' 로 라벨 표기 통일.
  static String _normalizeGradeLabel(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    // A급/B급/C급/D급 → A조/B조/C조/D조
    final m = RegExp(r'^([A-Z])급$').firstMatch(t);
    if (m != null) return '${m.group(1)}조';
    if (t == '초심') return '초심조';
    return t;
  }

  /// legacy '전체' → '혼복,남복,여복' 변환.
  /// 알 수 없는 값은 '혼복' fallback. 콤마 구분 다중값은 유효한 것만 추려서 반환.
  static String _normalizeEventType(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '혼복';
    if (s == '전체') return allEventTypes.join(',');
    final parts = s
        .split(',')
        .map((e) => e.trim())
        .where((e) => allEventTypes.contains(e))
        .toList();
    if (parts.isEmpty) return '혼복';
    return parts.join(',');
  }

  factory Tournament.fromMap(Map<String, dynamic> m) {
    // 'venues' 신규 키 우선, 없으면 legacy 문자열에서 파싱
    List<Venue>? parsedVenues;
    final raw = m['venues'];
    if (raw is List && raw.isNotEmpty) {
      parsedVenues = raw
          .whereType<Map>()
          .map((e) => Venue.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    return Tournament(
      id: m['id'] ?? '',
      name: m['name'] ?? '',
      region: m['region'] ?? '',
      tournamentType: TournamentType.values.firstWhere(
        (t) => t.name == m['tournament_type'],
        orElse: () => TournamentType.general,
      ),
      startDate: m['start_date'] ?? '',
      endDate: m['end_date'] ?? '',
      eventType: _normalizeEventType(m['event_type']),
      targetGrade: _normalizeTargetGradeRead(m['target_grade']),
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
              .map((s) => s.trim().replaceAll('대', ''))
              .where((s) => s.isNotEmpty)
              .toList();
        }
        return defaultAgeGroups;
      }(),
      gradeGroups: () {
        final raw = m['grade_groups'];
        if (raw is String && raw.isNotEmpty) {
          return raw
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
        return defaultGradeGroups;
      }(),
      // legacy 문자열 (parsedVenues 미존재 시 fallback)
      venue: m['venue'] ?? '',
      venueAddresses: m['venue_addresses'] ?? '',
      venueCourts: m['venue_courts'] ?? '',
      venues: parsedVenues,
      assignMap: () {
        final raw = m['assign_map'];
        if (raw is Map) {
          return raw.map(
              (k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
        }
        return const <String, String>{};
      }(),
    );
  }
}
