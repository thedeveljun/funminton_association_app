import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/match.dart';
import '../../models/player.dart';
import '../../models/tournament.dart';
import '../../services/bracket_service.dart';
import '../../services/sample_data.dart';
import '../../services/storage_service.dart';
import '../../utils/age_group.dart';
import '../../widgets/common/filter_chips.dart';
import '../../widgets/common/stat_banner.dart';
import '../../widgets/players/player_list_item.dart';
import '../../widgets/bracket/match_card.dart';
import '../../widgets/bracket/score_input_sheet.dart';

const _headerInk = Color(0xFF0D1B3E);

// ═══════════════════════════════════════════════════════
//  BracketScreen
// ═══════════════════════════════════════════════════════
class BracketScreen extends StatefulWidget {
  final Tournament tournament;
  const BracketScreen({super.key, required this.tournament});

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
  final _date1Ctrl = TextEditingController(text: '2026-05-10');
  final _date2Ctrl = TextEditingController(text: '2026-05-11');
  final List<VenueConfig> _venues = [
    VenueConfig(id: 'v1', name: '제1경기장', courts: 6, colorHex: '#1a3a8f'),
  ];
  int _venueIdCounter = 2;
  final Map<AssignKey, String> _assignMap = {};

  List<Match> _matches = [];
  String _venueFilter = 'all';
  String _dayFilter = 'all';
  List<PlayerStats> _rankings = [];

  /// "전체" 제외, 실제 연령 그룹 라벨 목록
  List<String> get _ageGroupLabels =>
      _tournament.ageGroups.where((l) => l != '전체').toList();

  /// "전체" 제외, 실제 급수 그룹 라벨 목록
  List<String> get _gradeGroupLabels =>
      _tournament.gradeGroups.where((l) => l != '전체').toList();

  static const _allGrades = ['A', 'B', 'C', 'D', '초심'];
  static const _venueColors = [
    '#1a3a8f',
    '#2a7d4f',
    '#9c4221',
    '#553ab7',
    '#b7791f',
    '#1a7a9f'
  ];

  void rebuild(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _tournament = widget.tournament;
    _tc = TabController(length: 4, vsync: this);
    for (int i = 0; i < SampleData.players.length; i++) {
      _selected.add(SampleData.players[i].id);
    }
    // 모든 연령 그룹을 기본 활성/펼침. ageGroups가 비어있으면 default 사용.
    for (final label in _ageGroupLabels) {
      _activeAgeGroups.add(label);
      _openSections.add(label);
    }
    _activeGrades.addAll(_gradeGroupLabels);
    for (final label in _ageGroupLabels) {
      for (final g in _allGrades) {
        _assignMap[AssignKey(label, g)] = 'v1';
      }
    }
  }

  // ── Tournament 그룹 편집 ──────────────────────────
  void _persistTournament() {
    final idx = SampleData.tournaments.indexWhere((t) => t.id == _tournament.id);
    if (idx >= 0) {
      SampleData.tournaments[idx] = _tournament;
    }
    StorageService.saveTournaments(SampleData.tournaments);
  }

  void _addAgeGroup(String label) {
    final masterOn =
        _ageGroupLabels.isNotEmpty &&
            _ageGroupLabels.every(_activeAgeGroups.contains);
    setState(() {
      _tournament = _tournament
          .copyWith(ageGroups: [..._tournament.ageGroups, label]);
      if (masterOn) {
        _activeAgeGroups.add(label);
        _openSections.add(label);
      }
      for (final g in _allGrades) {
        _assignMap[AssignKey(label, g)] = _venues.first.id;
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

  void _addGradeGroup(String label) {
    final masterOn =
        _gradeGroupLabels.isNotEmpty &&
            _gradeGroupLabels.every(_activeGrades.contains);
    setState(() {
      _tournament = _tournament
          .copyWith(gradeGroups: [..._tournament.gradeGroups, label]);
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
    _tc.dispose();
    _date1Ctrl.dispose();
    _date2Ctrl.dispose();
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

  void _generateBracket() {
    final selPlayers =
        SampleData.players.where((p) => _selected.contains(p.id)).toList();
    if (selPlayers.length < 4) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('최소 4명 이상 선택하세요.')));
      return;
    }
    final matches = BracketService.generate(
      tournamentId: _tournament.id,
      players: selPlayers,
      venues: _venues,
      totalDays: _totalDays,
      assignMap: _assignMap,
    );
    setState(() {
      _matches = matches;
      _rankings = [];
    });
    _tc.animateTo(2);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('대진표 생성 완료: ${matches.length}경기')));
  }

  Future<void> _saveScore(Match match, int sA, int sB) async {
    setState(() {
      final idx = _matches.indexWhere((m) => m.id == match.id);
      if (idx >= 0) {
        _matches[idx] = _matches[idx]
            .copyWith(scoreA: sA, scoreB: sB, status: MatchStatus.done);
      }
    });
    final selPlayers =
        SampleData.players.where((p) => _selected.contains(p.id)).toList();
    setState(() {
      _rankings =
          BracketService.calcRankings(players: selPlayers, matches: _matches);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selCount = _selected.length;

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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('참가자',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text('$selCount명', style: const TextStyle(fontSize: 11)),
            ])),
            Tab(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('설정',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(
                  '${_venues.fold(0, (s, v) => s + v.courts)}코트·$_totalDays일',
                  style: const TextStyle(fontSize: 11)),
            ])),
            Tab(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('대진표',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(_matches.isEmpty ? '-' : '${_matches.length}경기',
                  style: const TextStyle(fontSize: 11)),
            ])),
            const Tab(
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
          _BracketTab(this),
          _ResultsTab(this),
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
      FilterChipRow(
        options: const ['혼복', '남복', '여복'],
        selected: s._type,
        onSelect: (v) => s.rebuild(() => s._type = v),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: on
                                ? const Color(0xFF2563EB)
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
                                : const Color(0xFF2563EB),
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
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: on
                                ? const Color(0xFF2563EB)
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
                                : const Color(0xFF2563EB),
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
          bottom: 20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(children: [
          _DateCard(s),
          _VenueSection(s),
          _AssignTable(s),
          _CourtSummary(s),
          Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: ElevatedButton(
                  onPressed: s._generateBracket,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('✦ 대진표 생성',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)))),
        ]),
      );
}

class _DateCard extends StatelessWidget {
  final _BracketScreenState s;
  const _DateCard(this.s);

  @override
  Widget build(BuildContext context) => _card(
        title: '대회 날짜',
        subtitle: '최대 2일',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('1일차',
              style: TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 4),
          TextField(
              controller: s._date1Ctrl,
              decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today, size: 16))),
          const SizedBox(height: 10),
          Row(children: [
            _dayBtn('1일 대회', s._totalDays == 1,
                () => s.rebuild(() => s._totalDays = 1)),
            const SizedBox(width: 8),
            _dayBtn('2일 대회', s._totalDays == 2,
                () => s.rebuild(() => s._totalDays = 2)),
          ]),
          if (s._totalDays == 2) ...[
            const SizedBox(height: 10),
            const Text('2일차',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 4),
            TextField(
                controller: s._date2Ctrl,
                decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.calendar_today, size: 16))),
          ],
        ]),
      );

  // ★ BuildContext 파라미터 제거 — 불필요
  Widget _dayBtn(String lbl, bool on, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 10),
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

class _VenueSection extends StatelessWidget {
  final _BracketScreenState s;
  const _VenueSection(this.s);

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('경기장 설정',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text2)),
            Text('${s._venues.length}개 운영 중',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ),
        ...s._venues.asMap().entries.map((e) => _VenueCard(s, e.value, e.key)),
        if (s._venues.length < 6)
          GestureDetector(
            onTap: () {
              final idx =
                  s._venues.length % _BracketScreenState._venueColors.length;
              s.rebuild(() {
                s._venues.add(VenueConfig(
                  id: 'v${s._venueIdCounter++}',
                  name: '제${s._venues.length + 1}경기장',
                  courts: 4,
                  colorHex: _BracketScreenState._venueColors[idx],
                ));
              });
            },
            child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.gray3, width: 1.5),
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 16, color: AppColors.muted),
                      SizedBox(width: 4),
                      Text('경기장 추가',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted)),
                    ])),
          ),
      ]);
}

class _VenueCard extends StatelessWidget {
  final _BracketScreenState s;
  final VenueConfig v;
  final int idx;
  const _VenueCard(this.s, this.v, this.idx);

  Color get _color {
    final hex = v.colorHex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gray2, width: .5)),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider))),
            child: Row(children: [
              Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                      color: _color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextFormField(
                initialValue: v.name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text),
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero),
                onChanged: (val) => s.rebuild(() => v.name = val),
              )),
              if (s._venues.length > 1)
                GestureDetector(
                  onTap: () => s.rebuild(() {
                    s._venues.removeWhere((x) => x.id == v.id);
                    for (final key in s._assignMap.keys.toList()) {
                      if (s._assignMap[key] == v.id) {
                        s._assignMap[key] = s._venues.first.id;
                      }
                    }
                  }),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                          border: Border.all(color: AppColors.red3),
                          borderRadius: BorderRadius.circular(7)),
                      child: const Text('삭제',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.red))),
                )
              else
                const Text('기본',
                    style: TextStyle(fontSize: 10, color: AppColors.gray3)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Text('코트 수',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(width: 10),
              Expanded(child: _CourtGrid(v, s)),
            ]),
          ),
        ]),
      );
}

class _CourtGrid extends StatelessWidget {
  final VenueConfig v;
  final _BracketScreenState s;
  const _CourtGrid(this.v, this.s);

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            childAspectRatio: 1.1,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4),
        itemCount: 18,
        itemBuilder: (_, i) {
          final n = i + 1;
          final on = v.courts == n;
          return GestureDetector(
            onTap: () => s.rebuild(() => v.courts = n),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                  color: on ? AppColors.blue2 : AppColors.gray,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: on ? AppColors.blue2 : Colors.transparent,
                      width: 1.5)),
              child: Center(
                  child: Text('$n',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: on ? Colors.white : AppColors.text2))),
            ),
          );
        },
      );
}

class _AssignTable extends StatelessWidget {
  final _BracketScreenState s;
  const _AssignTable(this.s);

  @override
  Widget build(BuildContext context) {
    final activeLabels =
        s._ageGroupLabels.where(s._activeAgeGroups.contains).toList();
    if (activeLabels.isEmpty) return const SizedBox();

    return _card(
      title: '연령·급수별 경기장 배정',
      subtitle: '경기장별 분리 운영',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder.all(color: AppColors.gray2, width: 1),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF7F9FC)),
              children: [
                _th('연령\\급수'),
                ..._BracketScreenState._allGrades.map(_th),
              ],
            ),
            ...activeLabels.map((label) {
              return TableRow(children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text2)),
                ),
                ..._BracketScreenState._allGrades.map((g) {
                  final aKey = AssignKey(label, g);
                  final curId = s._assignMap[aKey] ?? s._venues.first.id;
                  return Padding(
                    padding: const EdgeInsets.all(3),
                    child: DropdownButton<String>(
                      value: s._venues.any((v) => v.id == curId)
                          ? curId
                          : s._venues.first.id,
                      isDense: true,
                      underline: const SizedBox(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue,
                          fontFamily: 'NotoSansKR'),
                      items: s._venues
                          .map((v) => DropdownMenuItem(
                              value: v.id,
                              child: Text(v.name.replaceAll('경기장', '장'),
                                  style: const TextStyle(fontSize: 10))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          s.rebuild(() => s._assignMap[aKey] = val);
                        }
                      },
                    ),
                  );
                }),
              ]);
            }),
          ],
        ),
      ),
    );
  }

  Widget _th(String t) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
              padding: const EdgeInsets.only(bottom: 8),
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
          const Divider(),
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
//  TAB 3: 대진표
// ═══════════════════════════════════════════════════════
class _BracketTab extends StatelessWidget {
  final _BracketScreenState s;
  const _BracketTab(this.s);

  // ★ 클래스 메서드로 올바르게 선언
  Widget _dayTab(BuildContext context, String val, String lbl) {
    final on = s._dayFilter == val;
    return Expanded(
        child: GestureDetector(
      onTap: () => s.rebuild(() => s._dayFilter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: on ? AppColors.blue : Colors.transparent,
                    width: 2.5))),
        child: Center(
            child: Text(lbl,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: on ? AppColors.blue : AppColors.muted))),
      ),
    ));
  }

  Widget _vBtn(String id, String lbl, Color? color) {
    final on = s._venueFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: GestureDetector(
        onTap: () => s.rebuild(() => s._venueFilter = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: on ? (color ?? AppColors.blue2) : AppColors.gray,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: on ? (color ?? AppColors.blue2) : Colors.transparent,
                  width: 1.5)),
          child: Text(lbl,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : AppColors.text2)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (s._matches.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('아직 대진표가 없습니다.',
              style: TextStyle(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 14),
          ElevatedButton(
              onPressed: s._generateBracket, child: const Text('대진표 생성하기')),
        ]),
      );
    }

    final done = s._matches.where((m) => m.isDone).length;
    final total = s._matches.length;
    final selCnt = s._selected.length;
    final totalCourts = s._venues.fold(0, (sum, v) => sum + v.courts);

    var filtered = s._matches;
    if (s._venueFilter != 'all') {
      filtered = filtered.where((m) => m.venueId == s._venueFilter).toList();
    }
    if (s._dayFilter != 'all') {
      filtered =
          filtered.where((m) => m.day.toString() == s._dayFilter).toList();
    }

    final grouped = <String, List<Match>>{};
    for (final m in filtered) {
      final k = '${m.venueId}-${m.courtNumber}';
      grouped.putIfAbsent(k, () => []).add(m);
    }

    return Column(children: [
      StatBanner(items: [
        StatItem('$selCnt명', '참가'),
        StatItem('$totalCourts코트', '총코트'),
        StatItem('${total}경기', '경기'),
        StatItem('$done완료', '완료'),
      ]),
      if (s._totalDays == 2)
        Container(
          color: AppColors.white,
          child: Row(children: [
            _dayTab(context, 'all', '전체'),
            _dayTab(context, '1', '1일차'),
            _dayTab(context, '2', '2일차'),
          ]),
        ),
      Container(
        color: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _vBtn('all', '전체', null),
            ...s._venues.map((v) {
              final cnt = s._matches.where((m) => m.venueId == v.id).length;
              if (cnt == 0) return const SizedBox();
              Color col;
              final hex = v.colorHex.replaceAll('#', '');
              try {
                col = Color(int.parse('FF$hex', radix: 16));
              } catch (_) {
                col = AppColors.blue;
              }
              return _vBtn(v.id, '${v.name}($cnt)', col);
            }),
          ]),
        ),
      ),
      const Divider(height: 1),
      // ★ Builder + for 루프로 List<Widget> 명확하게 구성
      Expanded(
        child: Builder(
          builder: (context) {
            final keys = grouped.keys.toList()..sort();
            final items = <Widget>[];
            for (final k in keys) {
              final ms = grouped[k]!;
              final first = ms.first;
              final doneCnt = ms.where((m) => m.isDone).length;
              items.add(Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray2, width: .5)),
                child: Column(children: [
                  CourtBlockHeader(
                    title: first.courtLabel,
                    done: doneCnt,
                    total: ms.length,
                    colorHex: first.venueColorHex,
                  ),
                  ...ms.map((m) => MatchCard(
                        match: m,
                        onTap: () => ScoreInputSheet.show(
                          context,
                          m,
                          (sA, sB) async => s._saveScore(m, sA, sB),
                        ),
                      )),
                ]),
              ));
            }
            return ListView(
              padding: EdgeInsets.only(
                bottom: 20 + MediaQuery.of(context).padding.bottom,
              ),
              children: items,
            );
          },
        ),
      ),
    ]); // ← Column 닫힘
  } // ← build() 닫힘
} // ← _BracketTab 클래스 닫힘

// ═══════════════════════════════════════════════════════
//  TAB 4: 성적
// ═══════════════════════════════════════════════════════
class _ResultsTab extends StatelessWidget {
  final _BracketScreenState s;
  const _ResultsTab(this.s);

  @override
  Widget build(BuildContext context) {
    if (s._rankings.isEmpty) {
      return const Center(
          child: Text('경기 결과를 입력하면 성적이 집계됩니다.',
              style: TextStyle(color: AppColors.muted)));
    }
    const medals = ['🥇', '🥈', '🥉'];
    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: s._rankings.length,
      itemBuilder: (_, i) {
        final r = s._rankings[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(children: [
            SizedBox(
                width: 34,
                child: Text(i < 3 ? medals[i] : '${i + 1}',
                    style: TextStyle(
                        fontSize: i < 3 ? 18 : 14,
                        fontWeight: FontWeight.w700,
                        color: i == 0
                            ? AppColors.amber
                            : i == 1
                                ? AppColors.gray3
                                : i == 2
                                    ? const Color(0xFF9C4221)
                                    : AppColors.muted),
                    textAlign: TextAlign.center)),
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.gradeBackground(r.player.grade),
                    shape: BoxShape.circle),
                child: Center(
                    child: Text(r.player.name[0],
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gradeText(r.player.grade))))),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(r.player.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    const SizedBox(width: 4),
                    Text('(${r.player.gender}) ${r.player.grade}급',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                  ]),
                  Text('${r.player.clubName} · ${r.record}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${r.points}점',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue)),
              Text('${r.games}경기',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ]),
          ]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
//  공통 헬퍼 함수
// ═══════════════════════════════════════════════════════
Widget _card(
        {required String title, String? subtitle, required Widget child}) =>
    Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray2, width: .5)),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text2)),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
