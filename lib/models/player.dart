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
  });

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
      );

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
