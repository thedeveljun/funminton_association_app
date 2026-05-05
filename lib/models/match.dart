import 'player.dart';

/// 경기 유형
enum MatchType {
  sameGrade('동일급수'),
  balanced('균형급수'),
  free('자유');

  final String label;
  const MatchType(this.label);
}

/// 경기 상태
enum MatchStatus {
  waiting, // 대기
  ongoing, // 진행중
  done, // 완료
}

/// 경기 1건
class Match {
  final String id;
  final String tournamentId;
  final int courtNumber; // 전체 코트 번호
  final int localCourt; // 경기장 내 코트 번호
  final String venueId;
  final String venueName;
  final String venueColorHex; // '#1a3a8f'
  final MatchType type;
  final List<Player> teamA;
  final List<Player> teamB;
  final int day; // 1일차 | 2일차
  final String? date; // 'YYYY-MM-DD'
  final int gameIndex; // 대회 내 경기 순번

  int? scoreA;
  int? scoreB;
  MatchStatus status;

  Match({
    required this.id,
    required this.tournamentId,
    required this.courtNumber,
    required this.localCourt,
    required this.venueId,
    required this.venueName,
    this.venueColorHex = '#1a3a8f',
    required this.type,
    required this.teamA,
    required this.teamB,
    this.day = 1,
    this.date,
    required this.gameIndex,
    this.scoreA,
    this.scoreB,
    this.status = MatchStatus.waiting,
  });

  // ── 파생 속성 ──────────────────────────────
  bool get isDone => status == MatchStatus.done;
  bool get isOngoing => status == MatchStatus.ongoing;
  bool get teamAWins => isDone && (scoreA ?? 0) > (scoreB ?? 0);
  bool get teamBWins => isDone && (scoreB ?? 0) > (scoreA ?? 0);
  bool get isDraw => isDone && scoreA == scoreB;

  String get teamANames => teamA.map((p) => p.name).join(' / ');
  String get teamBNames => teamB.map((p) => p.name).join(' / ');

  String get teamAGrades => teamA.map((p) => p.grade).join('·');
  String get teamBGrades => teamB.map((p) => p.grade).join('·');

  String get courtLabel => '$venueName ${localCourt}코트';
  String get scoreDisplay => isDone ? '${scoreA ?? 0} : ${scoreB ?? 0}' : 'VS';

  // ── DB 변환 ────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'tournament_id': tournamentId,
        'court_number': courtNumber,
        'local_court': localCourt,
        'venue_id': venueId,
        'venue_name': venueName,
        'venue_color': venueColorHex,
        'type': type.name,
        'team_a_ids': teamA.map((p) => p.id).join(','),
        'team_b_ids': teamB.map((p) => p.id).join(','),
        'day': day,
        'date': date,
        'game_index': gameIndex,
        'score_a': scoreA,
        'score_b': scoreB,
        'status': status.name,
      };

  Match copyWith({int? scoreA, int? scoreB, MatchStatus? status}) => Match(
        id: id,
        tournamentId: tournamentId,
        courtNumber: courtNumber,
        localCourt: localCourt,
        venueId: venueId,
        venueName: venueName,
        venueColorHex: venueColorHex,
        type: type,
        teamA: teamA,
        teamB: teamB,
        day: day,
        date: date,
        gameIndex: gameIndex,
        scoreA: scoreA ?? this.scoreA,
        scoreB: scoreB ?? this.scoreB,
        status: status ?? this.status,
      );
}

/// 연령·급수별 경기장 배정 키
class AssignKey {
  final String decadeKey; // '20','30','40','50','60','70'
  final String grade; // 'A','B','C','D','초심'

  const AssignKey(this.decadeKey, this.grade);

  @override
  bool operator ==(Object other) =>
      other is AssignKey &&
      other.decadeKey == decadeKey &&
      other.grade == grade;

  @override
  int get hashCode => Object.hash(decadeKey, grade);

  @override
  String toString() => '$decadeKey-$grade';
}
