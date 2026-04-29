// lib/screens/finance/widgets/donation_form_sheet.dart
//
// 찬조 수정/삭제 바텀시트.
//
// 기능:
//   - 종류(개인/기타) / 형태(현금/물품) 토글
//   - 후원자명 / 금액 / 후원자 클럽 / 연락처 입력
//   - 물품 설명 (물품 선택 시)
//   - 날짜 선택
//   - 감사 표시 토글
//   - 메모
//   - 우상단 휴지통 → 삭제 (확인 다이얼로그)
//
// 호출 예:
//   final result = await showModalBottomSheet<DonationFormResult>(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (_) => DonationFormSheet(initial: donation),
//   );

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/donation.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';

/// 폼 결과: 신규 등록(`add`) / 수정(`update`) / 삭제(`delete`)
enum DonationFormAction { add, update, delete }

class DonationFormResult {
  final DonationFormAction action;
  final Donation donation;

  const DonationFormResult({required this.action, required this.donation});
}

class DonationFormSheet extends StatefulWidget {
  /// 수정 대상 찬조. null이면 신규 등록 모드.
  final Donation? initial;

  /// 신규 등록 모드일 때 사용할 대회 정보 (initial이 null일 때 필수)
  final String? tournamentId;
  final String? tournamentName;

  const DonationFormSheet({
    super.key,
    this.initial,
    this.tournamentId,
    this.tournamentName,
  }) : assert(
          initial != null || (tournamentId != null && tournamentName != null),
          'initial이 null이면 tournamentId/tournamentName 필수',
        );

  @override
  State<DonationFormSheet> createState() => _DonationFormSheetState();
}

class _DonationFormSheetState extends State<DonationFormSheet> {
  late TextEditingController _donorNameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _clubNameCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _itemDescCtrl;
  late TextEditingController _memoCtrl;

  late DonationType _type;
  late DonationKind _kind;
  late String _date;
  late bool _acknowledged;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    if (d != null) {
      // 수정 모드
      _donorNameCtrl = TextEditingController(text: d.donorName);
      _amountCtrl = TextEditingController(
        text: _formatNumberWithCommas(d.amount.toString()),
      );
      _clubNameCtrl = TextEditingController(text: d.donorClubName ?? '');
      _contactCtrl = TextEditingController(text: d.donorContact);
      _itemDescCtrl = TextEditingController(text: d.itemDescription);
      _memoCtrl = TextEditingController(text: d.memo);
      _type = d.type;
      _kind = d.kind;
      _date = d.date.isEmpty ? todayStr() : d.date;
      _acknowledged = d.acknowledged;
    } else {
      // 신규 등록 모드
      _donorNameCtrl = TextEditingController();
      _amountCtrl = TextEditingController();
      _clubNameCtrl = TextEditingController();
      _contactCtrl = TextEditingController();
      _itemDescCtrl = TextEditingController();
      _memoCtrl = TextEditingController();
      _type = DonationType.individual;
      _kind = DonationKind.cash;
      _date = todayStr();
      _acknowledged = false;
    }
  }

  @override
  void dispose() {
    _donorNameCtrl.dispose();
    _amountCtrl.dispose();
    _clubNameCtrl.dispose();
    _contactCtrl.dispose();
    _itemDescCtrl.dispose();
    _memoCtrl.dispose();
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

  int _parseAmount() {
    final digits = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
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
  Future<void> _pickDate() async {
    final parts = _date.split('-');
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
      helpText: '찬조일 선택',
    );
    if (picked != null) {
      setState(() {
        _date =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  // ── 검증 + 저장 ──────────────────────────
  void _save() {
    final donorName = _donorNameCtrl.text.trim();
    if (donorName.isEmpty) {
      _showSnack('후원자명을 입력해주세요');
      return;
    }
    final amount = _parseAmount();
    if (amount <= 0) {
      _showSnack('금액을 입력해주세요');
      return;
    }

    final clubName =
        _clubNameCtrl.text.trim().isEmpty ? null : _clubNameCtrl.text.trim();
    final contact = _contactCtrl.text.trim();
    final itemDesc = _itemDescCtrl.text.trim();
    final memo = _memoCtrl.text.trim();

    if (widget.initial == null) {
      // 신규 등록 모드
      final newDonation = Donation(
        id: 'don_${DateTime.now().microsecondsSinceEpoch}',
        tournamentId: widget.tournamentId,
        tournamentName: widget.tournamentName,
        type: _type,
        kind: _kind,
        donorName: donorName,
        donorClubName: clubName,
        donorContact: contact,
        amount: amount,
        itemDescription: itemDesc,
        date: _date,
        memo: memo,
        acknowledged: _acknowledged,
      );
      Navigator.of(context).pop(
        DonationFormResult(
          action: DonationFormAction.add,
          donation: newDonation,
        ),
      );
    } else {
      // 수정 모드
      final updated = widget.initial!.copyWith(
        type: _type,
        kind: _kind,
        donorName: donorName,
        donorClubName: clubName,
        donorContact: contact,
        amount: amount,
        itemDescription: itemDesc,
        date: _date,
        memo: memo,
        acknowledged: _acknowledged,
      );
      Navigator.of(context).pop(
        DonationFormResult(
          action: DonationFormAction.update,
          donation: updated,
        ),
      );
    }
  }

  // ── 삭제 확인 ────────────────────────────
  void _delete() {
    final initial = widget.initial;
    if (initial == null) return; // 신규 모드에서는 삭제 불가

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('찬조 삭제'),
        content: Text(
          '${initial.donorName}의 찬조 ${initial.formattedAmount}을(를) '
          '삭제하시겠습니까?\n\n'
          '⚠️ 연결된 거래도 함께 삭제됩니다.',
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
                DonationFormResult(
                  action: DonationFormAction.delete,
                  donation: initial,
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
    final isItem = _kind == DonationKind.item;

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
                            widget.initial == null ? '찬조 추가' : '찬조 수정',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: kInk,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.initial?.tournamentName ??
                                widget.tournamentName ??
                                '',
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
                    // 삭제 버튼은 수정 모드일 때만 표시
                    if (widget.initial != null)
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
                      // 종류 + 형태 (한 줄)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel(label: '종류'),
                                const SizedBox(height: 5),
                                _SegmentedToggle<DonationType>(
                                  options: const [
                                    _SegOption(DonationType.individual, '개인'),
                                    _SegOption(DonationType.corporate, '기타'),
                                  ],
                                  value: _type,
                                  onChanged: (v) => setState(() => _type = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel(label: '형태'),
                                const SizedBox(height: 5),
                                _SegmentedToggle<DonationKind>(
                                  options: const [
                                    _SegOption(DonationKind.cash, '현금'),
                                    _SegOption(DonationKind.item, '물품'),
                                  ],
                                  value: _kind,
                                  onChanged: (v) => setState(() => _kind = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 후원자명
                      const _FieldLabel(label: '후원자명'),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _donorNameCtrl,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: financeInputDeco(
                            _type == DonationType.individual
                                ? '예: 김철수'
                                : '예: ○○스포츠'),
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
                        decoration: financeInputDeco('예: 100,000').copyWith(
                          suffixText: '원',
                          suffixStyle: const TextStyle(
                            fontSize: 14,
                            color: kMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 물품 설명 (물품일 때만 표시)
                      if (isItem) ...[
                        const _FieldLabel(label: '물품 설명'),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _itemDescCtrl,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(fontSize: 14),
                          decoration: financeInputDeco('예: 셔틀콕 30통'),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 후원자 클럽 + 연락처 (한 줄)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel(
                                    label: '후원자 클럽', optional: true),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: _clubNameCtrl,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: financeInputDeco('예: 중앙클럽'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel(label: '연락처', optional: true),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: _contactCtrl,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: financeInputDeco('010-0000-0000'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 날짜
                      const _FieldLabel(label: '찬조일'),
                      const SizedBox(height: 5),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF9CA5B5), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 18, color: kAccent),
                              const SizedBox(width: 10),
                              Text(
                                _date,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: kInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 감사 표시 토글
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _acknowledged
                              ? const Color(0xFFE8F5EE)
                              : const Color(0xFFF6F7FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _acknowledged
                                ? const Color(0xFF9BB5D0)
                                : kCardBorderLight,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _acknowledged
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: _acknowledged ? kIncomeFg : kMuted,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _acknowledged ? '감사 표시 완료' : '감사 표시 미완료',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _acknowledged ? kIncomeFg : kInk,
                                    ),
                                  ),
                                  const Text(
                                    '후원자에게 감사 표시했는지 여부',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: kMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _acknowledged,
                              onChanged: (v) =>
                                  setState(() => _acknowledged = v),
                              activeColor: kIncomeFg,
                            ),
                          ],
                        ),
                      ),
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
                          widget.initial == null ? '등록' : '수정',
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

// ══════════════════════════════════════════════
// 보조 위젯들
// ══════════════════════════════════════════════

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

class _SegOption<T> {
  final T value;
  final String label;
  const _SegOption(this.value, this.label);
}

/// 두 개의 옵션을 토글 형태로 보여주는 위젯 (현금/물품, 개인/기타 등)
class _SegmentedToggle<T> extends StatelessWidget {
  final List<_SegOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  const _SegmentedToggle({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9CA5B5), width: 1.5),
      ),
      child: Row(
        children: options.map((opt) {
          final selected = opt.value == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.value),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: selected ? kBannerNavy : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : kInk,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
