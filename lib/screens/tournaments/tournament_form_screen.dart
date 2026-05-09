import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../models/tournament.dart';
import '../../models/venue.dart';
import '../../services/sample_data.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/form_action_bar.dart';

class TournamentFormScreen extends StatefulWidget {
  /// null 이면 신규 등록, 값이 있으면 수정 모드
  final Tournament? initial;

  const TournamentFormScreen({super.key, this.initial});

  @override
  State<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends State<TournamentFormScreen> {
  bool get _isEdit => widget.initial != null;

  // ── 기본 정보 ──────────────────────────
  final _nameCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  TournamentType _tournamentType = TournamentType.general;
  String _startDate = '';
  String _endDate = '';

  // ── 경기장 (다중) ──────────────────────────
  final List<TextEditingController> _venueNameCtrls = [];
  final List<TextEditingController> _venueAddrCtrls = [];
  final List<int> _venueCourts = [];

  static const int _defaultCourts = 4;
  static const int _maxCourtsPerVenue = 10;

  // ── 경기 정보 ──────────────────────────
  /// 선택된 종별 (List). 최소 1개 이상 유지.
  final Set<String> _selectedEvents = {'혼복'};

  /// 선택된 대상급수. 모두 선택 = '전체' 칩 자동 ON.
  final Set<String> _selectedGrades = {...Tournament.allTargetGrades};

  /// 표시할 급수 목록 (기본 + 사용자 추가). 선수/동호인 관리 화면과 동일한
  /// SharedPreferences 키(data_custom_grades_v1)를 공유해서 한 번 추가한
  /// 자강조/E조 등이 모든 급수 칩에 함께 노출됨.
  List<String> _targetGrades = [...Tournament.allTargetGrades];

  final _entryFeeCtrl = TextEditingController();
  final _deadlineCtrl = TextEditingController();

  // ── 예산 정보 ──────────────────────────
  final _budgetCtrl = TextEditingController();
  final _citySupportCtrl = TextEditingController();
  final _citySupportNoteCtrl = TextEditingController();

  // ── 운영 옵션 ──────────────────────────
  bool _hasClubShare = false;
  bool _acceptsDonation = false;

  // ── 안내사항 ──────────────────────────
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _loadCustomGrades();
    if (t == null) {
      _addVenueRow(); // 신규 등록 시 기본 1개소
      return;
    }
    _nameCtrl.text = t.name;
    _regionCtrl.text = t.region;
    _tournamentType = t.tournamentType;
    _startDate = t.startDate;
    _endDate = t.endDate;
    _selectedEvents
      ..clear()
      ..addAll(t.eventTypeList);
    if (_selectedEvents.isEmpty) _selectedEvents.add('혼복');
    _selectedGrades
      ..clear()
      ..addAll(t.targetGradeList);
    if (_selectedGrades.isEmpty) {
      _selectedGrades.addAll(Tournament.allTargetGrades);
    }
    if (t.entryFee > 0) _entryFeeCtrl.text = _fmtAmount(t.entryFee);
    if (t.totalBudget > 0) _budgetCtrl.text = _fmtAmount(t.totalBudget);
    if (t.citySupportAmount > 0) {
      _citySupportCtrl.text = _fmtAmount(t.citySupportAmount);
    }
    _citySupportNoteCtrl.text = t.citySupportNote;
    _hasClubShare = t.hasClubShare;
    _acceptsDonation = t.acceptsDonation;
    _descCtrl.text = t.description;

    // 기존 venues 채우기 — 비어 있으면 단일 빈 행으로 시작
    if (t.venues.isEmpty) {
      _addVenueRow();
    } else {
      for (final v in t.venues) {
        _venueNameCtrls.add(TextEditingController(text: v.name));
        _venueAddrCtrls.add(TextEditingController(text: v.address));
        _venueCourts.add(v.courts > 0 ? v.courts : _defaultCourts);
      }
    }
  }

  Future<void> _loadCustomGrades() async {
    final saved = await StorageService.loadCustomGrades();
    if (!mounted || saved.isEmpty) return;
    final extras =
        saved.where((g) => !_targetGrades.contains(g)).toList();
    if (extras.isEmpty) return;
    setState(() {
      _targetGrades.addAll(extras);
      // 신규 등록이면 새 급수도 기본 선택 상태로 노출
      if (widget.initial == null) _selectedGrades.addAll(extras);
    });
  }

  Future<void> _persistCustomGrades() async {
    final custom = _targetGrades
        .where((g) => !Tournament.allTargetGrades.contains(g))
        .toList();
    await StorageService.saveCustomGrades(custom);
  }

  Future<void> _addCustomGrade(String label) async {
    if (_targetGrades.contains(label)) {
      _snack('이미 존재하는 급수입니다.');
      return;
    }
    setState(() {
      _targetGrades.add(label);
      _selectedGrades.add(label);
    });
    await _persistCustomGrades();
  }

  Future<void> _removeCustomGrade(String label) async {
    setState(() {
      _targetGrades.remove(label);
      _selectedGrades.remove(label);
    });
    await _persistCustomGrades();
  }

  void _addVenueRow({String name = '', String address = '', int? courts}) {
    _venueNameCtrls.add(TextEditingController(text: name));
    _venueAddrCtrls.add(TextEditingController(text: address));
    _venueCourts.add(courts ?? _defaultCourts);
  }

  void _removeVenueRow() {
    if (_venueNameCtrls.length <= 1) return;
    _venueNameCtrls.removeLast().dispose();
    _venueAddrCtrls.removeLast().dispose();
    _venueCourts.removeLast();
  }

  static String _fmtAmount(int v) => v.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _regionCtrl.dispose();
    for (final c in _venueNameCtrls) {
      c.dispose();
    }
    for (final c in _venueAddrCtrls) {
      c.dispose();
    }
    _entryFeeCtrl.dispose();
    _deadlineCtrl.dispose();
    _budgetCtrl.dispose();
    _citySupportCtrl.dispose();
    _citySupportNoteCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  int _parseAmount(String v) =>
      int.tryParse(v.replaceAll(',', '').replaceAll('원', '').trim()) ?? 0;

  Future<void> _pickDate(TextEditingController? ctrl,
      {void Function(String)? onPick}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      final s =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      if (ctrl != null) ctrl.text = s;
      if (onPick != null) onPick(s);
      setState(() {});
    }
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('대회명을 입력해주세요.');
      return;
    }
    if (_startDate.isEmpty) {
      _snack('시작일을 선택해주세요.');
      return;
    }

    final budget = _parseAmount(_budgetCtrl.text);
    final citySupport = _parseAmount(_citySupportCtrl.text);
    if (citySupport > budget) {
      _snack('시 지원금이 총 예산보다 클 수 없습니다.');
      return;
    }

    final prev = widget.initial;

    // 폼의 경기장 목록 → List<Venue>. 이름이 비어있는 행은 제외.
    final builtVenues = <Venue>[];
    for (var i = 0; i < _venueNameCtrls.length; i++) {
      final name = _venueNameCtrls[i].text.trim();
      if (name.isEmpty) continue;
      final addr = _venueAddrCtrls[i].text.trim();
      // 기존 venue 의 id/colorHex 보존 시도
      final existing =
          (prev != null && i < prev.venues.length) ? prev.venues[i] : null;
      builtVenues.add(Venue(
        id: existing?.id ?? 'v${i + 1}',
        name: name,
        address: addr,
        courts: _venueCourts[i],
        colorHex: existing?.colorHex ??
            Venue.defaultColors[i % Venue.defaultColors.length],
      ));
    }

    final t = Tournament(
      id: prev?.id ?? 't_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      region: _regionCtrl.text.trim(),
      tournamentType: _tournamentType,
      startDate: _startDate,
      endDate: _endDate.isEmpty ? _startDate : _endDate,
      eventType: Tournament.allEventTypes
          .where(_selectedEvents.contains)
          .join(','),
      targetGrade:
          _targetGrades.where(_selectedGrades.contains).join(','),
      entryFee: _parseAmount(_entryFeeCtrl.text),
      status: prev?.status ?? 'upcoming',
      participantCount: prev?.participantCount ?? 0,
      progressPercent: prev?.progressPercent ?? 0,
      description: _descCtrl.text.trim(),
      totalBudget: budget,
      citySupportAmount: citySupport,
      citySupportNote: _citySupportNoteCtrl.text.trim(),
      hasClubShare: _hasClubShare,
      acceptsDonation: _acceptsDonation,
      ageGroups: prev?.ageGroups ?? Tournament.defaultAgeGroups,
      gradeGroups: prev?.gradeGroups ?? Tournament.defaultGradeGroups,
      venues: builtVenues,
    );

    if (_isEdit) {
      final idx = SampleData.tournaments.indexWhere((x) => x.id == t.id);
      if (idx >= 0) {
        SampleData.tournaments[idx] = t;
      } else {
        SampleData.tournaments.add(t);
      }
    } else {
      SampleData.tournaments.add(t);
    }
    SampleData.saveTournaments();
    Navigator.pop(context, t);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.gray,
        appBar: AppBar(
          title: Text(_isEdit ? '대회 수정' : '대회 등록',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          centerTitle: false,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── 기본 정보 ─────────────────────
            _section('기본 정보'),
            _field(
                '대회명',
                _f(_nameCtrl,
                    hint: '예: 2026 협회장기 배드민턴 대회',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _field('지역', _f(_regionCtrl, hint: '예: 한국시'))),
              const SizedBox(width: 8),
              Expanded(child: _field('대회 분류', _typeDropdown())),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _field('시작일', _dateField(_startDate, true))),
              const SizedBox(width: 8),
              Expanded(child: _field('종료일', _dateField(_endDate, false))),
            ]),
            const SizedBox(height: 10),
            _venueSection(),

            const SizedBox(height: 16),
            // ── 경기 정보 ─────────────────────
            // 종별·대상 급수는 대회 생성 후 [설정] 탭에서 편집.
            _section('경기 정보'),
            Row(children: [
              Expanded(
                  child: _field('참가비 (원)',
                      _f(_entryFeeCtrl, hint: '30,000', isAmount: true))),
              const SizedBox(width: 8),
              Expanded(
                  child: _field(
                      '신청 마감일',
                      _dateField(_deadlineCtrl.text, null,
                          ctrl: _deadlineCtrl))),
            ]),

            const SizedBox(height: 16),
            // ── 예산 정보 (NEW) ────────────────
            _section('예산 정보', subtitle: '대회 예산과 시·지자체 지원금을 별도 관리합니다'),
            _field(
                '총 예산 (원)', _f(_budgetCtrl, hint: '6,800,000', isAmount: true)),
            const SizedBox(height: 6),
            _field(
                '시 지원금 (원)',
                _f(_citySupportCtrl,
                    hint: '0 (지원금이 없으면 비워두세요)', isAmount: true)),
            const SizedBox(height: 6),
            _field('시 지원 항목·조건',
                _f(_citySupportNoteCtrl, hint: '예: 체육관 대여비 일부 지원')),
            const SizedBox(height: 6),
            _budgetPreview(),

            const SizedBox(height: 16),
            // ── 운영 옵션 (NEW) ────────────────
            _section('운영 옵션'),
            _toggleTile(
              title: '클럽 분담금 적용',
              subtitle: '협회장기대회처럼 클럽이 분담금을 내는 대회',
              value: _hasClubShare,
              onChanged: (v) => setState(() => _hasClubShare = v),
            ),
            const SizedBox(height: 6),
            _toggleTile(
              title: '찬조 받기',
              subtitle: '개인·기업의 현금/물품 찬조를 추적',
              value: _acceptsDonation,
              onChanged: (v) => setState(() => _acceptsDonation = v),
            ),

            const SizedBox(height: 16),
            // ── 안내 사항 ─────────────────────
            _section('안내 사항'),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '대회 관련 안내 사항 입력',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
        bottomNavigationBar: FormActionBar(
          onSubmit: _save,
          submitLabel: _isEdit ? '저장' : '등록',
        ),
      );

  // ─────────────── 헬퍼 위젯들 ───────────────

  Widget _section(String title, {String? subtitle}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 3,
              height: 14,
              margin: const EdgeInsets.only(right: 7, bottom: 2),
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
      );

  Widget _field(String lbl, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lbl,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text2)),
          const SizedBox(height: 4),
          child,
        ],
      );

  static const _denseInputDecoration = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );

  Widget _f(TextEditingController ctrl,
      {String? hint, bool isAmount = false, TextStyle? style}) {
    return TextField(
      controller: ctrl,
      style: style,
      keyboardType: isAmount ? TextInputType.number : TextInputType.text,
      inputFormatters: isAmount
          ? [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
              _ThousandsFormatter(),
            ]
          : null,
      decoration: _denseInputDecoration.copyWith(hintText: hint),
    );
  }

  Widget _typeDropdown() => DropdownButtonFormField<TournamentType>(
        value: _tournamentType,
        isDense: true,
        decoration: _denseInputDecoration,
        items: TournamentType.values
            .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _tournamentType = v;
            // 분류 선택 시 합리적 기본값 자동 설정
            if (v == TournamentType.associationCup) {
              _hasClubShare = true;
              _acceptsDonation = true;
            } else if (v == TournamentType.cityCup ||
                v == TournamentType.mediaCup) {
              _hasClubShare = false;
              _acceptsDonation = true;
            } else {
              _hasClubShare = false;
              _acceptsDonation = false;
            }
          });
        },
      );

  Widget _dateField(String value, bool? isStart,
      {TextEditingController? ctrl}) {
    return GestureDetector(
      onTap: () => _pickDate(
        ctrl,
        onPick: (s) {
          if (isStart == true) _startDate = s;
          if (isStart == false) _endDate = s;
        },
      ),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD8DEE8)),
        ),
        child: Row(children: [
          Text(
            (ctrl?.text ?? value).isEmpty
                ? 'YYYY-MM-DD'
                : (ctrl?.text ?? value),
            style: TextStyle(
              fontSize: 14,
              color: (ctrl?.text ?? value).isEmpty
                  ? const Color(0xFFAAAAAA)
                  : AppColors.text,
            ),
          ),
          const Spacer(),
          const Icon(Icons.calendar_today_outlined,
              size: 16, color: AppColors.muted),
        ]),
      ),
    );
  }

  Widget _budgetPreview() {
    final budget = _parseAmount(_budgetCtrl.text);
    final city = _parseAmount(_citySupportCtrl.text);
    final burden = budget - city;
    if (budget == 0) return const SizedBox.shrink();

    String fmt(int v) {
      final s = v.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
      return '$s원';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB7CDE8)),
      ),
      child: Row(children: [
        const Icon(Icons.account_balance_wallet_outlined,
            size: 16, color: AppColors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('협회 자체 부담액',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted)),
              const SizedBox(height: 2),
              Text(fmt(burden),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue)),
            ],
          ),
        ),
        if (city > 0)
          Text('시 지원 ${fmt(city)}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }

  // ── 종별 칩 (다중 선택, 최소 1개) ─────────
  Widget _eventChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: Tournament.allEventTypes.map((e) {
        final selected = _selectedEvents.contains(e);
        return _chip(
          label: e,
          selected: selected,
          onTap: () {
            setState(() {
              if (selected) {
                if (_selectedEvents.length <= 1) {
                  _snack('최소 1개의 종별은 선택되어야 합니다.');
                  return;
                }
                _selectedEvents.remove(e);
              } else {
                _selectedEvents.add(e);
              }
            });
          },
        );
      }).toList(),
    );
  }

  // ── 대상 급수 칩 (전체=마스터 토글, 개별 자유 선택, +로 자강조/E조 등 추가) ──
  Widget _gradeChips() {
    final isAll = _targetGrades.isNotEmpty &&
        _targetGrades.every(_selectedGrades.contains);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _chip(
          label: '전체',
          selected: isAll,
          onTap: () {
            setState(() {
              if (isAll) {
                _selectedGrades.clear();
              } else {
                _selectedGrades
                  ..clear()
                  ..addAll(_targetGrades);
              }
            });
          },
        ),
        for (final g in _targetGrades)
          _chip(
            label: g,
            selected: _selectedGrades.contains(g),
            onTap: () {
              setState(() {
                if (_selectedGrades.contains(g)) {
                  _selectedGrades.remove(g);
                } else {
                  _selectedGrades.add(g);
                }
              });
            },
          ),
        _AddChipButton(onTap: _showGradeManageDialog),
      ],
    );
  }

  void _showGradeManageDialog() {
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
                    '추가한 급수는 선수/동호인 관리 화면과 공유됩니다.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  if (_targetGrades.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('급수 목록',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted)),
                    const SizedBox(height: 4),
                    ..._targetGrades.map((g) => Row(children: [
                          Expanded(
                              child: Text(g,
                                  style:
                                      const TextStyle(fontSize: 14))),
                          IconButton(
                            tooltip: '삭제',
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: AppColors.red),
                            onPressed: () async {
                              await _removeCustomGrade(g);
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
                onPressed: () async {
                  final raw = ctrl.text.trim();
                  if (raw.isEmpty) {
                    _snack('라벨을 입력하세요.');
                    return;
                  }
                  await _addCustomGrade(raw);
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

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryMid : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected ? AppColors.primaryMid : const Color(0xFFD8DEE8),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(selected ? Icons.check : Icons.circle_outlined,
                size: 12,
                color: selected ? Colors.white : const Color(0xFFB8BFCC)),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.text2)),
          ]),
        ),
      );

  // ── 경기장 섹션 (대회 생성 시 1개만 입력, 추가는 설정 탭에서) ───
  Widget _venueSection() {
    final count = _venueNameCtrls.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 경기장 카드 리스트
        for (var i = 0; i < count; i++) ...[
          _venueCard(i),
          if (i < count - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _stepperBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 36,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon,
              size: 18,
              color: enabled ? AppColors.blue : const Color(0xFFCFCFCF)),
        ),
      );

  Widget _venueCard(int i) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8DEE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('경기장 ${i + 1}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted)),
          const SizedBox(height: 6),
          _venueRow(
            label: '대회장소',
            child: _f(_venueNameCtrls[i], hint: '예: 한국시민체육관'),
          ),
          const SizedBox(height: 6),
          _venueRow(
            label: '위치',
            child: _f(_venueAddrCtrls[i], hint: '예: 한국 한국시 ...'),
            leadingIcon: Icons.place_outlined,
          ),
          const SizedBox(height: 6),
          _venueRow(
            label: '코트 수',
            child: Row(children: [
              _stepperBtn(
                icon: Icons.remove,
                enabled: _venueCourts[i] > 0,
                onTap: () => setState(() {
                  if (_venueCourts[i] > 0) {
                    _venueCourts[i] = _venueCourts[i] - 1;
                  }
                }),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${_venueCourts[i]}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              _stepperBtn(
                icon: Icons.add,
                enabled: _venueCourts[i] < _maxCourtsPerVenue,
                onTap: () => setState(() {
                  if (_venueCourts[i] < _maxCourtsPerVenue) {
                    _venueCourts[i] = _venueCourts[i] + 1;
                  }
                }),
              ),
              const SizedBox(width: 8),
              const Text('코트',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _venueRow(
      {required String label, required Widget child, IconData? leadingIcon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          child: Row(children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2)),
          ]),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? AppColors.primaryMid : const Color(0xFFD8DEE8),
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppColors.primaryMid,
            onChanged: onChanged,
          ),
        ]),
      );
}

class _AddChipButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddChipButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.gray3, width: 1.5),
          ),
          child: const Icon(Icons.add, size: 14, color: AppColors.muted),
        ),
      );
}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
