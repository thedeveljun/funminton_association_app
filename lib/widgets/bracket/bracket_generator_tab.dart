// 배드민턴 대진표 자동 생성 — 운영 화면 탭 본체
//
// 구조:
//   1) 종목 셀렉터 (혼복/남복/여복/단식)
//   2) 코트 수
//   3) "대진표 생성" 버튼
//   4) 생성 후 → (종목 × 연령 × 급수) Division 카드 리스트
//      각 카드는 펼치면 다각형/토너먼트 시각화 + 일정표

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/bracket_models.dart';
import '../../models/match.dart';
import '../../models/player.dart';
import '../../models/tournament.dart';
import '../../models/venue.dart';
import '../../utils/age_group.dart';
import '../../utils/bracket_logic.dart';
import 'polygon_bracket.dart';
import 'tournament_bracket.dart';

class BracketGeneratorTab extends StatefulWidget {
  final Tournament tournament;
  final List<Player> selectedPlayers;
  final Map<AssignKey, String> assignMap;

  const BracketGeneratorTab({
    super.key,
    required this.tournament,
    this.selectedPlayers = const [],
    this.assignMap = const {},
  });

  /// 활성 경기장 (코트 수 > 0) 만 반환.
  List<Venue> get activeVenues =>
      tournament.venues.where((v) => v.courts > 0).toList();

  @override
  State<BracketGeneratorTab> createState() => _BracketGeneratorTabState();
}

class _BracketGeneratorTabState extends State<BracketGeneratorTab> {
  static const List<String> _events = ['혼복', '남복', '여복', '단식'];

  String _event = '혼복';
  int _courts = 4;

  List<Division>? _divisions; // null = 미생성
  String? _expandedKey;

  @override
  void initState() {
    super.initState();
    _courts = widget.tournament.totalActiveCourts.clamp(1, 999);
  }

  String _keyOf(Division d) => '${d.event}|${d.ageGroup}|${d.grade}';

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF1E3A8A);
    }
  }

  void _generate() {
    final t = widget.tournament;
    final ages = activeAgeLabels(t);
    final grades = activeGradeLabels(t);
    final all = ages;

    final divisions = buildDivisions(
      players: widget.selectedPlayers,
      event: _event,
      ageLabels: ages,
      allAgeLabels: all,
      gradeLabels: grades,
      ageMatches: ageMatches,
      venueIdOf: (event, age, grade) =>
          widget.assignMap[AssignKey(event, age, grade)] ?? '',
    );
    setState(() {
      _divisions = divisions;
      _expandedKey = divisions.isNotEmpty ? _keyOf(divisions.first) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 시스템 내비게이션 바(제스처 바)에 마지막 카드가 가려지지 않도록 하단 inset 추가.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      color: const Color(0xFFF3F4F6),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(10, 10, 10, 10 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSettingsCard(),
            const SizedBox(height: 8),
            _buildGenerateButton(),
            const SizedBox(height: 8),
            if (_divisions != null) ..._buildResults(),
            const SizedBox(height: 8),
            _buildRulesCard(),
          ],
        ),
      ),
    );
  }

  // ── 상단 설정 ──────────────────────────────
  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('대진표 설정',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
          const SizedBox(height: 6),
          // 종목 셀렉터
          Row(children: [
            const SizedBox(width: 60, child: Text('종목')),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _events.map((e) {
                  final on = e == _event;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _event = e;
                      _divisions = null; // 종목 바뀌면 재생성 유도
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: on
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: on
                              ? const Color(0xFF1E3A8A)
                              : const Color(0xFFBFDBFE),
                          width: 1.4,
                        ),
                      ),
                      child: Text(e,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  on ? Colors.white : const Color(0xFF1E3A8A))),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          // 경기장 합산 코트 수 — read-only. 설정 탭의 경기장 코트 수에서 자동 합산.
          Row(children: [
            const SizedBox(width: 60, child: Text('코트 수')),
            Expanded(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final v in widget.activeVenues)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _hexToColor(v.colorHex),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${v.name.isEmpty ? '미지정' : v.name} ${v.courts}코트',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            widget.activeVenues.isEmpty
                ? '* 설정 탭에서 경기장·코트 수를 먼저 입력하세요.'
                : '* 코트 수는 설정 탭에서 변경합니다.',
            style: const TextStyle(
                fontSize: 10, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    final canGenerate = widget.selectedPlayers.length >= 2;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canGenerate ? _generate : null,
        icon: const Icon(Icons.shuffle, size: 20, color: Colors.white),
        label: Text(
          _divisions == null ? '대진표 생성' : '대진표 다시 생성',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          minimumSize: const Size(0, 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── 결과: 요약 + Division 카드 리스트 ──────
  List<Widget> _buildResults() {
    final divs = _divisions!;
    if (divs.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            const Icon(Icons.info_outline,
                size: 36, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 8),
            Text(
              '$_event 으로 생성 가능한 부서가 없습니다.\n참가자/연령/급수 설정을 확인하세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
            ),
          ]),
        ),
      ];
    }

    final totalTeams = divs.fold<int>(0, (s, d) => s + d.teams.length);
    final totalMatches =
        divs.fold<int>(0, (s, d) => s + d.format.totalMatches);

    return [
      _buildSummaryCard(divs.length, totalTeams, totalMatches),
      const SizedBox(height: 6),
      ...divs.map((d) => Padding(
            padding: const EdgeInsets.only(top: 1),
            child: _DivisionCard(
              division: d,
              expanded: _keyOf(d) == _expandedKey,
              courts: _courts,
              venues: widget.activeVenues,
              assignMap: widget.assignMap,
              onToggle: () => setState(() {
                _expandedKey = _keyOf(d) == _expandedKey ? null : _keyOf(d);
              }),
            ),
          )),
    ];
  }

  Widget _buildSummaryCard(int divCount, int totalTeams, int totalMatches) {
    Widget stat(String label, String value) => Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151))),
              const SizedBox(width: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A8A))),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        stat('종목 수', '$divCount'),
        stat('총 팀', '$totalTeams'),
        stat('총 경기', '$totalMatches'),
      ]),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('규정 메모',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                  fontSize: 13)),
          SizedBox(height: 4),
          Text(
            '· 25점 1세트 (듀스 31점)\n'
            '· 동률: 다승 → 승자승 → 득실차\n'
            '· 단독 풀리그: 3팀(삼각형) / 4팀(사각형) / 5팀(오각형)\n'
            '· 6팀↑ 부서: 모든 조 3~4팀 (5팀 조 없음)\n'
            '· 11팀 부서: [4,4,3] → 본선 풀리그(3강)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1E40AF),
                height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  단일 Division 카드 (펼치면 시각화 + 일정표)
// ═══════════════════════════════════════════════════════
class _DivisionCard extends StatefulWidget {
  final Division division;
  final bool expanded;
  final int courts;
  final List<Venue> venues;
  final Map<AssignKey, String> assignMap;
  final VoidCallback onToggle;

  const _DivisionCard({
    required this.division,
    required this.expanded,
    required this.courts,
    required this.venues,
    required this.assignMap,
    required this.onToggle,
  });

  /// 현재 (event, age, grade) 에 배정된 venueId.
  /// 1) assignMap (실시간 설정값) 우선
  /// 2) 그 다음 division.venueId (생성 시 베이크된 값)
  String get _resolvedVenueId {
    final live = assignMap[AssignKey(
        division.event, division.ageGroup, division.grade)];
    if (live != null && live.isNotEmpty) return live;
    return division.venueId;
  }

  /// 배정된 Venue. 없으면 null.
  Venue? get assignedVenue {
    final id = _resolvedVenueId;
    if (id.isEmpty) return null;
    for (final v in venues) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// 배정된 경기장의 코트 시작 번호 (활성 경기장 누적 합).
  /// 1번 경기장 4코트 → 1~4. 2번 경기장 3코트 → 5~7.
  int get startCourt {
    final id = _resolvedVenueId;
    int s = 1;
    for (final v in venues) {
      if (v.id == id) return s;
      s += v.courts;
    }
    return 1;
  }

  /// 배정된 경기장의 코트 수. 미배정이면 전체 합.
  int get assignedCourts {
    final v = assignedVenue;
    if (v != null) return v.courts;
    return courts; // fallback: 전체 합
  }

  /// venue 표시 이름 — 비어있으면 "경기장 N" 폴백.
  String displayNameFor(Venue v) {
    if (v.name.isNotEmpty) return v.name;
    final idx = venues.indexWhere((e) => e.id == v.id);
    return '경기장 ${idx + 1}';
  }

  @override
  State<_DivisionCard> createState() => _DivisionCardState();
}

class _DivisionCardState extends State<_DivisionCard> {
  int _activeGroup = 0;
  bool _showFinals = false;

  /// 본선 토너먼트 라운드 이름 리스트 (예선 영향 없음).
  /// fSize=2: ['결승']
  /// fSize=4: ['4강','결승']
  /// fSize=8: ['8강','준결승','결승']
  /// fSize=16: ['16강','8강','준결승','결승']
  /// fSize=32: ['32강','16강','8강','준결승','결승']
  /// 풀리그 본선이면 finals.name 한 개.
  List<String> _finalsRoundNames(FinalsInfo? f) {
    if (f == null) return const [];
    if (f.isRoundRobin) return [f.name];
    final names = <String>[];
    int r = f.size;
    while (r >= 2) {
      if (r == 2) {
        names.add('결승');
      } else if (r == 4) {
        names.add('준결승');
      } else {
        names.add('$r강');
      }
      r ~/= 2;
    }
    return names;
  }

  List<MatchInfo> _matchesForGroup(GroupInfo g, int idx) {
    int startNum = 1;
    for (int i = 0; i < idx; i++) {
      startNum += widget.division.format.groups[i].matches;
    }
    return generateMatches(
      group: g,
      courts: widget.assignedCourts,
      startCourt: widget.startCourt,
      startMatchNum: startNum,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.division;
    final fmt = d.format;
    final teamCount = d.teams.length;
    final venue = widget.assignedVenue;
    final venueColor = venue != null
        ? _hexToColor(venue.colorHex)
        : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더 (탭하면 펼침)
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 6, 2),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _badge(d.event, AppColors.primaryMid),
                          _badge('${d.ageGroup} / ${d.grade}',
                              const Color(0xFF6B7280)),
                          // 펼쳐있지 않을 때만 팀 수 배지 표시 (펼쳐있을 때는 본문 큰 텍스트와 중복).
                          if (!widget.expanded)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                  fmt.kind == BracketKind.polygon
                                      ? '$teamCount팀 풀리그'
                                      : '$teamCount팀',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF92400E))),
                            ),
                          if (venue != null)
                            _badge(widget.displayNameFor(venue), venueColor),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  widget.expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: const Color(0xFF9CA3AF),
                ),
              ]),
            ),
          ),
          // 본문 (펼친 경우)
          if (widget.expanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            _buildBody(d, fmt),
          ],
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF1E3A8A);
    }
  }

  Widget _badge(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      );

  Widget _buildBody(Division d, BracketFormat fmt) {
    if (_activeGroup >= fmt.groups.length) _activeGroup = 0;
    final activeGroup = fmt.groups[_activeGroup];
    final activeMatches = _matchesForGroup(activeGroup, _activeGroup);

    // teamData: 카드 단위로 d.teams 사용. 활성 조에 해당하는 팀만 잘라 보내기.
    // (snake draft 적용된 순서로 미리 재정렬되어 있음)
    final teamData = _teamsForGroup(d.teams, fmt, _activeGroup);

    final venue = widget.assignedVenue;
    final venueColor =
        venue != null ? _hexToColor(venue.colorHex) : const Color(0xFF1E3A8A);

    final finalsRounds = _finalsRoundNames(fmt.finals);
    final hasFinals = fmt.finals != null;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        // 1) 큰 세그먼트: [예선] [본선] — 본선 있을 때만
        if (hasFinals) ...[
          _segmentControl(),
          const SizedBox(height: 8),
        ],
        // 2) 라운드 칩: 예선이면 조 칩, 본선이면 라운드 이름
        if (!_showFinals && fmt.groups.length > 1)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...fmt.groups.asMap().entries.map((e) => _pill(
                    label: '${e.value.name} (${e.value.size})',
                    active: e.key == _activeGroup,
                    onTap: () => setState(() => _activeGroup = e.key),
                  )),
            ],
          ),
        if (_showFinals && finalsRounds.length > 1)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in finalsRounds)
                _pill(
                  label: name,
                  active: name == finalsRounds.last,
                  onTap: () {},
                ),
            ],
          ),
        const SizedBox(height: 6),
        if (!_showFinals) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${activeGroup.size}팀 풀리그',
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A8A)),
              ),
              if (venue != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: venueColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: venueColor, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place,
                          size: 12, color: venueColor),
                      const SizedBox(width: 2),
                      Text(widget.displayNameFor(venue),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: venueColor)),
                    ],
                  ),
                ),
            ],
          ),
          Text(
            '${activeGroup.matches}경기 · 팀당 ${activeGroup.size - 1}경기'
            '${fmt.finals != null ? ' · 본선 ${activeGroup.qualifiers}팀 진출' : ''}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          _resultMatrix(teamData, activeMatches, venueColor: venueColor),
          const SizedBox(height: 10),
          PolygonBracket(
            teams: activeGroup.size,
            teamData: teamData,
            matches: activeMatches,
            courtColor: venueColor,
          ),
          const SizedBox(height: 10),
          _rankingTable(teamData),
          const SizedBox(height: 10),
          _matchCardList(
            activeGroup,
            activeMatches,
            teamData,
            venueColor: venueColor,
            divisionLabel: '${d.event} ${d.ageGroup}-${d.grade}',
            assignedVenue: venue,
          ),
        ] else if (fmt.finals != null) ...[
          Text(
            '본선 ${fmt.finals!.name} '
            '${fmt.finals!.isRoundRobin ? '풀리그' : '토너먼트'}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E3A8A)),
          ),
          Text(
            '${fmt.finals!.matches}경기 · 예선 1위 성적순 시드',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 6),
          if (fmt.finals!.isRoundRobin)
            PolygonBracket(
              teams: fmt.finals!.size,
              teamData: List.generate(
                fmt.finals!.size,
                (i) => TeamData(name: '본선 ${i + 1}', players: const []),
              ),
              matches: generateMatches(
                group: GroupInfo(
                  size: fmt.finals!.size,
                  name: fmt.finals!.name,
                  matches: fmt.finals!.matches,
                  shape: ShapeHint.values[
                      fmt.finals!.size <= 6 ? fmt.finals!.size - 2 : 0],
                ),
                courts: widget.courts,
              ),
            )
          else
            TournamentBracket(size: fmt.finals!.size),
        ],
      ]),
    );
  }

  /// 임시 팀 분배 — 조별로 인덱스 균등 분할.
  /// (snake draft 미적용. 후속 작업에서 클럽 안배 추가 예정.)
  List<TeamData> _teamsForGroup(
      List<TeamData> all, BracketFormat fmt, int groupIdx) {
    int start = 0;
    for (int i = 0; i < groupIdx; i++) {
      start += fmt.groups[i].size;
    }
    final end = start + fmt.groups[groupIdx].size;
    return all.sublist(
      start.clamp(0, all.length),
      end.clamp(0, all.length),
    );
  }

  /// 큰 세그먼트 컨트롤 [예선 | 본선]. 참조 앱 스타일.
  Widget _segmentControl() {
    Widget btn(String label, bool active, VoidCallback onTap, Color activeColor) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: active ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color:
                      active ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(children: [
        btn('예선', !_showFinals,
            () => setState(() => _showFinals = false),
            const Color(0xFF22C55E)),
        btn('본선', _showFinals,
            () => setState(() => _showFinals = true),
            const Color(0xFF22C55E)),
      ]),
    );
  }

  Widget _pill({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color:
                active ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? const Color(0xFF1E3A8A)
                  : const Color(0xFFBFDBFE),
              width: 1.4,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFF1E3A8A),
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              )),
        ),
      );

  /// 조 내 모든 팀 vs 팀 결과 매트릭스 (참조 앱 스타일).
  /// 헤더 3행: 종합순위 / 소속 / 선수
  /// 각 데이터 행: 팀별 vs 다른 팀 셀. 자기 자신은 "-".
  /// 셀: 점수(또는 0-0) + 코트번호 + 경기번호
  /// venueColor 가 있으면 코트번호 텍스트 색상으로 사용 (경기장 식별).
  Widget _resultMatrix(
    List<TeamData> teams,
    List<MatchInfo> matches, {
    Color? venueColor,
  }) {
    final courtColor = venueColor ?? const Color(0xFF059669);
    final n = teams.length;

    Widget cell(Widget child, {Color? bg}) => Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          color: bg,
          alignment: Alignment.center,
          child: child,
        );

    Widget txt(
      String s, {
      double size = 12,
      FontWeight w = FontWeight.w500,
      Color color = const Color(0xFF111827),
    }) =>
        Text(
          s,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size,
            fontWeight: w,
            color: color,
            height: 1.25,
          ),
        );

    Widget headerCell(String s, {Color color = const Color(0xFF374151)}) =>
        cell(txt(s, w: FontWeight.w700, color: color),
            bg: const Color(0xFFF7F9FC));

    Widget rowHeader(String s) => cell(
          txt(s, w: FontWeight.w700, color: const Color(0xFF111827)),
          bg: const Color(0xFFF7F9FC),
        );

    Widget dataCell(int row, int col) {
      if (row == col) {
        return cell(
          txt('-', size: 16, color: const Color(0xFF9CA3AF)),
        );
      }
      final lo = row < col ? row : col;
      final hi = row < col ? col : row;
      MatchInfo? m;
      for (final x in matches) {
        if (x.team1Index == lo && x.team2Index == hi) {
          m = x;
          break;
        }
      }
      if (m == null) {
        return cell(txt('-'));
      }
      return cell(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          txt('0-0',
              size: 13,
              w: FontWeight.w700,
              color: const Color(0xFF1E3A8A)),
          txt('${m.court}코트', size: 11, color: courtColor),
          txt('${m.num_}경기',
              size: 11, color: const Color(0xFF6B7280)),
        ],
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(
          color: const Color(0xFFD1D5DB),
          width: 0.6,
        ),
        defaultColumnWidth: const FixedColumnWidth(72),
        columnWidths: const {0: FixedColumnWidth(56)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            headerCell('순위'),
            ...List.generate(
              n,
              (_) => headerCell('-위', color: const Color(0xFF6B7280)),
            ),
          ]),
          TableRow(children: [
            headerCell('소속'),
            ...teams.map((t) => headerCell(t.name)),
          ]),
          TableRow(children: [
            headerCell('선수'),
            ...teams.map((t) => headerCell(t.players.join('\n'))),
          ]),
          for (int r = 0; r < n; r++)
            TableRow(children: [
              rowHeader(teams[r].players.join('\n')),
              for (int c = 0; c < n; c++) dataCell(r, c),
            ]),
        ],
      ),
    );
  }

  /// 하단 순위표 — 다승·득실차·다득점 기준 (참조 앱 스타일).
  /// 결과 미입력 시 모든 데이터 셀 '-'.
  /// 패/실 칸은 빨강, 승/득/차 칸은 파랑으로 의미 강조.
  Widget _rankingTable(List<TeamData> teams) {
    const blue = Color(0xFF1E3A8A);
    const red = Color(0xFFDC2626);

    Widget headerCell(String s, {Color color = const Color(0xFF374151)}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          color: const Color(0xFFF7F9FC),
          alignment: Alignment.center,
          child: Text(s,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        );

    Widget dataCell(String s,
            {FontWeight w = FontWeight.w500,
            Color color = const Color(0xFF111827)}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          alignment: Alignment.center,
          child: Text(s,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: w,
                  color: color,
                  height: 1.3)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4, bottom: 2),
          child: Text(
            '* 다승–승자승–다득점–득실차',
            style: TextStyle(
                fontSize: 11,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w700),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(
                color: const Color(0xFFD1D5DB), width: 0.6),
            defaultColumnWidth: const FixedColumnWidth(20),
            columnWidths: const {
              0: FixedColumnWidth(30), // 순위
              1: FixedColumnWidth(76), // 소속 (두 클럽 6+6+1자 가능)
              2: FixedColumnWidth(72), // 선수
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(children: [
                headerCell('순위'),
                headerCell('소속'),
                headerCell('선수'),
                headerCell('승', color: blue),
                headerCell('패', color: red),
                headerCell('득', color: blue),
                headerCell('실', color: red),
                headerCell('차', color: blue),
              ]),
              for (final t in teams)
                TableRow(children: [
                  dataCell('-', color: const Color(0xFF9CA3AF)),
                  dataCell(t.name, w: FontWeight.w600),
                  dataCell(t.players.join('\n')),
                  dataCell('-', color: blue),
                  dataCell('-', color: red),
                  dataCell('-', color: blue),
                  dataCell('-', color: red),
                  dataCell('-', color: blue),
                ]),
            ],
          ),
        ),
      ],
    );
  }

  /// 코트 번호 → 활성 경기장 매핑.
  /// 경기장1 코트 4 → 1~4, 경기장2 코트 3 → 5~7, ...
  Venue? _venueForCourt(int court) {
    int s = 1;
    for (final v in widget.venues) {
      if (court >= s && court < s + v.courts) return v;
      s += v.courts;
    }
    return null;
  }

  /// 경기 카드 리스트 (참조 앱 스타일).
  /// 각 매치를 큰 카드로: 시간 / 상태칩 / 코트·경기번호 / 부서·조 / 팀A 점수 팀B
  /// 경기장 칩은 각 카드 상단 외부에 배치 (참고 그림 4·15 스타일).
  Widget _matchCardList(
    GroupInfo group,
    List<MatchInfo> matches,
    List<TeamData> teams, {
    Color? venueColor,
    required String divisionLabel,
    Venue? assignedVenue,
  }) {
    final fallbackColor = venueColor ?? const Color(0xFF1E3A8A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${group.name} 경기 카드',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1E3A8A)),
        ),
        const SizedBox(height: 6),
        ...matches.map((m) {
          final t1 = m.team1Index < teams.length ? teams[m.team1Index] : null;
          final t2 = m.team2Index < teams.length ? teams[m.team2Index] : null;
          // 부서에 경기장이 지정된 경우 그 경기장 사용,
          // 미지정이면 코트 번호가 속한 경기장으로 자동 매핑.
          final mVenue = assignedVenue ?? _venueForCourt(m.court);
          final mColor =
              mVenue != null ? _hexToColor(mVenue.colorHex) : fallbackColor;
          final mVenueName =
              mVenue != null ? widget.displayNameFor(mVenue) : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 카드 상단 외부 경기장 칩
                if (mVenueName.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4, right: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFD1D5DB), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.place, size: 12, color: mColor),
                        const SizedBox(width: 3),
                        Text(mVenueName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151))),
                      ],
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF9CA3AF),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 상단: 시간 / 상태
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                        child: Row(children: [
                          Text(m.time,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151))),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B7280),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text('경기시작전',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                          const Spacer(),
                          // 우측 균형용 빈 영역(시간 텍스트 폭과 시각적 대칭).
                          Opacity(
                            opacity: 0,
                            child: Text(m.time,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),
                      // 코트·경기번호 / 부서 라벨
                      Text('${m.court}코트 ${m.num_}경기',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: mColor)),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: divisionLabel,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827)),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: '[${group.name}]',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, color: Color(0xFF9CA3AF)),
                // 본문: 팀A / 점수 / 팀B
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 클럽명 — 톤 약하게 (회색·중간 두께)
                          Text(t1?.name ?? '미정',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 3),
                          // 선수 이름 — 메인 강조 (크고 진하게)
                          if (t1 != null)
                            for (final p in t1.players)
                              Text(p,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text('0',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                  color: mColor)),
                        ),
                        const SizedBox(width: 2),
                        const SizedBox(
                          width: 32,
                          child: Text('0',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                  color: Color(0xFF111827))),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(t2?.name ?? '미정',
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 3),
                          if (t2 != null)
                            for (final p in t2.players)
                              Text(p,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827))),
                        ],
                      ),
                    ),
                  ]),
                ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

}
