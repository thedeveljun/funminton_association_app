// lib/screens/finance/widgets/transaction_dialog.dart
//
// 수입/지출 항목 추가/수정 다이얼로그.
//
// 기능:
//   - 수입/지출 토글
//   - 항목명 / 금액 / 날짜 / 메모 입력
//   - 편집 모드일 경우 삭제 버튼 표시
//
// 호출 예:
//   showDialog(
//     context: context,
//     builder: (_) => TransactionDialog(
//       initial: tx,           // null이면 추가 모드, 값 있으면 수정 모드
//       onSnack: _showSnack,
//       onSave: _save,
//       onDelete: _delete,
//     ),
//   );

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/finance_transaction.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';

class DlgField extends StatelessWidget {
  final String label;
  final Widget child;
  const DlgField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5F6B7A),
                )),
            const SizedBox(height: 5),
            child,
          ],
        ),
      );
}

class TransactionDialog extends StatefulWidget {
  final FinanceTransaction? initial;
  final void Function(FinanceTransaction) onSave;
  final VoidCallback? onDelete;
  final void Function(String) onSnack;
  const TransactionDialog({
    this.initial,
    required this.onSave,
    this.onDelete,
    required this.onSnack,
  });

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  late bool _isIncome;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _memoCtrl;
  late String _date;

  bool get _isEdit => widget.initial != null;

  String _formatThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _isIncome = init?.isIncome ?? true;
    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _amountCtrl = TextEditingController(
        text: init != null ? _formatThousands(init.amount) : '');
    _memoCtrl = TextEditingController(text: init?.memo ?? '');
    _date = init?.date ?? todayStr();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  DateTime _parseDate(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final amount = int.tryParse(
            _amountCtrl.text.replaceAll(',', '').replaceAll('원', '').trim()) ??
        0;
    if (title.isEmpty) {
      widget.onSnack('항목명을 입력해주세요.');
      return;
    }
    if (amount <= 0) {
      widget.onSnack('금액을 입력해주세요.');
      return;
    }
    final init = widget.initial;
    final tx = FinanceTransaction(
      id: init?.id ?? 'u_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      amount: amount,
      isIncome: _isIncome,
      category: init?.category ?? '기타',
      date: _date,
      clubId: init?.clubId,
      clubName: init?.clubName,
      tournamentId: init?.tournamentId,
      tournamentName: init?.tournamentName,
      memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
    );
    widget.onSave(tx);
    Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('항목 삭제',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: const Text('이 내역을 삭제하시겠습니까?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF555555))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제',
                style:
                    TextStyle(color: kExpenseFg, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.onDelete?.call();
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _typeBtn(String label, bool incomeKind, Color activeColor) {
    final selected = _isIncome == incomeKind;
    return GestureDetector(
      onTap: () => setState(() => _isIncome = incomeKind),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        decoration: BoxDecoration(
          color: selected ? activeColor : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF888888),
            )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? '항목 수정' : '항목 추가',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  )),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _typeBtn('수입', true, kIncomeIcon)),
                const SizedBox(width: 8),
                Expanded(child: _typeBtn('지출', false, kSummaryExpenseFg)),
              ]),
              const SizedBox(height: 10),
              DlgField(
                label: '항목명',
                child: TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: financeInputDeco('예: 대관료'),
                ),
              ),
              DlgField(
                label: '금액 (원)',
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                    ThousandsFormatter(),
                  ],
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: financeInputDeco('입력'),
                ),
              ),
              DlgField(
                label: '날짜',
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _parseDate(_date),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _date =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                    }
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFB8BEC9)),
                    ),
                    child: Row(children: [
                      Text(_date,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: kInk,
                          )),
                      const Spacer(),
                      const Icon(Icons.calendar_today_outlined,
                          size: 15, color: Color(0xFF888888)),
                    ]),
                  ),
                ),
              ),
              DlgField(
                label: '메모',
                child: TextField(
                  controller: _memoCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: financeInputDeco('예: 자체대회'),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                if (_isEdit) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _confirmDelete,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kExpenseBorder),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('삭제',
                          style: TextStyle(
                              color: kExpenseFg, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFB6BCC8)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('취소',
                        style: TextStyle(color: Color(0xFF555555))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: kAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(_isEdit ? '저장' : '추가',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
}
