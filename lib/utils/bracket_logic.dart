// 배드민턴 대진표 자동 생성 — 알고리즘 (순수 함수)

import '../models/bracket_models.dart';
import '../models/player.dart';
import '../models/tournament.dart';

/// 다각형 시각화 힌트.
ShapeHint _shapeOf(int size) {
  switch (size) {
    case 3:
      return ShapeHint.triangle;
    case 4:
      return ShapeHint.square;
    case 5:
      return ShapeHint.pentagon;
    case 6:
      return ShapeHint.hexagon;
    default:
      return ShapeHint.none;
  }
}

/// 총 팀 수를 k개 조로 균등 분할 (앞쪽 조가 1팀 더 많음).
List<int> _split(int total, int k) {
  if (k <= 0) return const [];
  final base = total ~/ k;
  final rem = total % k;
  return List.generate(k, (i) => base + (i < rem ? 1 : 0));
}

/// max group size 가 4 를 넘지 않으면서 min size 가 3 이상인,
/// 가장 작은 K 로 분할. 단독 풀리그(N≤5) 외 모든 케이스에 사용.
/// 5팀 조는 단독 풀리그 외에는 허용하지 않음 (협회 운영 합리성).
List<int> _splitMax4(int total) {
  for (int k = 2; k <= total ~/ 3; k++) {
    final s = _split(total, k);
    if (s.first <= 4 && s.last >= 3) return s;
  }
  // fallback: 강제 max 4 (min 보장 못함 — 매우 작은 N 케이스는 별도 분기에서 차단됨)
  final k = (total / 4).ceil();
  return _split(total, k);
}

/// 조 수 K 와 N 에 따라 본선 size 자동 결정.
/// K=3 만 본선 풀리그(3강), 그 외는 토너먼트 (4/8/16/32강).
/// 가능한 한 K * q = fSize 정수 비율을 유지하되,
/// 조 수가 비표준이면 부전승(BYE)으로 메꾼다.
({int fSize, bool isRoundRobin}) _decideFinals(int K, int n) {
  if (K == 2) {
    // n=6,7 → 결승. n=8 → 4강 (q=2)
    return (fSize: n >= 8 ? 4 : 2, isRoundRobin: false);
  }
  if (K == 3) {
    // 본선 풀리그(3강). 각 조 1위만 진출
    return (fSize: 3, isRoundRobin: true);
  }
  if (K == 4) {
    // n<16 → 4강 (q=1), n>=16 → 8강 (q=2)
    return (fSize: n >= 16 ? 8 : 4, isRoundRobin: false);
  }
  if (K <= 7) {
    // 5,6,7 → 8강 토너먼트 (BYE: 8-K)
    return (fSize: 8, isRoundRobin: false);
  }
  if (K == 8) {
    return (fSize: n >= 32 ? 16 : 8, isRoundRobin: false);
  }
  if (K <= 15) {
    return (fSize: 16, isRoundRobin: false);
  }
  if (K == 16) {
    return (fSize: n >= 64 ? 32 : 16, isRoundRobin: false);
  }
  return (fSize: 32, isRoundRobin: false);
}

GroupInfo _group(int size, int idx, int qualifiers) {
  return GroupInfo(
    size: size,
    name: '${String.fromCharCode(65 + idx)}조',
    matches: size * (size - 1) ~/ 2,
    qualifiers: qualifiers,
    shape: _shapeOf(size),
  );
}

/// 본선 토너먼트 명칭 ('4강','8강',...). 풀리그 본선은 별도 처리.
const Map<int, String> _knockoutNames = {
  2: '결승',
  4: '4강',
  8: '8강',
  16: '16강',
  32: '32강',
};

/// 팀 수에 따라 대진방식 자동 결정. 3팀 미만이면 null
/// (2팀은 경기로 인정하지 않음 — 부서 자체가 만들어지지 않음).
BracketFormat? determineFormat(int n) {
  if (n < 3) return null;

  // ── 단독 풀리그 (3~5팀) ───────────────────
  if (n <= 5) {
    final shape = _shapeOf(n);
    return BracketFormat(
      kind: BracketKind.polygon,
      groups: [
        GroupInfo(
          size: n,
          name: '본선',
          matches: n * (n - 1) ~/ 2,
          qualifiers: n,
          shape: shape,
        ),
      ],
      format: '$n팀 풀리그',
    );
  }

  // ── 예선 + 본선 (6팀 이상) ────────────────
  // 모든 조 size ∈ {3, 4} 보장. 5팀 조는 단독 풀리그(N=5)에서만 허용.
  final sizes = _splitMax4(n);
  final K = sizes.length;

  // 본선 결정
  final f = _decideFinals(K, n);
  final fSize = f.fSize;
  final isFinalsRoundRobin = f.isRoundRobin;

  // 11팀 [4,4,3] → 본선 풀리그(3강): 11개 클럽 표준 운영
  final recommended = n == 11;

  // qualifiers per group: fSize >= K*2 면 q=2, 아니면 q=1.
  // K * q < fSize 인 경우 본선에 (fSize - K*q) 자리는 부전승(BYE).
  final qPerGroup = fSize >= K * 2 ? 2 : 1;

  final groups = <GroupInfo>[];
  for (int i = 0; i < sizes.length; i++) {
    groups.add(_group(sizes[i], i, qPerGroup));
  }

  final fName = isFinalsRoundRobin
      ? '본선($fSize강)'
      : (_knockoutNames[fSize] ?? '$fSize강');
  final fMatches =
      isFinalsRoundRobin ? fSize * (fSize - 1) ~/ 2 : fSize - 1;

  final formatStr = isFinalsRoundRobin
      ? '$K개 조 풀리그 + $fName 풀리그'
      : '$K개 조 풀리그 + $fName 토너먼트';

  return BracketFormat(
    kind: isFinalsRoundRobin
        ? BracketKind.groupRoundRobin
        : BracketKind.groupKnockout,
    groups: groups,
    finals: FinalsInfo(
      size: fSize,
      name: fName,
      matches: fMatches,
      isRoundRobin: isFinalsRoundRobin,
    ),
    format: formatStr,
    recommended: recommended,
  );
}

// ═══════════════════════════════════════════════════════
//  대회 규모·포맷 권장 (운영진 의사결정 보조)
// ═══════════════════════════════════════════════════════

/// 부서별 권장 포맷.
class FormatRecommendation {
  /// 권장 포맷 이름. 예: '풀리그', '단일 토너먼트 + 위로조', '예선+본선'
  final String label;

  /// 운영진이 보고 판단할 짧은 사유. 예: '모든 팀 3경기 보장'
  final String reason;

  /// 한 팀이 평균적으로 치르는 최소 경기 수.
  final int minMatchesPerTeam;

  /// 현재 앱이 이 포맷을 실제로 지원하는지. false면 안내만 하고 실제 생성은 fallback.
  final bool supportedNow;

  const FormatRecommendation({
    required this.label,
    required this.reason,
    required this.minMatchesPerTeam,
    this.supportedNow = true,
  });
}

/// 팀 수 기반 권장 포맷 결정.
/// - 3~5팀: 풀리그 (모든 팀 N-1 경기)
/// - 6~8팀: 단일 토너먼트 + 위로조 (1라운드 패자도 추가 경기) — 동호인 만족도↑
/// - 9~16팀: 조별예선 + 본선 (소·중규모 표준)
/// - 17팀 이상: 조별예선 + 본선 (16강 이상)
FormatRecommendation recommendFormat(int teams) {
  if (teams < 3) {
    return const FormatRecommendation(
      label: '부서 미생성',
      reason: '3팀 미만은 경기로 인정하지 않음',
      minMatchesPerTeam: 0,
    );
  }
  if (teams <= 5) {
    return FormatRecommendation(
      label: '풀리그',
      reason: '모든 팀 ${teams - 1}경기 보장 — 만족도 높음',
      minMatchesPerTeam: teams - 1,
    );
  }
  if (teams <= 8) {
    return const FormatRecommendation(
      label: '단일 토너먼트 + 위로조',
      reason: '1라운드 패자도 위로조 진출 — 한 번 지고 끝나지 않음 (현재 버전은 예선+본선으로 대체)',
      minMatchesPerTeam: 2,
      supportedNow: false,
    );
  }
  if (teams <= 16) {
    return FormatRecommendation(
      label: '예선+본선 (8강)',
      reason: '$teams팀: 3~4팀 조별예선 → 본선 토너먼트',
      minMatchesPerTeam: 3,
    );
  }
  return FormatRecommendation(
    label: '예선+본선 (16강↑)',
    reason: '$teams팀: 조별예선 → 16강 이상 본선',
    minMatchesPerTeam: 3,
  );
}

/// 대회 전체 규모 tier 판정 (총 참가자 수 기준).
String tournamentScaleTier(int totalParticipants) {
  if (totalParticipants <= 0) return '미정';
  if (totalParticipants <= 50) return '소규모 (~50명, 클럽 대회)';
  if (totalParticipants <= 150) return '중규모 (~150명, 구청급)';
  if (totalParticipants <= 500) return '시 단위 (~500명, 협회)';
  if (totalParticipants <= 1500) return '광역 (~1500명)';
  return '특대형 (1500명+)';
}

/// 표준 round-robin (circle method) 라운드 생성.
/// 각 라운드 = 동시 진행 가능한 [팀A, 팀B] 페어 리스트.
/// 한 라운드 안에서는 같은 팀이 절대 두 번 등장하지 않는다.
/// 홀수 n 은 한 팀에게 라운드마다 부전승.
List<List<List<int>>> roundRobinRounds(int n) {
  if (n < 2) return const [];
  final m = n.isOdd ? n + 1 : n;
  final bye = n.isOdd ? n : -1;
  final teams = List<int>.generate(m, (i) => i);
  final half = m ~/ 2;
  final rounds = <List<List<int>>>[];
  for (int r = 0; r < m - 1; r++) {
    final round = <List<int>>[];
    for (int i = 0; i < half; i++) {
      final a = teams[i];
      final b = teams[m - 1 - i];
      if (a != bye && b != bye) round.add([a, b]);
    }
    rounds.add(round);
    // 원형 회전: 첫 팀 고정, 나머지를 회전 (마지막 → 두 번째 자리)
    final last = teams.removeAt(m - 1);
    teams.insert(1, last);
  }
  return rounds;
}

/// 한 그룹이 차지하는 시간 슬롯(=라운드/코트 분할) 수.
/// 라운드 안에서 매치가 코트 수보다 많으면 슬롯이 분할되어 추가됨.
int slotsForGroup(int n, int courts) {
  if (n < 2 || courts < 1) return 0;
  final rounds = roundRobinRounds(n);
  int slots = 0;
  for (final r in rounds) {
    slots += (r.length + courts - 1) ~/ courts;
  }
  return slots;
}

/// 한 그룹의 코트·시간 할당 정보.
class GroupAllocation {
  /// venue 의 startCourt 기준 코트 오프셋 (0-base).
  final int courtOffset;
  /// 이 그룹이 사용하는 코트 수 (= floor(size/2) 까지, 최대 가용 코트로 클램프).
  final int parallelCourts;
  /// venue 의 기준 시각에서 더해질 분(누적 오프셋).
  final int extraStartMinutes;

  const GroupAllocation({
    required this.courtOffset,
    required this.parallelCourts,
    required this.extraStartMinutes,
  });
}

/// 한 division 의 group 들을 경기장 코트에 병렬 배치.
/// - 코트가 남으면 다음 그룹을 같은 시간에 다른 코트 범위에 배치.
/// - 코트가 모자라면 현재 배치(batch) 가 끝난 후로 큐잉.
/// [restMinutes] 라운드 사이 휴식이 있으면 그룹 길이에 포함시켜 다음 batch 가 그만큼 밀림.
List<GroupAllocation> allocateGroups({
  required List<GroupInfo> groups,
  required int venueCourts,
  required int matchMinutes,
  int initialOffsetMin = 0,
  int restMinutes = 0,
}) {
  final result = <GroupAllocation>[];
  if (venueCourts < 1) return result;
  int courtOffset = 0;
  int batchStart = initialOffsetMin;
  int maxBatchDurationMin = 0;

  for (final g in groups) {
    int parallelNeeded = (g.size / 2).floor();
    if (parallelNeeded < 1) parallelNeeded = 1;
    if (parallelNeeded > venueCourts) parallelNeeded = venueCourts;

    if (courtOffset + parallelNeeded > venueCourts) {
      // 현재 batch 가 끝난 후 새 batch 시작.
      batchStart += maxBatchDurationMin;
      courtOffset = 0;
      maxBatchDurationMin = 0;
    }

    result.add(GroupAllocation(
      courtOffset: courtOffset,
      parallelCourts: parallelNeeded,
      extraStartMinutes: batchStart,
    ));

    final groupSlots = slotsForGroup(g.size, parallelNeeded);
    final groupRoundCount = roundRobinRounds(g.size).length;
    final groupDurationMin =
        groupSlots * matchMinutes + (groupRoundCount - 1).clamp(0, 1 << 30) * restMinutes;
    if (groupDurationMin > maxBatchDurationMin) {
      maxBatchDurationMin = groupDurationMin;
    }
    courtOffset += parallelNeeded;
  }
  return result;
}

/// 할당 리스트 기준으로 division 전체가 차지하는 총 시간(분).
int totalMinutesForAllocations(
    List<GroupInfo> groups, List<GroupAllocation> allocations, int matchMinutes,
    {int baseStart = 0, int restMinutes = 0}) {
  int maxEnd = baseStart;
  for (int i = 0; i < groups.length && i < allocations.length; i++) {
    final a = allocations[i];
    final slots = slotsForGroup(groups[i].size, a.parallelCourts);
    final rounds = roundRobinRounds(groups[i].size).length;
    final end = a.extraStartMinutes +
        slots * matchMinutes +
        (rounds - 1).clamp(0, 1 << 30) * restMinutes;
    if (end > maxEnd) maxEnd = end;
  }
  return maxEnd;
}

/// 조의 모든 경기에 코트 번호와 시간 자동 배정.
/// - 같은 라운드(=시각) 안에서 동일 팀이 두 번 배정되지 않도록 round-robin 사용.
/// - 라운드 내 매치 > 코트 수면 다음 시간 슬롯으로 자동 분할.
/// [extraStartMinutes] 앞 그룹이 끝난 후의 누적 오프셋(분).
/// [restMinutes] 라운드 사이 추가 휴식(분). 0이면 휴식 없음. 같은 팀이 연속 라운드에서
/// 다시 경기하는 round-robin 특성상, 한 슬롯 이상의 휴식을 강제하려면 양수 권장.
List<MatchInfo> generateMatches({
  required GroupInfo group,
  required int courts,
  int startCourt = 1,
  int startMatchNum = 1,
  String startTime = '13:00',
  int matchMinutes = 30,
  int extraStartMinutes = 0,
  int restMinutes = 0,
}) {
  final matches = <MatchInfo>[];
  final n = group.size;
  if (n < 2 || courts < 1) return matches;

  final rounds = roundRobinRounds(n);
  final timeParts = startTime.split(':');
  final baseMin =
      int.parse(timeParts[0]) * 60 + int.parse(timeParts[1]);
  final step = matchMinutes > 0 ? matchMinutes : 30;
  int mNum = startMatchNum;
  int slotIdx = 0;
  int extraRest = 0; // 누적 라운드간 휴식 분

  for (int r = 0; r < rounds.length; r++) {
    final round = rounds[r];
    final totalSlotsInRound = (round.length + courts - 1) ~/ courts;
    for (int s = 0; s < totalSlotsInRound; s++) {
      final t = baseMin + extraStartMinutes + extraRest + slotIdx * step;
      final hh = (t ~/ 60).toString().padLeft(2, '0');
      final mm = (t % 60).toString().padLeft(2, '0');
      for (int c = 0;
          c < courts && s * courts + c < round.length;
          c++) {
        final pair = round[s * courts + c];
        matches.add(MatchInfo(
          num_: mNum,
          court: startCourt + c,
          team1Index: pair[0],
          team2Index: pair[1],
          time: '$hh:$mm',
        ));
        mNum++;
      }
      slotIdx++;
    }
    if (r < rounds.length - 1) extraRest += restMinutes;
  }
  return matches;
}

/// 팀 수에 따른 다각형 한글 이름.
String polygonName(int n) {
  const names = [
    '', '', '', '삼각형', '사각형', '오각형', '육각형', '칠각형', '팔각형'
  ];
  return n < names.length ? names[n] : '$n각형';
}

// ═══════════════════════════════════════════════════════
//  Division 빌더 — 종목 × 연령 × 급수별 대진표 묶음
// ═══════════════════════════════════════════════════════

/// 선택된 참가자를 (종목 × 연령 × 급수) 별로 묶어 Division 리스트 생성.
///
/// - players:        선택된 참가자 (이미 _selected 필터 적용된 상태)
/// - event:          '혼복'|'남복'|'여복' 중 하나
/// - ageLabels:      활성 연령 라벨 (전체 제외, '40','50' 등)
/// - allAgeLabels:   ageMatches 매칭에 필요한 전체 라벨
/// - gradeLabels:    활성 급수 라벨 ('A조','B조',...)
/// - venueIdOf:      (event,age,grade)→venueId 조회 함수. 없으면 ''
///
/// 한 Division 내 팀 구성:
///   복식(혼복/남복/여복): 2명 페어. 짝이 안 맞으면 마지막 1명은 BYE.
/// 페어링 전략: gradeIndex(고수 우선) → 나이↓ → 이름. 슬라이딩 페어로 단순 매칭.
List<Division> buildDivisions({
  required List<Player> players,
  required String event,
  required List<String> ageLabels,
  required List<String> allAgeLabels,
  required List<String> gradeLabels,
  required bool Function(String, int, List<String>) ageMatches,
  String Function(String event, String age, String grade)? venueIdOf,
  bool shuffle = false,
}) {
  final List<Division> out = [];

  // 종목별 성별 필터
  bool genderOk(Player p) {
    if (event == '남복') return p.gender == '남';
    if (event == '여복') return p.gender == '여';
    return true; // 혼복 — 성별 무관
  }

  for (final age in ageLabels) {
    for (final grade in gradeLabels) {
      final pool = players
          .where(genderOk)
          .where((p) => p.grade == grade)
          .where((p) => ageMatches(age, p.age, allAgeLabels))
          .toList();
      // 복식 6명(=3팀) 미만이면 부서 미생성.
      // determineFormat 이 n<3 에서 null 을 반환하므로 이중 안전망.
      if (pool.length < 6) continue;

      pool.sort((a, b) {
        final g = a.gradeIndex.compareTo(b.gradeIndex);
        if (g != 0) return g;
        final ag = a.age.compareTo(b.age);
        if (ag != 0) return ag;
        return a.name.compareTo(b.name);
      });
      // shuffle=true 면 정렬을 흩어 매번 다른 페어링이 나오게 한다.
      // 다른-클럽/반대-성별 우선 정책은 partnerIdx 검색이 그대로 유지.
      if (shuffle) pool.shuffle();

      // 복식: 가능하면 다른 클럽 선수끼리 페어링. 혼복은 남녀 1:1 필수.
      // 정렬 순서(급수→나이→이름)를 기준으로, 각 페어 선택 시 가장 가까운
      // 다른-클럽 파트너를 우선 선택. 동일 클럽만 남은 경우에 한해 동일 클럽 페어.
      // 혼복 우선순위: 반대 성별 + 다른 클럽 → 반대 성별(동일 클럽) → 매칭 불가 시
      // 남은 선수는 BYE (반대 성별 부족으로 페어 못 만듦).
      // 클럽명 표시: 두 선수 클럽이 다르면 두 줄, 같으면 한 줄. 각 8글자까지.
      String trimClub(String s) =>
          s.length > 8 ? '${s.substring(0, 8)}…' : s;
      final teams = <TeamData>[];
      final remaining = List<Player>.from(pool);
      final isMixed = event == '혼복';
      while (remaining.length >= 2) {
        final p1 = remaining.removeAt(0);
        int partnerIdx;
        if (isMixed) {
          // 반대 성별 + 다른 클럽 우선.
          partnerIdx = remaining.indexWhere(
              (p) => p.gender != p1.gender && p.clubId != p1.clubId);
          if (partnerIdx == -1) {
            // 반대 성별만이라도.
            partnerIdx =
                remaining.indexWhere((p) => p.gender != p1.gender);
          }
          if (partnerIdx == -1) {
            // 반대 성별이 모두 소진. p1 포함 남은 동성은 모두 BYE.
            break;
          }
        } else {
          // 남복/여복: 다른 클럽 우선, 없으면 동일 클럽.
          partnerIdx = remaining.indexWhere((p) => p.clubId != p1.clubId);
          if (partnerIdx == -1) partnerIdx = 0;
        }
        final p2 = remaining.removeAt(partnerIdx);
        // 혼복: 표시 순서 [남, 여] 고정. 남복/여복은 페어링 순서 그대로.
        final first = (isMixed && p1.gender != '남' && p2.gender == '남')
            ? p2
            : p1;
        final second = identical(first, p1) ? p2 : p1;
        final raw1 = first.clubName.isEmpty ? '무소속' : first.clubName;
        final raw2 = second.clubName.isEmpty ? '무소속' : second.clubName;
        final c1 = trimClub(raw1);
        final c2 = trimClub(raw2);
        // raw 가 같거나 trim 후 같으면(=긴 이름 잘렸을 때 동일) 한 줄로.
        final clubName = (raw1 == raw2 || c1 == c2) ? c1 : '$c1\n$c2';
        teams.add(TeamData(
          name: clubName,
          players: [first.name, second.name],
          playerIds: [first.id, second.id],
        ));
      }

      final fmt = determineFormat(teams.length);
      if (fmt == null) continue;

      // 클럽 안배 (snake draft): 조 순서대로 [조1팀들, 조2팀들, ...] 재배열.
      // _DivisionCard._teamsForGroup 의 sublist 로직과 호환.
      final groupSizes = fmt.groups.map((g) => g.size).toList();
      final reordered =
          _distributeSnakeDraft(teams, groupSizes).expand((g) => g).toList();

      out.add(Division(
        event: event,
        ageGroup: age,
        grade: grade,
        teams: reordered,
        format: fmt,
        venueId: venueIdOf?.call(event, age, grade) ?? '',
      ));
    }
  }
  return out;
}

/// Tournament 의 활성 급수만 추려 정렬 순서로 반환.
List<String> activeGradeLabels(Tournament t) =>
    t.gradeGroups.where((l) => l != '전체').toList();

/// Tournament 의 활성 연령만 추려 반환.
List<String> activeAgeLabels(Tournament t) =>
    t.ageGroups.where((l) => l != '전체').toList();

// ═══════════════════════════════════════════════════════
//  Snake draft — 같은 클럽이 같은 조에 몰리는 것 방지
// ═══════════════════════════════════════════════════════

/// teams 의 TeamData.name 을 "클럽 식별자"로 사용해 K개 조에 분배.
/// 우선순위:
///   1) 같은 클럽이 아직 들어오지 않은 조 우선
///   2) 남은 자리(capacity)가 많은 조 우선
/// 클럽 처리 순서는 팀 수 desc → 이름 asc.
///
/// 한 클럽의 팀 수가 K 보다 많으면 같은 클럽이 같은 조에 들어가는 건 불가피.
/// 이 경우 가장 빈 조에 추가됨 (capacity 가 동일하면 인덱스 작은 쪽).
List<List<TeamData>> _distributeSnakeDraft(
  List<TeamData> teams,
  List<int> groupSizes,
) {
  final K = groupSizes.length;
  if (K <= 1) return [List.of(teams)];

  // 클럽별 그룹화 (TeamData.name = 클럽명)
  final byClub = <String, List<TeamData>>{};
  for (final t in teams) {
    byClub.putIfAbsent(t.name, () => []).add(t);
  }

  // 큰 클럽이 먼저 분산되도록 팀 수 desc 정렬
  final clubs = byClub.keys.toList()
    ..sort((a, b) {
      final c = byClub[b]!.length.compareTo(byClub[a]!.length);
      return c != 0 ? c : a.compareTo(b);
    });

  final result = List.generate(K, (_) => <TeamData>[]);
  final cap = List<int>.from(groupSizes);

  for (final club in clubs) {
    for (final t in byClub[club]!) {
      // 후보 조 정렬: (1) 같은 클럽 없음 우선 (2) cap 큰 순
      final order = List.generate(K, (j) => j)
        ..sort((a, b) {
          final aHas = result[a].any((x) => x.name == club) ? 1 : 0;
          final bHas = result[b].any((x) => x.name == club) ? 1 : 0;
          if (aHas != bHas) return aHas.compareTo(bHas);
          return cap[b].compareTo(cap[a]);
        });

      // 첫 번째 capacity 있는 조에 배치
      for (final j in order) {
        if (cap[j] > 0) {
          result[j].add(t);
          cap[j]--;
          break;
        }
      }
    }
  }

  return result;
}
