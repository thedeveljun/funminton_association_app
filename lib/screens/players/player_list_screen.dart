import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/player.dart';
import '../../services/sample_data.dart';
import '../../services/storage_service.dart';
import '../../utils/age_group.dart';
import '../../widgets/players/player_list_item.dart';
import '../clubs/upload_screen.dart';
import 'player_detail_screen.dart';
import 'player_form_screen.dart';

const _searchInk = Color(0xFF0D1B3E);
const _searchMuted = Color(0xFF9BA8BB);
const _searchAccent = Color(0xFF22A06B);

class PlayerListScreen extends StatefulWidget {
  const PlayerListScreen({super.key});
  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen> {
  /// 기본 급수 라벨 (삭제 불가) — PlayerFormScreen._builtinGrades 와 동일하게 유지
  static const List<String> _defaultGrades = [
    '자강조',
    'S조',
    'A조',
    'B조',
    'C조',
    'D조',
    '초심조',
  ];

  /// 표시 순서: 기본 + 사용자 추가
  List<String> _allGrades = List.of(_defaultGrades);

  /// 다중 선택된 급수. 비어 있으면 0명.
  final Set<String> _activeGrades = {..._defaultGrades};

  /// 기본 연령 그룹 라벨 (참가자 탭과 동일한 숫자 라벨).
  static const List<String> _defaultAges = ['20', '30', '40', '50', '60', '70'];

  /// 표시 순서: 기본 + 사용자 추가
  List<String> _allAges = List.of(_defaultAges);

  /// 다중 선택된 연령 그룹. 비어 있으면 0명.
  final Set<String> _activeAges = {..._defaultAges};

  String _genderFilter = '전체';
  /// '클럽별' 정렬 (클럽명 가나다 순, 그룹 내 나이 오름차순)
  bool _sortByClub = false;
  /// '급수별' 정렬 (자강조 → S조 → A조 → … → 초심조, 그룹 내 나이 오름차순)
  bool _sortByGrade = false;
  final _ctrl = TextEditingController();

  /// '급수별' 정렬용 순서 — 자강조 → S조 → A조 → B조 → C조 → D조 → 초심조.
  /// 알 수 없는 급수는 9999 로 정렬 끝으로 밀어냄.
  static const Map<String, int> _gradeSortOrder = {
    '자강조': 0,
    'S조': 1,
    'A조': 2,
    'B조': 3,
    'C조': 4,
    'D조': 5,
    '초심조': 6,
  };

  int _gradeSortIndex(String g) => _gradeSortOrder[g] ?? 9999;

  @override
  void initState() {
    super.initState();
    _loadCustomGrades();
    _loadCustomAges();
  }

  Future<void> _loadCustomGrades() async {
    final order = await StorageService.loadGradeOrder();
    final saved = await StorageService.loadCustomGrades();
    if (!mounted) return;
    setState(() {
      if (order != null && order.isNotEmpty) {
        // 저장된 순서 사용 + 누락된 기본 급수는 끝에 보강
        _allGrades = [
          ...order,
          ..._defaultGrades.where((g) => !order.contains(g)),
        ];
      } else {
        _allGrades = [
          ..._defaultGrades,
          ...saved.where((g) => !_defaultGrades.contains(g)),
        ];
      }
      // 데이터에만 존재하는 미등록 급수도 칩에 보강 (엑셀 업로드 legacy 등)
      for (final p in SampleData.players) {
        if (p.grade.isNotEmpty && !_allGrades.contains(p.grade)) {
          _allGrades.add(p.grade);
        }
      }
      _activeGrades.addAll(_allGrades);
    });
  }

  Future<void> _persistCustomGrades() async {
    final custom =
        _allGrades.where((g) => !_defaultGrades.contains(g)).toList();
    await StorageService.saveCustomGrades(custom);
    await StorageService.saveGradeOrder(_allGrades);
  }

  void _toggleGrade(String label) {
    setState(() {
      if (_activeGrades.contains(label)) {
        _activeGrades.remove(label);
      } else {
        _activeGrades.add(label);
      }
    });
  }

  void _toggleAllGrades() {
    final allOn = _allGrades.isNotEmpty &&
        _allGrades.every(_activeGrades.contains);
    setState(() {
      if (allOn) {
        _activeGrades.clear();
      } else {
        _activeGrades
          ..clear()
          ..addAll(_allGrades);
      }
    });
  }

  Future<void> _addCustomGrade(String label) async {
    if (_allGrades.contains(label)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이미 존재하는 급수입니다.')));
      return;
    }
    setState(() {
      _allGrades.add(label);
      _activeGrades.add(label);
    });
    await _persistCustomGrades();
  }

  Future<void> _removeCustomGrade(String label) async {
    setState(() {
      _allGrades.remove(label);
      _activeGrades.remove(label);
    });
    await _persistCustomGrades();
  }

  // ─── 연령 그룹 ─────────────────────────────────

  Future<void> _loadCustomAges() async {
    final order = await StorageService.loadAgeGroupOrder();
    final saved = await StorageService.loadCustomAgeGroups();
    if (!mounted) return;
    setState(() {
      if (order != null && order.isNotEmpty) {
        _allAges = [
          ...order,
          ..._defaultAges.where((g) => !order.contains(g)),
        ];
      } else {
        _allAges = [
          ..._defaultAges,
          ...saved.where((g) => !_defaultAges.contains(g)),
        ];
      }
      _activeAges.addAll(_allAges);
    });
  }

  Future<void> _persistCustomAges() async {
    final custom =
        _allAges.where((g) => !_defaultAges.contains(g)).toList();
    await StorageService.saveCustomAgeGroups(custom);
    await StorageService.saveAgeGroupOrder(_allAges);
  }

  void _toggleAge(String label) {
    setState(() {
      if (_activeAges.contains(label)) {
        _activeAges.remove(label);
      } else {
        _activeAges.add(label);
      }
    });
  }

  void _toggleAllAges() {
    final allOn =
        _allAges.isNotEmpty && _allAges.every(_activeAges.contains);
    setState(() {
      if (allOn) {
        _activeAges.clear();
      } else {
        _activeAges
          ..clear()
          ..addAll(_allAges);
      }
    });
  }

  Future<void> _addCustomAge(String label) async {
    if (_allAges.contains(label)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 존재하는 연령 그룹입니다.')));
      return;
    }
    setState(() {
      final combined = [..._allAges, label];
      // 숫자는 오름차순, 텍스트는 끝에 입력 순서.
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
      _allAges = [...numeric, ...textual];
      _activeAges.add(label);
    });
    await _persistCustomAges();
  }

  Future<void> _removeCustomAge(String label) async {
    setState(() {
      _allAges.remove(label);
      _activeAges.remove(label);
    });
    await _persistCustomAges();
  }

  Future<void> _confirmDeleteAllPlayers() async {
    final total = SampleData.players.length;
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제할 선수가 없습니다.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('전체 삭제',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
          '등록된 $total명의 선수를 모두 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('전체 삭제',
                style: TextStyle(
                    color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    SampleData.players.clear();
    await SampleData.savePlayers();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$total명을 모두 삭제했습니다.')),
      );
    }
  }

  List<Player> get _filtered {
    var list = SampleData.players.toList();
    list = list.where((p) => _activeGrades.contains(p.grade)).toList();
    // 활성 연령 그룹 중 하나라도 매칭되어야 통과 (참가자 탭과 동일 정책).
    list = list
        .where(
            (p) => _activeAges.any((l) => ageMatches(l, p.age, _allAges)))
        .toList();
    if (_genderFilter != '전체') {
      list = list.where((p) => p.gender == _genderFilter).toList();
    }
    final q = _ctrl.text.trim();
    if (q.isNotEmpty) {
      list = list
          .where((p) => p.name.contains(q) || p.clubName.contains(q))
          .toList();
    }
    list.sort((a, b) {
      // 둘 다 켜지면: 클럽 → 급수 → 그 안에서 나이 오름차순 → 이름순
      if (_sortByClub) {
        final c = a.clubName.compareTo(b.clubName); // 가나다 순
        if (c != 0) return c;
      }
      if (_sortByGrade) {
        final c = _gradeSortIndex(a.grade).compareTo(_gradeSortIndex(b.grade));
        if (c != 0) return c;
      }
      // 클럽별/급수별 중 하나라도 켜져 있으면 그룹 내 나이 오름차순
      if (_sortByClub || _sortByGrade) {
        final c = a.age.compareTo(b.age);
        if (c != 0) return c;
      }
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        titleSpacing: -4,
        leadingWidth: 34,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.maybePop(context),
          icon:
              const Icon(Icons.arrow_back_ios_new, size: 20, color: _searchInk),
        ),
        title: const Text(
          '선수관리',
          style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.w700, color: _searchInk),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => UploadScreen(type: UploadType.player),
                ),
              );
              if (result == true) {
                setState(() {});
                await SampleData.savePlayers();
              }
            },
            icon: const Icon(Icons.upload_file_rounded, color: _searchAccent),
            tooltip: '엑셀 업로드',
          ),
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PlayerFormScreen()));
              setState(() {});
              await SampleData.savePlayers();
            },
            icon: const Icon(Icons.add, size: 18),
            label:
                const Text('등록', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          PopupMenuButton<String>(
            tooltip: '더보기',
            icon: const Icon(Icons.more_vert, color: _searchInk),
            onSelected: (v) {
              if (v == 'delete_all') _confirmDeleteAllPlayers();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete_all',
                child: Row(children: [
                  Icon(Icons.delete_sweep_rounded,
                      size: 18, color: Color(0xFFB91C1C)),
                  SizedBox(width: 8),
                  Text('전체 삭제',
                      style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: SizedBox(
            height: 37,
            child: TextField(
              controller: _ctrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _searchInk,
                  letterSpacing: -0.3),
              decoration: InputDecoration(
                hintText: '선수명, 클럽명 검색',
                hintStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _searchMuted),
                prefixIcon: const Icon(Icons.person_search_rounded,
                    size: 18, color: _searchAccent),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 34, minHeight: 34),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide:
                        const BorderSide(color: _searchAccent, width: 1.4)),
                filled: true,
                fillColor: const Color(0xFFF0F4FB),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: _searchMuted),
                        onPressed: () => setState(() => _ctrl.clear()),
                      )
                    : null,
              ),
            ),
          ),
        ),
        _AgeFilterBar(
          allAges: _allAges,
          activeAges: _activeAges,
          onToggleAge: _toggleAge,
          onToggleAll: _toggleAllAges,
          onAddAge: _addCustomAge,
          onRemoveAge: _removeCustomAge,
        ),
        _GradeFilterBar(
          allGrades: _allGrades,
          activeGrades: _activeGrades,
          onToggleGrade: _toggleGrade,
          onToggleAll: _toggleAllGrades,
          onAddGrade: _addCustomGrade,
          onRemoveGrade: _removeCustomGrade,
        ),
        _GenderSortRow(
          gender: _genderFilter,
          sortByClub: _sortByClub,
          sortByGrade: _sortByGrade,
          onGender: (v) => setState(() => _genderFilter = v),
          onToggleClub: () => setState(() => _sortByClub = !_sortByClub),
          onToggleGrade: () => setState(() => _sortByGrade = !_sortByGrade),
        ),
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(children: [
            Text(
                '총 ${filtered.length.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}명',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => PlayerListItem(
              player: filtered[i],
              index: i + 1,
              onTap: () async {
                await Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) =>
                            PlayerDetailScreen(player: filtered[i])));
                if (mounted) setState(() {});
              },
            ),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  급수 다중 선택 필터 — 참가자 탭 _GradeToggleBar 와 동일한 패턴.
//   · '전체' 마스터 토글 (amber)
//   · 칩: 탭=토글, 길게 눌러=삭제 다이얼로그
//   · + 칩: 단순 추가 다이얼로그
// ═══════════════════════════════════════════════════════
class _GradeFilterBar extends StatelessWidget {
  final List<String> allGrades;
  final Set<String> activeGrades;
  final ValueChanged<String> onToggleGrade;
  final VoidCallback onToggleAll;
  final ValueChanged<String> onAddGrade;
  final ValueChanged<String> onRemoveGrade;

  const _GradeFilterBar({
    required this.allGrades,
    required this.activeGrades,
    required this.onToggleGrade,
    required this.onToggleAll,
    required this.onAddGrade,
    required this.onRemoveGrade,
  });

  @override
  Widget build(BuildContext context) {
    final allOn =
        allGrades.isNotEmpty && allGrades.every(activeGrades.contains);
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(children: [
        GestureDetector(
          onTap: onToggleAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: allOn ? AppColors.amber : AppColors.amber2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.amber, width: 1.5),
            ),
            child: Text(
              '전체',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: allOn ? Colors.white : AppColors.amberText,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ...allGrades.map((g) {
                final on = activeGrades.contains(g);
                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: GestureDetector(
                    onTap: () => onToggleGrade(g),
                    onLongPress: () => _showDeleteDialog(context, g),
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
            ]),
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
        title: const Text('급수 추가'),
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
              if (allGrades.contains(raw)) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이미 존재하는 그룹입니다.')));
                return;
              }
              onAddGrade(raw);
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String label) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('$label 삭제'),
        content: const Text(
            '이 급수 그룹을 삭제하시겠습니까? 해당 급수 선수는 자동 필터에서 제외됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              onRemoveGrade(label);
              Navigator.of(dialogCtx).pop();
            },
            child:
                const Text('삭제', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  연령 다중 선택 필터 — 참가자 탭 _DecadeToggleBar 와 동일한 패턴.
//   · '연령' 마스터 토글 (amber)
//   · 칩: 탭=토글, 길게 눌러=삭제 다이얼로그
//   · + 칩: 숫자/텍스트 라벨 추가
// ═══════════════════════════════════════════════════════
class _AgeFilterBar extends StatelessWidget {
  final List<String> allAges;
  final Set<String> activeAges;
  final ValueChanged<String> onToggleAge;
  final VoidCallback onToggleAll;
  final ValueChanged<String> onAddAge;
  final ValueChanged<String> onRemoveAge;

  const _AgeFilterBar({
    required this.allAges,
    required this.activeAges,
    required this.onToggleAge,
    required this.onToggleAll,
    required this.onAddAge,
    required this.onRemoveAge,
  });

  @override
  Widget build(BuildContext context) {
    final allOn =
        allAges.isNotEmpty && allAges.every(activeAges.contains);
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(children: [
        GestureDetector(
          onTap: onToggleAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: allOn ? AppColors.amber : AppColors.amber2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.amber, width: 1.5),
            ),
            child: Text(
              '연령',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: allOn ? Colors.white : AppColors.amberText,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ...allAges.map((label) {
                final on = activeAges.contains(label);
                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: GestureDetector(
                    onTap: () => onToggleAge(label),
                    onLongPress: () =>
                        _showDeleteDialog(context, label),
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
              _AddChip(onTap: () => _showAddDialog(context)),
            ]),
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
        title: const Text('연령 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: '예: 45 또는 고등학생'),
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
              if (allAges.contains(raw)) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이미 존재하는 그룹입니다.')));
                return;
              }
              onAddAge(raw);
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String label) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('$label 삭제'),
        content: const Text('이 연령 그룹을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              onRemoveAge(label);
              Navigator.of(dialogCtx).pop();
            },
            child:
                const Text('삭제', style: TextStyle(color: AppColors.red)),
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

// ═══════════════════════════════════════════════════════
//  성별 + 정렬(클럽별/급수별) 선택 — 같은 행에 묶음
//  · 성별: 단일선택 (블루 톤)
//  · 정렬: 토글 (그레이 톤). 다시 누르면 기본(이름순)
// ═══════════════════════════════════════════════════════
class _GenderSortRow extends StatelessWidget {
  final String gender;
  final bool sortByClub;
  final bool sortByGrade;
  final ValueChanged<String> onGender;
  final VoidCallback onToggleClub;
  final VoidCallback onToggleGrade;

  const _GenderSortRow({
    required this.gender,
    required this.sortByClub,
    required this.sortByGrade,
    required this.onGender,
    required this.onToggleClub,
    required this.onToggleGrade,
  });

  static const _genderOptions = ['전체', '남', '여'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          ..._genderOptions.map((opt) {
            final on = opt == gender;
            return Padding(
              padding: const EdgeInsets.only(right: 7),
              child: GestureDetector(
                onTap: () => onGender(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
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
                    opt,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      color: on ? Colors.white : AppColors.primaryMid,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 6),
          _SortChip(
            label: '클럽별',
            on: sortByClub,
            onTap: onToggleClub,
          ),
          _SortChip(
            label: '급수별',
            on: sortByGrade,
            onTap: onToggleGrade,
          ),
        ]),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _SortChip({
    required this.label,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              // 회색 톤 — off는 중간 톤, on은 짙은 톤으로 가독성↑
              color: on ? AppColors.muted : const Color(0xFFD7DCE5),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: on ? AppColors.muted : AppColors.gray3,
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                color: on ? Colors.white : AppColors.text2,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      );
}
