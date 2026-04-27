/// 클럽의 협회 납부 현황 상태
/// (협회비·당해년도 분담금 합계·이사회비를 종합한 라벨)
enum ClubPayStatus {
  fullyPaid, // 완납 — 협회비·분담금·이사회비 모두 납부
  partialPaid, // 일부납부 — 일부만 납부
  unpaid, // 미납 — 아직 미납
}

class Club {
  final String id;
  final String name;
  final String region; // 소속 시·구 (예: '과천시', '서초구')
  final String presidentName;
  final String presidentPhone;
  final String secretaryName;
  final String secretaryPhone;
  final String venue;
  final String foundedAt;
  final String practiceDay;
  final String practiceTime;
  final int memberCount;
  final ClubPayStatus payStatus; // 수동 라벨 (관리자 표시용)
  final String status;
  final int countA;
  final int countB;
  final int countC;
  final int countD;
  final int countBeginner;

  // ── 납부 항목별 상태 (당해년도 기준) ─────────────────
  final bool assocFeePaid; // 협회비 납부 여부 (정기 회비)
  final bool sharePaid; // 당해년도 모든 대회 분담금 완납 여부 (캐시 — 실제 분담금은 대회별로 별도 관리)
  final bool boardFeePaid; // 이사회비 납부 여부 (회장·총무)

  const Club({
    required this.id,
    required this.name,
    this.region = '',
    this.presidentName = '',
    this.presidentPhone = '',
    this.secretaryName = '',
    this.secretaryPhone = '',
    this.venue = '',
    this.foundedAt = '',
    this.practiceDay = '',
    this.practiceTime = '',
    this.memberCount = 0,
    this.payStatus = ClubPayStatus.unpaid,
    this.status = '활성',
    this.countA = 0,
    this.countB = 0,
    this.countC = 0,
    this.countD = 0,
    this.countBeginner = 0,
    this.assocFeePaid = false,
    this.sharePaid = false,
    this.boardFeePaid = false,
  });

  /// 완납 여부 (기존 feePaid 호환)
  bool get feePaid => payStatus == ClubPayStatus.fullyPaid;

  /// 3개 납부 boolean으로 자동 산출한 납부 현황
  /// (수동 `payStatus`와 비교하여 동기화 검증에 사용)
  ClubPayStatus get computedPayStatus {
    final paidCount =
        (assocFeePaid ? 1 : 0) + (sharePaid ? 1 : 0) + (boardFeePaid ? 1 : 0);
    if (paidCount == 3) return ClubPayStatus.fullyPaid;
    if (paidCount == 0) return ClubPayStatus.unpaid;
    return ClubPayStatus.partialPaid;
  }

  /// 납부 현황 라벨
  String get payStatusLabel {
    switch (payStatus) {
      case ClubPayStatus.fullyPaid:
        return '완납';
      case ClubPayStatus.partialPaid:
        return '일부납부';
      case ClubPayStatus.unpaid:
        return '미납';
    }
  }

  /// 납부 현황 배경색
  static const Map<ClubPayStatus, int> payBgColor = {
    ClubPayStatus.fullyPaid: 0xFFC6F6D5,
    ClubPayStatus.partialPaid: 0xFFFEEBC8,
    ClubPayStatus.unpaid: 0xFFE2E8F0,
  };

  /// 납부 현황 텍스트 색
  static const Map<ClubPayStatus, int> payFgColor = {
    ClubPayStatus.fullyPaid: 0xFF1C4532,
    ClubPayStatus.partialPaid: 0xFF744210,
    ClubPayStatus.unpaid: 0xFF4A5568,
  };

  String get initials => name.length >= 2 ? name.substring(0, 2) : name;

  /// 부분 업데이트용
  Club copyWith({
    String? name,
    String? region,
    String? presidentName,
    String? presidentPhone,
    String? secretaryName,
    String? secretaryPhone,
    String? venue,
    String? foundedAt,
    String? practiceDay,
    String? practiceTime,
    int? memberCount,
    ClubPayStatus? payStatus,
    String? status,
    int? countA,
    int? countB,
    int? countC,
    int? countD,
    int? countBeginner,
    bool? assocFeePaid,
    bool? sharePaid,
    bool? boardFeePaid,
  }) =>
      Club(
        id: id,
        name: name ?? this.name,
        region: region ?? this.region,
        presidentName: presidentName ?? this.presidentName,
        presidentPhone: presidentPhone ?? this.presidentPhone,
        secretaryName: secretaryName ?? this.secretaryName,
        secretaryPhone: secretaryPhone ?? this.secretaryPhone,
        venue: venue ?? this.venue,
        foundedAt: foundedAt ?? this.foundedAt,
        practiceDay: practiceDay ?? this.practiceDay,
        practiceTime: practiceTime ?? this.practiceTime,
        memberCount: memberCount ?? this.memberCount,
        payStatus: payStatus ?? this.payStatus,
        status: status ?? this.status,
        countA: countA ?? this.countA,
        countB: countB ?? this.countB,
        countC: countC ?? this.countC,
        countD: countD ?? this.countD,
        countBeginner: countBeginner ?? this.countBeginner,
        assocFeePaid: assocFeePaid ?? this.assocFeePaid,
        sharePaid: sharePaid ?? this.sharePaid,
        boardFeePaid: boardFeePaid ?? this.boardFeePaid,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'region': region,
        'president_name': presidentName,
        'president_phone': presidentPhone,
        'secretary_name': secretaryName,
        'secretary_phone': secretaryPhone,
        'venue': venue,
        'founded_at': foundedAt,
        'practice_day': practiceDay,
        'practice_time': practiceTime,
        'member_count': memberCount,
        'pay_status': payStatus.index,
        'status': status,
        'count_a': countA,
        'count_b': countB,
        'count_c': countC,
        'count_d': countD,
        'count_beginner': countBeginner,
        'assoc_fee_paid': assocFeePaid ? 1 : 0,
        'share_paid': sharePaid ? 1 : 0,
        'board_fee_paid': boardFeePaid ? 1 : 0,
      };

  factory Club.fromMap(Map<String, dynamic> m) => Club(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        region: m['region'] ?? '',
        presidentName: m['president_name'] ?? '',
        presidentPhone: m['president_phone'] ?? '',
        secretaryName: m['secretary_name'] ?? '',
        secretaryPhone: m['secretary_phone'] ?? '',
        venue: m['venue'] ?? '',
        foundedAt: m['founded_at'] ?? '',
        practiceDay: m['practice_day'] ?? '',
        practiceTime: m['practice_time'] ?? '',
        memberCount: m['member_count'] ?? 0,
        payStatus: ClubPayStatus.values[m['pay_status'] ?? 2],
        status: m['status'] ?? '활성',
        countA: m['count_a'] ?? 0,
        countB: m['count_b'] ?? 0,
        countC: m['count_c'] ?? 0,
        countD: m['count_d'] ?? 0,
        countBeginner: m['count_beginner'] ?? 0,
        assocFeePaid: (m['assoc_fee_paid'] ?? 0) == 1,
        sharePaid: (m['share_paid'] ?? 0) == 1,
        boardFeePaid: (m['board_fee_paid'] ?? 0) == 1,
      );
}
