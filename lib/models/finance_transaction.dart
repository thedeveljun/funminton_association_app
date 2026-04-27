class FinanceTransaction {
  final String id;
  final String title;
  final int amount;
  final bool isIncome;
  final String category;
  final String date;
  final String? clubId;
  final String? clubName;
  final String? tournamentId;
  final String? tournamentName;
  final String? memo;

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
  });

  /// 사용 가능한 카테고리 (수입/지출 공통 풀)
  static const List<String> categories = [
    '협회비', // 클럽 → 협회 정기 회비
    '분담금', // 대회별 클럽 분담금
    '시지원금', // 시·지자체 지원금
    '참가비', // 대회 참가비 수입
    '개인찬조', // 회원 개인 찬조 (현금)
    '물품찬조', // 기업/개인 물품찬조 (평가액)
    '시상금', // 우승/입상자 상금 지출
    '용품', // 셔틀콕 등 용품 구매
    '시설', // 체육관 대여 등
    '심판', // 심판 인건비
    '이사회비', // 이사회 운영비
    '기타',
  ];

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
      };

  factory FinanceTransaction.fromMap(Map<String, dynamic> m) =>
      FinanceTransaction(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        amount: (m['amount'] ?? 0) as int,
        isIncome: (m['is_income'] ?? 1) == 1,
        category: m['category'] ?? '기타',
        date: m['date'] ?? '',
        clubId: m['club_id'] as String?,
        clubName: m['club_name'] as String?,
        tournamentId: m['tournament_id'] as String?,
        tournamentName: m['tournament_name'] as String?,
        memo: m['memo'] as String?,
      );

  /// +1,234,567원 / -1,234,567원
  String get formattedAmount {
    final str = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '${isIncome ? '+' : '-'}${str}원';
  }
}
