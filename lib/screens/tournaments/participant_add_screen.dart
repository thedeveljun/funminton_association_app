import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../models/player.dart';
import '../../services/sample_data.dart';
import 'entry_upload_screen.dart';

/// 급수 라벨 추가/삭제 콜백 — 호출자(bracket_screen)가 Tournament.gradeGroups
/// 갱신·영속화를 책임진다.
typedef GradeMutator = void Function(String grade);

/// 휴대전화 번호 포매터: 입력된 숫자에 자동으로 '-' 삽입.
///   3자리 이하: 그대로 (예: 010)
///   4~7자리: XXX-XXXX (예: 010-1234)
///   10자리: XXX-XXX-XXXX (예: 031-123-4567)
///   11자리: XXX-XXXX-XXXX (예: 010-1234-5678)
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final t = digits.length > 11 ? digits.substring(0, 11) : digits;
    String out;
    if (t.length <= 3) {
      out = t;
    } else if (t.length <= 7) {
      out = '${t.substring(0, 3)}-${t.substring(3)}';
    } else {
      // 8자 이상: 11자면 3-4-4, 10자면 3-3-4
      final mid = t.length >= 11 ? 7 : 6;
      out = '${t.substring(0, 3)}-${t.substring(3, mid)}-${t.substring(mid)}';
    }
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

/// 주 액션 색 — 참가자 탭의 '참가자 추가' 핀과 동일한 인디고.
const _primaryAction = Color(0xFF3730A3);

const _events = ['혼복', '남복', '여복'];

/// 표준 급수 정렬 순서 — 사용자 정의 급수는 표 끝(원래 순서 유지) + '전체' 맨 앞.
const _gradeSortOrder = <String, int>{
  '자강조': 0,
  'S조': 1,
  'A조': 2,
  'B조': 3,
  'C조': 4,
  'D조': 5,
  'E조': 6,
  '초심조': 7,
};

List<String> _sortedGrades(Iterable<String> grades) {
  final known = <String>[];
  final unknown = <String>[];
  for (final g in grades) {
    if (_gradeSortOrder.containsKey(g)) {
      known.add(g);
    } else {
      unknown.add(g);
    }
  }
  known.sort(
      (a, b) => _gradeSortOrder[a]!.compareTo(_gradeSortOrder[b]!));
  return [...known, ...unknown];
}

/// 참가자 추가 진입점 — '직접 입력' / '엑셀 일괄 등록' 두 갈래로 분기.
/// 두 갈래 모두 [EntryUploadResult] 를 들고 돌아오며, 호출자(bracket_screen) 가
/// `_selected` 와 `_entryEventCounts` 에 머지한다.
class ParticipantAddScreen extends StatelessWidget {
  final Set<String> existingSelected;
  final List<String> initialGrades;
  final GradeMutator onAddGrade;
  final GradeMutator onRemoveGrade;
  const ParticipantAddScreen({
    super.key,
    required this.existingSelected,
    required this.initialGrades,
    required this.onAddGrade,
    required this.onRemoveGrade,
  });

  Future<void> _openManual(BuildContext context) async {
    final r = await Navigator.push<EntryUploadResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualEntryScreen(
          existingSelected: existingSelected,
          initialGrades: initialGrades,
          onAddGrade: onAddGrade,
          onRemoveGrade: onRemoveGrade,
        ),
      ),
    );
    if (r != null && context.mounted) Navigator.pop(context, r);
  }

  Future<void> _openExcel(BuildContext context) async {
    final r = await Navigator.push<EntryUploadResult>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryUploadScreen(existingSelected: existingSelected),
      ),
    );
    if (r != null && context.mounted) Navigator.pop(context, r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(context, '참가자 추가'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 2, 4, 14),
                child: Text(
                  '등록 방법을 선택하세요',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _MethodCard(
                icon: Icons.edit_outlined,
                accent: _primaryAction,
                title: '직접 입력',
                desc: '한 명씩 폼으로 등록 — 즉시 명단에 반영됩니다',
                badge: '간편',
                onTap: () => _openManual(context),
              ),
              const SizedBox(height: 8),
              _MethodCard(
                icon: Icons.cloud_upload_outlined,
                accent: AppColors.primaryMid,
                title: '엑셀로 일괄 등록',
                desc: '여러 명을 한 번에 — 양식 다운로드 → 작성 → 업로드',
                badge: '여러 명',
                onTap: () => _openExcel(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String desc;
  final String badge;
  final VoidCallback onTap;
  const _MethodCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.desc,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                                letterSpacing: -0.2)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(badge,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: -0.1)),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.text2,
                            height: 1.3,
                            letterSpacing: -0.1)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// 참가자 1명을 폼으로 직접 입력. 등록 시 [SampleData.players] 에 신규 추가하고
/// [EntryUploadResult] 로 반환하여 호출자가 선택/카운트 머지하도록 한다.
/// 개별 등록은 항상 파트너 미매칭 1건으로 보고 — 추후 별도 보정 필요.
class ManualEntryScreen extends StatefulWidget {
  final Set<String> existingSelected;
  final List<String> initialGrades;
  final GradeMutator onAddGrade;
  final GradeMutator onRemoveGrade;
  const ManualEntryScreen({
    super.key,
    required this.existingSelected,
    required this.initialGrades,
    required this.onAddGrade,
    required this.onRemoveGrade,
  });

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _nameCtrl = TextEditingController();
  final _clubCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // 파트너 (선택) — 채우면 한번에 2명 등록 + 페어 매칭.
  final _pNameCtrl = TextEditingController();
  final _pBirthCtrl = TextEditingController();
  final _pClubCtrl = TextEditingController();
  final _pPhoneCtrl = TextEditingController();

  String _event = '혼복';
  String? _grade; // null = 미선택 (필수 선택)
  String _gender = '남';
  bool _genderManuallySet = false;

  late List<String> _grades = _sortedGrades(widget.initialGrades);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _clubCtrl.dispose();
    _birthCtrl.dispose();
    _phoneCtrl.dispose();
    _pNameCtrl.dispose();
    _pBirthCtrl.dispose();
    _pClubCtrl.dispose();
    _pPhoneCtrl.dispose();
    super.dispose();
  }

  /// 파트너 자동 성별 — 종목별로 결정.
  /// 혼복: 본인과 반대. 남복/여복: 본인과 동일.
  String get _partnerGender {
    if (_event == '혼복') return _gender == '남' ? '여' : '남';
    return _gender;
  }

  /// 파트너 만 나이 (생년월일 입력 시 자동).
  int get _partnerAge =>
      Player.calcAgeFromBirthDate(_pBirthCtrl.text.trim());

  bool get _partnerEmpty =>
      _pNameCtrl.text.trim().isEmpty && _pBirthCtrl.text.trim().isEmpty;

  bool get _partnerComplete {
    return _pNameCtrl.text.trim().isNotEmpty &&
        _partnerAge > 0;
  }

  Future<void> _showAddGradeDialog() async {
    final ctrl = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('급수 추가',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: _inputTextStyle,
              decoration: _inputDeco('예: E조 또는 마스터조'),
            ),
            const SizedBox(height: 8),
            const Text('대회 전체에서 사용되는 급수에 추가됩니다.',
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryAction,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (added == null || added.isEmpty) return;
    if (_grades.contains(added)) {
      _snack('이미 존재하는 급수입니다.');
      return;
    }
    widget.onAddGrade(added);
    setState(() {
      _grades = _sortedGrades([..._grades, added]);
      _grade = added; // 새로 추가한 급수를 바로 선택
    });
  }

  Future<void> _showDeleteGradeDialog(String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('급수 삭제',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
        content: Text('"$label" 을(를) 삭제할까요? 대회 전체에서 제거됩니다.',
            style: const TextStyle(fontSize: 15, color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.onRemoveGrade(label);
    setState(() {
      _grades.remove(label);
      if (_grade == label) _grade = null;
    });
  }

  void _onEventChanged(String v) {
    setState(() {
      _event = v;
      // 사용자가 성별을 직접 건드리지 않았다면, 종목에 맞춰 자동 보정.
      if (!_genderManuallySet) {
        if (v == '여복') _gender = '여';
        if (v == '남복') _gender = '남';
      }
    });
  }

  /// 입력된 생년월일에서 만 나이 계산. 정규화 실패 시 0.
  int get _calculatedAge =>
      Player.calcAgeFromBirthDate(_birthCtrl.text.trim());

  bool get _canSubmit {
    final selfOk = _nameCtrl.text.trim().isNotEmpty &&
        _clubCtrl.text.trim().isNotEmpty &&
        _calculatedAge > 0 &&
        _grade != null;
    if (!selfOk) return false;
    // 파트너는 비어있거나 (본인만 등록), 이름+생년월일이 모두 채워져야 함.
    return _partnerEmpty || _partnerComplete;
  }

  /// 이름+클럽으로 기존 선수 매칭. 없으면 새 Player 생성.
  /// 반환: (player, isNew).
  (Player, bool) _findOrCreate({
    required String name,
    required String clubName,
    required String gender,
    required String grade,
    required String birthDate,
    required int age,
    required String phone,
  }) {
    for (final p in SampleData.players) {
      if (p.name == name && p.clubName == clubName) {
        return (p, false);
      }
    }
    final club = SampleData.clubs.where((c) => c.name == clubName).firstOrNull;
    final seq = SampleData.players.length + 1;
    final player = Player(
      id: 'player_${DateTime.now().millisecondsSinceEpoch}_$seq',
      name: name,
      gender: gender,
      grade: grade,
      clubId: club?.id ?? '',
      clubName: clubName,
      phone: phone,
      birthDate: birthDate,
      age: age,
      regNumber: '2026-${seq.toString().padLeft(4, '0')}',
    );
    SampleData.players.add(player);
    return (player, true);
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final clubName = _clubCtrl.text.trim();
    final birthRaw = _birthCtrl.text.trim();
    final normBirth = Player.normalizeBirthDate(birthRaw);
    final age = Player.calcAgeFromBirthDate(birthRaw);
    if (name.isEmpty || clubName.isEmpty || age <= 0 || _grade == null) {
      _snack('이름·소속클럽·생년월일·급수는 필수입니다.');
      return;
    }
    if (!_partnerEmpty && !_partnerComplete) {
      _snack('파트너 이름·생년월일을 모두 입력하거나 둘 다 비워주세요.');
      return;
    }

    int newCount = 0;
    final (self, selfIsNew) = _findOrCreate(
      name: name,
      clubName: clubName,
      gender: _gender,
      grade: _grade!,
      birthDate: normBirth,
      age: age,
      phone: _phoneCtrl.text.trim(),
    );
    if (selfIsNew) newCount++;

    Player? partner;
    if (_partnerComplete) {
      final pName = _pNameCtrl.text.trim();
      final pBirthRaw = _pBirthCtrl.text.trim();
      final pNormBirth = Player.normalizeBirthDate(pBirthRaw);
      final pAge = Player.calcAgeFromBirthDate(pBirthRaw);
      final pClub = _pClubCtrl.text.trim().isEmpty
          ? clubName
          : _pClubCtrl.text.trim();
      final (p, pIsNew) = _findOrCreate(
        name: pName,
        clubName: pClub,
        gender: _partnerGender,
        grade: _grade!, // 같은 부서이므로 본인과 동일 급수
        birthDate: pNormBirth,
        age: pAge,
        phone: _pPhoneCtrl.text.trim(),
      );
      if (pIsNew) newCount++;
      partner = p;
    }

    if (newCount > 0) SampleData.savePlayers();

    final selected = {...widget.existingSelected, self.id};
    if (partner != null) selected.add(partner.id);

    final result = EntryUploadResult(
      selectedPlayerIds: selected.toList(),
      eventCounts: {_event: partner != null ? 2 : 1},
      newPlayerCount: newCount,
      // 파트너 함께 등록 시 페어 매칭 완료 → 0. 본인만 등록 시 1건 미매칭.
      unmatchedPartnerCount: partner != null ? 0 : 1,
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: const [
          Icon(Icons.check_circle_rounded, color: AppColors.green2),
          SizedBox(width: 8),
          Text('등록 완료',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.2)),
        ]),
        content: Text(
          partner != null
              ? '$name 님과 ${partner.name} 님 페어로 등록 완료. ($_event)'
              : '$name 님을 등록했습니다. ($_event)',
          style: const TextStyle(
              fontSize: 15, color: AppColors.text2, height: 1.45),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, result);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryAction,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 14)),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final knownClubs =
        SampleData.clubs.map((c) => c.name).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(context, '직접 입력'),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(children: [
                // ── 종목 + 급수 한 카드 ─────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFB8C9F0), width: 2),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 종목 inline
                      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        const _SectionLabel('종목'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _events
                                .map((e) => _PillChoice(
                                      label: e,
                                      selected: _event == e,
                                      onTap: () => _onEventChanged(e),
                                      compact: true,
                                    ))
                                .toList(),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      // 급수 inline (chips Wrap)
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _SectionLabel('급수', required: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final g in _grades)
                                _PillChoice(
                                  label: g.replaceAll('조', ''),
                                  selected: _grade == g,
                                  onTap: () => setState(() => _grade = g),
                                  onLongPress: () => _showDeleteGradeDialog(g),
                                  compact: true,
                                ),
                              _AddChip(onTap: _showAddGradeDialog),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.only(left: 2),
                        child: Text(
                          '칩 길게 누르면 삭제 · [+] 로 추가',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ── 기본 정보 ─────────────────────────────
                _FormSection(
                  title: '기본 정보',
                  child: Column(children: [
                    _LabeledField(
                      label: '이름',
                      required: true,
                      child: TextField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        style: _inputTextStyle,
                        decoration: _inputDeco('예: 홍길동'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        flex: 3,
                        child: _LabeledField(
                          label: '생년월일',
                          required: true,
                          child: TextField(
                            controller: _birthCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            style: _inputTextStyle,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: _inputDeco('980815'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _LabeledField(
                          label: '성별',
                          required: true,
                          child: Row(children: [
                            Expanded(
                              child: _PillChoice(
                                label: '남',
                                selected: _gender == '남',
                                onTap: () => setState(() {
                                  _gender = '남';
                                  _genderManuallySet = true;
                                }),
                                fullWidth: true,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _PillChoice(
                                label: '여',
                                selected: _gender == '여',
                                onTap: () => setState(() {
                                  _gender = '여';
                                  _genderManuallySet = true;
                                }),
                                fullWidth: true,
                                compact: true,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                    if (_birthCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          _calculatedAge > 0
                              ? '만 $_calculatedAge세'
                              : '생년월일 형식: YYMMDD (6자리)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _calculatedAge > 0
                                  ? AppColors.muted
                                  : AppColors.red,
                              letterSpacing: -0.1),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _LabeledField(
                      label: '소속클럽',
                      required: true,
                      child: Autocomplete<String>(
                        optionsBuilder: (te) {
                          final q = te.text.trim();
                          if (q.isEmpty) return const Iterable<String>.empty();
                          return knownClubs
                              .where((c) => c.contains(q))
                              .take(8);
                        },
                        fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
                          if (ctrl.text != _clubCtrl.text) {
                            ctrl.text = _clubCtrl.text;
                          }
                          ctrl.addListener(() {
                            if (_clubCtrl.text != ctrl.text) {
                              _clubCtrl.text = ctrl.text;
                              setState(() {});
                            }
                          });
                          return TextField(
                            controller: ctrl,
                            focusNode: fn,
                            textInputAction: TextInputAction.next,
                            style: _inputTextStyle,
                            decoration: _inputDeco('예: 한빛클럽'),
                            onChanged: (_) => setState(() {}),
                          );
                        },
                        onSelected: (v) {
                          _clubCtrl.text = v;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LabeledField(
                      label: '연락처',
                      required: false,
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: _inputTextStyle,
                        inputFormatters: [_PhoneFormatter()],
                        decoration: _inputDeco('예: 010-1234-5678'),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                // ── 파트너 (선택) ─────────────────────────
                _FormSection(
                  title: '파트너 (선택)',
                  child: Column(children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: TextField(
                          controller: _pNameCtrl,
                          textInputAction: TextInputAction.next,
                          style: _inputTextStyle,
                          decoration: _inputDeco('이름'),
                          onChanged: (v) {
                            // 파트너 입력 시작하면 본인 클럽 자동 채움 (편의)
                            if (v.isNotEmpty &&
                                _pClubCtrl.text.isEmpty &&
                                _clubCtrl.text.isNotEmpty) {
                              _pClubCtrl.text = _clubCtrl.text;
                            }
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _pBirthCtrl,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          style: _inputTextStyle,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: _inputDeco('생년월일 (980815)'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ]),
                    if (_pBirthCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          _partnerAge > 0
                              ? '파트너 만 $_partnerAge세'
                              : '생년월일 형식: YYMMDD (6자리)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _partnerAge > 0
                                  ? AppColors.muted
                                  : AppColors.red,
                              letterSpacing: -0.1),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _LabeledField(
                      label: '소속클럽',
                      required: true,
                      child: TextField(
                        controller: _pClubCtrl,
                        textInputAction: TextInputAction.next,
                        style: _inputTextStyle,
                        decoration: _inputDeco('예: 한빛클럽'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LabeledField(
                      label: '연락처',
                      required: false,
                      child: TextField(
                        controller: _pPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: _inputTextStyle,
                        inputFormatters: [_PhoneFormatter()],
                        decoration: _inputDeco('예: 010-1234-5678'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        '자동: 성별 $_partnerGender · 급수 ${_grade ?? '본인과 동일'}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                  top: BorderSide(color: AppColors.divider, width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('참가자 등록'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryAction,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _primaryAction.withOpacity(0.35),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// 공통 AppBar — 다른 화면 톤과 통일
// ─────────────────────────────────────────────────────
PreferredSizeWidget _appBar(BuildContext context, String title) => AppBar(
      elevation: 0,
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      centerTitle: false,
      titleSpacing: 0,
      leadingWidth: 40,
      leading: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => Navigator.maybePop(context),
        icon:
            const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.text),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.3)),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: AppColors.divider),
      ),
    );

const _inputTextStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  color: AppColors.text,
  letterSpacing: -0.2,
);

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 16,
          fontWeight: FontWeight.w500),
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primaryAction, width: 1.5),
      ),
    );

class _FormSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _FormSection({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFB8C9F0), width: 2),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: -0.3)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

/// 종목/급수처럼 칩 묶음 옆에 인라인 배치되는 짧은 굵은 라벨.
class _SectionLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _SectionLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(text,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.3)),
      if (required)
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 2),
          child: Text('*',
              style: TextStyle(
                  fontSize: 16,
                  color: AppColors.red,
                  fontWeight: FontWeight.w800)),
        ),
    ]);
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final bool required;
  final Widget child;
  const _LabeledField({
    required this.label,
    required this.required,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text2,
                    letterSpacing: -0.2)),
            if (required)
              const Padding(
                padding: EdgeInsets.only(left: 3),
                child: Text('*',
                    style: TextStyle(
                        fontSize: 16.5,
                        color: AppColors.red,
                        fontWeight: FontWeight.w800)),
              ),
          ]),
          const SizedBox(height: 4),
          child,
        ],
      );
}

class _PillChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;
  final bool fullWidth;
  const _PillChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
    this.fullWidth = false,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 5),
        alignment: fullWidth ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected ? _primaryAction : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? _primaryAction
                : _primaryAction.withOpacity(0.18),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _primaryAction,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

/// 참가자 수정 — 기존 [Player] 의 모든 편집 가능 필드(이름·생년월일·성별·소속클럽·
/// 급수·연락처) 를 폼으로 노출. 저장 시 [SampleData.updatePlayer] 로 SP+Firestore
/// dual-write.
///
/// ManualEntryScreen 과 같은 톤이지만 종목/파트너 섹션은 제거 (편집 대상이 아님).
class EditPlayerScreen extends StatefulWidget {
  final Player player;
  final List<String> initialGrades;
  final GradeMutator onAddGrade;
  final GradeMutator onRemoveGrade;
  const EditPlayerScreen({
    super.key,
    required this.player,
    required this.initialGrades,
    required this.onAddGrade,
    required this.onRemoveGrade,
  });

  @override
  State<EditPlayerScreen> createState() => _EditPlayerScreenState();
}

class _EditPlayerScreenState extends State<EditPlayerScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _clubCtrl;
  late final TextEditingController _birthCtrl;
  late final TextEditingController _phoneCtrl;
  late String _gender;
  late String? _grade;
  late List<String> _grades;

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    _nameCtrl = TextEditingController(text: p.name);
    _clubCtrl = TextEditingController(text: p.clubName);
    _birthCtrl = TextEditingController(text: p.birthDate);
    _phoneCtrl = TextEditingController(text: p.phone);
    _gender = p.gender;
    _grade = p.grade;
    // 기존 선수 급수가 대회 급수 목록에 없으면 함께 보여줘 누락 방지.
    final base = {...widget.initialGrades};
    if (p.grade.isNotEmpty) base.add(p.grade);
    _grades = _sortedGrades(base);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _clubCtrl.dispose();
    _birthCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  int get _calculatedAge =>
      Player.calcAgeFromBirthDate(_birthCtrl.text.trim());

  bool get _canSubmit =>
      _nameCtrl.text.trim().isNotEmpty &&
      _clubCtrl.text.trim().isNotEmpty &&
      _calculatedAge > 0 &&
      _grade != null;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 14)),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showAddGradeDialog() async {
    final ctrl = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('급수 추가',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: _inputTextStyle,
          decoration: _inputDeco('예: E조 또는 마스터조'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryAction,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (added == null || added.isEmpty) return;
    if (_grades.contains(added)) {
      _snack('이미 존재하는 급수입니다.');
      return;
    }
    widget.onAddGrade(added);
    setState(() {
      _grades = _sortedGrades([..._grades, added]);
      _grade = added;
    });
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final clubName = _clubCtrl.text.trim();
    final birthRaw = _birthCtrl.text.trim();
    final normBirth = Player.normalizeBirthDate(birthRaw);
    final age = Player.calcAgeFromBirthDate(birthRaw);
    if (name.isEmpty || clubName.isEmpty || age <= 0 || _grade == null) {
      _snack('이름·소속클럽·생년월일·급수는 필수입니다.');
      return;
    }
    final club = SampleData.clubs
        .where((c) => c.name == clubName)
        .firstOrNull;
    final updated = widget.player.copyWith(
      name: name,
      gender: _gender,
      birthDate: normBirth,
      age: age,
      grade: _grade,
      clubId: club?.id ?? widget.player.clubId,
      clubName: clubName,
      phone: _phoneCtrl.text.trim(),
    );
    await SampleData.updatePlayer(updated);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final knownClubs =
        SampleData.clubs.map((c) => c.name).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(context, '참가자 수정'),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFB8C9F0), width: 2),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _SectionLabel('급수', required: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final g in _grades)
                            _PillChoice(
                              label: g.replaceAll('조', ''),
                              selected: _grade == g,
                              onTap: () => setState(() => _grade = g),
                              compact: true,
                            ),
                          _AddChip(onTap: _showAddGradeDialog),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                _FormSection(
                  title: '기본 정보',
                  child: Column(children: [
                    _LabeledField(
                      label: '이름',
                      required: true,
                      child: TextField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        style: _inputTextStyle,
                        decoration: _inputDeco('예: 홍길동'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        flex: 3,
                        child: _LabeledField(
                          label: '생년월일',
                          required: true,
                          child: TextField(
                            controller: _birthCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            style: _inputTextStyle,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: _inputDeco('980815'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _LabeledField(
                          label: '성별',
                          required: true,
                          child: Row(children: [
                            Expanded(
                              child: _PillChoice(
                                label: '남',
                                selected: _gender == '남',
                                onTap: () => setState(() => _gender = '남'),
                                fullWidth: true,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _PillChoice(
                                label: '여',
                                selected: _gender == '여',
                                onTap: () => setState(() => _gender = '여'),
                                fullWidth: true,
                                compact: true,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                    if (_birthCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          _calculatedAge > 0
                              ? '만 $_calculatedAge세'
                              : '생년월일 형식: YYMMDD (6자리)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _calculatedAge > 0
                                  ? AppColors.muted
                                  : AppColors.red,
                              letterSpacing: -0.1),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _LabeledField(
                      label: '소속클럽',
                      required: true,
                      child: Autocomplete<String>(
                        initialValue: TextEditingValue(text: _clubCtrl.text),
                        optionsBuilder: (te) {
                          final q = te.text.trim();
                          if (q.isEmpty) return const Iterable<String>.empty();
                          return knownClubs
                              .where((c) => c.contains(q))
                              .take(8);
                        },
                        fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
                          if (ctrl.text != _clubCtrl.text &&
                              ctrl.text.isEmpty) {
                            ctrl.text = _clubCtrl.text;
                          }
                          ctrl.addListener(() {
                            if (_clubCtrl.text != ctrl.text) {
                              _clubCtrl.text = ctrl.text;
                              setState(() {});
                            }
                          });
                          return TextField(
                            controller: ctrl,
                            focusNode: fn,
                            textInputAction: TextInputAction.next,
                            style: _inputTextStyle,
                            decoration: _inputDeco('예: 한빛클럽'),
                            onChanged: (_) => setState(() {}),
                          );
                        },
                        onSelected: (v) {
                          _clubCtrl.text = v;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LabeledField(
                      label: '연락처',
                      required: false,
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: _inputTextStyle,
                        inputFormatters: [_PhoneFormatter()],
                        decoration: _inputDeco('예: 010-1234-5678'),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                  top: BorderSide(color: AppColors.divider, width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('수정 저장'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryAction,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _primaryAction.withOpacity(0.35),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 칩 줄 끝에 붙는 '+' 추가 버튼.
class _AddChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddChip({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: _primaryAction.withOpacity(0.35), width: 1.4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.add_rounded, size: 16, color: _primaryAction),
          SizedBox(width: 2),
          Text('추가',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _primaryAction,
                  letterSpacing: -0.2)),
        ]),
      ),
    );
  }
}
