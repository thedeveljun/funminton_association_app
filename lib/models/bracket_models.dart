// 배드민턴 대진표 자동 생성 — 데이터 모델
// (reference/bracket_reference.dart SECTION 1)

class TeamData {
  final String name;
  final List<String> players;

  const TeamData({required this.name, required this.players});
}

class GroupInfo {
  final int size;
  final String name;
  final int matches;

  const GroupInfo({
    required this.size,
    required this.name,
    required this.matches,
  });
}

class FinalsInfo {
  final int size;
  final String name;
  final int matches;

  const FinalsInfo({
    required this.size,
    required this.name,
    required this.matches,
  });
}

class BracketFormat {
  final List<GroupInfo> groups;
  final FinalsInfo? finals;
  final String format;
  final bool recommended;

  const BracketFormat({
    required this.groups,
    this.finals,
    required this.format,
    this.recommended = false,
  });

  int get totalMatches {
    final prelim = groups.fold<int>(0, (sum, g) => sum + g.matches);
    return prelim + (finals?.matches ?? 0);
  }
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
