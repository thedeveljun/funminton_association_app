import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../models/tournament.dart';
import '../../services/sample_data.dart';
import '../../widgets/common/form_action_bar.dart';

class TournamentFormScreen extends StatefulWidget {
  const TournamentFormScreen({super.key});

  @override
  State<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends State<TournamentFormScreen> {
  // ── 기본 정보 ──────────────────────────
  final _nameCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  TournamentType _tournamentType = TournamentType.general;
  String _startDate = '';
  String _endDate = '';

  // ── 경기 정보 ──────────────────────────
  String _eventType = '혼복';
  String _targetGrade = '전체';
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
  void dispose() {
    _nameCtrl.dispose();
    _regionCtrl.dispose();
    _venueCtrl.dispose();
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

    final t = Tournament(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      region: _regionCtrl.text.trim(),
      tournamentType: _tournamentType,
      startDate: _startDate,
      endDate: _endDate.isEmpty ? _startDate : _endDate,
      venue: _venueCtrl.text.trim(),
      eventType: _eventType,
      targetGrade: _targetGrade,
      entryFee: _parseAmount(_entryFeeCtrl.text),
      status: 'upcoming',
      description: _descCtrl.text.trim(),
      totalBudget: budget,
      citySupportAmount: citySupport,
      citySupportNote: _citySupportNoteCtrl.text.trim(),
      hasClubShare: _hasClubShare,
      acceptsDonation: _acceptsDonation,
    );

    SampleData.tournaments.add(t);
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
          title: const Text('대회 등록',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          centerTitle: false,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── 기본 정보 ─────────────────────
            _section('기본 정보'),
            _field('대회명', _f(_nameCtrl, hint: '예: 2026 협회장기 배드민턴 대회')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('지역', _f(_regionCtrl, hint: '예: 과천시'))),
              const SizedBox(width: 10),
              Expanded(child: _field('대회 분류', _typeDropdown())),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('시작일', _dateField(_startDate, true))),
              const SizedBox(width: 10),
              Expanded(child: _field('종료일', _dateField(_endDate, false))),
            ]),
            const SizedBox(height: 12),
            _field('대회 장소', _f(_venueCtrl, hint: '체육관명 또는 주소')),

            const SizedBox(height: 18),
            // ── 경기 정보 ─────────────────────
            _section('경기 정보'),
            Row(children: [
              Expanded(
                  child: _field(
                      '종별',
                      _dd(_eventType, ['혼복', '남복', '여복', '전체'],
                          (v) => setState(() => _eventType = v)))),
              const SizedBox(width: 10),
              Expanded(
                  child: _field(
                      '대상 급수',
                      _dd(_targetGrade, ['전체', 'A급', 'B급', 'C급', 'D급', '초심'],
                          (v) => setState(() => _targetGrade = v)))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _field('참가비 (원)',
                      _f(_entryFeeCtrl, hint: '30,000', isAmount: true))),
              const SizedBox(width: 10),
              Expanded(
                  child: _field(
                      '신청 마감일',
                      _dateField(_deadlineCtrl.text, null,
                          ctrl: _deadlineCtrl))),
            ]),

            const SizedBox(height: 18),
            // ── 예산 정보 (NEW) ────────────────
            _section('예산 정보', subtitle: '대회 예산과 시·지자체 지원금을 별도 관리합니다'),
            _field(
                '총 예산 (원)', _f(_budgetCtrl, hint: '6,800,000', isAmount: true)),
            const SizedBox(height: 12),
            _field(
                '시 지원금 (원)',
                _f(_citySupportCtrl,
                    hint: '0 (지원금이 없으면 비워두세요)', isAmount: true)),
            const SizedBox(height: 12),
            _field('시 지원 항목·조건',
                _f(_citySupportNoteCtrl, hint: '예: 체육관 대여비 일부 지원')),
            const SizedBox(height: 8),
            _budgetPreview(),

            const SizedBox(height: 18),
            // ── 운영 옵션 (NEW) ────────────────
            _section('운영 옵션'),
            _toggleTile(
              title: '클럽 분담금 적용',
              subtitle: '협회장기대회처럼 클럽이 분담금을 내는 대회',
              value: _hasClubShare,
              onChanged: (v) => setState(() => _hasClubShare = v),
            ),
            const SizedBox(height: 8),
            _toggleTile(
              title: '찬조 받기',
              subtitle: '개인·기업의 현금/물품 찬조를 추적',
              value: _acceptsDonation,
              onChanged: (v) => setState(() => _acceptsDonation = v),
            ),

            const SizedBox(height: 18),
            // ── 안내 사항 ─────────────────────
            _section('안내 사항'),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '대회 관련 안내 사항 입력'),
            ),
            const SizedBox(height: 24),
          ]),
        ),
        bottomNavigationBar: FormActionBar(
          onSubmit: _save,
          submitLabel: '등록',
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(subtitle,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2)),
          const SizedBox(height: 5),
          child,
        ],
      );

  Widget _f(TextEditingController ctrl, {String? hint, bool isAmount = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isAmount ? TextInputType.number : TextInputType.text,
      inputFormatters: isAmount
          ? [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
              _ThousandsFormatter(),
            ]
          : null,
      decoration: InputDecoration(hintText: hint),
    );
  }

  Widget _dd(
          String value, List<String> items, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        decoration: const InputDecoration(),
        items: items
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );

  Widget _typeDropdown() => DropdownButtonFormField<TournamentType>(
        value: _tournamentType,
        decoration: const InputDecoration(),
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
        height: 44,
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
      padding: const EdgeInsets.all(12),
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

  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? AppColors.blue : const Color(0xFFD8DEE8),
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
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppColors.blue,
            onChanged: onChanged,
          ),
        ]),
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
