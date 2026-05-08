import 'dart:math';
import '../../models/match.dart';
import '../../models/player.dart';
import '../../models/venue.dart';

/// 대진표 자동 생성 서비스
/// 알고리즘 원칙:
/// 1. 동일 클럽 회피
/// 2. 급수 균형
/// 3. 코트 순환 배정
/// 4. 동시 경기 금지
/// 5. 연속 경기 지양 (최소 1경기 휴식)
/// 6. 순위: 승수 > 승자승 > 세트득실 > 점수득실
class BracketService {
  BracketService._();

  static final Random _rng = Random();

  // ── 대진표 생성 메인 ──────────────────────────
  static List<Match> generate({
    required String tournamentId,
    required List<Player> players,
    required List<Venue> venues,
    required int totalDays,
    required Map<AssignKey, String> assignMap, // AssignKey → venueId
    int gamesPerPerson = 3,
  }) {
    if (players.length < 4 || venues.isEmpty) return [];

    final matches = <Match>[];

    // ── 코트 맵 구성 (코트번호 → venue 정보) ──
    final courtMap = <int, _CourtInfo>{};
    int courtNum = 1;
    for (final v in venues) {
      for (int c = 1; c <= v.courts; c++) {
        courtMap[courtNum] = _CourtInfo(
          venueId: v.id,
          venueName: v.name,
          colorHex: v.colorHex,
          localCourt: c,
        );
        courtNum++;
      }
    }
    final totalCourts = courtMap.length;
    if (totalCourts == 0) return [];

    // ── 경기장별 선수 분류 ────────────────────
    final venueGroups = <String, List<Player>>{};
    for (final v in venues) venueGroups[v.id] = [];

    for (final p in players) {
      final vid = _getVenueId(p, assignMap, venues);
      venueGroups[vid]!.add(p);
    }

    // ── 경기장별 대진 생성 ────────────────────
    int gameIdx = 1;
    for (final venue in venues) {
      final vPlayers = venueGroups[venue.id] ?? [];
      if (vPlayers.length < 4) continue;

      final vCourts = courtMap.entries
          .where((e) => e.value.venueId == venue.id)
          .map((e) => e.key)
          .toList()
        ..sort();
      if (vCourts.isEmpty) continue;

      final totalGames = (vPlayers.length ~/ 4) * gamesPerPerson;
      final byGrade = _groupByGrade(vPlayers);

      // 선수별 최근 경기 추적 (연속 경기 방지)
      final lastGameOf = <String, int>{};

      for (int r = 0; r < totalGames; r++) {
        const rtype = MatchType.sameGrade; // 모든 대회는 동일 급수
        final cNum = vCourts[r % vCourts.length];
        final ci = courtMap[cNum]!;
        final day = totalDays == 2 ? (r < (totalGames / 2).ceil() ? 1 : 2) : 1;

        // 팀 구성 (동일 클럽 회피 + 연속 경기 지양)
        final teams = _pickTeams(
          vPlayers,
          byGrade,
          lastGameOf,
          r,
        );
        if (teams == null) continue;

        // 경기 등록
        matches.add(Match(
          id: '${tournamentId}_m$gameIdx',
          tournamentId: tournamentId,
          courtNumber: cNum,
          localCourt: ci.localCourt,
          venueId: ci.venueId,
          venueName: ci.venueName,
          venueColorHex: ci.colorHex,
          type: rtype,
          teamA: teams[0],
          teamB: teams[1],
          day: day,
          gameIndex: gameIdx,
        ));

        // 선수별 최근 경기 기록
        for (final p in [...teams[0], ...teams[1]]) {
          lastGameOf[p.id] = r;
        }
        gameIdx++;
      }
    }

    return matches;
  }

  // ── 팀 구성 ───────────────────────────────
  static List<List<Player>>? _pickTeams(
    List<Player> all,
    Map<String, List<Player>> byGrade,
    Map<String, int> lastGame,
    int currentRound,
  ) {
    // 모든 대회는 동일 급수 — 4명 이상인 급수 중 랜덤 선택, 부족하면 전체 풀 사용
    final valid = byGrade.entries.where((e) => e.value.length >= 4).toList();
    final pool = valid.isEmpty
        ? List<Player>.from(all)
        : List<Player>.from(valid[_rng.nextInt(valid.length)].value);

    // 연속 경기 지양: 직전 경기 참여자 뒤로
    pool.sort((a, b) {
      final la = lastGame[a.id] ?? -999;
      final lb = lastGame[b.id] ?? -999;
      return la.compareTo(lb); // 더 오래 쉰 선수 앞으로
    });

    if (pool.length < 4) return null;

    // 4명 선택 후 동일 클럽 회피
    var a1 = pool[0], a2 = pool[1], b1 = pool[2], b2 = pool[3];

    // A팀 내 같은 클럽 → swap a2 ↔ b1
    if (a1.clubId == a2.clubId && a1.clubId.isNotEmpty) {
      final tmp = a2;
      a2 = b1;
      b1 = tmp;
    }
    // B팀 내 같은 클럽 → swap b2 ↔ a2
    if (b1.clubId == b2.clubId && b1.clubId.isNotEmpty) {
      final tmp = b2;
      b2 = a2;
      a2 = tmp;
    }
    // 재검사
    if (a1.clubId == a2.clubId && a1.clubId.isNotEmpty) {
      // 더 깊은 swap
      if (pool.length > 4) {
        a2 = pool[4];
      }
    }

    return [
      [a1, a2],
      [b1, b2]
    ];
  }

  // ── 선수 경기장 배정 ──────────────────────
  static String _getVenueId(
    Player p,
    Map<AssignKey, String> assignMap,
    List<Venue> venues,
  ) {
    // assignMap 의 grade 키는 '조' 없는 짧은 라벨('A','B','C','D','초심').
    // Player.grade 는 'A조'/'B조'/... 라서 gradeShort 로 정규화해야 매칭됨.
    final key = AssignKey(p.decadeKey, p.gradeShort);
    return assignMap[key] ?? venues.first.id;
  }

  // ── 급수별 그룹화 ─────────────────────────
  static Map<String, List<Player>> _groupByGrade(List<Player> players) {
    final map = <String, List<Player>>{};
    for (final p in players) {
      map.putIfAbsent(p.grade, () => []).add(p);
    }
    return map;
  }

  // ── 순위 계산 ────────────────────────────
  /// 순서: 승수 → 승자승 → 세트득실 → 점수득실
  static List<PlayerStats> calcRankings({
    required List<Player> players,
    required List<Match> matches,
  }) {
    final statsMap = <String, PlayerStats>{};
    for (final p in players) {
      statsMap[p.id] = PlayerStats(player: p);
    }

    for (final m in matches.where((m) => m.isDone)) {
      final aWin = m.teamAWins;
      final sa = m.scoreA ?? 0;
      final sb = m.scoreB ?? 0;

      for (final p in m.teamA) {
        final s = statsMap[p.id];
        if (s == null) continue;
        s.games++;
        if (aWin) {
          s.wins++;
          s.points += 30;
        } else {
          s.losses++;
          s.points += 10;
        }
        s.scoreDiff += sa - sb;
      }
      for (final p in m.teamB) {
        final s = statsMap[p.id];
        if (s == null) continue;
        s.games++;
        if (!aWin) {
          s.wins++;
          s.points += 30;
        } else {
          s.losses++;
          s.points += 10;
        }
        s.scoreDiff += sb - sa;
      }
    }

    // 승자승 계산
    _calcHeadToHead(statsMap, matches);

    final ranked = statsMap.values.where((s) => s.games > 0).toList()
      ..sort((a, b) {
        if (b.points != a.points) return b.points.compareTo(a.points);
        if (b.wins != a.wins) return b.wins.compareTo(a.wins);
        if (b.h2hWins != a.h2hWins) return b.h2hWins.compareTo(a.h2hWins);
        if (b.scoreDiff != a.scoreDiff)
          return b.scoreDiff.compareTo(a.scoreDiff);
        return 0;
      });

    // 등수 부여
    for (int i = 0; i < ranked.length; i++) {
      ranked[i].rank = i + 1;
    }
    return ranked;
  }

  static void _calcHeadToHead(
    Map<String, PlayerStats> statsMap,
    List<Match> matches,
  ) {
    for (final m in matches.where((m) => m.isDone)) {
      if (m.teamAWins) {
        for (final p in m.teamA) {
          statsMap[p.id]?.h2hWins++;
        }
      } else if (m.teamBWins) {
        for (final p in m.teamB) {
          statsMap[p.id]?.h2hWins++;
        }
      }
    }
  }
}

// ── 내부 헬퍼 클래스 ──────────────────────────
class _CourtInfo {
  final String venueId;
  final String venueName;
  final String colorHex;
  final int localCourt;

  const _CourtInfo({
    required this.venueId,
    required this.venueName,
    required this.colorHex,
    required this.localCourt,
  });
}

/// 선수 성적 통계
class PlayerStats {
  final Player player;
  int rank = 0;
  int games = 0;
  int wins = 0;
  int losses = 0;
  int points = 0;
  int scoreDiff = 0;
  int h2hWins = 0;

  PlayerStats({required this.player});

  String get record => '${wins}승 ${losses}패';
}
