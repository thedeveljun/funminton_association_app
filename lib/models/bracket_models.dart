// 배드민턴 대진표 자동 생성 — 데이터 모델

/// 대진 형식 분류.
/// - roundRobin: 풀리그 단독 (다각형 시각화 권장)
/// - polygon:    풀리그 단독 + 다각형 강조 (3~6팀)
/// - knockout:   토너먼트 단독
/// - groupKnockout: 예선 풀리그 + 본선 토너먼트
/// - groupRoundRobin: 예선 풀리그 + 본선 풀리그 (3강 등)
enum BracketKind {
  roundRobin,
  polygon,
  knockout,
  groupKnockout,
  groupRoundRobin,
}

/// 풀리그 다각형 시각화 힌트.
/// none = 직선/일자 (2팀) 또는 7팀 이상.
enum ShapeHint { none, triangle, square, pentagon, hexagon }

extension ShapeHintLabel on ShapeHint {
  String get label {
    switch (this) {
      case ShapeHint.triangle:
        return '삼각형';
      case ShapeHint.square:
        return '사각형';
      case ShapeHint.pentagon:
        return '오각형';
      case ShapeHint.hexagon:
        return '육각형';
      case ShapeHint.none:
        return '';
    }
  }
}

class TeamData {
  final String name;
  final List<String> players;

  /// 매치 점수 저장 시 Firestore `matches/{tid}/rounds/*` 의 teamA/teamB 필드에
  /// 들어가는 player ID 리스트. `players` 와 같은 인덱스로 정렬. 본선 placeholder
  /// 등 ID 가 없을 때는 빈 리스트.
  final List<String> playerIds;

  const TeamData({
    required this.name,
    required this.players,
    this.playerIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'players': players,
        'playerIds': playerIds,
      };

  factory TeamData.fromMap(Map<String, dynamic> m) => TeamData(
        name: (m['name'] ?? '').toString(),
        players: (m['players'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        playerIds: (m['playerIds'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

class GroupInfo {
  final int size;
  final String name;
  final int matches;

  /// 본선 진출자 수 (각 조에서 몇 팀이 본선行).
  /// finals 가 null 이면 의미 없음.
  final int qualifiers;

  /// 풀리그 시각화 힌트 (조 단위).
  final ShapeHint shape;

  const GroupInfo({
    required this.size,
    required this.name,
    required this.matches,
    this.qualifiers = 0,
    this.shape = ShapeHint.none,
  });

  Map<String, dynamic> toMap() => {
        'size': size,
        'name': name,
        'matches': matches,
        'qualifiers': qualifiers,
        'shape': shape.name,
      };

  factory GroupInfo.fromMap(Map<String, dynamic> m) => GroupInfo(
        size: (m['size'] ?? 0) as int,
        name: (m['name'] ?? '').toString(),
        matches: (m['matches'] ?? 0) as int,
        qualifiers: (m['qualifiers'] ?? 0) as int,
        shape: ShapeHint.values.firstWhere(
          (e) => e.name == m['shape'],
          orElse: () => ShapeHint.none,
        ),
      );
}

class FinalsInfo {
  final int size;
  final String name;
  final int matches;

  /// 본선이 토너먼트면 false, 풀리그면 true.
  final bool isRoundRobin;

  const FinalsInfo({
    required this.size,
    required this.name,
    required this.matches,
    this.isRoundRobin = false,
  });

  Map<String, dynamic> toMap() => {
        'size': size,
        'name': name,
        'matches': matches,
        'is_round_robin': isRoundRobin,
      };

  factory FinalsInfo.fromMap(Map<String, dynamic> m) => FinalsInfo(
        size: (m['size'] ?? 0) as int,
        name: (m['name'] ?? '').toString(),
        matches: (m['matches'] ?? 0) as int,
        isRoundRobin: (m['is_round_robin'] ?? false) as bool,
      );
}

class BracketFormat {
  final BracketKind kind;
  final List<GroupInfo> groups;
  final FinalsInfo? finals;
  final String format;
  final bool recommended;

  const BracketFormat({
    required this.kind,
    required this.groups,
    this.finals,
    required this.format,
    this.recommended = false,
  });

  int get totalMatches {
    final prelim = groups.fold<int>(0, (sum, g) => sum + g.matches);
    return prelim + (finals?.matches ?? 0);
  }

  /// 각 조 진출자 합 = 본선 사이즈여야 정합.
  int get totalQualifiers =>
      groups.fold<int>(0, (s, g) => s + g.qualifiers);

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'groups': groups.map((g) => g.toMap()).toList(),
        'finals': finals?.toMap(),
        'format': format,
        'recommended': recommended,
      };

  factory BracketFormat.fromMap(Map<String, dynamic> m) => BracketFormat(
        kind: BracketKind.values.firstWhere(
          (e) => e.name == m['kind'],
          orElse: () => BracketKind.roundRobin,
        ),
        groups: (m['groups'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => GroupInfo.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        finals: m['finals'] is Map
            ? FinalsInfo.fromMap(Map<String, dynamic>.from(m['finals'] as Map))
            : null,
        format: (m['format'] ?? '').toString(),
        recommended: (m['recommended'] ?? false) as bool,
      );
}

class MatchInfo {
  final int num_;
  final int court;
  final int team1Index;
  final int team2Index;
  final String time;

  const MatchInfo({
    required this.num_,
    required this.court,
    required this.team1Index,
    required this.team2Index,
    required this.time,
  });
}

/// 단일 대진표 단위. (종목 × 연령 × 급수)
/// venueId 는 _assignMap 에서 가져온 경기장 식별자.
class Division {
  final String event; // '혼복'|'남복'|'여복'
  final String ageGroup; // 예: '40' / '전체'
  final String grade; // 예: 'A조'
  final List<TeamData> teams;
  final BracketFormat format;
  final String venueId;

  const Division({
    required this.event,
    required this.ageGroup,
    required this.grade,
    required this.teams,
    required this.format,
    this.venueId = '',
  });

  /// 화면 표시용 라벨. "혼복 / 40 / A조"
  String get label => '$event / $ageGroup / $grade';

  Map<String, dynamic> toMap() => {
        'event': event,
        'age_group': ageGroup,
        'grade': grade,
        'teams': teams.map((t) => t.toMap()).toList(),
        'format': format.toMap(),
        'venue_id': venueId,
      };

  factory Division.fromMap(Map<String, dynamic> m) => Division(
        event: (m['event'] ?? '').toString(),
        ageGroup: (m['age_group'] ?? '').toString(),
        grade: (m['grade'] ?? '').toString(),
        teams: (m['teams'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => TeamData.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        format: BracketFormat.fromMap(
            Map<String, dynamic>.from(m['format'] as Map? ?? const {})),
        venueId: (m['venue_id'] ?? '').toString(),
      );
}
