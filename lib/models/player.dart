class Player {
  final String id;
  final String name;
  final String gender;
  final String birthDate; // 생년월일 6자리 YYMMDD
  final String grade; // '자강조'|'S조'|'A조'|'B조'|'C조'|'D조'|'초심조'
  final String clubId;
  final String clubName;
  final String phone;
  final String regNumber; // 협회 등록번호
  final int age;
  final List<String> awards;

  /// 이 선수가 출전(또는 등록)한 대회 ID 목록. 한 명이 여러 대회에 출전 가능.
  /// Phase 2 부터 사실상 "어느 대회에 선택된 선수인가" 의 source of truth —
  /// BracketScreen 의 `_selected` SP 캐시를 Firestore 화 한 것.
  /// Firestore `players/{id}` 의 `tournamentIds` 배열 필드로 영속화.
  /// 보안규칙(Phase 3)은 read/write 시 이 배열의 tournament ownership 으로 게이트.
  final List<String> tournamentIds;

  const Player({
    required this.id,
    required this.name,
    this.gender = '남',
    this.birthDate = '',
    this.grade = 'C조',
    this.clubId = '',
    this.clubName = '',
    this.phone = '',
    this.regNumber = '',
    this.age = 0,
    this.awards = const [],
    this.tournamentIds = const [],
  });

  Player copyWith({
    String? name,
    String? gender,
    String? birthDate,
    String? grade,
    String? clubId,
    String? clubName,
    String? phone,
    int? age,
    List<String>? tournamentIds,
  }) =>
      Player(
        id: id,
        name: name ?? this.name,
        gender: gender ?? this.gender,
        birthDate: birthDate ?? this.birthDate,
        grade: grade ?? this.grade,
        clubId: clubId ?? this.clubId,
        clubName: clubName ?? this.clubName,
        phone: phone ?? this.phone,
        regNumber: regNumber,
        age: age ?? this.age,
        awards: awards,
        tournamentIds: tournamentIds ?? this.tournamentIds,
      );

  // ── 연령대 ──────────────────────────────
  String get decadeLabel {
    if (age < 30) return '20대';
    if (age < 40) return '30대';
    if (age < 50) return '40대';
    if (age < 60) return '50대';
    if (age < 70) return '60대';
    return '70대';
  }

  String get decadeKey {
    if (age < 30) return '20';
    if (age < 40) return '30';
    if (age < 50) return '40';
    if (age < 60) return '50';
    if (age < 70) return '60';
    return '70';
  }

  // ── 급수 순서 (정렬용) ────────────────────
  static const gradeOrder = {
    '자강조': 0,
    'S조': 1,
    'A조': 2,
    'B조': 3,
    'C조': 4,
    'D조': 5,
    '초심조': 6,
  };

  int get gradeIndex => gradeOrder[grade] ?? 6;

  // ── 급수 라벨 (조 제거) ───────────────────
  String get gradeShort => grade.replaceAll('조', '');

  // ── DB 변환 ──────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'gender': gender,
        'birth_date': birthDate,
        'grade': grade,
        'club_id': clubId,
        'club_name': clubName,
        'phone': phone,
        'reg_number': regNumber,
        'age': age,
        'awards': awards,
        'tournamentIds': tournamentIds,
      };

  factory Player.fromMap(Map<String, dynamic> m) => Player(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        gender: m['gender'] ?? '남',
        birthDate: m['birth_date'] ?? '',
        grade: m['grade'] ?? 'C조',
        clubId: m['club_id'] ?? '',
        clubName: m['club_name'] ?? '',
        phone: m['phone'] ?? '',
        regNumber: m['reg_number'] ?? '',
        age: m['age'] ?? 0,
        awards: (m['awards'] as List?)?.cast<String>() ?? const [],
        tournamentIds: () {
          final raw = m['tournamentIds'];
          if (raw is List) return raw.whereType<String>().toList();
          return const <String>[];
        }(),
      );

  /// 다양한 입력 포맷을 6자리 YYMMDD 표준형으로 정규화.
  /// 허용: "981127", "98-11-27", "1998.11.27", "98.11.27", "1998-11-27" 등.
  /// 8자리(YYYYMMDD)는 앞 2자리(세기) 잘라서 6자리로 변환.
  /// 정규화 실패시 '' 반환 (오류 없음).
  static String normalizeBirthDate(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 6) return digits;
    if (digits.length == 8) return digits.substring(2);
    return '';
  }

  /// 생년월일 문자열 → 만 나이.
  /// 허용 포맷: "850315", "19850315", "1985-03-15", "85.03.15", "850315-1234567"
  /// YY <= 현재연도 두자리 → 2000년대, 그 외 → 1900년대.
  /// 잘못된 입력은 0 반환.
  static int calcAgeFromBirthDate(String bd) {
    final digits = bd.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 0;
    int year;
    if (digits.length >= 8) {
      year = int.tryParse(digits.substring(0, 4)) ?? 0;
    } else if (digits.length >= 6) {
      final yy = int.tryParse(digits.substring(0, 2)) ?? -1;
      if (yy < 0) return 0;
      final yyNow = DateTime.now().year % 100;
      year = yy <= yyNow ? 2000 + yy : 1900 + yy;
    } else {
      return 0;
    }
    if (year < 1900 || year > DateTime.now().year) return 0;
    final age = DateTime.now().year - year;
    return (age >= 0 && age <= 120) ? age : 0;
  }
}
