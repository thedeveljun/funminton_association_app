/// 협회가 주관하지 않지만 일정상 참가/참고해야 할 외부 대회를 기록.
/// 예: '생활대축전배드민턴대회' (경기도지사기대회 주최가 아님) 등.
/// Tournament 모델과는 별개로 관리되며, 대진/재정 등에 영향을 주지 않음.
class ScheduledTournament {
  final String id;
  final String name; // 대회명 (예: 2026 생활대축전배드민턴대회)
  final String host; // 주최 (예: 대한배드민턴협회, 경기도배드민턴협회)
  final String location; // 개최 지역/장소 (예: 경기도 수원시 / 수원실내체육관)
  final String startDate; // YYYY-MM-DD
  final String endDate; // YYYY-MM-DD (단일 일자면 startDate와 동일)
  final bool attending; // 참가 예정 여부
  final String memo; // 비고/안내

  const ScheduledTournament({
    required this.id,
    required this.name,
    this.host = '',
    this.location = '',
    required this.startDate,
    this.endDate = '',
    this.attending = false,
    this.memo = '',
  });

  ScheduledTournament copyWith({
    String? name,
    String? host,
    String? location,
    String? startDate,
    String? endDate,
    bool? attending,
    String? memo,
  }) =>
      ScheduledTournament(
        id: id,
        name: name ?? this.name,
        host: host ?? this.host,
        location: location ?? this.location,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        attending: attending ?? this.attending,
        memo: memo ?? this.memo,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'host': host,
        'location': location,
        'start_date': startDate,
        'end_date': endDate,
        'attending': attending ? 1 : 0,
        'memo': memo,
      };

  factory ScheduledTournament.fromMap(Map<String, dynamic> m) =>
      ScheduledTournament(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        host: (m['host'] ?? '').toString(),
        location: (m['location'] ?? '').toString(),
        startDate: (m['start_date'] ?? '').toString(),
        endDate: (m['end_date'] ?? '').toString(),
        attending: (m['attending'] ?? 0) == 1,
        memo: (m['memo'] ?? '').toString(),
      );
}
