// lib/screens/finance/widgets/transaction_dialog.dart
//
// 수입/지출 항목 추가/수정 다이얼로그 — 펀클럽(funminton_club_app) 입력 창을 옮겨 왔다.
//
// 기능:
//   - 수입/지출 토글
//   - 영수증 사진: 새로 적을 때 찍으면 업체명·날짜·시각·금액·전화번호를 읽어 지출로 채움.
//     고칠 때는 사진만 붙임. 사진은 이 폰 안(receipts/)에만 보관
//   - 업체명(지출)/항목명(수입) · 금액 · 날짜·시각 · 전화번호 · 메모
//   - 빠뜨린 칸은 그 칸 밑에 빨간 글씨로 알림
//   - 편집 모드일 경우 삭제 버튼 표시
//
// 협회비·분담금·찬조와 이어진 줄은 이 창으로 열지 않는다(FinanceScreen 이 안내 창을 띄움).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/finance_transaction.dart';
import '../../../services/receipt/receipt_scanner.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';

class DlgField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? error;
  final double bottom;
  const DlgField({
    required this.label,
    required this.child,
    this.error,
    this.bottom = 10,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5F6B7A),
                )),
            const SizedBox(height: 5),
            child,
            if (error != null) ...[
              const SizedBox(height: 3),
              Text(error!,
                  style: const TextStyle(fontSize: 12, color: kErrorRed)),
            ],
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
  late final TextEditingController _phoneCtrl;
  late String _date;

  /// 빠뜨린 칸은 그 칸 밑에서 알린다. 스낵바는 키보드에 가린다.
  String? _titleError;
  String? _amountError;

  /// 영수증 글자를 읽는 중인지, 읽은 뒤 알릴 말.
  bool _scanning = false;
  String? _scanNote;

  /// 붙인 영수증 사진(이 폰의 경로). 처음에는 원래 항목의 사진.
  String? _photo;

  /// 저장을 눌렀는지. 안 누르고 닫으면 새로 찍은 사진은 지운다.
  bool _saved = false;

  /// 영수증에서 업체명·전화번호를 못 읽었는지. 그 칸에 '직접 입력하기' 를 띄운다.
  bool _storeUnknown = false;
  bool _phoneUnknown = false;

  bool get _isEdit => widget.initial != null;

  /// 지출은 돈을 낸 곳이라 '업체명', 수입은 '항목명'.
  String get _titleLabel => _isIncome ? '항목명' : '업체명';

  String _withCommas(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _isIncome = init?.isIncome ?? true;
    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _amountCtrl = TextEditingController(
        text: init != null && init.amount > 0 ? _withCommas(init.amount) : '');
    _memoCtrl = TextEditingController(text: init?.memo ?? '');
    _phoneCtrl = TextEditingController(text: init?.phone ?? '');
    // 새로 적는 것에는 시각까지 찍는다. 고치는 것은 원래 도장을 그대로 둔다.
    _date = init?.date ?? nowStr();
    _photo = init?.imagePath;
    // 고치기 시작하면 빨간 안내는 바로 걷는다.
    _titleCtrl.addListener(() {
      if (_titleError != null) setState(() => _titleError = null);
    });
    _amountCtrl.addListener(() {
      if (_amountError != null) setState(() => _amountError = null);
    });
  }

  @override
  void dispose() {
    // 저장하지 않고 닫았으면 이번에 찍은 사진은 남길 까닭이 없다.
    if (!_saved && _photo != widget.initial?.imagePath) {
      ReceiptScanner.deletePhoto(_photo);
    }
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  DateTime _parseDate(String s) {
    try {
      return DateTime.parse(dayOf(s));
    } catch (_) {
      return DateTime.now();
    }
  }

  /// 영수증 사진을 붙이고, 새로 적는 항목이면 업체명·날짜·최종금액을 읽어
  /// 칸을 채운다. 고치는 항목은 사진만 붙인다(적어 둔 값을 덮지 않는다).
  ///
  /// 틀릴 수 있어 **채우기만 한다** — 저장은 사람이 보고 누른다.
  Future<void> _scanReceipt() async {
    if (!ReceiptScanner.supported) {
      widget.onSnack('영수증 사진은 휴대폰 앱에서만 쓸 수 있습니다.');
      return;
    }
    setState(() {
      _scanning = true;
      _scanNote = null;
    });
    try {
      final path = await ReceiptScanner.pickPhoto(context);
      if (!mounted || path == null) return;
      // 이번 창에서 먼저 찍었던 사진은 바꿔 끼우며 지운다(원래 사진은 저장 때).
      if (_photo != widget.initial?.imagePath) {
        ReceiptScanner.deletePhoto(_photo);
      }
      setState(() => _photo = path);
      if (_isEdit) {
        setState(() => _scanNote = '영수증 사진을 붙였습니다. 저장을 눌러 주세요.');
        return;
      }
      final info = await ReceiptScanner.read(path);
      if (!mounted) return;
      setState(() {
        _isIncome = false;
        if (info.store != null) _titleCtrl.text = info.store!;
        _storeUnknown = info.store == null;
        _phoneUnknown = info.phone == null;
        if (info.amount != null) _amountCtrl.text = _withCommas(info.amount!);
        if (info.phone != null) _phoneCtrl.text = info.phone!;
        final d = info.date;
        if (d != null) {
          _date = d.length >= 19 ? d : stampOn(DateTime.parse(d), keep: _date);
        }
        final missed = [
          if (info.store == null) '업체명',
          if (info.date == null) '날짜',
          // 날짜만 읽고 시각을 못 읽으면 시각은 지금 시각이 들어가 있다.
          if (info.date != null && info.date!.length < 19) '시각',
          if (info.amount == null) '금액',
          if (info.phone == null) '전화번호',
        ];
        _scanNote = info.isEmpty
            ? '영수증 글자를 읽지 못했습니다. 밝은 곳에서 다시 찍어 주세요.'
            : missed.isEmpty
                ? '읽은 내용이 맞는지 확인하고 저장해 주세요.'
                : '못 읽은 칸: ${missed.join('·')} — 직접 적어 주세요.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _scanNote = '영수증을 읽는 중 문제가 생겼습니다. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final amount = int.tryParse(
            _amountCtrl.text.replaceAll(',', '').replaceAll('원', '').trim()) ??
        0;

    // 두 칸을 한 번에 짚어 준다.
    final titleError = title.isEmpty ? '$_titleLabel을 적어 주세요.' : null;
    final amountError = amount <= 0 ? '금액을 적어 주세요.' : null;
    if (titleError != null || amountError != null) {
      setState(() {
        _titleError = titleError;
        _amountError = amountError;
      });
      return;
    }

    final init = widget.initial;
    _saved = true;
    // 사진을 빼거나 바꿨으면 원래 사진 파일은 지운다.
    if (init != null && init.imagePath != _photo) {
      ReceiptScanner.deletePhoto(init.imagePath);
    }
    final memo = _memoCtrl.text.trim();
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
      memo: memo.isEmpty ? null : memo,
      phone: _phoneCtrl.text.trim(),
      imagePath: _photo,
      link: init?.link,
      restore: init?.restore,
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
      _saved = true; // 사진은 삭제 처리 쪽에서 지운다
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

  /// 영수증에서 못 읽은 칸이면 안내 글씨를 '직접 입력하기'(주황)으로 바꾼다.
  InputDecoration _unknownHint(InputDecoration base, bool unknown) {
    if (!unknown) return base;
    return base.copyWith(
      hintText: '직접 입력하기',
      hintStyle: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE08A00)),
    );
  }

  /// 붙인 영수증 사진 — 작은 사진을 누르면 크게 보고, '빼기'로 뗀다.
  Widget _photoRow() {
    final path = _photo!;
    return Row(children: [
      GestureDetector(
        onTap: () => ReceiptScanner.view(context, path),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ReceiptScanner.thumb(
            path,
            size: 44,
            fallback: Container(
              width: 44,
              height: 44,
              color: const Color(0xFFF0F0F0),
              child: const Icon(Icons.image_not_supported_outlined,
                  color: Color(0xFF999999)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: TextButton(
          onPressed: () => ReceiptScanner.view(context, path),
          style: TextButton.styleFrom(alignment: Alignment.centerLeft),
          child: const Text('영수증 크게 보기',
              style: TextStyle(fontSize: 13, color: Color(0xFF333333))),
        ),
      ),
      TextButton(
        onPressed: () {
          if (_photo != widget.initial?.imagePath) {
            ReceiptScanner.deletePhoto(_photo);
          }
          setState(() {
            _photo = null;
            _scanNote = null;
          });
        },
        child: const Text('빼기',
            style: TextStyle(fontSize: 13, color: kSummaryExpenseFg)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
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
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _typeBtn('수입', true, kIncomeIcon)),
                const SizedBox(width: 8),
                Expanded(child: _typeBtn('지출', false, kSummaryExpenseFg)),
              ]),
              const SizedBox(height: 6),

              // 영수증 사진 — 새로 적을 때는 찍으면 업체명·날짜·금액까지 채우고,
              // 고칠 때는 사진만 붙인다.
              if (_photo != null) ...[
                _photoRow(),
                const SizedBox(height: 6),
              ],
              OutlinedButton.icon(
                onPressed: _scanning ? null : _scanReceipt,
                icon: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(_scanning
                    ? '영수증 읽는 중…'
                    : _photo != null
                        ? '영수증 다시 찍기'
                        : _isEdit
                            ? '영수증 사진 붙이기'
                            : '영수증 사진으로 채우기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kSummaryExpenseFg,
                  side: const BorderSide(color: Color(0xFFD9B3B3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                ),
              ),
              if (_scanNote != null) ...[
                const SizedBox(height: 6),
                Text(_scanNote!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF666666))),
              ],
              const SizedBox(height: 8),

              DlgField(
                bottom: 6,
                label: _titleLabel,
                error: _titleError,
                child: TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: _unknownHint(
                    financeInputDeco(_isIncome ? '예: 대관료' : '예: 한빛체육관',
                        hasError: _titleError != null),
                    _storeUnknown,
                  ),
                ),
              ),

              // 금액 | 날짜·시각 — 한 줄에 나란히.
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 4,
                  child: DlgField(
                    bottom: 6,
                    label: '금액 (원)',
                    error: _amountError,
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                        ThousandsFormatter(),
                      ],
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: financeInputDeco('입력',
                          hasError: _amountError != null),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: DlgField(
                    bottom: 6,
                    label: '날짜·시각',
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _parseDate(_date),
                          // 영수증은 오래된 것도 있다.
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          // 날짜만 옮겨 적고 시각은 지킨다.
                          setState(() => _date = stampOn(picked, keep: _date));
                        }
                      },
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF9CA5B5), width: 1.5),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(fmtStamp(_date),
                                  style: const TextStyle(
                                      fontSize: 14, color: kInk)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.calendar_today_outlined,
                              size: 15, color: Color(0xFF888888)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),

              DlgField(
                bottom: 6,
                label: '전화번호',
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 14),
                  decoration: _unknownHint(
                      financeInputDeco('예: 02-1234-5678'), _phoneUnknown),
                ),
              ),
              DlgField(
                bottom: 6,
                label: '메모',
                child: TextField(
                  controller: _memoCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: financeInputDeco('예: 자체대회'),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                if (_isEdit && widget.onDelete != null) ...[
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
                    child: Text(_isEdit ? '수정' : '추가',
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
