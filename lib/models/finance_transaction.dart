class FinanceTransaction {
  final String id;
  final String title;
  final int amount;
  final bool isIncome;
  final String category;
  final String date;
  final String? clubId;
  final String? clubName;
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
    this.memo,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'is_income': isIncome ? 1 : 0,
        'category': category,
        'date': date,
        'club_id': clubId,
        'club_name': clubName,
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
        memo: m['memo'] as String?,
      );

  /// 1,234,567원 형태로 포맷
  String get formattedAmount {
    final str = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '${isIncome ? '+' : '-'}${str}원';
  }
}
