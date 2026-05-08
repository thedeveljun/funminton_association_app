// 배드민턴 대진표 자동 생성 — 운영 화면 탭 본체
// (reference/bracket_reference.dart SECTION 5 변환:
//   Scaffold/AppBar 제거, BracketScreen 내부 탭으로 사용)

import 'package:flutter/material.dart';
import '../../models/bracket_models.dart';
import '../../models/tournament.dart';
import '../../utils/bracket_logic.dart';
import 'polygon_bracket.dart';
import 'tournament_bracket.dart';

class BracketGeneratorTab extends StatefulWidget {
  final Tournament tournament;

  const BracketGeneratorTab({super.key, required this.tournament});

  @override
  State<BracketGeneratorTab> createState() => _BracketGeneratorTabState();
}

class _BracketGeneratorTabState extends State<BracketGeneratorTab> {
  static const List<int> _courtOptions = [2, 3, 4, 5, 6, 8];

  late int _teamCount;
  late int _courts;
  int _activeIdx = 0;
  bool _showFinals = false;
  late TextEditingController _teamCountController;

  @override
  void initState() {
    super.initState();
    final pc = widget.tournament.participantCount;
    // 참가자 수(명) → 팀 수(2명/팀, 홀수면 올림). 0이면 기본값 11.
    _teamCount = (pc > 0 ? ((pc + 1) ~/ 2) : 11).clamp(4, 200);
    final tCourts = widget.tournament.totalActiveCourts;
    _courts = _courtOptions.contains(tCourts) ? tCourts : 4;
    _teamCountController = TextEditingController(text: _teamCount.toString());
  }

  @override
  void dispose() {
    _teamCountController.dispose();
    super.dispose();
  }

  List<MatchInfo> _matchesForGroup(GroupInfo g, int idx, BracketFormat format) {
    int startMatchNum = 1;
    for (int i = 0; i < idx; i++) {
      startMatchNum += format.groups[i].matches;
    }
    return generateMatches(
      group: g,
      courts: _courts,
      startMatchNum: startMatchNum,
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = determineFormat(_teamCount);

    if (format == null) {
      return Container(
        color: const Color(0xFFF3F4F6),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: const Text(
          '최소 4팀 이상이어야 진행 가능합니다\n(과천시 협회 규정)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      );
    }

    if (_activeIdx >= format.groups.length) _activeIdx = 0;
    final activeGroup = format.groups[_activeIdx];
    final activeMatches =
        _matchesForGroup(activeGroup, _activeIdx, format);
    final prelim = format.groups.fold<int>(0, (s, g) => s + g.matches);
    final total = format.totalMatches;
    final hours = (total * 30 / _courts / 60).toStringAsFixed(1);
    final sizeStr = format.groups.map((g) => '${g.size}팀').join(' + ');

    return Container(
      color: const Color(0xFFF3F4F6),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSettingsCard(),
            const SizedBox(height: 12),
            _buildStatsCard(total, format.groups.length, prelim, hours),
            const SizedBox(height: 12),
            _buildSummaryCard(format, sizeStr),
            const SizedBox(height: 12),
            Center(child: _buildPhoneMockup(format, activeGroup, activeMatches)),
            const SizedBox(height: 12),
            _buildScheduleCard(activeGroup, activeMatches),
            const SizedBox(height: 12),
            _buildRulesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('대회 설정',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 80, child: Text('출전 팀 수')),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _teamCountController,
                  keyboardType: TextInputType.number,
                  onSubmitted: (v) {
                    final n = int.tryParse(v) ?? 4;
                    setState(() {
                      _teamCount = n.clamp(4, 200);
                      _teamCountController.text = _teamCount.toString();
                    });
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('팀 (4~200)',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 80, child: Text('코트 수')),
              DropdownButton<int>(
                value: _courts,
                items: _courtOptions
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text('$c코트')))
                    .toList(),
                onChanged: (v) => setState(() => _courts = v ?? 4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
      int total, int groupCount, int prelim, String hours) {
    Widget stat(String label, String value) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A))),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: stat('총 경기수', '$total')),
          const SizedBox(width: 6),
          Expanded(child: stat('조 구성', '$groupCount개')),
          const SizedBox(width: 6),
          Expanded(child: stat('예선 경기', '$prelim')),
          const SizedBox(width: 6),
          Expanded(child: stat('소요 시간', '${hours}h')),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BracketFormat format, String sizeStr) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  format.format,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E40AF)),
                ),
              ),
              if (format.recommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('권장 ★',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF78350F),
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '예선: ${format.groups.length}개 조 ($sizeStr)' +
                (format.finals != null
                    ? ' · 본선: ${format.finals!.name} 토너먼트'
                    : ''),
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF1E40AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneMockup(BracketFormat format, GroupInfo activeGroup,
      List<MatchInfo> activeMatches) {
    final teamData = List<TeamData>.generate(
      activeGroup.size,
      (i) => TeamData(
          name: '팀 ${i + 1}', players: const ['선수 A', '선수 B']),
    );

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF1E3A8A),
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            width: double.infinity,
            child: Text(
              activeGroup.name == '본선'
                  ? '본선 풀리그'
                  : '예선 ${activeGroup.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (format.groups.length > 1 || format.finals != null)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...format.groups.asMap().entries.map((e) => _pill(
                            label: '${e.value.name} (${e.value.size})',
                            active: e.key == _activeIdx && !_showFinals,
                            onTap: () => setState(() {
                              _activeIdx = e.key;
                              _showFinals = false;
                            }),
                          )),
                      if (format.finals != null)
                        _pill(
                          label: format.finals!.name,
                          active: _showFinals,
                          onTap: () =>
                              setState(() => _showFinals = true),
                        ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (!_showFinals) ...[
                  Text(
                    '${activeGroup.size}팀 풀리그 — ${polygonName(activeGroup.size)}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E3A8A)),
                  ),
                  Text(
                    '${activeGroup.matches}경기 · 팀당 ${activeGroup.size - 1}경기',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  PolygonBracket(
                    teams: activeGroup.size,
                    teamData: teamData,
                    matches: activeMatches,
                  ),
                ] else if (format.finals != null) ...[
                  Text(
                    '본선 ${format.finals!.name} 토너먼트',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E3A8A)),
                  ),
                  Text(
                    '${format.finals!.matches}경기 · 부전승 자리 자동 배치',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  TournamentBracket(size: format.finals!.size),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E3A8A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active
                  ? const Color(0xFF1E3A8A)
                  : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: active ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(GroupInfo group, List<MatchInfo> matches) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${group.name} 경기 일정',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A))),
          const SizedBox(height: 8),
          ...matches.map((m) => Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 8),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: Color(0xFFF3F4F6), width: 0.5)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                        width: 40,
                        child: Text('M${m.num_}',
                            style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                    SizedBox(
                        width: 50,
                        child: Text('${m.court}코트',
                            style: const TextStyle(
                                color: Color(0xFF059669), fontSize: 12))),
                    Expanded(
                        child: Text(
                            '팀 ${m.team1Index + 1} vs 팀 ${m.team2Index + 1}',
                            style: const TextStyle(fontSize: 13))),
                    Text(m.time,
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 11)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('과천시 협회 규정',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92400E),
                  fontSize: 12)),
          SizedBox(height: 4),
          Text(
            '· 25점 1세트 (듀스 31점)\n'
            '· 동률 처리: 다승 → 승자승 → 득실차 → 합산나이\n'
            '· 예선 1위 성적순 본선 부전승 배치\n'
            '· 예선 게임수 많은 조 1위 자동 부전승\n'
            '· B/C/D/E조 우승팀 익년 1월 승급',
            style: TextStyle(
                fontSize: 11, color: Color(0xFF78350F), height: 1.7),
          ),
        ],
      ),
    );
  }
}
