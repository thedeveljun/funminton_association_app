// lib/models/player_fee_payment.dart

/// 선수 1명의 협회비 납부 1건
///
/// 클럽이 명단을 협회에 제출하면, 협회 직원이 선수별로 체크박스를 눌러
/// 납부 처리한다. 한 번의 체크 = PlayerFeePayment 1건 + FinanceTransaction 1건.
class PlayerFeePayment {
  final String id;
  final String playerId;
  final String playerName;
  final String clubId;
  final String clubName;
  final int year; // 협회비 연도 (예: 2026)
  final int amount; // 단가 (기본 15,000)
  final String date; // 납부일 'YYYY-MM-DD'
  final String? txId; // 연결된 FinanceTransaction id
  final String memo;

  const PlayerFeePayment({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.clubId,
    required this.clubName,
    required this.year,
    required this.amount,
    required this.date,
    this.txId,
    this.memo = '',
  });

  /// '15,000원' 형식
  String get formattedAmount {
    final s = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '$s원';
  }

  PlayerFeePayment copyWith({
    int? amount,
    String? date,
    String? txId,
    String? memo,
  }) =>
      PlayerFeePayment(
        id: id,
        playerId: playerId,
        playerName: playerName,
        clubId: clubId,
        clubName: clubName,
        year: year,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        txId: txId ?? this.txId,
        memo: memo ?? this.memo,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'player_id': playerId,
        'player_name': playerName,
        'club_id': clubId,
        'club_name': clubName,
        'year': year,
        'amount': amount,
        'date': date,
        'tx_id': txId,
        'memo': memo,
      };

  factory PlayerFeePayment.fromMap(Map<String, dynamic> m) => PlayerFeePayment(
        id: m['id'] ?? '',
        playerId: m['player_id'] ?? '',
        playerName: m['player_name'] ?? '',
        clubId: m['club_id'] ?? '',
        clubName: m['club_name'] ?? '',
        year: (m['year'] ?? DateTime.now().year) as int,
        amount: (m['amount'] ?? 0) as int,
        date: m['date'] ?? '',
        txId: m['tx_id'] as String?,
        memo: m['memo'] ?? '',
      );
}

/// 클럽 1개의 협회비 납부 현황 (선수별 집계)
class ClubFeeSummary {
  final String clubId;
  final String clubName;
  final int totalPlayers; // 클럽 회원 수
  final int paidPlayers; // 납부 완료 선수 수
  final int totalPaid; // 납부 금액 합계 (원)
  final List<PlayerFeePayment> payments;

  const ClubFeeSummary({
    required this.clubId,
    required this.clubName,
    required this.totalPlayers,
    required this.paidPlayers,
    required this.totalPaid,
    required this.payments,
  });

  /// 미납자 수
  int get unpaidPlayers => totalPlayers - paidPlayers;

  /// 전원 납부
  bool get isFullyPaid => totalPlayers > 0 && paidPlayers == totalPlayers;

  /// 일부 납부
  bool get isPartiallyPaid => paidPlayers > 0 && paidPlayers < totalPlayers;

  /// 미납 (한 명도 안 냄)
  bool get isUnpaid => paidPlayers == 0;

  /// 납부율 0.0~1.0
  double get ratio => totalPlayers == 0 ? 0.0 : paidPlayers / totalPlayers;

  /// 집계 헬퍼: 클럽 ID + 회원 수 + 전체 납부 리스트로부터 자동 계산
  factory ClubFeeSummary.from({
    required String clubId,
    required String clubName,
    required int totalPlayers,
    required List<PlayerFeePayment> allPayments,
    int? year,
  }) {
    final yr = year ?? DateTime.now().year;
    final clubPayments =
        allPayments.where((p) => p.clubId == clubId && p.year == yr).toList();

    // 같은 선수가 중복 결제됐을 수 있으니 playerId 기준 unique
    final paidPlayerIds = <String>{};
    int sum = 0;
    for (final p in clubPayments) {
      if (paidPlayerIds.add(p.playerId)) {
        sum += p.amount;
      }
    }

    return ClubFeeSummary(
      clubId: clubId,
      clubName: clubName,
      totalPlayers: totalPlayers,
      paidPlayers: paidPlayerIds.length,
      totalPaid: sum,
      payments: clubPayments,
    );
  }
}
