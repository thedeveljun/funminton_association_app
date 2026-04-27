/// 대회별 클럽 분담금 (계획 + 납부 상태)
///
/// 사용 시나리오:
/// - 협회장기대회처럼 클럽이 대회 운영비를 분담하는 경우
/// - 대회마다 클럽별 금액이 다름 (예: 회원수 기준 차등 분담)
/// - 납부 시 FinanceTransaction(category: '분담금')이 함께 생성됨
class ClubShare {
  final String id;
  final String tournamentId;
  final String tournamentName;
  final String clubId;
  final String clubName;
  final int amount; // 분담 금액 (원)
  final bool paid; // 납부 여부
  final String? paidDate; // 납부일 'YYYY-MM-DD'
  final String? txId; // 연결된 FinanceTransaction id (납부 시 생성)
  final String memo;

  const ClubShare({
    required this.id,
    required this.tournamentId,
    required this.tournamentName,
    required this.clubId,
    required this.clubName,
    required this.amount,
    this.paid = false,
    this.paidDate,
    this.txId,
    this.memo = '',
  });

  // ── 파생 게터 ────────────────────────────

  /// 1,234,567원 형태 포맷
  String get formattedAmount {
    final s = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '$s원';
  }

  /// 상태 라벨
  String get statusLabel => paid ? '납부' : '미납';

  /// 상태 배경색
  int get statusBgColor => paid ? 0xFFC6F6D5 : 0xFFFEEBC8;

  /// 상태 텍스트색
  int get statusFgColor => paid ? 0xFF1C4532 : 0xFF744210;

  // ── 부분 업데이트 ────────────────────────
  ClubShare copyWith({
    int? amount,
    bool? paid,
    String? paidDate,
    String? txId,
    String? memo,
  }) =>
      ClubShare(
        id: id,
        tournamentId: tournamentId,
        tournamentName: tournamentName,
        clubId: clubId,
        clubName: clubName,
        amount: amount ?? this.amount,
        paid: paid ?? this.paid,
        paidDate: paidDate ?? this.paidDate,
        txId: txId ?? this.txId,
        memo: memo ?? this.memo,
      );

  /// 납부 처리 (편의 메서드)
  ClubShare markPaid({required String paidDate, String? txId}) => copyWith(
        paid: true,
        paidDate: paidDate,
        txId: txId,
      );

  /// 미납 처리 (취소)
  ClubShare markUnpaid() => ClubShare(
        id: id,
        tournamentId: tournamentId,
        tournamentName: tournamentName,
        clubId: clubId,
        clubName: clubName,
        amount: amount,
        paid: false,
        paidDate: null,
        txId: null,
        memo: memo,
      );

  // ── DB 변환 ──────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'tournament_id': tournamentId,
        'tournament_name': tournamentName,
        'club_id': clubId,
        'club_name': clubName,
        'amount': amount,
        'paid': paid ? 1 : 0,
        'paid_date': paidDate,
        'tx_id': txId,
        'memo': memo,
      };

  factory ClubShare.fromMap(Map<String, dynamic> m) => ClubShare(
        id: m['id'] ?? '',
        tournamentId: m['tournament_id'] ?? '',
        tournamentName: m['tournament_name'] ?? '',
        clubId: m['club_id'] ?? '',
        clubName: m['club_name'] ?? '',
        amount: (m['amount'] ?? 0) as int,
        paid: (m['paid'] ?? 0) == 1,
        paidDate: m['paid_date'] as String?,
        txId: m['tx_id'] as String?,
        memo: m['memo'] ?? '',
      );
}

/// 대회별 분담금 집계 결과 (요약 카드용)
class ClubShareSummary {
  final String tournamentId;
  final String tournamentName;
  final int totalAmount; // 분담금 총 계획액
  final int collectedAmount; // 납부된 금액
  final int totalCount; // 대상 클럽 수
  final int paidCount; // 납부 완료 클럽 수

  const ClubShareSummary({
    required this.tournamentId,
    required this.tournamentName,
    required this.totalAmount,
    required this.collectedAmount,
    required this.totalCount,
    required this.paidCount,
  });

  /// 미납 금액
  int get pendingAmount => totalAmount - collectedAmount;

  /// 미납 클럽 수
  int get unpaidCount => totalCount - paidCount;

  /// 납부율 (0.0 ~ 1.0)
  double get collectionRatio =>
      totalAmount > 0 ? collectedAmount / totalAmount : 0.0;

  /// 클럽 수 기준 납부율
  double get paidClubRatio => totalCount > 0 ? paidCount / totalCount : 0.0;

  /// 전액 납부 완료 여부
  bool get isFullyCollected => totalCount > 0 && paidCount == totalCount;

  /// 리스트로부터 집계 생성
  factory ClubShareSummary.from(
    String tournamentId,
    String tournamentName,
    List<ClubShare> shares,
  ) {
    final relevant =
        shares.where((s) => s.tournamentId == tournamentId).toList();
    final total = relevant.fold<int>(0, (sum, s) => sum + s.amount);
    final collected =
        relevant.where((s) => s.paid).fold<int>(0, (sum, s) => sum + s.amount);
    final paidCount = relevant.where((s) => s.paid).length;

    return ClubShareSummary(
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      totalAmount: total,
      collectedAmount: collected,
      totalCount: relevant.length,
      paidCount: paidCount,
    );
  }
}
