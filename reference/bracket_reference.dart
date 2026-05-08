// ===========================================================================
// 배드민턴 대진표 자동 생성 시스템 - Flutter 참조 구현
// 과천시 협회 규정 적용
// ===========================================================================
//
// 이 파일은 reference/bracket_reference.dart 로 두고,
// Claude Code가 읽어서 아래 SECTION별로 분리된 별도 파일로 만든다.
//
// 권장 분리 구조:
// - lib/models/bracket_models.dart       (SECTION 1)
// - lib/utils/bracket_logic.dart         (SECTION 2)
// - lib/widgets/polygon_bracket.dart     (SECTION 3)
// - lib/widgets/tournament_bracket.dart  (SECTION 4)
// - lib/screens/bracket_generator.dart   (SECTION 5)
// ===========================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ===========================================================================
// SECTION 1: 데이터 모델
// File: lib/models/bracket_models.dart
// ===========================================================================

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

// ===========================================================================
// SECTION 2: 알고리즘 (순수 함수)
// File: lib/utils/bracket_logic.dart
// ===========================================================================

/// 팀 수에 따라 대진방식 자동 결정.
/// 4팀 미만이면 null 반환 (협회 규정상 진행 불가).
BracketFormat? determineFormat(int n) {
  if (n < 4) return null;

  // 헬퍼: 총 팀을 k개 조로 균등 분할
  List<int> split(int total, int k) {
    final base = total ~/ k;
    final rem = total % k;
    return List.generate(k, (i) => base + (i < rem ? 1 : 0));
  }

  // 4-5팀: 풀리그 단독
  if (n <= 5) {
    return BracketFormat(
      groups: [GroupInfo(size: n, name: '본선', matches: n * (n - 1) ~/ 2)],
      finals: null,
      format: '풀리그 단독',
    );
  }

  late List<int> sizes;
  late int fSize;
  bool recommended = false;

  if (n == 6) {
    sizes = [3, 3];
    fSize = 2;
  } else if (n == 7) {
    sizes = [4, 3];
    fSize = 2;
  } else if (n == 8) {
    sizes = [4, 4];
    fSize = 4;
  } else if (n == 9) {
    sizes = [3, 3, 3];
    fSize = 3;
  } else if (n == 10) {
    sizes = [5, 5];
    fSize = 4;
  } else if (n == 11) {
    sizes = [6, 5];
    fSize = 4;
    recommended = true;
  } else if (n == 12) {
    sizes = [3, 3, 3, 3];
    fSize = 4;
  } else if (n <= 16) {
    sizes = split(n, 4);
    fSize = 8;
  } else if (n <= 24) {
    sizes = split(n, (n / 4).ceil());
    fSize = 8;
  } else if (n <= 32) {
    sizes = split(n, 8);
    fSize = 8;
  } else if (n <= 48) {
    sizes = split(n, (n / 4).ceil());
    fSize = 16;
  } else if (n <= 64) {
    sizes = split(n, 16);
    fSize = 16;
  } else {
    sizes = split(n, (n / 5).ceil());
    fSize = 32;
  }

  final groups = <GroupInfo>[];
  for (int i = 0; i < sizes.length; i++) {
    groups.add(GroupInfo(
      size: sizes[i],
      name: '${String.fromCharCode(65 + i)}조',
      matches: sizes[i] * (sizes[i] - 1) ~/ 2,
    ));
  }

  const fNames = {
    2: '결승',
    3: '본선(3강)',
    4: '4강',
    8: '8강',
    16: '16강',
    32: '32강',
  };

  return BracketFormat(
    groups: groups,
    finals: FinalsInfo(
      size: fSize,
      name: fNames[fSize]!,
      matches: fSize - 1,
    ),
    format: '${groups.length}개 조 풀리그 + ${fNames[fSize]} 토너먼트',
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

// ===========================================================================
// SECTION 3: 다각형 대진표 위젯
// File: lib/widgets/polygon_bracket.dart
// ===========================================================================

/// 정N각형의 모든 정점에 팀을 배치하고 모든 정점을 선으로 연결.
/// 각 선이 하나의 경기 = N(N-1)/2 경기 자동 생성.
class PolygonBracket extends StatelessWidget {
  final int teams;
  final List<TeamData> teamData;
  final List<MatchInfo>? matches;

  const PolygonBracket({
    super.key,
    required this.teams,
    required this.teamData,
    this.matches,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.75,
      child: CustomPaint(
        painter: PolygonBracketPainter(
          teams: teams,
          teamData: teamData,
          matches: matches,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class PolygonBracketPainter extends CustomPainter {
  final int teams;
  final List<TeamData> teamData;
  final List<MatchInfo>? matches;

  PolygonBracketPainter({
    required this.teams,
    required this.teamData,
    this.matches,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.45;
    final r = math.min(size.width / 2, size.height / 2) * 0.6;
    final n = teams;
    final startAngle = -math.pi / 2; // 12시 방향에서 시작
    final step = 2 * math.pi / n;

    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final a = startAngle + i * step;
      points.add(Offset(cx + r * math.cos(a), cy + r * math.sin(a)));
    }

    final edgePaint = Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    int matchIdx = 0;
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        canvas.drawLine(points[i], points[j], edgePaint);

        if (n <= 6 && matches != null && matchIdx < matches!.length) {
          _drawMatchLabel(
            canvas,
            points[i],
            points[j],
            cx,
            cy,
            '${matches![matchIdx].court}코트',
          );
        }
        matchIdx++;
      }
    }

    final vertexPaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..style = PaintingStyle.fill;

    for (final p in points) {
      canvas.drawCircle(p, 4.5, vertexPaint);
    }

    for (int i = 0; i < n; i++) {
      final a = startAngle + i * step;
      const labelDist = 38.0;
      final lx = cx + (r + labelDist) * math.cos(a);
      final ly = cy + (r + labelDist) * math.sin(a);

      final teamName =
          i < teamData.length ? teamData[i].name : '팀 ${i + 1}';
      final players = i < teamData.length
          ? teamData[i].players.join(' · ')
          : '선수 A · B';

      _drawLabel(canvas, lx, ly, teamName, players, math.cos(a));
    }
  }

  void _drawMatchLabel(
    Canvas canvas,
    Offset p1,
    Offset p2,
    double cx,
    double cy,
    String text,
  ) {
    final mx = (p1.dx + p2.dx) / 2;
    final my = (p1.dy + p2.dy) / 2;
    final dx = mx - cx;
    final dy = my - cy;
    final dist = math.sqrt(dx * dx + dy * dy);
    double ox = 0, oy = 0;
    if (dist > 4) {
      ox = (dx / dist) * 8;
      oy = (dy / dist) * 8;
    }

    final rect = Rect.fromCenter(
      center: Offset(mx + ox, my + oy),
      width: 36,
      height: 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..color = const Color(0xFFDC2626)
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFDC2626),
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(mx + ox - tp.width / 2, my + oy - tp.height / 2));
  }

  void _drawLabel(Canvas canvas, double lx, double ly, String name,
      String players, double cosA) {
    final namePainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Color(0xFF1E3A8A),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final playersPainter = TextPainter(
      text: TextSpan(
        text: players,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double nameOffsetX = -namePainter.width / 2;
    double playersOffsetX = -playersPainter.width / 2;
    if (cosA > 0.3) {
      nameOffsetX = 0;
      playersOffsetX = 0;
    } else if (cosA < -0.3) {
      nameOffsetX = -namePainter.width;
      playersOffsetX = -playersPainter.width;
    }

    namePainter.paint(canvas, Offset(lx + nameOffsetX, ly - 8));
    playersPainter.paint(canvas, Offset(lx + playersOffsetX, ly + 6));
  }

  @override
  bool shouldRepaint(PolygonBracketPainter oldDelegate) {
    return oldDelegate.teams != teams || oldDelegate.matches != matches;
  }
}

// ===========================================================================
// SECTION 4: 토너먼트 브래킷 위젯
// File: lib/widgets/tournament_bracket.dart
// ===========================================================================

class TournamentBracket extends StatelessWidget {
  final int size;
  final List<TeamData>? seedTeams;

  const TournamentBracket({
    super.key,
    required this.size,
    this.seedTeams,
  });

  @override
  Widget build(BuildContext context) {
    final rounds = (math.log(size) / math.log(2)).ceil();
    final slotCount = math.pow(2, rounds).toInt();

    return SizedBox(
      height: slotCount * 35.0 + 30,
      child: CustomPaint(
        painter: TournamentBracketPainter(
          rounds: rounds,
          slotCount: slotCount,
          actualTeams: size,
          seedTeams: seedTeams,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class TournamentBracketPainter extends CustomPainter {
  final int rounds;
  final int slotCount;
  final int actualTeams;
  final List<TeamData>? seedTeams;

  TournamentBracketPainter({
    required this.rounds,
    required this.slotCount,
    required this.actualTeams,
    this.seedTeams,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colWidth = size.width / (rounds + 1);
    final usableHeight = size.height - 20;

    final slots = <_BracketSlot>[];
    for (int r = 0; r <= rounds; r++) {
      final slotsInRound = slotCount ~/ math.pow(2, r).toInt();
      final spacing = usableHeight / slotsInRound;
      for (int s = 0; s < slotsInRound; s++) {
        slots.add(_BracketSlot(
          round: r,
          slot: s,
          x: r * colWidth + 5,
          y: spacing * s + spacing / 2 - 12,
          width: colWidth - 14,
        ));
      }
    }

    for (final s in slots.where((s) => s.round < rounds)) {
      final isFirst = s.round == 0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.x, s.y, s.width, 24),
          const Radius.circular(3),
        ),
        Paint()
          ..color = isFirst
              ? const Color(0xFFDBEAFE)
              : const Color(0xFFF3F4F6)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.x, s.y, s.width, 24),
          const Radius.circular(3),
        ),
        Paint()
          ..color = isFirst
              ? const Color(0xFF1E3A8A)
              : const Color(0xFFD1D5DB)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke,
      );

      if (isFirst) {
        String label;
        if (s.slot < actualTeams) {
          label = seedTeams != null && s.slot < seedTeams!.length
              ? seedTeams![s.slot].name
              : '시드 ${s.slot + 1}';
        } else {
          label = '부전승';
        }
        if (label.length > 8) label = '${label.substring(0, 8)}..';

        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Color(0xFF1E3A8A),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(s.x + 6, s.y + 7));
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    for (final s in slots) {
      if (s.round == 0 || s.round >= rounds) continue;
      final c1 = slots.where((c) =>
          c.round == s.round - 1 && c.slot == s.slot * 2).toList();
      final c2 = slots.where((c) =>
          c.round == s.round - 1 && c.slot == s.slot * 2 + 1).toList();
      if (c1.isEmpty || c2.isEmpty) continue;

      canvas.drawLine(
        Offset(c1.first.x + c1.first.width, c1.first.y + 12),
        Offset(s.x, s.y + 12),
        linePaint,
      );
      canvas.drawLine(
        Offset(c2.first.x + c2.first.width, c2.first.y + 12),
        Offset(s.x, s.y + 12),
        linePaint,
      );
    }

    final tp = TextPainter(
      text: const TextSpan(
        text: '예선 1위 성적순으로 부전승 자리 배치',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(5, size.height - 14));
  }

  @override
  bool shouldRepaint(TournamentBracketPainter oldDelegate) {
    return oldDelegate.actualTeams != actualTeams ||
        oldDelegate.rounds != rounds;
  }
}

class _BracketSlot {
  final int round;
  final int slot;
  final double x;
  final double y;
  final double width;

  _BracketSlot({
    required this.round,
    required this.slot,
    required this.x,
    required this.y,
    required this.width,
  });
}

// ===========================================================================
// SECTION 5: 메인 화면
// File: lib/screens/bracket_generator.dart
// ===========================================================================

class BracketGeneratorScreen extends StatefulWidget {
  const BracketGeneratorScreen({super.key});

  @override
  State<BracketGeneratorScreen> createState() =>
      _BracketGeneratorScreenState();
}

class _BracketGeneratorScreenState extends State<BracketGeneratorScreen> {
  int _teamCount = 11;
  int _courts = 4;
  int _activeIdx = 0;
  bool _showFinals = false;
  late TextEditingController _teamCountController;

  @override
  void initState() {
    super.initState();
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
      return Scaffold(
        appBar: AppBar(
          title: const Text('대진표 생성'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              '최소 4팀 이상이어야 진행 가능합니다\n(과천시 협회 규정)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('대진표 자동 생성'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
                items: const [2, 3, 4, 5, 6, 8]
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

// ===========================================================================
// 사용 예시 (테스트용 main)
// ===========================================================================

void main() {
  runApp(MaterialApp(
    title: '배드민턴 대진표',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
    ),
    home: const BracketGeneratorScreen(),
    debugShowCheckedModeBanner: false,
  ));
}
