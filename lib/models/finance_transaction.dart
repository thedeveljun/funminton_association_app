class FinanceTransaction {
  final String id;
  final String title;
  final int amount;
  final bool isIncome;
  final String category;

  /// 'YYYY-MM-DD HH:MM:SS'. 예전 자료는 'YYYY-MM-DD' 만 있을 수 있다.
  final String date;
  final String? clubId;
  final String? clubName;
  final String? tournamentId;
  final String? tournamentName;
  final String? memo;

  /// 가맹점 전화번호 (영수증에서 읽거나 직접 적음).
  final String phone;

  /// 붙인 영수증 사진(이 폰 안의 경로).
  final String? imagePath;

  /// 협회비·분담금·찬조와 이어진 줄의 표시(태그). 손으로 적은 줄은 널.
  /// 형식은 FinanceLedger 참고 — `협회비_<키>`, `협회비납부_<키>`, `협회비반납_<키>` …
  final String? link;

  /// 반납 줄에만 — 반납하며 떼어 낸 납부 기록(협회비 납부·분담금)의 사본.
  /// '반납 되돌리기' 때 이것으로 납부 기록을 되살린다.
  final Map<String, dynamic>? restore;

  const FinanceTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.isIncome,
    this.category = '기타',
    required this.date,
    this.clubId,
    this.clubName,
    this.tournamentId,
    this.tournamentName,
    this.memo,
    this.phone = '',
    this.imagePath,
    this.link,
    this.restore,
  });

  /// 사용 가능한 카테고리 (수입/지출 공통 풀)
  static const List<String> categories = [
    '협회비', // 클럽 → 협회 정기 회비
    '분담금', // 대회별 클럽 분담금
    '시지원금', // 시·지자체 지원금
    '참가비', // 대회 참가비 수입
    '개인찬조', // 회원 개인 찬조 (현금)
    '기업찬조', // 기업 찬조 (현금)
    '물품찬조', // 기업/개인 물품찬조 (평가액)
    '시상금', // 우승/입상자 상금 지출
    '용품', // 셔틀콕 등 용품 구매
    '시설', // 체육관 대여 등
    '심판', // 심판 인건비
    '이사회비', // 이사회 운영비
    '기타',
  ];

  /// 널로 지울 수 있게 clear* 플래그를 둔다(분담금처럼 null 을 못 넣는 일을 막음).
  FinanceTransaction copyWith({
    String? title,
    int? amount,
    bool? isIncome,
    String? category,
    String? date,
    String? clubId,
    String? clubName,
    String? tournamentId,
    String? tournamentName,
    String? memo,
    bool clearMemo = false,
    String? phone,
    String? imagePath,
    bool clearImage = false,
    String? link,
    bool clearLink = false,
    Map<String, dynamic>? restore,
    bool clearRestore = false,
  }) =>
      FinanceTransaction(
        id: id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        isIncome: isIncome ?? this.isIncome,
        category: category ?? this.category,
        date: date ?? this.date,
        clubId: clubId ?? this.clubId,
        clubName: clubName ?? this.clubName,
        tournamentId: tournamentId ?? this.tournamentId,
        tournamentName: tournamentName ?? this.tournamentName,
        memo: clearMemo ? null : (memo ?? this.memo),
        phone: phone ?? this.phone,
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
        link: clearLink ? null : (link ?? this.link),
        restore: clearRestore ? null : (restore ?? this.restore),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'is_income': isIncome ? 1 : 0,
        'category': category,
        'date': date,
        'club_id': clubId,
        'club_name': clubName,
        'tournament_id': tournamentId,
        'tournament_name': tournamentName,
        'memo': memo,
        if (phone.isNotEmpty) 'phone': phone,
        if (imagePath != null) 'image_path': imagePath,
        if (link != null) 'link': link,
        if (restore != null) 'restore': restore,
      };

  factory FinanceTransaction.fromMap(Map<String, dynamic> m) =>
      FinanceTransaction(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        amount: (m['amount'] as num?)?.toInt() ?? 0,
        isIncome: (m['is_income'] ?? 1) == 1,
        category: m['category'] ?? '기타',
        date: _normStamp(m['date'] as String? ?? ''),
        clubId: m['club_id'] as String?,
        clubName: m['club_name'] as String?,
        tournamentId: m['tournament_id'] as String?,
        tournamentName: m['tournament_name'] as String?,
        memo: m['memo'] as String?,
        phone: m['phone'] as String? ?? '',
        imagePath: m['image_path'] as String?,
        link: m['link'] as String?,
        restore: m['restore'] == null
            ? null
            : Map<String, dynamic>.from(m['restore'] as Map),
      );

  /// 날짜 앞 10자의 `.`·`/` 를 `-` 로 맞춘다.
  static String _normStamp(String s) {
    if (s.length < 10) return s;
    return s.substring(0, 10).replaceAll(RegExp(r'[./]'), '-') +
        s.substring(10);
  }

  /// +1,234,567원 / -1,234,567원
  String get formattedAmount {
    final str = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '${isIncome ? '+' : '-'}${str}원';
  }
}
