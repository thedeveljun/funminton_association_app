// lib/screens/finance/widgets/club_share_form_sheet.dart
//
// 분담금 등록/수정 바텀시트.
//
// 기능:
//   - 대회 자동 고정 (호출 시 tournament 전달)
//   - 클럽 드롭다운 (가나다순). 이미 등록된 클럽 선택 시 자동 수정 모드
//   - 금액 입력 (천단위 콤마 자동)
//   - 납부 체크박스 + 납부일 (체크 시 활성)
//   - 메모 입력
//
// 호출 예:
//   final result = await showModalBottomSheet<ClubShareFormResult>(
//     context: context,
//     isScrollControlled: true,
//     builder: (_) => ClubShareFormSheet(
//       tournament: t,
//       existingShares: SampleData.clubShares,
//     ),
//   );
//   if (result != null) {
//     setState(() {
//       // 결과 처리
//     });
//   }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/club.dart';
import '../../../models/club_share.dart';
import '../../../models/tournament.dart';
import '../../../services/sample_data.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';

/// 폼 결과: 신규 등록(`add`) / 수정(`update`) / 삭제(`delete`)
enum ClubShareFormAction { add, update, delete }

class ClubShareFormResult {
  final ClubShareFormAction action;
  final ClubShare share;

  const ClubShareFormResult({required this.action, required this.share});
}

class ClubShareFormSheet extends StatefulWidget {
  /// 어느 대회의 분담금인지 고정
  final Tournament tournament;

  /// 현재까지 등록된 모든 분담금 (중복 검사 + 수정 모드 판단용)
  final List<ClubShare> existingShares;

  /// 처음부터 수정 모드로 띄울 때만 전달 (옵션)
  final ClubShare? editing;

  const ClubShareFormSheet({
    super.key,
    required this.tournament,
    required this.existingShares,
    this.editing,
  });

  @override
  State<ClubShareFormSheet> createState() => _ClubShareFormSheetState();
}

class _ClubShareFormSheetState extends State<ClubShareFormSheet> {
  // 폼 상태
  Club? _selectedClub;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _memoCtrl = TextEditingController();
  bool _paid = false;
  String _paidDate = todayStr();

  /// 현재 (대회+선택된클럽) 으로 이미 등록된 분담금이 있으면 그것을 반환
  ClubShare? get _existing {
    if (_selectedClub == null) return null;
    final clubId = _selectedClub!.id;
    for (final s in widget.existingShares) {
      if (s.tournamentId == widget.tournament.id && s.clubId == clubId) {
        return s;
      }
    }
    return null;
  }

  /// 수정 모드인지 (editing이 있거나, 선택된 클럽으로 이미 등록된 분담금이 있을 때)
  bool get _isEditMode => widget.editing != null || _existing != null;

  @override
  void initState() {
    super.initState();
    // editing 이 전달되면 그 값으로 폼 채우기
    final e = widget.editing;
    if (e != null) {
      _selectedClub = SampleData.clubs.firstWhere(
        (c) => c.id == e.clubId,
        orElse: () => SampleData.clubs.isNotEmpty
            ? SampleData.clubs.first
            : const Club(id: '', name: ''),
      );
      _amountCtrl.text = _formatNumberWithCommas(e.amount.toString());
      _memoCtrl.text = e.memo;
      _paid = e.paid;
      _paidDate = e.paidDate ?? todayStr();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  // ── 헬퍼: 천단위 콤마 ────────────────────
  String _formatNumberWithCommas(String s) {
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final n = int.tryParse(digits) ?? 0;
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  int _parseAmount() {
    final digits = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  // ── 클럽 선택 시 자동 채우기 ─────────────
  void _onClubChanged(Club? c) {
    setState(() {
      _selectedClub = c;
      // 이미 등록된 분담금이 있으면 그 값으로 폼을 자동으로 채움 (수정 모드)
      final ex = _existing;
      if (ex != null) {
        _amountCtrl.text = _formatNumberWithCommas(ex.amount.toString());
        _memoCtrl.text = ex.memo;
        _paid = ex.paid;
        _paidDate = ex.paidDate ?? todayStr();
      }
    });
  }

  // ── 날짜 선택 ────────────────────────────
  Future<void> _pickDate() async {
    final parts = _paidDate.split('-');
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
      helpText: '납부일 선택',
    );
    if (picked != null) {
      setState(() {
        _paidDate =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  // ── 검증 + 저장 ──────────────────────────
  void _save() {
    if (_selectedClub == null) {
      _showSnack('클럽을 선택해주세요');
      return;
    }
    final amount = _parseAmount();
    if (amount <= 0) {
      _showSnack('금액을 입력해주세요');
      return;
    }

    final ex = _existing ?? widget.editing;
    final share = ClubShare(
      id: ex?.id ?? 'cs_${DateTime.now().microsecondsSinceEpoch}',
      tournamentId: widget.tournament.id,
      tournamentName: widget.tournament.name,
      clubId: _selectedClub!.id,
      clubName: _selectedClub!.name,
      amount: amount,
      paid: _paid,
      paidDate: _paid ? _paidDate : null,
      txId: ex?.txId, // 이미 연결된 거래가 있다면 보존
      memo: _memoCtrl.text.trim(),
    );

    Navigator.of(context).pop(
      ClubShareFormResult(
        action:
            ex != null ? ClubShareFormAction.update : ClubShareFormAction.add,
        share: share,
      ),
    );
  }

  // ── 삭제 (수정 모드일 때만) ──────────────
  void _delete() {
    final ex = _existing ?? widget.editing;
    if (ex == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('분담금 삭제'),
        content: Text('${ex.clubName}의 분담금 ${ex.formattedAmount}을 삭제하시겠습니까?'),
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
                ClubShareFormResult(
                  action: ClubShareFormAction.delete,
                  share: ex,
                ),
              );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final clubs = [...SampleData.clubs]
      ..sort((a, b) => a.name.compareTo(b.name));
    final isEdit = _isEditMode;

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? '분담금 수정' : '분담금 추가',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: kInk,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.tournament.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: kMuted,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isEdit)
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 클럽 선택
                      _FieldLabel(
                        label: '클럽',
                        helper: isEdit ? '이미 등록된 분담금이 있어 수정 모드' : null,
                      ),
                      const SizedBox(height: 5),
                      DropdownButtonFormField<Club>(
                        value: _selectedClub,
                        isExpanded: true,
                        decoration: financeInputDeco('클럽 선택'),
                        items: clubs.map((c) {
                          // 이미 등록된 클럽인지 표시
                          final already = widget.existingShares.any((s) =>
                              s.tournamentId == widget.tournament.id &&
                              s.clubId == c.id);
                          return DropdownMenuItem<Club>(
                            value: c,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: already ? kMuted : kInk,
                                    ),
                                  ),
                                ),
                                if (already)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF1F6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '등록됨',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF666666),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _onClubChanged,
                      ),
                      const SizedBox(height: 14),
                      // 금액
                      const _FieldLabel(label: '금액'),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsFormatter(),
                        ],
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: financeInputDeco('예: 350,000').copyWith(
                          suffixText: '원',
                          suffixStyle: const TextStyle(
                            fontSize: 14,
                            color: kMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 납부 여부
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _paid
                              ? const Color(0xFFE8F5EE)
                              : const Color(0xFFF6F7FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _paid
                                ? const Color(0xFF9BB5D0)
                                : kCardBorderLight,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _paid
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: _paid ? kIncomeFg : kMuted,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _paid ? '납부 완료' : '미납',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _paid ? kIncomeFg : kInk,
                                ),
                              ),
                            ),
                            Switch(
                              value: _paid,
                              onChanged: (v) => setState(() => _paid = v),
                              activeColor: kIncomeFg,
                            ),
                          ],
                        ),
                      ),
                      // 납부일 (납부 완료 시에만)
                      if (_paid) ...[
                        const SizedBox(height: 14),
                        const _FieldLabel(label: '납부일'),
                        const SizedBox(height: 5),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F7FA),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: kCardBorderLight, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 18, color: kAccent),
                                const SizedBox(width: 10),
                                Text(
                                  _paidDate,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: kInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      // 메모
                      const _FieldLabel(label: '메모', optional: true),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _memoCtrl,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(fontSize: 14),
                        decoration: financeInputDeco('선택 입력'),
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
                        child: Text(
                          isEdit ? '수정' : '등록',
                          style: const TextStyle(
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

// ── 라벨 위젯 ────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final bool optional;
  final String? helper;

  const _FieldLabel({
    required this.label,
    this.optional = false,
    this.helper,
  });

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
          if (helper != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                helper!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      );
}
