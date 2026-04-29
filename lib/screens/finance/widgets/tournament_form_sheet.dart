// lib/screens/finance/widgets/tournament_form_sheet.dart
//
// 대회 수정/삭제 바텀시트.
//
// 기능:
//   - 대회명 / 대회 종류 / 상태
//   - 시작일 / 종료일 / 지역 / 장소
//   - 총 예산 / 시 보조금 / 시 보조금 메모
//   - 분담금 적용 토글 / 찬조 받음 토글
//   - 우상단 휴지통 → 삭제 (확인 다이얼로그)
//
// 호출 예:
//   final result = await showModalBottomSheet<TournamentFormResult>(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (_) => TournamentFormSheet(initial: tournament),
//   );

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/tournament.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';

/// 폼 결과: 수정(`update`) / 삭제(`delete`)
enum TournamentFormAction { update, delete }

class TournamentFormResult {
  final TournamentFormAction action;
  final Tournament tournament;

  const TournamentFormResult({required this.action, required this.tournament});
}

class TournamentFormSheet extends StatefulWidget {
  /// 수정 대상 대회 (필수 — 현재는 수정/삭제만 지원)
  final Tournament initial;

  const TournamentFormSheet({super.key, required this.initial});

  @override
  State<TournamentFormSheet> createState() => _TournamentFormSheetState();
}

class _TournamentFormSheetState extends State<TournamentFormSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _budgetCtrl;
  late TextEditingController _citySupportCtrl;
  late TextEditingController _citySupportNoteCtrl;

  late TournamentType _type;
  late String _status;
  late String _startDate;
  late String _endDate;
  late bool _hasClubShare;
  late bool _acceptsDonation;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _nameCtrl = TextEditingController(text: t.name);
    _budgetCtrl = TextEditingController(
      text: _formatNumberWithCommas(t.totalBudget.toString()),
    );
    _citySupportCtrl = TextEditingController(
      text: _formatNumberWithCommas(t.citySupportAmount.toString()),
    );
    _citySupportNoteCtrl = TextEditingController(text: t.citySupportNote);
    _type = t.tournamentType;
    _status = t.status;
    _startDate = t.startDate.isEmpty ? todayStr() : t.startDate;
    _endDate = t.endDate.isEmpty ? _startDate : t.endDate;
    _hasClubShare = t.hasClubShare;
    _acceptsDonation = t.acceptsDonation;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    _citySupportCtrl.dispose();
    _citySupportNoteCtrl.dispose();
    super.dispose();
  }

  // ── 헬퍼 ──────────────────────────────────
  String _formatNumberWithCommas(String s) {
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty || digits == '0') return '';
    final n = int.tryParse(digits) ?? 0;
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  int _parseAmount(TextEditingController c) {
    final digits = c.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ── 날짜 선택 ────────────────────────────
  Future<void> _pickDate({required bool isStart}) async {
    final src = isStart ? _startDate : _endDate;
    final parts = src.split('-');
    final initial = parts.length == 3
        ? DateTime(
            int.tryParse(parts[0]) ?? DateTime.now().year,
            int.tryParse(parts[1]) ?? 1,
            int.tryParse(parts[2]) ?? 1,
          )
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: isStart ? '시작일 선택' : '종료일 선택',
    );
    if (picked != null) {
      setState(() {
        final s =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        if (isStart) {
          _startDate = s;
          // 종료일이 시작일보다 빠르면 종료일도 같이 갱신
          if (_endDate.compareTo(_startDate) < 0) {
            _endDate = _startDate;
          }
        } else {
          _endDate = s;
        }
      });
    }
  }

  // ── 검증 + 저장 ──────────────────────────
  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('대회명을 입력해주세요');
      return;
    }
    final budget = _parseAmount(_budgetCtrl);
    final citySupport = _parseAmount(_citySupportCtrl);
    if (citySupport > budget) {
      _showSnack('시 보조금이 총 예산보다 클 수 없습니다');
      return;
    }

    final updated = widget.initial.copyWith(
      name: name,
      tournamentType: _type,
      status: _status,
      startDate: _startDate,
      endDate: _endDate,
      totalBudget: budget,
      citySupportAmount: citySupport,
      citySupportNote: _citySupportNoteCtrl.text.trim(),
      hasClubShare: _hasClubShare,
      acceptsDonation: _acceptsDonation,
    );

    Navigator.of(context).pop(
      TournamentFormResult(
        action: TournamentFormAction.update,
        tournament: updated,
      ),
    );
  }

  // ── 삭제 확인 ────────────────────────────
  void _delete() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('대회 삭제'),
        content: Text(
          '${widget.initial.name}을(를) 삭제하시겠습니까?\n\n'
          '⚠️ 이 대회와 연결된 분담금/찬조/거래 내역은 그대로 유지됩니다. '
          '필요시 별도로 정리해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: kExpenseFg),
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(
                TournamentFormResult(
                  action: TournamentFormAction.delete,
                  tournament: widget.initial,
                ),
              );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E4EC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '대회 수정',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _delete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: kExpenseFg,
                      ),
                      tooltip: '삭제',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: kCardBorderLight),
              // 폼 본문
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 대회명
                      const _FieldLabel(label: '대회명'),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: financeInputDeco('예: 2026 협회장기대회'),
                      ),
                      const SizedBox(height: 14),

                      // 대회 종류 + 상태 (한 줄)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel(label: '대회 종류'),
                                const SizedBox(height: 5),
                                DropdownButtonFormField<TournamentType>(
                                  value: _type,
                                  isExpanded: true,
                                  decoration: financeInputDeco(''),
                                  items: TournamentType.values.map((t) {
                                    return DropdownMenuItem(
                                      value: t,
                                      child: Text(t.label),
                                    );
                                  }).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _type = v);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel(label: '상태'),
                                const SizedBox(height: 5),
                                DropdownButtonFormField<String>(
                                  value: _status,
                                  isExpanded: true,
                                  decoration: financeInputDeco(''),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'upcoming', child: Text('예정')),
                                    DropdownMenuItem(
                                        value: 'ongoing', child: Text('진행중')),
                                    DropdownMenuItem(
                                        value: 'completed', child: Text('완료')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _status = v);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 시작일 + 종료일 (한 줄)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel(label: '시작일'),
                                const SizedBox(height: 5),
                                _DateBox(
                                  date: _startDate,
                                  onTap: () => _pickDate(isStart: true),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel(label: '종료일'),
                                const SizedBox(height: 5),
                                _DateBox(
                                  date: _endDate,
                                  onTap: () => _pickDate(isStart: false),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // ── 재정 섹션 ──
                      _SectionDivider(label: '재정 정보'),
                      const SizedBox(height: 10),

                      // 총 예산
                      const _FieldLabel(label: '총 예산'),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _budgetCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsFormatter(),
                        ],
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: financeInputDeco('예: 6,800,000').copyWith(
                          suffixText: '원',
                          suffixStyle: const TextStyle(
                            fontSize: 14,
                            color: kMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),

                      // 시 보조금
                      const _FieldLabel(label: '시 보조금', optional: true),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _citySupportCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsFormatter(),
                        ],
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: financeInputDeco('예: 1,500,000').copyWith(
                          suffixText: '원',
                          suffixStyle: const TextStyle(
                            fontSize: 14,
                            color: kMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),

                      // 협회 부담 자동 표시 (예산 - 시 보조금)
                      if (_parseAmount(_budgetCtrl) > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8F0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFE8A0A0).withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 14, color: kExpenseFg),
                              const SizedBox(width: 6),
                              const Text(
                                '협회 부담:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kExpenseFg,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                fmtAmt(_parseAmount(_budgetCtrl) -
                                    _parseAmount(_citySupportCtrl)),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: kExpenseFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // 시 보조금 메모
                      const _FieldLabel(label: '시 보조금 메모', optional: true),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _citySupportNoteCtrl,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 14),
                        decoration: financeInputDeco('예: 시민체육진흥기금 보조'),
                      ),
                      const SizedBox(height: 18),

                      // ── 옵션 섹션 ──
                      _SectionDivider(label: '운영 옵션'),
                      const SizedBox(height: 6),

                      // 분담금 토글
                      _ToggleTile(
                        icon: Icons.account_balance_outlined,
                        label: '클럽 분담금 적용',
                        helper: '클럽들이 운영비를 분담',
                        value: _hasClubShare,
                        onChanged: (v) => setState(() => _hasClubShare = v),
                      ),
                      const SizedBox(height: 8),

                      // 찬조 토글
                      _ToggleTile(
                        icon: Icons.volunteer_activism_outlined,
                        label: '찬조 받음',
                        helper: '개인/기타 찬조 모집',
                        value: _acceptsDonation,
                        onChanged: (v) => setState(() => _acceptsDonation = v),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // 하단 버튼
              const Divider(height: 1, color: kCardBorderLight),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: kCardBorderLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBannerNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '수정',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 라벨 ────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final bool optional;

  const _FieldLabel({required this.label, this.optional = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5F6B7A),
            ),
          ),
          if (optional) ...[
            const SizedBox(width: 6),
            const Text(
              '(선택)',
              style: TextStyle(
                fontSize: 11,
                color: kMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      );
}

// ── 섹션 구분선 ─────────────────────────────
class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: kAccent,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(color: kCardBorderLight, thickness: 1),
          ),
        ],
      );
}

// ── 날짜 박스 ───────────────────────────────
class _DateBox extends StatelessWidget {
  final String date;
  final VoidCallback onTap;
  const _DateBox({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kCardBorderLight, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: kAccent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  date.isEmpty ? '선택' : date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: date.isEmpty ? kMuted : kInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── 토글 타일 ───────────────────────────────
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String helper;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFF1F7FE) : const Color(0xFFF6F7FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? const Color(0xFF9BB5D0) : kCardBorderLight,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: value ? kAccent : kMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: value ? kAccent : kInk,
                    ),
                  ),
                  Text(
                    helper,
                    style: const TextStyle(
                      fontSize: 11,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: kAccent,
            ),
          ],
        ),
      );
}
