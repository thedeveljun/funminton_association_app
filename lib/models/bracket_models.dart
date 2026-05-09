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

  const TeamData({required this.name, required this.players});
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
  final String event; // '혼복'|'남복'|'여복'|'단식'
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
}
