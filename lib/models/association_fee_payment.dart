/// 협회비 납부 사유
enum FeeReason {
  regular,
  newMember,
  correction,
  refund;

  String get label {
    switch (this) {
      case FeeReason.regular:
        return '정기';
      case FeeReason.newMember:
        return '신규가입';
      case FeeReason.correction:
        return '정정';
      case FeeReason.refund:
        return '환불';
    }
  }

  int get bgColor {
    switch (this) {
      case FeeReason.regular:
        return 0xFFE8F5EE;
      case FeeReason.newMember:
        return 0xFFEAF2FF;
      case FeeReason.correction:
        return 0xFFFFF7E6;
      case FeeReason.refund:
        return 0xFFFFEBEB;
    }
  }

  int get fgColor {
    switch (this) {
      case FeeReason.regular:
        return 0xFF2A7A4A;
      case FeeReason.newMember:
        return 0xFF2563EB;
      case FeeReason.correction:
        return 0xFFB7791F;
      case FeeReason.refund:
        return 0xFFCC2222;
    }
  }
}

class AssociationFeePayment {
  final String id;
  final String clubId;
  final String clubName;
  final int amount;
  final FeeReason reason;
  final int? memberDelta;
  final String date;
  final String? txId;
  final String memo;

  const AssociationFeePayment({
    required this.id,
    required this.clubId,
    required this.clubName,
    required this.amount,
    this.reason = FeeReason.regular,
    this.memberDelta,
    required this.date,
    this.txId,
    this.memo = '',
  });

  String get formattedAmount {
    final s = amount.abs().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    final sign = amount < 0 ? '-' : '+';
    return '$sign$s원';
  }

  String get memberDeltaLabel {
    if (memberDelta == null) return '';
    final n = memberDelta!;
    if (n > 0) return '+$n명';
    if (n < 0) return '$n명';
    return '';
  }

  AssociationFeePayment copyWith({
    int? amount,
    FeeReason? reason,
    int? memberDelta,
    String? date,
    String? txId,
    String? memo,
  }) =>
      AssociationFeePayment(
        id: id,
        clubId: clubId,
        clubName: clubName,
        amount: amount ?? this.amount,
        reason: reason ?? this.reason,
        memberDelta: memberDelta ?? this.memberDelta,
        date: date ?? this.date,
        txId: txId ?? this.txId,
        memo: memo ?? this.memo,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'club_id': clubId,
        'club_name': clubName,
        'amount': amount,
        'reason': reason.name,
        'member_delta': memberDelta,
        'date': date,
        'tx_id': txId,
        'memo': memo,
      };

  factory AssociationFeePayment.fromMap(Map<String, dynamic> m) =>
      AssociationFeePayment(
        id: m['id'] ?? '',
        clubId: m['club_id'] ?? '',
        clubName: m['club_name'] ?? '',
        amount: (m['amount'] ?? 0) as int,
        reason: FeeReason.values.firstWhere(
          (r) => r.name == m['reason'],
          orElse: () => FeeReason.regular,
        ),
        memberDelta: m['member_delta'] as int?,
        date: m['date'] ?? '',
        txId: m['tx_id'] as String?,
        memo: m['memo'] ?? '',
      );
}

class ClubFeeSummary {
  final String clubId;
  final String clubName;
  final int totalPaid;
  final int paymentCount;
  final int regularCount;
  final int additionalCount;
  final String? lastPaidDate;
  final List<AssociationFeePayment> payments;

  const ClubFeeSummary({
    required this.clubId,
    required this.clubName,
    required this.totalPaid,
    required this.paymentCount,
    required this.regularCount,
    required this.additionalCount,
    this.lastPaidDate,
    this.payments = const [],
  });

  bool get hasRegularPaid => regularCount > 0;
  bool get isUnpaid => paymentCount == 0;

  factory ClubFeeSummary.from(
    String clubId,
    String clubName,
    List<AssociationFeePayment> all,
  ) {
    final relevant = all.where((p) => p.clubId == clubId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    int total = 0;
    int payCnt = 0;
    int regCnt = 0;
    int addCnt = 0;
    for (final p in relevant) {
      total += p.amount;
      if (p.reason == FeeReason.refund) continue;
      payCnt++;
      if (p.reason == FeeReason.regular) {
        regCnt++;
      } else if (p.reason == FeeReason.newMember ||
          p.reason == FeeReason.correction) {
        addCnt++;
      }
    }

    return ClubFeeSummary(
      clubId: clubId,
      clubName: clubName,
      totalPaid: total,
      paymentCount: payCnt,
      regularCount: regCnt,
      additionalCount: addCnt,
      lastPaidDate: relevant.isEmpty ? null : relevant.first.date,
      payments: relevant,
    );
  }
}
