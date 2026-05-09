import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/match.dart';
import '../../models/player.dart';
import '../../models/tournament.dart';
import '../../models/venue.dart';
import '../../services/sample_data.dart';
import '../../services/storage_service.dart';
import '../../utils/age_group.dart';
import '../../widgets/bracket/bracket_generator_tab.dart';
import '../../widgets/common/filter_chips.dart';
import '../../widgets/players/player_list_item.dart';
import 'entry_upload_screen.dart';

const _headerInk = Color(0xFF0D1B3E);

// ═══════════════════════════════════════════════════════
//  BracketScreen
// ═══════════════════════════════════════════════════════
class BracketScreen extends StatefulWidget {
  final Tournament tournament;
  final int initialTabIndex;
  const BracketScreen({
    super.key,
    required this.tournament,
    this.initialTabIndex = 0,
  });

  @override
  State<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends State<BracketScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  late Tournament _tournament;

  String _type = '혼복';
  // _activeAgeGroups / _openSections 의 원소는 ageGroup 라벨("20","45","전체"제외).
  final Set<String> _activeAgeGroups = {};
  final Set<String> _activeGrades = {};
  final Set<String> _openSections = {};
  final Set<String> _selected = {};

  int _totalDays = 1;
  static const int _maxDays = 4;
  final _date1Ctrl = TextEditingController(text: '2026-05-10');
  final _date2Ctrl = TextEditingController(text: '2026-05-11');
  final _date3Ctrl = TextEditingController(text: '2026-05-12');
  final _date4Ctrl = TextEditingController(text: '2026-05-13');
  late List<Venue> _venues;
  final Map<AssignKey, String> _assignMap = {};
  Timer? _persistDebounce;
  static const int _maxCourtsPerVenue = 10;

  /// 참가신청 엑셀 업로드로 누적된 종목별 카운트.
  /// 비어있으면 BottomSheet 에 종목 요약 라인 미노출.
  Map<String, int> _entryEventCounts = const {};

  /// 사용자 정의 급수 (자강조 등). 표준 급수와 합쳐 칩으로 노출.
  List<String> _customGrades = const [];

  /// "전체" 제외, 실제 연령 그룹 라벨 목록
  List<String> get _ageGroupLabels =>
      _tournament.ageGroups.where((l) => l != '전체').toList();

  /// "전체" 제외, 실제 급수 그룹 라벨 목록
  List<String> get _gradeGroupLabels =>
      _tournament.gradeGroups.where((l) => l != '전체').toList();

  static const _allGrades = ['A', 'B', 'C', 'D', '초심'];

  void rebuild(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _tournament = widget.tournament;
    _tc = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    for (int i = 0; i < SampleData.players.length; i++) {
      _selected.add(SampleData.players[i].id);
    }
    // 모든 연령 그룹을 기본 활성/펼침. ageGroups가 비어있으면 default 사용.
    for (final label in _ageGroupLabels) {
      _activeAgeGroups.add(label);
      _openSections.add(label);
    }
    _activeGrades.addAll(_gradeGroupLabels);

    // venues 하이드레이트: 저장된 venues 가 있으면 사용, 없으면 기본 1개 생성.
    final stored = _tournament.venues;
    if (stored.isNotEmpty) {
      _venues = stored
          .asMap()
          .entries
          .map((e) => e.value.copyWith(
                id: e.value.id.isNotEmpty ? e.value.id : 'v${e.key + 1}',
                colorHex: e.value.colorHex.isNotEmpty
                    ? e.value.colorHex
                    : Venue.defaultColors[e.key % Venue.defaultColors.length],
              ))
          .toList();
    } else {
      _venues = [
        Venue(
          id: 'v1',
          name: '',
          address: '',
          courts: Tournament.defaultCourtsPerVenue,
          colorHex: Venue.defaultColors[0],
        ),
      ];
    }

    for (final ev in Tournament.allEventTypes) {
      for (final label in _ageGroupLabels) {
        for (final g in _allGrades) {
          _assignMap[AssignKey(ev, label, g)] = _venues.first.id;
        }
      }
    }

    _loadCustomGrades();
  }

  Future<void> _loadCustomGrades() async {
    final saved = await StorageService.loadCustomGrades();
    if (!mounted) return;
    setState(() => _customGrades = saved);
  }

  /// 표준 + 사용자 정의 급수 (표시 순서 보존).
  List<String> get _allTargetGrades =>
      [...Tournament.allTargetGrades, ..._customGrades];

  /// 종별(혼복/남복/여복) 토글. 마지막 1개는 끄지 못하도록 보장.
  void _toggleEvent(String e) {
    final cur = _tournament.eventTypeList.toSet();
    if (cur.contains(e)) {
      if (cur.length <= 1) return;
      cur.remove(e);
    } else {
      cur.add(e);
    }
    final ordered =
        Tournament.allEventTypes.where(cur.contains).join(',');
    setState(() {
      _tournament = _tournament.copyWith(eventType: ordered);
    });
    _persistTournament();
  }

  /// 대상 급수 토글. 0개 허용 (저장 시 빈 문자열).
  void _toggleGrade(String g) {
    final cur = _tournament.targetGradeList.toSet();
    if (cur.contains(g)) {
      cur.remove(g);
    } else {
      cur.add(g);
    }
    final ordered =
        _allTargetGrades.where(cur.contains).join(',');
    setState(() {
      _tournament = _tournament.copyWith(targetGrade: ordered);
    });
    _persistTournament();
  }

  /// '전체' 마스터 토글: 모든 급수 ON ↔ 모두 OFF.
  void _toggleAllGrades() {
    final cur = _tournament.targetGradeList.toSet();
    final isAll = _allTargetGrades.every(cur.contains);
    final next = isAll ? '' : _allTargetGrades.join(',');
    setState(() {
      _tournament = _tournament.copyWith(targetGrade: next);
    });
    _persistTournament();
  }

  // ── Tournament 그룹 편집 ──────────────────────────
  void _persistTournament() {
    final idx = SampleData.tournaments.indexWhere((t) => t.id == _tournament.id);
    if (idx >= 0) {
      SampleData.tournaments[idx] = _tournament;
    }
    StorageService.saveTournaments(SampleData.tournaments);
  }

  void _persistTournamentDebounced() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(
      const Duration(milliseconds: 500),
      _persistTournament,
    );
  }

  // ── Venue 편집 ──────────────────────────────────
  /// _venues 와 _tournament.venues 를 동기화 후 저장 (디바운스).
  void _syncVenuesToTournament({bool debounce = true}) {
    _tournament =
        _tournament.copyWith(venues: _venues.map((v) => v.copyWith()).toList());
    if (debounce) {
      _persistTournamentDebounced();
    } else {
      _persistTournament();
    }
  }

  void _updateVenueName(int i, String name) {
    if (i < 0 || i >= _venues.length) return;
    _venues[i] = _venues[i].copyWith(name: name);
    _syncVenuesToTournament();
    if (mounted) setState(() {});
  }

  void _updateVenueAddress(int i, String address) {
    if (i < 0 || i >= _venues.length) return;
    _venues[i] = _venues[i].copyWith(address: address);
    _syncVenuesToTournament();
  }

  void _updateVenueCourts(int i, int courts) {
    if (i < 0 || i >= _venues.length) return;
    final clamped = courts.clamp(0, _maxCourtsPerVenue);
    if (_venues[i].courts == clamped) return;
    setState(() {
      _venues[i] = _venues[i].copyWith(courts: clamped);
      _syncVenuesToTournament(debounce: false);
    });
  }

  /// 새 경기장 1개 추가. 기본 4코트, 색상은 `Venue.defaultColors` 순환.
  void _addVenue() {
    final id = 'v${DateTime.now().millisecondsSinceEpoch}';
    final color =
        Venue.defaultColors[_venues.length % Venue.defaultColors.length];
    setState(() {
      _venues.add(Venue(
        id: id,
        name: '',
        address: '',
        courts: 4,
        colorHex: color,
      ));
      _syncVenuesToTournament(debounce: false);
    });
  }

  /// AI 자동 배정: 선택된 참가자 인원수 기반으로 경기 부하를 경기장 코트 비율에 맞춰 분산.
  /// 각 (종별, 연령, 급수) 셀의 경기 수를 계산 → 큰 것부터 가장 부족한 경기장에 배정 (LDM).
  void _aiAssignVenues() {
    if (_venues.isEmpty) return;
    final activeVs = _venues.where((v) => v.courts > 0).toList();
    if (activeVs.isEmpty) return;

    final selectedPlayers = SampleData.players
        .where((p) => _selected.contains(p.id))
        .toList();

    final selectedEvents = _tournament.eventTypeList
        .where(Tournament.allEventTypes.contains)
        .toList();
    final ages = _ageGroupLabels.where(_activeAgeGroups.contains).toList();
    final grades = _gradeGroupLabels.where(_activeGrades.contains).toList();

    final newMap = Map<AssignKey, String>.from(_assignMap);

    for (final ev in selectedEvents) {
      final isSingles = ev == '단식';
      // 종목별 성별 필터
      bool genderOk(Player p) {
        if (ev == '남복') return p.gender == '남';
        if (ev == '여복') return p.gender == '여';
        return true; // 혼복/단식
      }

      // 셀별 경기 수 산출
      final cells = <_AiCell>[];
      for (final age in ages) {
        for (final g in grades) {
          final pool = selectedPlayers
              .where(genderOk)
              .where((p) => p.grade == g)
              .where((p) => ageMatches(age, p.age, _ageGroupLabels))
              .toList();
          final teams = isSingles ? pool.length : pool.length ~/ 2;
          final matches = teams >= 3 ? (teams * (teams - 1)) ~/ 2 : 0;
          cells.add(_AiCell(age: age, grade: g, matches: matches));
        }
      }

      // 경기 수 내림차순 정렬 (큰 것부터 분배)
      cells.sort((a, b) => b.matches.compareTo(a.matches));

      // 코트 비율 기반 목표 부하
      final totalCourts =
          activeVs.fold<int>(0, (s, v) => s + v.courts);
      final totalMatches =
          cells.fold<int>(0, (s, c) => s + c.matches);
      final venueLoad = <String, int>{
        for (final v in activeVs) v.id: 0
      };
      final venueTarget = <String, double>{
        for (final v in activeVs)
          v.id: totalMatches * (v.courts / totalCourts),
      };

      for (final cell in cells) {
        // 가장 부족한(target - load 가 가장 큰) 경기장 선택
        Venue? best;
        double bestSlack = -double.infinity;
        for (final v in activeVs) {
          final slack = venueTarget[v.id]! - venueLoad[v.id]!;
          if (slack > bestSlack) {
            bestSlack = slack;
            best = v;
          }
        }
        if (best != null) {
          newMap[AssignKey(ev, cell.age, cell.grade)] = best.id;
          venueLoad[best.id] = venueLoad[best.id]! + cell.matches;
        }
      }
    }

    setState(() {
      _assignMap
        ..clear()
        ..addAll(newMap);
    });
    _persistTournament();
  }

  /// 경기장 삭제. 마지막 1개는 삭제 불가(최소 1개 유지).
  /// 해당 경기장에 배정된 (연령,급수)는 첫 번째 남은 경기장으로 재배정.
  void _removeVenue(int i) {
    if (i < 0 || i >= _venues.length) return;
    if (_venues.length <= 1) return;
    final removedId = _venues[i].id;
    setState(() {
      _venues.removeAt(i);
      final fallbackId = _venues.first.id;
      _assignMap.updateAll(
          (key, val) => val == removedId ? fallbackId : val);
      _syncVenuesToTournament(debounce: false);
    });
  }

  void _addAgeGroup(String label) {
    final masterOn =
        _ageGroupLabels.isNotEmpty &&
            _ageGroupLabels.every(_activeAgeGroups.contains);
    setState(() {
      // 새 라벨 추가 후 나이 순(숫자 오름차순) 재정렬.
      // '전체'는 맨 앞 고정. 숫자 라벨은 오름차순. 텍스트 라벨은 숫자 뒤에 기존 상대 순서 유지.
      final combined = [..._tournament.ageGroups, label];
      final hasAll = combined.remove('전체');
      final numeric = <String>[];
      final textual = <String>[];
      for (final l in combined) {
        if (int.tryParse(l) != null) {
          numeric.add(l);
        } else {
          textual.add(l);
        }
      }
      numeric.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      _tournament = _tournament
          .copyWith(ageGroups: [if (hasAll) '전체', ...numeric, ...textual]);
      if (masterOn) {
        _activeAgeGroups.add(label);
        _openSections.add(label);
      }
      for (final ev in Tournament.allEventTypes) {
        for (final g in _allGrades) {
          _assignMap[AssignKey(ev, label, g)] = _venues.first.id;
        }
      }
    });
    _persistTournament();
  }

  void _removeAgeGroup(String label) {
    setState(() {
      _tournament = _tournament.copyWith(
          ageGroups:
              _tournament.ageGroups.where((l) => l != label).toList());
      _activeAgeGroups.remove(label);
      _openSections.remove(label);
      _assignMap.removeWhere((k, _) => k.decadeKey == label);
    });
    _persistTournament();
  }

  /// 급수 정렬 순서: 자강조 → S조 → A조 → B조 → C조 → D조 → E조 → 초심조.
  /// 알 수 없는 라벨은 표 뒤(원래 순서 유지) — '전체'는 항상 맨 앞.
  static const Map<String, int> _gradeGroupSortOrder = {
    '자강조': 0,
    'S조': 1,
    'A조': 2,
    'B조': 3,
    'C조': 4,
    'D조': 5,
    'E조': 6,
    '초심조': 7,
  };

  void _addGradeGroup(String label) {
    final masterOn =
        _gradeGroupLabels.isNotEmpty &&
            _gradeGroupLabels.every(_activeGrades.contains);
    setState(() {
      // 새 라벨 추가 후 표준 급수 순서로 재정렬.
      // '전체'는 맨 앞, 표에 있는 급수는 정해진 순서, 그 외는 표 뒤에 기존 상대 순서 유지.
      final combined = [..._tournament.gradeGroups, label];
      final hasAll = combined.remove('전체');
      final known = <String>[];
      final unknown = <String>[];
      for (final l in combined) {
        if (_gradeGroupSortOrder.containsKey(l)) {
          known.add(l);
        } else {
          unknown.add(l);
        }
      }
      known.sort((a, b) =>
          _gradeGroupSortOrder[a]!.compareTo(_gradeGroupSortOrder[b]!));
      _tournament = _tournament
          .copyWith(gradeGroups: [if (hasAll) '전체', ...known, ...unknown]);
      if (masterOn) _activeGrades.add(label);
    });
    _persistTournament();
  }

  void _removeGradeGroup(String label) {
    setState(() {
      _tournament = _tournament.copyWith(
          gradeGroups:
              _tournament.gradeGroups.where((l) => l != label).toList());
      _activeGrades.remove(label);
    });
    _persistTournament();
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    if (_persistDebounce != null) {
      // 디바운스 대기 중인 변경사항 즉시 저장
      _persistTournament();
    }
    _tc.dispose();
    _date1Ctrl.dispose();
    _date2Ctrl.dispose();
    _date3Ctrl.dispose();
    _date4Ctrl.dispose();
    super.dispose();
  }

  List<Player> get _filteredPlayers {
    var list = SampleData.players;
    if (_type == '남복') {
      list = list.where((p) => p.gender == '남').toList();
    } else if (_type == '여복') {
      list = list.where((p) => p.gender == '여').toList();
    }
    // 활성 연령 그룹 중 하나라도 매칭되어야 통과
    list = list
        .where((p) => _activeAgeGroups
            .any((l) => ageMatches(l, p.age, _ageGroupLabels)))
        .toList();
    list = list.where((p) => _activeGrades.contains(p.grade)).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final selCount = _selected.length;
    final hasParticipants = selCount > 0;
    const doneBg = Color(0xFFC6F6D5); // 연한 그린 — 완료 표시

    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: -4,
        leadingWidth: 34,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.maybePop(context),
          icon:
              const Icon(Icons.arrow_back_ios_new, size: 20, color: _headerInk),
        ),
        title: Text(_tournament.name,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: _headerInk,
            ),
            overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tc,
          labelColor: AppColors.blue,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.blue,
          tabs: [
            Tab(
                height: 60,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  alignment: Alignment.center,
                  color: hasParticipants ? doneBg : null,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('참가자',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('$selCount명',
                        style: const TextStyle(fontSize: 11)),
                  ]),
                )),
            const Tab(
                height: 60,
                child: Text('설정',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            const Tab(
                height: 60,
                child: Text('대진표',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            const Tab(
                height: 60,
                child: Text('성적',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tc,
        children: [
          _ParticipantsTab(this),
          _SettingsTab(this),
          BracketGeneratorTab(
            tournament: _tournament,
            selectedPlayers: SampleData.players
                .where((p) => _selected.contains(p.id))
                .toList(),
            assignMap: _assignMap,
          ),
          const _ResultsTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 1: 참가자
// ═══════════════════════════════════════════════════════
class _ParticipantsTab extends StatelessWidget {
  final _BracketScreenState s;
  const _ParticipantsTab(this.s);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
        child: Row(children: [
          Expanded(
            child: FilterChipRow(
              options: const ['혼복', '남복', '여복'],
              selected: s._type,
              onSelect: (v) => s.rebuild(() => s._type = v),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 6),
          _PillBtn(
            icon: Icons.groups_2_outlined,
            label: '클럽별',
            onTap: () => _showClubLookup(context, s),
            bg: AppColors.gray2,
            fg: AppColors.text2,
          ),
        ]),
      ),
      Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
        child: Row(children: [
          _PillBtn(
            icon: Icons.download_rounded,
            label: '양식 다운로드',
            onTap: () => _onEntrySampleDownload(context),
            bg: AppColors.green2,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            fontSize: 12,
            iconSize: 16,
          ),
          const SizedBox(width: 6),
          _PillBtn(
            icon: Icons.cloud_upload_rounded,
            label: '신청서 업로드',
            onTap: () => _onEntryUpload(context, s),
            bg: AppColors.green2,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            fontSize: 12,
            iconSize: 16,
          ),
        ]),
      ),
      Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
        alignment: Alignment.centerLeft,
        child: const Text(
          '칩 길게 누르면 삭제 · [+] 로 추가',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
      ),
      _DecadeToggleBar(s),
      _GradeToggleBar(s),
      _SelectionSummary(s),
      Expanded(child: _AgedPlayerList(s)),
      Container(
        color: AppColors.gray,
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          12 + MediaQuery.of(context).padding.bottom, // 시스템 제스처 바 영역 확보
        ),
        child: Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: () {
                    final ids =
                        s._filteredPlayers.map((p) => p.id).toList();
                    s.rebuild(() => s._selected.addAll(ids));
                  },
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11)),
                  child: const Text('전체선택', style: TextStyle(fontSize: 13)))),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton(
                  onPressed: () {
                    final ids =
                        s._filteredPlayers.map((p) => p.id).toList();
                    s.rebuild(() => s._selected.removeAll(ids));
                  },
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11)),
                  child: const Text('전체해제', style: TextStyle(fontSize: 13)))),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: ElevatedButton(
                  onPressed: () => s._tc.animateTo(1),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11)),
                  child:
                      const Text('설정으로 →', style: TextStyle(fontSize: 13)))),
        ]),
      ),
    ]);
  }
}

class _DecadeToggleBar extends StatelessWidget {
  final _BracketScreenState s;
  const _DecadeToggleBar(this.s);

  @override
  Widget build(BuildContext context) {
    final labels = s._ageGroupLabels;
    final allOn =
        labels.isNotEmpty && labels.every(s._activeAgeGroups.contains);
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            s.rebuild(() {
              if (allOn) {
                s._activeAgeGroups.clear();
                s._openSections.clear();
              } else {
                s._activeAgeGroups
                  ..clear()
                  ..addAll(labels);
                s._openSections
                  ..clear()
                  ..addAll(labels);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: allOn ? AppColors.primaryMid : AppColors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: allOn ? AppColors.primaryMid : AppColors.gray3,
                width: 1.5,
              ),
            ),
            child: Text(
              '연령',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: allOn ? Colors.white : AppColors.muted,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...labels.map((label) {
                  final on = s._activeAgeGroups.contains(label);
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: GestureDetector(
                      onTap: () {
                        s.rebuild(() {
                          if (on) {
                            s._activeAgeGroups.remove(label);
                            s._openSections.remove(label);
                          } else {
                            s._activeAgeGroups.add(label);
                            s._openSections.add(label);
                          }
                        });
                      },
                      onLongPress: () =>
                          _showDeleteGroupDialog(context, label, isAge: true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 4),
                        decoration: BoxDecoration(
                          color: on
                              ? AppColors.primaryMid
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: on
                                ? AppColors.primaryMid
                                : const Color(0xFFBFDBFE),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$label${on ? ' ✓' : ' +'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                on ? FontWeight.w600 : FontWeight.w500,
                            color: on
                                ? Colors.white
                                : AppColors.primaryMid,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                _AddChip(onTap: () => _showAddAgeDialog(context)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  void _showAddAgeDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('연령 그룹 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: '예: 45 또는 고등학생'),
            ),
            const SizedBox(height: 8),
            const Text(
              '숫자(20, 45 등)는 자동 나이 매칭. 텍스트는 운영자 수동 선택용.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final raw = ctrl.text.trim();
              if (raw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('라벨을 입력하세요.')));
                return;
              }
              if (s._tournament.ageGroups.contains(raw)) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이미 존재하는 그룹입니다.')));
                return;
              }
              s._addAgeGroup(raw);
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog(BuildContext context, String label,
      {required bool isAge}) {
    if (label == '전체') return;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('$label 삭제'),
        content: Text(isAge
            ? '이 연령 그룹을 삭제하시겠습니까?'
            : '이 급수 그룹을 삭제하시겠습니까? 해당 급수 선수는 자동 필터에서 제외됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (isAge) {
                s._removeAgeGroup(label);
              } else {
                s._removeGradeGroup(label);
              }
              Navigator.of(dialogCtx).pop();
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeToggleBar extends StatelessWidget {
  final _BracketScreenState s;
  const _GradeToggleBar(this.s);

  @override
  Widget build(BuildContext context) {
    final options = s._gradeGroupLabels;
    final allOn =
        options.isNotEmpty && options.every(s._activeGrades.contains);
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            s.rebuild(() {
              if (allOn) {
                s._activeGrades.clear();
              } else {
                s._activeGrades
                  ..clear()
                  ..addAll(options);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: allOn ? AppColors.primaryMid : AppColors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: allOn ? AppColors.primaryMid : AppColors.gray3,
                width: 1.5,
              ),
            ),
            child: Text(
              '전체',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: allOn ? Colors.white : AppColors.muted,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...options.map((g) {
                  final on = s._activeGrades.contains(g);
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: GestureDetector(
                      onTap: () {
                        s.rebuild(() {
                          if (on) {
                            s._activeGrades.remove(g);
                          } else {
                            s._activeGrades.add(g);
                          }
                        });
                      },
                      onLongPress: () =>
                          _showDeleteDialog(context, g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 4),
                        decoration: BoxDecoration(
                          color: on
                              ? AppColors.primaryMid
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: on
                                ? AppColors.primaryMid
                                : const Color(0xFFBFDBFE),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$g${on ? ' ✓' : ' +'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                on ? FontWeight.w600 : FontWeight.w500,
                            color: on
                                ? Colors.white
                                : AppColors.primaryMid,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                _AddChip(onTap: () => _showAddDialog(context)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  void _showAddDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('급수 그룹 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: '예: 자강조'),
            ),
            const SizedBox(height: 8),
            const Text(
              '선수의 급수가 일치하면 자동 분류됩니다.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final raw = ctrl.text.trim();
              if (raw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('라벨을 입력하세요.')));
                return;
              }
              if (s._tournament.gradeGroups.contains(raw)) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이미 존재하는 그룹입니다.')));
                return;
              }
              s._addGradeGroup(raw);
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String label) {
    if (label == '전체') return;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('$label 삭제'),
        content:
            const Text('이 급수 그룹을 삭제하시겠습니까? 해당 급수 선수는 자동 필터에서 제외됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              s._removeGradeGroup(label);
              Navigator.of(dialogCtx).pop();
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.gray3, width: 1.5),
            ),
            child: const Icon(Icons.add, size: 16, color: AppColors.muted),
          ),
        ),
      );
}

class _SelectionSummary extends StatelessWidget {
  final _BracketScreenState s;
  const _SelectionSummary(this.s);

  @override
  Widget build(BuildContext context) {
    final filtered = s._filteredPlayers;
    final selectedInFilter =
        filtered.where((p) => s._selected.contains(p.id)).length;
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(children: [
        Text('선택인원 ${filtered.length}명',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted)),
        const Spacer(),
        Text('선택 $selectedInFilter / ${s._selected.length}명',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.blue)),
      ]),
    );
  }
}

class _AgedPlayerList extends StatelessWidget {
  final _BracketScreenState s;
  const _AgedPlayerList(this.s);

  @override
  Widget build(BuildContext context) {
    final filtered = s._filteredPlayers;
    final activeLabels =
        s._ageGroupLabels.where(s._activeAgeGroups.contains).toList();

    final sections = <Widget>[];
    for (final label in activeLabels) {
      final arr =
          filtered
              .where((p) => ageMatches(label, p.age, s._ageGroupLabels))
              .toList();
      // 동일 조건(같은 연령 섹션) 내 정렬: 급수(자강조 → ... → 초심조) → 나이↑ → 이름 가나다
      arr.sort((a, b) {
        final g = a.gradeIndex.compareTo(b.gradeIndex);
        if (g != 0) return g;
        final ag = a.age.compareTo(b.age);
        if (ag != 0) return ag;
        return a.name.compareTo(b.name);
      });
      if (arr.isEmpty) continue;
      final selCnt = arr.where((p) => s._selected.contains(p.id)).length;
      final isOpen = s._openSections.contains(label);

      sections.add(_AgeSectionTile(
        label: label,
        total: arr.length,
        selected: selCnt,
        isOpen: isOpen,
        onToggle: () => s.rebuild(() {
          isOpen
              ? s._openSections.remove(label)
              : s._openSections.add(label);
        }),
        children: isOpen
            ? arr
                .take(60)
                .map((p) => PlayerSelectItem(
                      player: p,
                      isSelected: s._selected.contains(p.id),
                      onTap: () => s.rebuild(() {
                        s._selected.contains(p.id)
                            ? s._selected.remove(p.id)
                            : s._selected.add(p.id);
                      }),
                    ))
                .toList()
            : [],
        extra: isOpen && arr.length > 60 ? arr.length - 60 : 0,
      ));
    }

    if (sections.isEmpty) {
      return const Center(
          child: Text('해당하는 참가자가 없습니다.',
              style: TextStyle(color: AppColors.muted)));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: sections,
    );
  }
}

class _AgeSectionTile extends StatelessWidget {
  final String label;
  final int total, selected, extra;
  final bool isOpen;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _AgeSectionTile({
    required this.label,
    required this.total,
    required this.selected,
    required this.extra,
    required this.isOpen,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            color: const Color(0xFFF7F9FC),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Row(children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('$total명 · 선택 $selected명',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const Spacer(),
              Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: AppColors.gray3),
            ]),
          ),
        ),
        ...children,
        if (extra > 0)
          Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFFF8FAFC),
              child: Center(
                  child: Text('외 $extra명 (급수 필터 이용)',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)))),
        Container(height: 2, color: AppColors.gray2),
      ]);
}

// ═══════════════════════════════════════════════════════
//  TAB 2: 설정
// ═══════════════════════════════════════════════════════
class _SettingsTab extends StatelessWidget {
  final _BracketScreenState s;
  const _SettingsTab(this.s);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: 12 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(children: [
          _DateCard(s),
          _EventGradeCard(s),
          ...List.generate(s._venues.length,
              (i) => _VenueEditCard(s: s, index: i)),
          // + 경기장 추가
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => s._addVenue(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('경기장 추가',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryMid,
                  side: const BorderSide(
                      color: Color(0xFFB8C9F0), width: 1.6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          _AssignTable(s),
          _CourtSummary(s),
        ]),
      );
}

class _DateCard extends StatelessWidget {
  final _BracketScreenState s;
  const _DateCard(this.s);

  TextEditingController _ctrl(int day) {
    switch (day) {
      case 1:
        return s._date1Ctrl;
      case 2:
        return s._date2Ctrl;
      case 3:
        return s._date3Ctrl;
      case 4:
        return s._date4Ctrl;
      default:
        return s._date1Ctrl;
    }
  }

  Widget _dateField(int day) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$day일차',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text2)),
          const SizedBox(height: 2),
          TextField(
              controller: _ctrl(day),
              style: const TextStyle(fontSize: 14, height: 1.0),
              decoration: const InputDecoration(
                  isDense: true,
                  isCollapsed: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  suffixIcon: Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.calendar_today, size: 14)),
                  suffixIconConstraints:
                      BoxConstraints(minWidth: 22, minHeight: 22))),
        ],
      );

  @override
  Widget build(BuildContext context) => _card(
        title: '대회 날짜',
        subtitle: '최대 ${_BracketScreenState._maxDays}일',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _dateField(1),
          const SizedBox(height: 6),
          Row(children: [
            for (int d = 1; d <= _BracketScreenState._maxDays; d++) ...[
              if (d > 1) const SizedBox(width: 6),
              _dayBtn('$d일', s._totalDays == d,
                  () => s.rebuild(() => s._totalDays = d)),
            ],
          ]),
          for (int d = 2; d <= s._totalDays; d++) ...[
            const SizedBox(height: 6),
            _dateField(d),
          ],
        ]),
      );

  Widget _dayBtn(String lbl, bool on, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
                color: on ? AppColors.blue2 : AppColors.gray,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: on ? AppColors.blue2 : Colors.transparent,
                    width: 1.5)),
            child: Center(
                child: Text(lbl,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: on ? Colors.white : AppColors.text2))),
          ),
        ),
      );
}

/// 공용 ⊖/⊕ 동그라미 버튼
class _CounterButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  const _CounterButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? AppColors.primaryMid : AppColors.gray,
          ),
          child: Icon(
            icon,
            size: 13,
            color: enabled ? Colors.white : AppColors.gray3,
          ),
        ),
      );
}

/// 경기 정보 카드 — 종별/연령/급수 선택 (참가자 탭 토글 상태와 동기화).
/// 추가/삭제는 참가자 탭에서 (이 카드는 선택만).
class _EventGradeCard extends StatelessWidget {
  final _BracketScreenState s;
  const _EventGradeCard(this.s);

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? selBg,
    Color? selFg,
  }) {
    final bg = selected ? (selBg ?? AppColors.primaryMid) : AppColors.gray;
    final fg = selected ? (selFg ?? Colors.white) : AppColors.text2;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? (selBg ?? AppColors.primaryMid)
                : const Color(0xFFD8DEE8),
            width: 1.4,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = s._tournament.eventTypeList.toSet();
    final ageLabels = s._ageGroupLabels;
    final gradeLabels = s._gradeGroupLabels;

    return _card(
      title: '경기 정보',
      subtitle: '참가자 탭 정보 자동 동기화 — 선택만 가능',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('종별',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.text2)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: Tournament.allEventTypes
              .map((e) => _chip(
                    label: e,
                    selected: selectedEvents.contains(e),
                    onTap: () => s._toggleEvent(e),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Text('연령',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text2)),
          const SizedBox(width: 8),
          if (ageLabels.isEmpty)
            const Text('* 참가자 탭에서 추가하세요',
                style:
                    TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
        const SizedBox(height: 6),
        if (ageLabels.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ageLabels
                .map((l) => _chip(
                      label: l,
                      selected: s._activeAgeGroups.contains(l),
                      onTap: () => s.rebuild(() {
                        if (s._activeAgeGroups.contains(l)) {
                          s._activeAgeGroups.remove(l);
                          s._openSections.remove(l);
                        } else {
                          s._activeAgeGroups.add(l);
                          s._openSections.add(l);
                        }
                      }),
                    ))
                .toList(),
          ),
        const SizedBox(height: 12),
        Row(children: [
          const Text('급수',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text2)),
          const SizedBox(width: 8),
          if (gradeLabels.isEmpty)
            const Text('* 참가자 탭에서 추가하세요',
                style:
                    TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
        const SizedBox(height: 6),
        if (gradeLabels.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: gradeLabels
                .map((g) => _chip(
                      label: g,
                      selected: s._activeGrades.contains(g),
                      onTap: () => s.rebuild(() {
                        if (s._activeGrades.contains(g)) {
                          s._activeGrades.remove(g);
                        } else {
                          s._activeGrades.add(g);
                        }
                      }),
                    ))
                .toList(),
          ),
      ]),
    );
  }
}

/// 경기장별 입력 카드 (이름/위치/코트 수)
class _VenueEditCard extends StatefulWidget {
  final _BracketScreenState s;
  final int index;
  const _VenueEditCard({required this.s, required this.index});

  @override
  State<_VenueEditCard> createState() => _VenueEditCardState();
}

class _VenueEditCardState extends State<_VenueEditCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _addrCtrl;

  @override
  void initState() {
    super.initState();
    final v = widget.s._venues[widget.index];
    _nameCtrl = TextEditingController(text: v.name);
    _addrCtrl = TextEditingController(text: v.address);
  }

  @override
  void didUpdateWidget(covariant _VenueEditCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.s._venues[widget.index];
    if (_nameCtrl.text != v.name) _nameCtrl.text = v.name;
    if (_addrCtrl.text != v.address) _addrCtrl.text = v.address;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.s._venues[widget.index];
    final disabled = v.courts == 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      decoration: BoxDecoration(
        color: disabled ? AppColors.gray : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        // 파스텔 블루 보더 — 다른 카드와 톤 통일
        border: Border.all(color: const Color(0xFFB8C9F0), width: 2.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('경기장 ${widget.index + 1}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text2)),
          if (disabled) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.red3.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('사용 안 함',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.red)),
            ),
          ],
          const Spacer(),
          // 경기장이 2개 이상일 때만 삭제 가능 (최소 1개 유지)
          if (widget.s._venues.length > 1)
            IconButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('경기장 삭제'),
                    content: Text(
                        '"${widget.s._venues[widget.index].name.isEmpty ? '경기장 ${widget.index + 1}' : widget.s._venues[widget.index].name}" 을(를) 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('취소')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('삭제',
                              style:
                                  TextStyle(color: AppColors.red))),
                    ],
                  ),
                );
                if (ok == true) widget.s._removeVenue(widget.index);
              },
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.red,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: '경기장 삭제',
            ),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          style: const TextStyle(fontSize: 14, height: 1.0),
          decoration: const InputDecoration(
            labelText: '대회장소',
            hintText: '예: 한국시민체육관',
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          ),
          onChanged: (val) => widget.s._updateVenueName(widget.index, val),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _addrCtrl,
          style: const TextStyle(fontSize: 14, height: 1.0),
          decoration: const InputDecoration(
            labelText: '위치',
            hintText: '예: 한국 한국시 중앙로 123',
            prefixIcon: Padding(
                padding: EdgeInsets.only(left: 8, right: 4),
                child: Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.gray3)),
            prefixIconConstraints:
                BoxConstraints(minWidth: 22, minHeight: 22),
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          ),
          maxLines: 1,
          onChanged: (val) =>
              widget.s._updateVenueAddress(widget.index, val),
        ),
        const SizedBox(height: 6),
        Row(children: [
          const Text('코트 수',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2)),
          const Spacer(),
          _CounterButton(
            icon: Icons.remove,
            enabled: v.courts > 0,
            onTap: v.courts > 0
                ? () => widget.s._updateVenueCourts(widget.index, v.courts - 1)
                : null,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            child: Text(
              '${v.courts}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _CounterButton(
            icon: Icons.add,
            enabled: v.courts < _BracketScreenState._maxCourtsPerVenue,
            onTap: v.courts < _BracketScreenState._maxCourtsPerVenue
                ? () => widget.s._updateVenueCourts(widget.index, v.courts + 1)
                : null,
          ),
        ]),
      ]),
    );
  }
}

/// AI 자동 배정용 셀 정보 — (연령, 급수) 단위 경기 수.
class _AiCell {
  final String age;
  final String grade;
  final int matches;
  const _AiCell({
    required this.age,
    required this.grade,
    required this.matches,
  });
}

class _AssignTable extends StatefulWidget {
  final _BracketScreenState s;
  const _AssignTable(this.s);

  @override
  State<_AssignTable> createState() => _AssignTableState();
}

class _AssignTableState extends State<_AssignTable> {
  /// 현재 보고 있는 종별 (탭). 대회의 활성 종별 중 첫 번째로 시작.
  String? _activeEvent;

  List<String> _selectedEvents() {
    final selected = widget.s._tournament.eventTypeList;
    return Tournament.allEventTypes.where(selected.contains).toList();
  }

  // 표 구조: 구분 컬럼 폭/행 높이 상수 — 좌측 고정 + 우측 스크롤 정렬용.
  static const double _kLeftColWidth = 32;
  static const double _kVenueColWidth = 150;
  static const double _kHeaderHeight = 40;
  static const double _kRowHeight = 64;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final activeAges =
        s._ageGroupLabels.where(s._activeAgeGroups.contains).toList();
    if (activeAges.isEmpty) return const SizedBox();

    final activeGrades =
        s._gradeGroupLabels.where(s._activeGrades.contains).toList();
    if (activeGrades.isEmpty) return const SizedBox();

    final events = _selectedEvents();
    if (events.isEmpty) return const SizedBox();

    final venues = s._venues;
    if (venues.isEmpty) return const SizedBox();

    // _activeEvent 가 비활성/없는 이벤트면 첫 번째로 폴백.
    final currentEvent =
        events.contains(_activeEvent) ? _activeEvent! : events.first;

    final totalHeight =
        _kHeaderHeight + activeAges.length * _kRowHeight;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB8C9F0), width: 2.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 제목 + AI 자동배정 버튼
        Row(children: [
          const Text('연령별 급수별 경기장 배정',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('AI 자동 배정'),
                  content: const Text(
                      '선택된 참가자 인원수에 맞춰 모든 종별·연령·급수를 경기장 코트 비율로 자동 배정합니다.\n기존 수동 배정은 모두 덮어씌워집니다.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('자동 배정',
                            style: TextStyle(
                                fontWeight: FontWeight.w800))),
                  ],
                ),
              );
              if (ok == true) s._aiAssignVenues();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.green2,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text('AI 자동배정',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        // 종별 선택 버튼 (한 줄)
        Row(children: [
          for (final ev in events) ...[
            _eventTab(ev, ev == currentEvent, () {
              setState(() => _activeEvent = ev);
            }),
            if (ev != events.last) const SizedBox(width: 6),
          ],
        ]),
        const SizedBox(height: 10),
        // 좌측 '구분' 컬럼 고정 + 우측 경기장 컬럼 가로 스크롤.
        SizedBox(
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 우측 (스크롤) — 좌측 폭만큼 padding 으로 비워두어 좌측 고정 컬럼이 위에 덮어씀.
              Padding(
                padding: const EdgeInsets.only(left: _kLeftColWidth),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // 헤더
                    Row(children: [
                      for (final v in venues)
                        _venueHeaderCell(v.name.isEmpty
                            ? '경기장 ${venues.indexOf(v) + 1}'
                            : v.name),
                    ]),
                    // 데이터 행
                    for (final age in activeAges)
                      Row(children: [
                        for (final v in venues)
                          _gradeCell(
                              currentEvent, age, v.id, activeGrades),
                      ]),
                  ]),
                ),
              ),
              // 좌측 고정 (구분 컬럼) — 흰색 배경으로 우측 콘텐츠 가림.
              SizedBox(
                width: _kLeftColWidth,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _fixedHeaderCell('구분'),
                  for (final age in activeAges) _fixedAgeCell(age),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  /// 좌측 고정 헤더 셀 (구분).
  Widget _fixedHeaderCell(String label) => Container(
        height: _kHeaderHeight,
        width: _kLeftColWidth,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.text2)),
      );

  /// 좌측 고정 연령 셀.
  Widget _fixedAgeCell(String age) => Container(
        height: _kRowHeight,
        width: _kLeftColWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        ),
        alignment: Alignment.center,
        child: Text(age,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.text2)),
      );

  /// 우측 스크롤 헤더 셀 (경기장 이름).
  Widget _venueHeaderCell(String name) => Container(
        height: _kHeaderHeight,
        width: _kVenueColWidth,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.text2)),
      );

  /// 한 (연령, 경기장) 셀: 활성 급수 칩 나열.
  /// 칩 탭 = 해당 (event, age, grade) → venueId 로 재배정.
  Widget _gradeCell(
      String event, String age, String venueId, List<String> grades) {
    final s = widget.s;
    return Container(
      height: _kRowHeight,
      width: _kVenueColWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        alignment: WrapAlignment.center,
        children: grades.map((g) {
          final key = AssignKey(event, age, g);
          final shortG = g.replaceAll('조', '');
          final assigned =
              (s._assignMap[key] ?? s._venues.first.id) == venueId;
          return GestureDetector(
            onTap: () => s.rebuild(() => s._assignMap[key] = venueId),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: assigned ? AppColors.primaryMid : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: assigned
                      ? AppColors.primaryMid
                      : const Color(0xFFA8B5C7),
                  width: 1.2,
                ),
              ),
              child: Text(shortG,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: assigned ? Colors.white : AppColors.text2)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _eventTab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryMid : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: selected ? AppColors.primaryMid : const Color(0xFFD8DEE8),
              width: 1.2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.text2)),
      ),
    );
  }

  Widget _th(String t) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(t,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.text2)));
}

class _CourtSummary extends StatelessWidget {
  final _BracketScreenState s;
  const _CourtSummary(this.s);

  @override
  Widget build(BuildContext context) => _card(
        title: '코트 요약',
        child: Column(children: [
          ...s._venues.map((v) {
            Color col;
            final hex = v.colorHex.replaceAll('#', '');
            try {
              col = Color(int.parse('FF$hex', radix: 16));
            } catch (_) {
              col = AppColors.blue;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: col, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(v.name,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.text2))),
                Text('${v.courts}코트',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
              ]),
            );
          }),
          const Divider(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('합계',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
            Text('${s._venues.fold(0, (sum, v) => sum + v.courts)}코트',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blue)),
          ]),
        ]),
      );
}

// ═══════════════════════════════════════════════════════
//  TAB 4: 성적
// ═══════════════════════════════════════════════════════
class _ResultsTab extends StatelessWidget {
  const _ResultsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Text('경기 결과를 입력하면 성적이 집계됩니다.',
            style: TextStyle(color: AppColors.muted)));
  }
}

// ═══════════════════════════════════════════════════════
//  공통 헬퍼 함수
// ═══════════════════════════════════════════════════════
Widget _card(
        {required String title, String? subtitle, required Widget child}) =>
    Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          // 파스텔 블루 보더 — 대회운영 카드와 톤 통일
          border: Border.all(color: const Color(0xFFB8C9F0), width: 2.5)),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text2)),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ]),
        const SizedBox(height: 6),
        child,
      ]),
    );

// ═══════════════════════════════════════════════════════
//  클럽별 참가자 조회 (BottomSheet)
// ═══════════════════════════════════════════════════════
void _showClubLookup(BuildContext context, _BracketScreenState s) {
  final selPlayers = SampleData.players
      .where((p) => s._selected.contains(p.id))
      .toList();

  // 클럽명 → 선수 목록
  final byClub = <String, List<Player>>{};
  for (final p in selPlayers) {
    final key = p.clubName.trim().isEmpty ? '(소속 미지정)' : p.clubName.trim();
    byClub.putIfAbsent(key, () => []).add(p);
  }
  final clubNames = byClub.keys.toList()..sort();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      final maxH = mq.size.height * 0.78;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Text('클럽별 참가자',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                const SizedBox(width: 8),
                Text('${selPlayers.length}명 · ${clubNames.length}개 클럽',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
            if (s._entryEventCounts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  _formatEventCounts(s._entryEventCounts),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text2),
                ),
              ),
            const SizedBox(height: 6),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: clubNames.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('선택된 참가자가 없습니다.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.muted)),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                          12, 10, 12, 12 + mq.padding.bottom),
                      itemCount: clubNames.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final club = clubNames[i];
                        final players = byClub[club]!
                          ..sort((a, b) => a.name.compareTo(b.name));
                        return _ClubLookupSection(
                            club: club, players: players);
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}

String _formatEventCounts(Map<String, int> counts) {
  final order = ['혼복', '남복', '여복', '단식'];
  final parts = <String>[];
  for (final k in order) {
    final n = counts[k] ?? 0;
    if (n == 0) continue;
    final unit = k == '단식' ? '명' : '쌍';
    final num = unit == '쌍' ? (n / 2).ceil() : n;
    parts.add('$k $num$unit');
  }
  return parts.isEmpty ? '' : parts.join(' · ');
}

Future<void> _onEntrySampleDownload(BuildContext context) async {
  // 업로드 화면을 열되 다운로드만 활용하도록 안내. 별도 분리 시 코드 중복이 커서
  // 같은 화면을 재사용. 사용자는 1단계 카드의 다운로드만 누르고 뒤로가기.
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const EntryUploadScreen(existingSelected: <String>{}),
    ),
  );
}

Future<void> _onEntryUpload(
    BuildContext context, _BracketScreenState s) async {
  final result = await Navigator.push<EntryUploadResult>(
    context,
    MaterialPageRoute(
      builder: (_) => EntryUploadScreen(existingSelected: s._selected),
    ),
  );
  if (result == null) return;
  s.rebuild(() {
    s._selected
      ..clear()
      ..addAll(result.selectedPlayerIds);
    final merged = <String, int>{...s._entryEventCounts};
    result.eventCounts.forEach((k, v) {
      merged[k] = (merged[k] ?? 0) + v;
    });
    s._entryEventCounts = merged;
  });
}

class _PillBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? bg;
  final Color? fg;
  final EdgeInsets? padding;
  final double? fontSize;
  final double? iconSize;
  const _PillBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.bg,
    this.fg,
    this.padding,
    this.fontSize,
    this.iconSize,
  });
  @override
  Widget build(BuildContext context) {
    final bgColor = bg ?? AppColors.primaryMid;
    final fgColor = fg ?? Colors.white;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: iconSize ?? 18, color: fgColor),
      label: Text(label, style: TextStyle(color: fgColor)),
      style: OutlinedButton.styleFrom(
        foregroundColor: fgColor,
        backgroundColor: bgColor,
        side: BorderSide(color: bgColor, width: 1.4),
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: TextStyle(
          fontSize: fontSize ?? 13,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _ClubLookupSection extends StatelessWidget {
  final String club;
  final List<Player> players;
  const _ClubLookupSection({required this.club, required this.players});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D9E6), width: 1.2),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(club,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
            ),
            Text('${players.length}명',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
          ]),
          const SizedBox(height: 4),
          Text(
            players.map((p) => p.name).join(', '),
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.text2,
                height: 1.45),
          ),
        ],
      ),
    );
  }
}
