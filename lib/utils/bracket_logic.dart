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

/// 조의 모든 경기에 코트 번호와 시간 자동 배정.
/// 1경기 30분 (25점 + 코트 전환 5분) 기준.
List<MatchInfo> generateMatches({
  required GroupInfo group,
  required int courts,
  int startCourt = 1,
  int startMatchNum = 1,
  String startTime = '13:00',
}) {
  final matches = <MatchInfo>[];
  final n = group.size;
  int mNum = startMatchNum;
  int courtIdx = 0;
  final timeParts = startTime.split(':');
  final timeMin =
      int.parse(timeParts[0]) * 60 + int.parse(timeParts[1]);

  for (int i = 0; i < n; i++) {
    for (int j = i + 1; j < n; j++) {
      final court = (courtIdx % courts) + startCourt;
      final round = courtIdx ~/ courts;
      final t = timeMin + round * 30;
      final hh = (t ~/ 60).toString().padLeft(2, '0');
      final mm = (t % 60).toString().padLeft(2, '0');

      matches.add(MatchInfo(
        num_: mNum,
        court: court,
        team1Index: i,
        team2Index: j,
        time: '$hh:$mm',
      ));
      mNum++;
      courtIdx++;
    }
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
/// - event:          '혼복'|'남복'|'여복'|'단식' 중 하나
/// - ageLabels:      활성 연령 라벨 (전체 제외, '40','50' 등)
/// - allAgeLabels:   ageMatches 매칭에 필요한 전체 라벨
/// - gradeLabels:    활성 급수 라벨 ('A조','B조',...)
/// - venueIdOf:      (event,age,grade)→venueId 조회 함수. 없으면 ''
///
/// 한 Division 내 팀 구성:
///   단식: 1인 1팀
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
}) {
  final List<Division> out = [];
  final isSingles = event == '단식';

  // 종목별 성별 필터
  bool genderOk(Player p) {
    if (event == '남복') return p.gender == '남';
    if (event == '여복') return p.gender == '여';
    return true; // 혼복/단식 — 성별 무관
  }

  for (final age in ageLabels) {
    for (final grade in gradeLabels) {
      final pool = players
          .where(genderOk)
          .where((p) => p.grade == grade)
          .where((p) => ageMatches(age, p.age, allAgeLabels))
          .toList();
      // 단식 3명, 복식 6명(=3팀) 미만이면 부서 미생성.
      // determineFormat 이 n<3 에서 null 을 반환하므로 이중 안전망.
      final minPool = isSingles ? 3 : 6;
      if (pool.length < minPool) continue;

      pool.sort((a, b) {
        final g = a.gradeIndex.compareTo(b.gradeIndex);
        if (g != 0) return g;
        final ag = a.age.compareTo(b.age);
        if (ag != 0) return ag;
        return a.name.compareTo(b.name);
      });

      final teams = <TeamData>[];
      if (isSingles) {
        for (int i = 0; i < pool.length; i++) {
          teams.add(TeamData(
            name: pool[i].clubName.isEmpty ? '무소속' : pool[i].clubName,
            players: [pool[i].name],
          ));
        }
      } else {
        // 복식: 1-2, 3-4, ... 인접 페어.
        // 두 선수가 다른 클럽이면 두 클럽 모두 표시 (\n 두 줄). 같으면 단일.
        // 클럽명은 각각 8글자까지 (초과 시 …).
        String trimClub(String s) =>
            s.length > 8 ? '${s.substring(0, 8)}…' : s;
        for (int i = 0; i < pool.length; i += 2) {
          if (i + 1 >= pool.length) break;
          final p1 = pool[i];
          final p2 = pool[i + 1];
          final raw1 = p1.clubName.isEmpty ? '무소속' : p1.clubName;
          final raw2 = p2.clubName.isEmpty ? '무소속' : p2.clubName;
          final c1 = trimClub(raw1);
          final c2 = trimClub(raw2);
          final clubName = raw1 == raw2 ? c1 : '$c1\n$c2';
          teams.add(TeamData(
            name: clubName,
            players: [p1.name, p2.name],
          ));
        }
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
