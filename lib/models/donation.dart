/// 찬조 주체
enum DonationType {
  individual, // 개인 (회원 또는 비회원)
  corporate; // 기업

  String get label {
    switch (this) {
      case DonationType.individual:
        return '개인';
      case DonationType.corporate:
        return '기업';
    }
  }
}

/// 찬조 형태
enum DonationKind {
  cash, // 현금
  item; // 물품 (평가액으로 환산)

  String get label {
    switch (this) {
      case DonationKind.cash:
        return '현금';
      case DonationKind.item:
        return '물품';
    }
  }
}

/// 찬조 1건
class Donation {
  final String id;
  final String? tournamentId;
  final String? tournamentName;
  final DonationType type;
  final DonationKind kind;

  // 찬조자 정보
  final String donorName;
  final String? donorPlayerId;
  final String? donorClubName;
  final String donorContact;

  // 금액·물품
  final int amount;
  final String itemDescription;

  // 메타
  final String date;
  final String? txId;
  final String memo;
  final bool acknowledged;

  const Donation({
    required this.id,
    this.tournamentId,
    this.tournamentName,
    this.type = DonationType.individual,
    this.kind = DonationKind.cash,
    required this.donorName,
    this.donorPlayerId,
    this.donorClubName,
    this.donorContact = '',
    this.amount = 0,
    this.itemDescription = '',
    this.date = '',
    this.txId,
    this.memo = '',
    this.acknowledged = false,
  });

  // ── 파생 게터 ────────────────────────────

  String get combinedLabel => '${type.label} · ${kind.label}';

  String get categoryKey {
    if (kind == DonationKind.item) return '물품찬조';
    return type == DonationType.individual ? '개인찬조' : '기업찬조';
  }

  String get formattedAmount {
    final s = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '$s원';
  }

  String get displayTitle {
    if (kind == DonationKind.item && itemDescription.isNotEmpty) {
      return '$donorName ($itemDescription)';
    }
    return donorName;
  }

  bool get isRegisteredPlayer =>
      donorPlayerId != null && donorPlayerId!.isNotEmpty;

  bool get hasTournament => tournamentId != null && tournamentId!.isNotEmpty;

  // ── 부분 업데이트 ────────────────────────
  Donation copyWith({
    String? tournamentId,
    String? tournamentName,
    DonationType? type,
    DonationKind? kind,
    String? donorName,
    String? donorPlayerId,
    String? donorClubName,
    String? donorContact,
    int? amount,
    String? itemDescription,
    String? date,
    String? txId,
    String? memo,
    bool? acknowledged,
  }) =>
      Donation(
        id: id,
        tournamentId: tournamentId ?? this.tournamentId,
        tournamentName: tournamentName ?? this.tournamentName,
        type: type ?? this.type,
        kind: kind ?? this.kind,
        donorName: donorName ?? this.donorName,
        donorPlayerId: donorPlayerId ?? this.donorPlayerId,
        donorClubName: donorClubName ?? this.donorClubName,
        donorContact: donorContact ?? this.donorContact,
        amount: amount ?? this.amount,
        itemDescription: itemDescription ?? this.itemDescription,
        date: date ?? this.date,
        txId: txId ?? this.txId,
        memo: memo ?? this.memo,
        acknowledged: acknowledged ?? this.acknowledged,
      );

  // ── DB 변환 ──────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'tournament_id': tournamentId,
        'tournament_name': tournamentName,
        'type': type.name,
        'kind': kind.name,
        'donor_name': donorName,
        'donor_player_id': donorPlayerId,
        'donor_club_name': donorClubName,
        'donor_contact': donorContact,
        'amount': amount,
        'item_description': itemDescription,
        'date': date,
        'tx_id': txId,
        'memo': memo,
        'acknowledged': acknowledged ? 1 : 0,
      };

  factory Donation.fromMap(Map<String, dynamic> m) => Donation(
        id: m['id'] ?? '',
        tournamentId: m['tournament_id'] as String?,
        tournamentName: m['tournament_name'] as String?,
        type: DonationType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => DonationType.individual,
        ),
        kind: DonationKind.values.firstWhere(
          (k) => k.name == m['kind'],
          orElse: () => DonationKind.cash,
        ),
        donorName: m['donor_name'] ?? '',
        donorPlayerId: m['donor_player_id'] as String?,
        donorClubName: m['donor_club_name'] as String?,
        donorContact: m['donor_contact'] ?? '',
        amount: (m['amount'] ?? 0) as int,
        itemDescription: m['item_description'] ?? '',
        date: m['date'] ?? '',
        txId: m['tx_id'] as String?,
        memo: m['memo'] ?? '',
        acknowledged: (m['acknowledged'] ?? 0) == 1,
      );
}

/// 대회별 찬조 집계 결과 (요약 카드용)
class DonationSummary {
  final String? tournamentId;
  final String? tournamentName;

  final int individualCashTotal;
  final int individualItemTotal;
  final int corporateCashTotal;
  final int corporateItemTotal;

  final int individualCount;
  final int corporateCount;

  const DonationSummary({
    this.tournamentId,
    this.tournamentName,
    this.individualCashTotal = 0,
    this.individualItemTotal = 0,
    this.corporateCashTotal = 0,
    this.corporateItemTotal = 0,
    this.individualCount = 0,
    this.corporateCount = 0,
  });

  int get cashTotal => individualCashTotal + corporateCashTotal;
  int get itemTotal => individualItemTotal + corporateItemTotal;
  int get individualTotal => individualCashTotal + individualItemTotal;
  int get corporateTotal => corporateCashTotal + corporateItemTotal;
  int get grandTotal => cashTotal + itemTotal;
  int get totalCount => individualCount + corporateCount;

  /// 리스트로부터 집계 생성. tournamentId가 null이면 전체 합산.
  factory DonationSummary.from(
    List<Donation> donations, {
    String? tournamentId,
    String? tournamentName,
  }) {
    final relevant = tournamentId == null
        ? donations
        : donations.where((d) => d.tournamentId == tournamentId).toList();

    int iCash = 0;
    int iItem = 0;
    int cCash = 0;
    int cItem = 0;
    int iCnt = 0;
    int cCnt = 0;

    for (final d in relevant) {
      if (d.type == DonationType.individual) {
        iCnt++;
        if (d.kind == DonationKind.cash) {
          iCash += d.amount;
        } else {
          iItem += d.amount;
        }
      } else {
        cCnt++;
        if (d.kind == DonationKind.cash) {
          cCash += d.amount;
        } else {
          cItem += d.amount;
        }
      }
    }

    return DonationSummary(
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      individualCashTotal: iCash,
      individualItemTotal: iItem,
      corporateCashTotal: cCash,
      corporateItemTotal: cItem,
      individualCount: iCnt,
      corporateCount: cCnt,
    );
  }
}
