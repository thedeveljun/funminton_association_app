import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/player.dart';
import '../../services/sample_data.dart';
import '../../services/storage_service.dart';
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

  void _reorderGrade(int oldIdx, int newIdx) {
    setState(() {
      if (newIdx > oldIdx) newIdx--;
      final item = _allGrades.removeAt(oldIdx);
      _allGrades.insert(newIdx, item);
    });
    _persistCustomGrades();
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
          '선수/동호인 관리',
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
        _GradeFilterBar(
          allGrades: _allGrades,
          activeGrades: _activeGrades,
          defaultGrades: _defaultGrades,
          onToggleGrade: _toggleGrade,
          onToggleAll: _toggleAllGrades,
          onAddGrade: _addCustomGrade,
          onRemoveGrade: _removeCustomGrade,
          onReorderGrade: _reorderGrade,
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
//  급수 다중 선택 필터 — 전체 마스터 토글 + 추가/삭제
// ═══════════════════════════════════════════════════════
class _GradeFilterBar extends StatelessWidget {
  final List<String> allGrades;
  final Set<String> activeGrades;
  final List<String> defaultGrades;
  final ValueChanged<String> onToggleGrade;
  final VoidCallback onToggleAll;
  final ValueChanged<String> onAddGrade;
  final ValueChanged<String> onRemoveGrade;
  final void Function(int oldIdx, int newIdx) onReorderGrade;

  const _GradeFilterBar({
    required this.allGrades,
    required this.activeGrades,
    required this.defaultGrades,
    required this.onToggleGrade,
    required this.onToggleAll,
    required this.onAddGrade,
    required this.onRemoveGrade,
    required this.onReorderGrade,
  });

  @override
  Widget build(BuildContext context) {
    final allOn =
        allGrades.isNotEmpty && allGrades.every(activeGrades.contains);
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: SizedBox(
        height: 32,
        child: Row(children: [
          GestureDetector(
            onTap: onToggleAll,
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
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                child: child,
              ),
              itemCount: allGrades.length + 1, // 마지막은 +추가 칩
              onReorder: (oldIdx, newIdx) {
                // +추가 칩(마지막 인덱스)은 드래그 불가지만 안전 가드
                if (oldIdx >= allGrades.length) return;
                if (newIdx > allGrades.length) newIdx = allGrades.length;
                onReorderGrade(oldIdx, newIdx);
              },
              itemBuilder: (ctx, i) {
                if (i == allGrades.length) {
                  // 스크롤 영역 마지막에 위치 → 칩이 많으면 가려지고, 끝까지 스크롤 시 노출
                  return Padding(
                    key: const ValueKey('__add_grade_chip__'),
                    padding: const EdgeInsets.only(right: 7),
                    child: _AddGradeChip(
                        onTap: () => _showManageDialog(context)),
                  );
                }
                final g = allGrades[i];
                final on = activeGrades.contains(g);
                return Padding(
                  key: ValueKey(g),
                  padding: const EdgeInsets.only(right: 7),
                  child: ReorderableDelayedDragStartListener(
                    index: i,
                    child: GestureDetector(
                      onTap: () => onToggleGrade(g),
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
                          '$g${on ? ' ✓' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                on ? FontWeight.w600 : FontWeight.w500,
                            color:
                                on ? Colors.white : AppColors.primaryMid,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _showManageDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setStateD) {
          return AlertDialog(
            title: const Text('급수 추가/삭제'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration:
                        const InputDecoration(hintText: '예: 자강조, E조'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '선수의 급수가 일치하면 필터에 노출됩니다.\n칩을 길게 눌러 좌우로 드래그하면 순서를 변경할 수 있습니다.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  if (allGrades.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('급수 목록',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted)),
                    const SizedBox(height: 4),
                    ...allGrades.map((g) => Row(children: [
                          Expanded(
                              child: Text(g,
                                  style: const TextStyle(fontSize: 14))),
                          IconButton(
                            tooltip: '삭제',
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: AppColors.red),
                            onPressed: () {
                              onRemoveGrade(g);
                              setStateD(() {});
                            },
                          ),
                        ])),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('닫기'),
              ),
              TextButton(
                onPressed: () {
                  final raw = ctrl.text.trim();
                  if (raw.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('라벨을 입력하세요.')));
                    return;
                  }
                  onAddGrade(raw);
                  ctrl.clear();
                  setStateD(() {});
                },
                child: const Text('추가'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddGradeChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddGradeChip({required this.onTap});

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
