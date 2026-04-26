class FinanceTransaction {
  final String id;
  final String title;
  final int amount;
  final bool isIncome; // true=수입, false=지출
  final String category; // '협회비' | '참가비' | '후원금' | '시상금' | '용품' | '기타'
  final String date;
  final String clubId;
  final String memo;

  const FinanceTransaction({
    required this.id,
    required this.title,
    required this.amount,
    this.isIncome = true,
    this.category = '기타',
    this.date = '',
    this.clubId = '',
    this.memo = '',
  });

  String get formattedAmount {
    final str = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '${isIncome ? "+" : "-"}$str원';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'is_income': isIncome ? 1 : 0,
        'category': category,
        'date': date,
        'club_id': clubId,
        'memo': memo,
      };
}

// ── 샘플 재정 데이터 ──────────────────────────
final List<FinanceTransaction> sampleTransactions = [
  FinanceTransaction(
      id: 'f1',
      title: '중앙클럽 협회비',
      amount: 300000,
      isIncome: true,
      category: '협회비',
      date: '2026-04-19',
      clubId: 'c1'),
  FinanceTransaction(
      id: 'f2',
      title: '협회장배 참가비',
      amount: 2130000,
      isIncome: true,
      category: '참가비',
      date: '2026-04-15'),
  FinanceTransaction(
      id: 'f3',
      title: '심판 인건비',
      amount: 500000,
      isIncome: false,
      category: '기타',
      date: '2026-04-15'),
  FinanceTransaction(
      id: 'f4',
      title: '동작클럽 협회비',
      amount: 200000,
      isIncome: true,
      category: '협회비',
      date: '2026-04-10',
      clubId: 'c2'),
  FinanceTransaction(
      id: 'f5',
      title: '시설 대여비',
      amount: 300000,
      isIncome: false,
      category: '기타',
      date: '2026-04-10'),
  FinanceTransaction(
      id: 'f6',
      title: '찬조금 (강남구청)',
      amount: 1000000,
      isIncome: true,
      category: '후원금',
      date: '2026-04-08'),
  FinanceTransaction(
      id: 'f7',
      title: '서초클럽 협회비',
      amount: 200000,
      isIncome: true,
      category: '협회비',
      date: '2026-04-07',
      clubId: 'c3'),
  FinanceTransaction(
      id: 'f8',
      title: '분당클럽 협회비',
      amount: 200000,
      isIncome: true,
      category: '협회비',
      date: '2026-04-05',
      clubId: 'c4'),
  FinanceTransaction(
      id: 'f9',
      title: '셔틀콕 구매',
      amount: 120000,
      isIncome: false,
      category: '용품',
      date: '2026-04-03'),
  FinanceTransaction(
      id: 'f10',
      title: '수원클럽 협회비',
      amount: 200000,
      isIncome: true,
      category: '협회비',
      date: '2026-03-28',
      clubId: 'c6'),
];
