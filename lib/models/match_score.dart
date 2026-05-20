// funminton 로컬 모드 — Firestore 미사용. Timestamp/FieldValue 자리에 plain DateTime/ISO string 사용.

/// 매치별 점수 + 팀 식별 — Firestore `matches/{tid}/rounds/{matchKey}` 미러.
///
/// doc ID 는 매치 위치만으로 안정 (`event|age|grade|group|matchNum`).
/// 팀 구성은 두 쌍의 필드로 저장:
///   - teamA / teamB : player IDs (players 컬렉션 doc ref) — 식별·비교 기준
///   - teamANames / teamBNames : 비정규화 이름 — 콘솔에서 바로 식별
/// 페어 변경 시 옛 점수의 자동 무효화는 클라이언트단 [scoreFor] 의 ID set 비교로
/// 처리 (이름 비교는 동명이인에 취약하므로 ID 기반).
class MatchScore {
  final String key;
  final int scoreA;
  final int scoreB;
  final List<String> teamA; // player IDs
  final List<String> teamB; // player IDs
  final List<String> teamANames; // 비정규화 이름
  final List<String> teamBNames;

  /// 저장한 사용자 uid. 6/17 보안규칙 마감용. 익명 계정도 uid 가 있음.
  final String createdBy;

  /// Firestore 가 채우는 server timestamp. 로컬 캐시에는 들어가지 않을 수 있음.
  final DateTime? updatedAt;

  /// 승자팀 서명 — PNG data URL (`data:image/png;base64,...`). 미서명 시 빈 문자열.
  /// 패자팀은 서명 면제 (실무상 진 팀은 자리를 떠나는 경우 많음).
  final String winnerSignature;

  /// 서명한 팀 식별 — 'A' (scoreA > scoreB) / 'B' (scoreB > scoreA) / '' (무서명/무승부).
  final String winnerSide;

  // ── Schedule metadata (콘솔 단독 대진표 렌더용) ─────────
  //
  // 점수 저장 시점에 함께 기록되는 매치 위치/시각 메타데이터. 미저장 매치는
  // 빈 값. ScheduleTab 의 _collectRows() 결과를 캐시한 BracketScreen
  // `_scheduleMetaByKey` 에서 lookup 해서 채운다.

  /// 매치 시작 시각 "HH:mm". 비어 있으면 schedule 미계산 시점.
  final String time;

  /// 일차 (1-base). 다일 대회에서 사용.
  final int day;

  /// 배정된 경기장 ID (Tournament.venues[].id). 비어 있으면 미배정.
  final String venueId;

  /// 글로벌 코트 번호 (전체 대회 누적). 1-base.
  final int globalCourt;

  /// 경기장 내 로컬 코트 번호. 1-base.
  final int localCourt;

  /// 조 이름 — "A조" / "본선" 등. doc ID 의 일부지만 콘솔 가독성 위해 명시 필드.
  final String groupName;

  const MatchScore({
    required this.key,
    required this.scoreA,
    required this.scoreB,
    required this.teamA,
    required this.teamB,
    required this.teamANames,
    required this.teamBNames,
    required this.createdBy,
    this.winnerSignature = '',
    this.winnerSide = '',
    this.updatedAt,
    this.time = '',
    this.day = 0,
    this.venueId = '',
    this.globalCourt = 0,
    this.localCourt = 0,
    this.groupName = '',
  });

  /// 현재 페어의 player IDs ([team1Ids]/[team2Ids]) 와 저장된 팀을 비교, 매치되면
  /// (team1점수, team2점수) 반환.
  /// - 정-방향 (저장 teamA == 현재 team1) → `(scoreA, scoreB)`
  /// - 역-방향 (저장 teamA == 현재 team2 의 swap) → `(scoreB, scoreA)`
  /// - 어느 쪽도 아니면 null (페어 재배정으로 무효화).
  /// 비교는 ID set equality — 팀 내부 선수 순서 무관, 동명이인 안전.
  /// 저장된 teamA/teamB 가 비어 있으면(legacy doc) null 반환 — 점수 표시 안 함.
  (int, int)? scoreFor(List<String> team1Ids, List<String> team2Ids) {
    if (teamA.isEmpty || teamB.isEmpty) return null;
    if (_sameSet(teamA, team1Ids) && _sameSet(teamB, team2Ids)) {
      return (scoreA, scoreB);
    }
    if (_sameSet(teamA, team2Ids) && _sameSet(teamB, team1Ids)) {
      return (scoreB, scoreA);
    }
    return null;
  }

  static bool _sameSet(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final s = {...a};
    return b.every(s.contains);
  }

  MatchScore copyWith({
    int? scoreA,
    int? scoreB,
    List<String>? teamA,
    List<String>? teamB,
    List<String>? teamANames,
    List<String>? teamBNames,
    String? createdBy,
    String? winnerSignature,
    String? winnerSide,
    String? time,
    int? day,
    String? venueId,
    int? globalCourt,
    int? localCourt,
    String? groupName,
  }) =>
      MatchScore(
        key: key,
        scoreA: scoreA ?? this.scoreA,
        scoreB: scoreB ?? this.scoreB,
        teamA: teamA ?? this.teamA,
        teamB: teamB ?? this.teamB,
        teamANames: teamANames ?? this.teamANames,
        teamBNames: teamBNames ?? this.teamBNames,
        createdBy: createdBy ?? this.createdBy,
        winnerSignature: winnerSignature ?? this.winnerSignature,
        winnerSide: winnerSide ?? this.winnerSide,
        updatedAt: updatedAt,
        time: time ?? this.time,
        day: day ?? this.day,
        venueId: venueId ?? this.venueId,
        globalCourt: globalCourt ?? this.globalCourt,
        localCourt: localCourt ?? this.localCourt,
        groupName: groupName ?? this.groupName,
      );

  /// Firestore write payload. updatedAt 는 server timestamp 가 자동 채움.
  Map<String, dynamic> toMap() => {
        'key': key,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'teamA': teamA,
        'teamB': teamB,
        'teamANames': teamANames,
        'teamBNames': teamBNames,
        'createdBy': createdBy,
        'winnerSignature': winnerSignature,
        'winnerSide': winnerSide,
        'time': time,
        'day': day,
        'venueId': venueId,
        'globalCourt': globalCourt,
        'localCourt': localCourt,
        'groupName': groupName,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  factory MatchScore.fromMap(Map<String, dynamic> m, {String? docId}) =>
      MatchScore(
        key: (m['key'] as String?) ?? docId ?? '',
        scoreA: (m['scoreA'] as num?)?.toInt() ?? 0,
        scoreB: (m['scoreB'] as num?)?.toInt() ?? 0,
        teamA: _strList(m['teamA']),
        teamB: _strList(m['teamB']),
        teamANames: _strList(m['teamANames']),
        teamBNames: _strList(m['teamBNames']),
        createdBy: (m['createdBy'] as String?) ?? '',
        winnerSignature: (m['winnerSignature'] as String?) ?? '',
        winnerSide: (m['winnerSide'] as String?) ?? '',
        updatedAt: () {
          final raw = m['updatedAt'];
          if (raw is String) return DateTime.tryParse(raw);
          if (raw is DateTime) return raw;
          return null;
        }(),
        time: (m['time'] as String?) ?? '',
        day: (m['day'] as num?)?.toInt() ?? 0,
        venueId: (m['venueId'] as String?) ?? '',
        globalCourt: (m['globalCourt'] as num?)?.toInt() ?? 0,
        localCourt: (m['localCourt'] as num?)?.toInt() ?? 0,
        groupName: (m['groupName'] as String?) ?? '',
      );

  /// SP 캐시용 JSON. updatedAt 은 캐시에서 빼고 stream snapshot 으로 복원.
  Map<String, dynamic> toJson() => {
        'key': key,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'teamA': teamA,
        'teamB': teamB,
        'teamANames': teamANames,
        'teamBNames': teamBNames,
        'createdBy': createdBy,
        'winnerSignature': winnerSignature,
        'winnerSide': winnerSide,
        'time': time,
        'day': day,
        'venueId': venueId,
        'globalCourt': globalCourt,
        'localCourt': localCourt,
        'groupName': groupName,
      };

  factory MatchScore.fromJson(Map<String, dynamic> j) => MatchScore(
        key: j['key']?.toString() ?? '',
        scoreA: (j['scoreA'] as num?)?.toInt() ?? 0,
        scoreB: (j['scoreB'] as num?)?.toInt() ?? 0,
        teamA: _strList(j['teamA']),
        teamB: _strList(j['teamB']),
        teamANames: _strList(j['teamANames']),
        teamBNames: _strList(j['teamBNames']),
        createdBy: j['createdBy']?.toString() ?? '',
        winnerSignature: j['winnerSignature']?.toString() ?? '',
        winnerSide: j['winnerSide']?.toString() ?? '',
        time: j['time']?.toString() ?? '',
        day: (j['day'] as num?)?.toInt() ?? 0,
        venueId: j['venueId']?.toString() ?? '',
        globalCourt: (j['globalCourt'] as num?)?.toInt() ?? 0,
        localCourt: (j['localCourt'] as num?)?.toInt() ?? 0,
        groupName: j['groupName']?.toString() ?? '',
      );

  static List<String> _strList(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const [];
}
