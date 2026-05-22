// 배드민턴 대진표 자동 생성 — 운영 화면 탭 본체
//
// 구조:
//   1) 종목 셀렉터 (혼복/남복/여복)
//   2) 코트 수
//   3) "대진표 생성" 버튼
//   4) 생성 후 → (종목 × 연령 × 급수) Division 카드 리스트
//      각 카드는 펼치면 다각형/토너먼트 시각화 + 일정표

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_colors.dart';
import '../../models/bracket_models.dart';
import '../../models/match_score.dart';
import '../../models/match.dart';
import '../../models/player.dart';
import '../../models/tournament.dart';
import '../../models/venue.dart';
import '../../services/analytics_service.dart';
import '../../utils/age_group.dart';
import '../../utils/bracket_logic.dart';
import '../../utils/match_key.dart';
import 'polygon_bracket.dart';
import 'tournament_bracket.dart';

class BracketGeneratorTab extends StatefulWidget {
  final Tournament tournament;
  final List<Player> selectedPlayers;
  final Map<AssignKey, String> assignMap;

  /// 사용자가 참가자 탭에서 토글한 연령 칩(전체 제외). 비어 있으면 빈 대진표.
  final Set<String> activeAgeGroups;

  /// 사용자가 참가자 탭에서 토글한 급수 칩(전체 제외). 비어 있으면 빈 대진표.
  final Set<String> activeGrades;

  /// 종목 셀렉터·생성된 Division 리스트가 바뀔 때마다 호출.
  /// divisions=null 은 "재생성 유도(=초기화)" 의미. 빈 리스트와 구분.
  /// events 는 사용자가 선택한 종목 라벨 리스트 (예: ['혼복','남복','여복']).
  final void Function(List<String> events, List<Division>? divisions)?
      onChanged;

  /// 경기시간 탭에서 입력된 매치 점수 + 팀 식별. _DivisionCard 매치 셀/순위표가
  /// 이 값을 그대로 사용 — 저장된 teamA/teamB 가 현재 페어와 다르면 자동 무효화.
  /// 키 빌드는 `utils/match_key.dart`.
  final Map<String, MatchScore> matchScores;

  /// 참가자 부족 시 인접 연령 자동 합치기 스위치. ON 이면 (종목·급수) 안에서
  /// 인접 연령들을 묶어 각 셀이 최소 6명(=3팀)을 채우도록 한다.
  /// 라벨은 '20·30' 처럼 가운뎃점으로 결합되며 [ageMatches] 가 처리.
  final bool autoMergeAges;

  /// 대회 일수 (1~4). 2 이상일 때 대진표 설정 카드에 일자 셀렉터 노출.
  final int totalDays;

  /// 각 division 이 속하는 일자를 반환. 일자 필터에 사용.
  /// (event, age, grade) 가 모두 매칭되는 첫 일자를 반환. 매칭 안 되면 1.
  /// → 각 division 이 정확히 하나의 일자에 속해서 1일차 + 2일차 + ... = 전체 가 성립.
  final int Function(Division d)? divisionDay;

  const BracketGeneratorTab({
    super.key,
    required this.tournament,
    this.selectedPlayers = const [],
    this.assignMap = const {},
    this.activeAgeGroups = const {},
    this.activeGrades = const {},
    this.onChanged,
    this.matchScores = const {},
    this.autoMergeAges = false,
    this.totalDays = 1,
    this.divisionDay,
  });

  /// 활성 경기장 (코트 수 > 0) 만 반환.
  List<Venue> get activeVenues =>
      tournament.venues.where((v) => v.courts > 0).toList();

  @override
  State<BracketGeneratorTab> createState() => _BracketGeneratorTabState();
}

class _BracketGeneratorTabState extends State<BracketGeneratorTab> {
  static const List<String> _events = ['혼복', '남복', '여복'];

  /// 선택된 종목 셋. 다중 선택 — 체크된 종목 모두 한 번에 대진표가 생성됨.
  final Set<String> _selectedEvents = {'혼복'};
  int _courts = 4;

  /// 일자 필터 — null = 전체 일자, 정수 = 그 일자에 활성인 종목의 부서만 표시.
  /// 다일 대회(_totalDays > 1) 일 때만 노출.
  int? _filterDay;

  List<Division>? _divisions; // null = 미생성
  String? _expandedKey;
  bool _generatingPdf = false;
  /// 각 Division 카드의 GlobalKey — 펼침 시 ensureVisible 로 화면 상단에 노출.
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _courts = widget.tournament.totalActiveCourts.clamp(1, 999);
    // 영속화된 결과가 있으면 그대로 hydrate — 셔플 페어링 결과가 탭 전환 후에도
    // 보존되도록. stale 가능성(참가자 변동 등)은 사용자가 명시적으로
    // '대진표 다시 생성' 을 눌러 갱신하는 모델.
    final saved = widget.tournament.divisions;
    if (saved.isNotEmpty) {
      _selectedEvents
        ..clear()
        ..addAll(widget.tournament.bracketEventList);
      _divisions = saved;
    }
  }

  String _keyOf(Division d) => '${d.event}|${d.ageGroup}|${d.grade}';

  /// 현재 선택된 종목 셋을 표시 순서대로 정렬해 반환 (혼복→남복→여복).
  List<String> get _orderedSelectedEvents =>
      _events.where(_selectedEvents.contains).toList();

  /// (종목·급수) 안에서 인접 연령을 합쳐 각 셀이 최소 6명을 채우도록 하는 라벨 리스트.
  /// 사용 알고리즘:
  /// 1) [ages] 순서대로 각 연령의 선수 수를 계산 (event/grade/gender 필터 반영).
  /// 2) 누적 풀이 6 미만이면 다음 연령을 합쳐 누적 (가운뎃점 '·' 으로 라벨 결합).
  /// 3) 누적 풀이 6 이상이 되면 라벨을 emit 하고 누적 초기화.
  /// 4) 마지막에 남은 누적(여전히 6 미만)도 emit — 시각화를 위해 카드는 안 만들어지지만
  ///    사용자가 확인할 수 있도록 빈 라벨로라도 둘 수 있음. 여기서는 6 미만이면 drop.
  List<String> _computeMergedAgeLabels({
    required String event,
    required String grade,
    required List<String> ages,
    required List<String> allAges,
  }) {
    bool genderOk(Player p) {
      if (event == '남복') return p.gender == '남';
      if (event == '여복') return p.gender == '여';
      return true;
    }

    int countFor(String age) => widget.selectedPlayers
        .where(genderOk)
        .where((p) => p.grade == grade)
        .where((p) => ageMatches(age, p.age, allAges))
        .length;

    final out = <String>[];
    final buf = <String>[];
    int acc = 0;
    for (final age in ages) {
      buf.add(age);
      acc += countFor(age);
      if (acc >= 6) {
        out.add(buf.join('·'));
        buf.clear();
        acc = 0;
      }
    }
    // 마지막 누적이 6 미만이면, 가능하면 직전 라벨에 덧붙여 흡수 (드랍 방지).
    if (buf.isNotEmpty) {
      if (out.isNotEmpty) {
        final last = out.removeLast();
        out.add('$last·${buf.join('·')}');
      } else {
        // 단일 누적도 6 미만이고 이전 emit 도 없으면 그냥 drop — 부서 생성 불가.
      }
    }
    return out;
  }

  void _generate() {
    final t = widget.tournament;
    // 칩으로 활성화한 라벨만 사용. 비어있으면 빈 리스트 (대진표 미생성).
    final ages = activeAgeLabels(t)
        .where(widget.activeAgeGroups.contains)
        .toList();
    final grades = activeGradeLabels(t)
        .where(widget.activeGrades.contains)
        .toList();
    // ageMatches 가 라벨 인접성 판단에 쓰는 전체 라벨 (활성 여부와 무관).
    final allAges = activeAgeLabels(t);

    // 첫 생성은 결정적(정렬 기반), 그 다음 호출부터는 셔플 페어링 — 사용자가
    // '대진표 다시 생성' 을 누르면 새 조합이 나오도록.
    final isReshuffle = _divisions != null;

    // 선택된 종목 각각에 대해 buildDivisions 를 호출하고 결과를 이어 붙인다.
    // 카드 표시 순서는 종목 셀렉터 노출 순서(혼복→남복→여복)를 따른다.
    // autoMergeAges=true 면 (종목·급수)별로 인접 연령을 묶은 라벨을 생성해 전달.
    final divisions = <Division>[];
    for (final event in _orderedSelectedEvents) {
      if (widget.autoMergeAges) {
        for (final grade in grades) {
          final mergedAges = _computeMergedAgeLabels(
              event: event,
              grade: grade,
              ages: ages,
              allAges: allAges);
          divisions.addAll(buildDivisions(
            players: widget.selectedPlayers,
            event: event,
            ageLabels: mergedAges,
            allAgeLabels: allAges,
            gradeLabels: [grade],
            ageMatches: ageMatches,
            venueIdOf: (event, age, grade) =>
                widget.assignMap[
                        AssignKey(event, age.split('·').first, grade)] ??
                    '',
            shuffle: isReshuffle,
          ));
        }
      } else {
        divisions.addAll(buildDivisions(
          players: widget.selectedPlayers,
          event: event,
          ageLabels: ages,
          allAgeLabels: allAges,
          gradeLabels: grades,
          ageMatches: ageMatches,
          venueIdOf: (event, age, grade) =>
              widget.assignMap[AssignKey(event, age, grade)] ?? '',
          shuffle: isReshuffle,
        ));
      }
    }
    setState(() {
      _divisions = divisions;
      _expandedKey = null; // 모든 카드 접힘으로 시작 — 사용자가 눌러서 펼침.
    });
    widget.onChanged?.call(_orderedSelectedEvents, divisions);
    AnalyticsService.bracketGenerate(
      tournamentId: widget.tournament.id,
      divisionCount: divisions.length,
    );
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
            Row(children: [
              Expanded(child: _buildGenerateButton()),
              if (_divisions != null && _divisions!.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildPdfButton(),
              ],
            ]),
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
          // 일자 셀렉터 (다일 대회만). '전체' + 1일차/2일차/... 토글.
          if (widget.totalDays > 1) ...[
            Row(children: [
              const SizedBox(width: 60, child: Text('일자')),
              Expanded(child: _buildDayChips()),
            ]),
            const SizedBox(height: 8),
          ],
          // 종목 셀렉터 (다중 선택). 체크된 종목 모두 한 번에 대진표가 생성됨.
          Row(children: [
            const SizedBox(width: 60, child: Text('종목')),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _events.map((e) {
                  final on = _selectedEvents.contains(e);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (on) {
                          // 마지막 한 개는 해제 불가 — 빈 셀렉션 방지.
                          if (_selectedEvents.length > 1) {
                            _selectedEvents.remove(e);
                          }
                        } else {
                          _selectedEvents.add(e);
                        }
                        _divisions = null; // 셀렉션 바뀌면 재생성 유도
                        _expandedKey = null;
                      });
                      widget.onChanged?.call(_orderedSelectedEvents, null);
                    },
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            on
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 14,
                            color: on
                                ? Colors.white
                                : const Color(0xFF1E3A8A),
                          ),
                          const SizedBox(width: 4),
                          Text(e,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: on
                                      ? Colors.white
                                      : const Color(0xFF1E3A8A))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          // 경기장 합산 코트 수 — 대회날짜 venue 칩과 동일 디자인(palette.chip + 검정).
          Row(children: [
            const SizedBox(width: 60, child: Text('코트 수')),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final v in widget.activeVenues)
                    Builder(builder: (_) {
                      // 통합 헬퍼 — 앱 전체 동일 정책.
                      final palette = AppColors.venuePaletteForVenue(
                          v, widget.activeVenues);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: palette.chip,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${v.name.isEmpty ? '미지정' : v.name} ${v.courts}코트',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  /// PDF 내보내기 버튼. 생성된 division 별로 카드를 차례로 펼쳐 캡처, A4 페이지로 묶어 공유.
  Widget _buildPdfButton() {
    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        onPressed: _generatingPdf ? null : _exportPdf,
        icon: _generatingPdf
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.text),
              )
            : const Icon(Icons.picture_as_pdf,
                size: 18, color: AppColors.text),
        label: const Text('PDF',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gray2,
          foregroundColor: AppColors.text,
          disabledBackgroundColor: const Color(0xFFE5E8ED),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          minimumSize: const Size(0, 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  /// 생성된 모든 division 을 순서대로 펼쳐 카드 RepaintBoundary 를 캡처,
  /// 한 페이지 한 division 으로 PDF 묶어 공유. 캡처가 끝나면 원래 펼침 상태로 복원.
  Future<void> _exportPdf() async {
    final divs = _divisions;
    if (divs == null || divs.isEmpty) return;
    final originalExpand = _expandedKey;
    setState(() => _generatingPdf = true);
    try {
      final pdf = pw.Document();
      for (final d in divs) {
        final dKey = _keyOf(d);
        // 1) 이 카드를 펼치고 다음 프레임 대기 — 본문 렌더 완료 보장.
        setState(() => _expandedKey = dKey);
        await WidgetsBinding.instance.endOfFrame;
        // 큰 대진표 + 라벨 레이아웃이 안정될 충분한 지연.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final cardKey = _cardKeys[dKey];
        final ctx = cardKey?.currentContext;
        if (ctx == null) continue;
        final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) continue;
        // pixelRatio 3.0 — 인쇄·확대 시도 선명하게.
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;
        final pdfImage = pw.MemoryImage(byteData.buffer.asUint8List());
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (c) => pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
        ));
      }
      if (pdf.document.pdfPageList.pages.isEmpty) return;
      final bytes = await pdf.save();
      final ts = DateTime.now().millisecondsSinceEpoch;
      await Printing.sharePdf(
          bytes: bytes, filename: 'bracket_$ts.pdf');
    } finally {
      if (mounted) {
        setState(() {
          _expandedKey = originalExpand;
          _generatingPdf = false;
        });
      }
    }
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

  // ── 일자 셀렉터 — 다일 대회 때만 노출 ───────
  Widget _buildDayChips() {
    Widget chip(String label, bool on, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: on
                        ? Colors.white
                        : const Color(0xFF1E3A8A))),
          ),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip('전체', _filterDay == null,
            () => setState(() => _filterDay = null)),
        for (int d = 1; d <= widget.totalDays; d++)
          chip('$d일차', _filterDay == d,
              () => setState(() => _filterDay = d)),
      ],
    );
  }

  // ── 결과: 요약 + Division 카드 리스트 ──────
  List<Widget> _buildResults() {
    final allDivs = _divisions!;
    // 일자 필터 적용 — 각 division 은 정확히 한 일자에 속함 (첫 매칭).
    // 전체 = 1일차 + 2일차 + ... 합이 정확히 성립.
    final divs = _filterDay == null
        ? allDivs
        : allDivs.where((d) {
            final fn = widget.divisionDay;
            if (fn == null) return true;
            return fn(d) == _filterDay;
          }).toList();
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
              '${_orderedSelectedEvents.join("·")} 으로 생성 가능한 부서가 없습니다.\n참가자/연령/급수 설정을 확인하세요.',
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
      ...divs.map((d) {
        final dKey = _keyOf(d);
        final cardKey = _cardKeys.putIfAbsent(dKey, () => GlobalKey());
        return RepaintBoundary(
          key: cardKey,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: _DivisionCard(
              division: d,
              expanded: dKey == _expandedKey,
              courts: _courts,
              venues: widget.activeVenues,
              assignMap: widget.assignMap,
              tournament: widget.tournament,
              matchScores: widget.matchScores,
              onToggle: () {
                final willExpand = dKey != _expandedKey;
                setState(() {
                  _expandedKey = willExpand ? dKey : null;
                });
                if (willExpand) {
                  // 펼침 후 다음 프레임에 카드 상단을 화면 위쪽으로 정렬 → 대진표가 하단에 노출.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final ctx = cardKey.currentContext;
                    if (ctx != null) {
                      Scrollable.ensureVisible(
                        ctx,
                        duration: const Duration(milliseconds: 300),
                        alignment: 0.0,
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
              },
            ),
          ),
        );
      }),
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
  final Tournament tournament;
  final Map<String, MatchScore> matchScores;

  const _DivisionCard({
    required this.division,
    required this.expanded,
    required this.courts,
    required this.venues,
    required this.assignMap,
    required this.onToggle,
    required this.tournament,
    this.matchScores = const {},
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

  /// 경기장별 로컬 코트 시작 번호. 항상 1.
  /// 각 경기장이 자체적으로 1코트부터 시작하도록 함.
  int get startCourt => 1;

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
    final dur = widget.tournament.matchDurationMinutes;
    // 같은 팀이 라운드 사이 한 슬롯 쉬도록 휴식 = 경기당 분.
    // round-robin 특성상 모든 팀이 매 라운드 경기하므로 라운드 사이 휴식이
    // 곧 개별 선수의 휴식이 됨.
    final rest = dur;
    final allocs = allocateGroups(
      groups: widget.division.format.groups,
      venueCourts: widget.assignedCourts,
      matchMinutes: dur,
      restMinutes: rest,
    );
    final a = allocs[idx];
    return generateMatches(
      group: g,
      courts: a.parallelCourts,
      startCourt: widget.startCourt + a.courtOffset,
      startMatchNum: startNum,
      startTime: widget.tournament.matchStartTime,
      matchMinutes: dur,
      extraStartMinutes: a.extraStartMinutes,
      restMinutes: rest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.division;
    final fmt = d.format;
    final teamCount = d.teams.length;
    final venue = widget.assignedVenue;
    // 13.jpg 코트 팔레트 — venue 가 있으면 그 색상에서 5변형 derive, 없으면 중성 톤.
    final palette =
        venue != null
            ? AppColors.venuePaletteForVenue(venue, widget.venues)
            : null;

    return Container(
      decoration: BoxDecoration(
        // 카드 본체 배경은 흰색 통일 — 좌측 컬러바와 보더만 venue 색.
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette?.cardBorder ?? AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 좌측 컬러바 — venue 가 있을 때만. Stack 으로 자식 height 에 stretch.
          if (palette != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: ColoredBox(color: palette.primary),
            ),
          Padding(
            padding: EdgeInsets.only(left: palette != null ? 6 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 헤더 (탭하면 펼침) — 14.jpg 디자인: 박스 없는 텍스트 + venue 칩만 박스.
                InkWell(
                  onTap: widget.onToggle,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          d.event,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${d.ageGroup} / ${d.grade}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$teamCount팀',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                        if (venue != null && palette != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.chip,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.displayNameFor(venue),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: palette.text,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // 본문 (펼친 경우)
                if (widget.expanded) ...[
                  Divider(
                      height: 1,
                      color: palette?.cardBorder ?? AppColors.divider),
                  _buildBody(d, fmt),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Division d, BracketFormat fmt) {
    if (_activeGroup >= fmt.groups.length) _activeGroup = 0;
    final activeGroup = fmt.groups[_activeGroup];
    final activeMatches = _matchesForGroup(activeGroup, _activeGroup);

    // teamData: 카드 단위로 d.teams 사용. 활성 조에 해당하는 팀만 잘라 보내기.
    // (snake draft 적용된 순서로 미리 재정렬되어 있음)
    final teamData = _teamsForGroup(d.teams, fmt, _activeGroup);

    final venue = widget.assignedVenue;
    final palette =
        venue != null
            ? AppColors.venuePaletteForVenue(venue, widget.venues)
            : null;
    final venueColor = palette?.primary ?? const Color(0xFF1E3A8A);

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
                '${activeGroup.size}팀',
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A8A)),
              ),
              if (venue != null && palette != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.chip,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place,
                          size: 12, color: palette.text),
                      const SizedBox(width: 2),
                      Text(widget.displayNameFor(venue),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: palette.text)),
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
          const SizedBox(height: 4),
          PolygonBracket(
            teams: activeGroup.size,
            teamData: teamData,
            matches: activeMatches,
            courtColor: venueColor,
          ),
          const SizedBox(height: 4),
          _rankingTable(teamData, activeMatches, activeGroup),
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
          const SizedBox(height: 4),
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
                startTime: widget.tournament.matchStartTime,
                matchMinutes: widget.tournament.matchDurationMinutes,
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
            AppColors.primaryMid),
        btn('본선', _showFinals,
            () => setState(() => _showFinals = true),
            const Color(0xFF2563EB)),
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

    final activeGroup =
        widget.division.format.groups[_activeGroup];
    Widget dataCell(int row, int col) {
      if (row == col) {
        return cell(
          txt('-', size: 16, color: const Color(0xFF9CA3AF)),
        );
      }
      // 라운드로빈은 회전 방식으로 페어를 만들기 때문에 team1Index < team2Index 가
      // 보장되지 않는다. 양방향으로 매칭해야 누락이 생기지 않는다.
      MatchInfo? m;
      for (final x in matches) {
        if ((x.team1Index == row && x.team2Index == col) ||
            (x.team1Index == col && x.team2Index == row)) {
          m = x;
          break;
        }
      }
      if (m == null) {
        return cell(txt('-'));
      }
      final key = matchScoreKey(
        event: widget.division.event,
        age: widget.division.ageGroup,
        grade: widget.division.grade,
        groupName: activeGroup.name,
        matchNum: m.num_,
      );
      // scoreFor: 저장된 teamA/B(IDs) 와 현재 m.team1Index/team2Index 의 IDs 가
      // 일치할 때만 (team1점수, team2점수) 반환. 페어 변경 후엔 null.
      final pair = widget.matchScores[key]?.scoreFor(
        teams[m.team1Index].playerIds,
        teams[m.team2Index].playerIds,
      );
      String scoreText;
      if (pair == null) {
        scoreText = '-';
      } else {
        // pair 는 (team1Index 점수, team2Index 점수). row 입장에서 표시하려면
        // m.team1Index == row 면 그대로, 반대 방향(=row=team2Index)이면 swap.
        final isReverse = m.team1Index == col; // row 가 team2Index 쪽
        final myScore = isReverse ? pair.$2 : pair.$1;
        final oppScore = isReverse ? pair.$1 : pair.$2;
        scoreText = '$myScore-$oppScore';
      }
      return cell(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          txt(scoreText,
              size: 13,
              w: FontWeight.w700,
              color: pair == null
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF1E3A8A)),
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

  /// 하단 순위표 — 다승–승자승–다득점–득실차 기준.
  /// matchScores 에 기록된 실제 매치 결과로 승/패/득/실/점수 계산.
  /// 미진행 매치는 통계 미반영(=0). 패/실 칸은 빨강, 승/득/차/점수 칸은 파랑.
  Widget _rankingTable(
      List<TeamData> teams, List<MatchInfo> matches, GroupInfo activeGroup) {
    const blue = Color(0xFF1E3A8A);
    const red = Color(0xFFDC2626);

    Widget headerCell(String s,
            {Color color = const Color(0xFF374151), double size = 11}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
          color: const Color(0xFFF7F9FC),
          alignment: Alignment.center,
          child: Text(s,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.w600,
                  color: color)),
        );

    Widget dataCell(String s,
            {FontWeight w = FontWeight.w500,
            Color color = const Color(0xFF111827),
            double size = 11}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
          alignment: Alignment.center,
          child: Text(s,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: size,
                  fontWeight: w,
                  color: color,
                  height: 1.3)),
        );

    // 매치 결과 기반 실제 통계 계산.
    // 정렬 우선순위: 다승 → 승자승(상대 전적) → 다득점(총 득점) → 득실차.
    final n = teams.length;
    final wins = List.filled(n, 0);
    final losses = List.filled(n, 0);
    final pf = List.filled(n, 0); // points for
    final pa = List.filled(n, 0); // points against
    final h2h = List.generate(n, (_) => List.filled(n, 0));
    for (final m in matches) {
      final key = matchScoreKey(
        event: widget.division.event,
        age: widget.division.ageGroup,
        grade: widget.division.grade,
        groupName: activeGroup.name,
        matchNum: m.num_,
      );
      // 저장된 teamA/B(IDs) 와 현재 m.team1Index/team2Index 의 IDs 가 일치할 때만
      // 점수 반영 — 페어 변경 후엔 자동 무효화.
      final pair = widget.matchScores[key]?.scoreFor(
        teams[m.team1Index].playerIds,
        teams[m.team2Index].playerIds,
      );
      if (pair == null) continue;
      final i = m.team1Index;
      final j = m.team2Index;
      final s1 = pair.$1;
      final s2 = pair.$2;
      pf[i] += s1;
      pa[i] += s2;
      pf[j] += s2;
      pa[j] += s1;
      if (s1 > s2) {
        wins[i]++;
        losses[j]++;
        h2h[i][j]++;
      } else if (s2 > s1) {
        wins[j]++;
        losses[i]++;
        h2h[j][i]++;
      }
    }
    final order = List.generate(n, (i) => i);
    order.sort((a, b) {
      if (wins[a] != wins[b]) return wins[b].compareTo(wins[a]);
      // 승자승: a 가 b 에게 이긴 횟수 vs 그 반대 (3팀 이상에선 단순 head-to-head).
      if (h2h[a][b] != h2h[b][a]) {
        return h2h[b][a].compareTo(h2h[a][b]);
      }
      if (pf[a] != pf[b]) return pf[b].compareTo(pf[a]);
      final diffA = pf[a] - pa[a];
      final diffB = pf[b] - pa[b];
      return diffB.compareTo(diffA);
    });
    final stats = <({
      int rank,
      int origIdx,
      int wins,
      int losses,
      int pf,
      int pa,
      int diff,
      int score,
    })>[];
    for (int rank = 0; rank < n; rank++) {
      final idx = order[rank];
      stats.add((
        rank: rank + 1,
        origIdx: idx,
        wins: wins[idx],
        losses: losses[idx],
        pf: pf[idx],
        pa: pa[idx],
        diff: pf[idx] - pa[idx],
        score: wins[idx] * 2,
      ));
    }

    String fmtSigned(int v) => v > 0 ? '+$v' : '$v';

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
            defaultColumnWidth: const FixedColumnWidth(22),
            columnWidths: const {
              0: FixedColumnWidth(26), // 순위 (font 축소)
              1: FixedColumnWidth(68), // 소속
              2: FixedColumnWidth(56), // 선수
              3: FixedColumnWidth(24), // 점수
              4: FixedColumnWidth(20), // 승
              5: FixedColumnWidth(20), // 패
              6: FixedColumnWidth(24), // 득
              7: FixedColumnWidth(24), // 실
              8: FixedColumnWidth(30), // 차
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(children: [
                headerCell('순위', size: 9),
                headerCell('소속'),
                headerCell('선수'),
                headerCell('승점', color: blue),
                headerCell('승', color: blue),
                headerCell('패', color: red),
                headerCell('득', color: blue),
                headerCell('실', color: red),
                headerCell('차', color: blue),
              ]),
              for (final s in stats)
                TableRow(children: [
                  dataCell(
                    '${s.rank}',
                    w: FontWeight.w700,
                    color: s.rank == 1
                        ? blue
                        : const Color(0xFF374151),
                  ),
                  dataCell(teams[s.origIdx].name, w: FontWeight.w600),
                  dataCell(teams[s.origIdx].players.join('\n')),
                  dataCell('${s.score}',
                      w: FontWeight.w800, color: blue),
                  dataCell('${s.wins}', color: blue),
                  dataCell('${s.losses}', color: red),
                  dataCell('${s.pf}', color: blue),
                  dataCell('${s.pa}', color: red),
                  dataCell(fmtSigned(s.diff),
                      w: FontWeight.w700, color: blue),
                ]),
            ],
          ),
        ),
      ],
    );
  }


}
