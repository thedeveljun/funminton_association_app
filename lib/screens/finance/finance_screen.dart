// lib/screens/finance/finance_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/club.dart';
import '../../models/finance_transaction.dart';
import '../../models/tournament.dart';
import '../../models/club_share.dart';
import '../../models/donation.dart';
import '../../models/association_fee_payment.dart';
import '../../services/sample_data.dart';
import 'tournament_finance_screen.dart';

const _bgPage = Color(0xFFF6F7FA);
const _ink = Color(0xFF111111);
const _accent = Color(0xFF5B8ABB);
const _muted = Color(0xFF888888);
const _bannerNavy = Color.fromARGB(255, 10, 36, 92);
const _bannerNavyAlt = Color(0xFF0F2B5F);
const _balanceNavy = Color.fromARGB(255, 12, 37, 102);
const _bannerAddBtn = Color(0xFF2A5A8A);
const _cardBorderLight = Color(0xFFE0E4EC);
const _periodActiveBg = Color(0xFFF5F7FA);

const _incomeFg = Color(0xFF2A7A4A);
const _incomeIcon = Color(0xFF4A9E6B);
const _incomeBg = Color(0xFFE8F5EE);
const _incomeBorder = Color(0xFF9BB5D0);

const _expenseFg = Color(0xFFCC2222);
const _expenseIcon = Color(0xFFCC4444);
const _expenseBg = Color(0xFFFFF0F0);
const _expenseBorder = Color(0xFFE8A0A0);
const _expenseCardBg = Color(0xFFFFF8F8);

const _summaryIncomeFg = Color(0xFF217D46);
const _summaryIncomeBg = Color(0xFFEAF5EE);
const _summaryExpenseFg = Color(0xFFB05B5B);
const _summaryExpenseBg = Color(0xFFFFF0F0);
const _monthlyTitle = Color(0xFF222222);
const _monthlyBalance = Color(0xFF1A3A5C);

const _statusPaidColor = Color(0xFF4A9E6B);
const _statusUnpaidColor = Color(0xFFAAAAAA);
const _statusAllColor = Color(0xFF9DC3E6);
const _amountYellow = Color(0xFFFFC300);

String _fmtAmt(int n) {
  final s = n.abs().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return n < 0 ? '-${s}원' : '${s}원';
}

String _toKoreanFull(int amount) {
  if (amount == 0) return '영원';
  final units = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
  final pos = ['', '십', '백', '천'];
  final bigPos = ['', '만', '억', '조'];
  String result = '';
  int bigIdx = 0;
  int n = amount.abs();
  while (n > 0) {
    final chunk = n % 10000;
    if (chunk != 0) {
      String chunkStr = '';
      int c = chunk;
      for (int i = 0; c > 0; i++) {
        final digit = c % 10;
        if (digit != 0) {
          final d = (digit == 1 && i > 0) ? '' : units[digit];
          chunkStr = '$d${pos[i]}$chunkStr';
        }
        c ~/= 10;
      }
      result = '$chunkStr${bigPos[bigIdx]}$result';
    }
    bigIdx++;
    n ~/= 10000;
  }
  if (amount < 0) result = '마이너스$result';
  return '${result}원';
}

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  String _summaryPeriod = '전체';
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  late List<FinanceTransaction> _transactions;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, 1, 1);
    _rangeEnd = now;
    _transactions = List<FinanceTransaction>.from(SampleData.transactions);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showAddDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransactionDialog(
        onSnack: _snack,
        onSave: (tx) => setState(() => _transactions.add(tx)),
      ),
    );
  }

  Future<void> _showEditDialog(FinanceTransaction tx) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransactionDialog(
        initial: tx,
        onSnack: _snack,
        onSave: (updated) => setState(() {
          final idx = _transactions.indexWhere((t) => t.id == tx.id);
          if (idx >= 0) _transactions[idx] = updated;
        }),
        onDelete: () =>
            setState(() => _transactions.removeWhere((t) => t.id == tx.id)),
      ),
    );
  }

  Future<void> _showFeePaymentForm(Club club) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FeePaymentFormDialog(
        club: club,
        onSnack: _snack,
        onSave: (payment, transaction) {
          setState(() {
            SampleData.feePayments.add(payment);
            _transactions.add(transaction);
          });
          _snack('납부 내역이 추가되었습니다.');
        },
      ),
    );
    // 폼 닫힌 뒤 시트를 다시 열어서 새 납부 확인
    if (mounted) {
      await _showFeeDialog(club);
    }
  }

  Future<void> _showFeeDialog(Club club) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FeePaymentSheet(
        club: club,
        onAdd: () async {
          Navigator.pop(context); // 시트 먼저 닫기
          await _showFeePaymentForm(club);
        },
        onDelete: (payment) {
          if (payment.txId != null) {
            _transactions.removeWhere((t) => t.id == payment.txId);
          }
          SampleData.feePayments.removeWhere((p) => p.id == payment.id);
          setState(() {});
        },
        onChanged: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bgPage,
        appBar: AppBar(
          backgroundColor: _bgPage,
          surfaceTintColor: _bgPage,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: -4,
          leadingWidth: 34,
          leading: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _ink),
          ),
          title: const Text(
            '재정관리',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded, size: 22, color: _accent),
            ),
          ],
          bottom: TabBar(
            controller: _tc,
            isScrollable: false,
            labelStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            labelColor: _accent,
            unselectedLabelColor: const Color(0xFF888888),
            indicatorColor: _accent,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: '협회비'),
              Tab(text: '수입/지출'),
              Tab(text: '대회재정'),
              Tab(text: '요약'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tc,
          children: [
            _FeeTab(onRowTap: _showFeeDialog),
            _IncomeExpenseTab(
              transactions: _transactions,
              onAddTap: _showAddDialog,
              onItemTap: _showEditDialog,
            ),
            _TournamentFinanceTab(transactions: _transactions),
            _SummaryTab(
              transactions: _transactions,
              period: _summaryPeriod,
              rangeStart: _rangeStart,
              rangeEnd: _rangeEnd,
              onPeriodChanged: (p, s, e) => setState(() {
                _summaryPeriod = p;
                if (s != null) _rangeStart = s;
                if (e != null) _rangeEnd = e;
              }),
            ),
          ],
        ),
      );
}

// ══════════════════════════════════════════════
// 탭1: 협회비 납부
// ══════════════════════════════════════════════
class _FeeTab extends StatelessWidget {
  final void Function(Club) onRowTap;
  const _FeeTab({required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    final clubs = SampleData.clubs;
    final payments = SampleData.feePayments;

    final summaries = {
      for (final c in clubs) c.id: ClubFeeSummary.from(c.id, c.name, payments),
    };

    int paid = 0;
    int paidTotal = 0;
    for (final c in clubs) {
      final s = summaries[c.id]!;
      if (s.hasRegularPaid) paid++;
      paidTotal += s.totalPaid;
    }
    final unpaid = clubs.length - paid;
    final unpaidEstimate = unpaid * 300000;

    return Column(children: [
      Container(
        color: _bannerNavy,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _StatusChip(label: '납부', count: paid, color: _statusPaidColor),
              const SizedBox(width: 6),
              _StatusChip(
                label: '미납',
                count: unpaid,
                color: _statusUnpaidColor,
                bgColor: const Color(0x33AAAAAA),
              ),
              const SizedBox(width: 6),
              _StatusChip(
                  label: '전체', count: clubs.length, color: _statusAllColor),
            ]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: _AmountSummaryBlock(
                      label: '납부총액', amount: paidTotal, color: _amountYellow)),
              const SizedBox(width: 16),
              Expanded(
                  child: _AmountSummaryBlock(
                      label: '미납 추정액',
                      amount: unpaidEstimate,
                      color: const Color.fromARGB(255, 247, 248, 248))),
            ]),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          itemCount: clubs.length,
          itemBuilder: (_, i) {
            final c = clubs[i];
            final s = summaries[c.id]!;
            return _FeeClubRow(
              club: c,
              summary: s,
              onTap: () => onRowTap(c),
            );
          },
        ),
      ),
    ]);
  }
}

class _FeeClubRow extends StatelessWidget {
  final Club club;
  final ClubFeeSummary summary;
  final VoidCallback onTap;

  const _FeeClubRow({
    required this.club,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPaid = summary.hasRegularPaid;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasPaid ? Colors.white : const Color(0xFFFFFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  hasPaid ? const Color(0xFFD5DAE1) : const Color(0xFFE8A0A0),
              width: 1.2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:
                  hasPaid ? const Color(0xFFE8F5EE) : const Color(0xFFFFEBEB),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              hasPaid ? '납부' : '미납',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: hasPaid ? _incomeIcon : _expenseIcon,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          letterSpacing: -0.3,
                        )),
                  ),
                  if (summary.additionalCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '+${summary.additionalCount}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  _subtitleText(),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
          Text(
            hasPaid ? _fmtAmt(summary.totalPaid) : '-',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: hasPaid ? _incomeFg : const Color(0xFFAAAAAA),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: Color(0xFFAAAAAA)),
        ]),
      ),
    );
  }

  String _subtitleText() {
    final parts = <String>[];
    if (club.region.isNotEmpty) {
      parts.add(club.region);
    } else if (club.memberCount > 0) {
      parts.add('${club.memberCount}명');
    }
    if (summary.paymentCount > 0) {
      parts.add('${summary.paymentCount}건 납부');
    }
    if (summary.lastPaidDate != null) {
      parts.add(summary.lastPaidDate!);
    }
    return parts.join(' · ');
  }
}

// ══════════════════════════════════════════════
// 협회비 납부 추가 폼
// ══════════════════════════════════════════════
class _FeePaymentFormDialog extends StatefulWidget {
  final Club club;
  final void Function(AssociationFeePayment, FinanceTransaction) onSave;
  final void Function(String) onSnack;

  const _FeePaymentFormDialog({
    required this.club,
    required this.onSave,
    required this.onSnack,
  });

  @override
  State<_FeePaymentFormDialog> createState() => _FeePaymentFormDialogState();
}

class _FeePaymentFormDialogState extends State<_FeePaymentFormDialog> {
  // 협회 정책 (추후 AppConfig 화면에서 변경 가능)
  static const int _regularDefault = 300000;
  static const int _newMemberPerHead = 15000;

  FeeReason _reason = FeeReason.regular;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _memberCtrl;
  late final TextEditingController _memoCtrl;
  late String _date;

  @override
  void initState() {
    super.initState();
    _amountCtrl =
        TextEditingController(text: _formatThousands(_regularDefault));
    _memberCtrl = TextEditingController();
    _memoCtrl = TextEditingController();
    _date = _todayStr();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memberCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  String _formatThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  DateTime _parseDate(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  void _onReasonChanged(FeeReason r) {
    setState(() {
      _reason = r;
      // 사유에 따라 금액 기본값 조정
      if (r == FeeReason.regular) {
        _amountCtrl.text = _formatThousands(_regularDefault);
        _memberCtrl.clear();
      } else if (r == FeeReason.newMember) {
        _memberCtrl.clear();
        _amountCtrl.clear();
      } else {
        _memberCtrl.clear();
        _amountCtrl.clear();
      }
    });
  }

  void _onMemberChanged(String v) {
    if (_reason != FeeReason.newMember) return;
    final n = int.tryParse(v.trim());
    if (n != null && n > 0) {
      _amountCtrl.text = _formatThousands(n * _newMemberPerHead);
    } else {
      _amountCtrl.clear();
    }
  }

  void _save() {
    final rawAmount = int.tryParse(
            _amountCtrl.text.replaceAll(',', '').replaceAll('원', '').trim()) ??
        0;
    if (rawAmount <= 0) {
      widget.onSnack('금액을 입력해주세요.');
      return;
    }

    int memberDelta = 0;
    if (_reason == FeeReason.newMember) {
      final m = int.tryParse(_memberCtrl.text.trim()) ?? 0;
      if (m <= 0) {
        widget.onSnack('회원 수를 입력해주세요.');
        return;
      }
      memberDelta = m;
    }

    // 환불은 음수로 저장
    final signedAmount = _reason == FeeReason.refund ? -rawAmount : rawAmount;
    final memo = _memoCtrl.text.trim().isEmpty
        ? _defaultMemo(memberDelta)
        : _memoCtrl.text.trim();

    final ts = DateTime.now().microsecondsSinceEpoch;
    final paymentId = 'fp_$ts';
    final txId = 'tx_fp_$ts';

    final payment = AssociationFeePayment(
      id: paymentId,
      clubId: widget.club.id,
      clubName: widget.club.name,
      amount: signedAmount,
      reason: _reason,
      memberDelta: memberDelta == 0 ? null : memberDelta,
      date: _date,
      txId: txId,
      memo: memo,
    );

    final tx = FinanceTransaction(
      id: txId,
      title: '${widget.club.name} 협회비 (${_reason.label})',
      amount: rawAmount,
      isIncome: _reason != FeeReason.refund,
      category: '협회비',
      date: _date,
      clubId: widget.club.id,
      clubName: widget.club.name,
      memo: memo,
    );

    widget.onSave(payment, tx);
    Navigator.pop(context);
  }

  String _defaultMemo(int delta) {
    switch (_reason) {
      case FeeReason.regular:
        return '${DateTime.now().year}년 정기 협회비';
      case FeeReason.newMember:
        return '신규 회원 $delta명 가입';
      case FeeReason.correction:
        return '협회비 정정';
      case FeeReason.refund:
        return '협회비 환불';
    }
  }

  Widget _reasonChip(FeeReason r) {
    final selected = _reason == r;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onReasonChanged(r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: selected ? Color(r.bgColor) : const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? Color(r.fgColor) : const Color(0xFFE0E4EC),
              width: selected ? 1.4 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            r.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Color(r.fgColor) : const Color(0xFF888888),
              letterSpacing: -0.2,
            ),
          ),
        ),
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
              const Text('납부 추가',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  )),
              const SizedBox(height: 4),
              Text(widget.club.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  )),
              const SizedBox(height: 14),
              _DlgField(
                label: '사유',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Row(
                    children: [
                      _reasonChip(FeeReason.regular),
                      _reasonChip(FeeReason.newMember),
                      _reasonChip(FeeReason.correction),
                      _reasonChip(FeeReason.refund),
                    ],
                  ),
                ),
              ),
              if (_reason == FeeReason.newMember)
                _DlgField(
                  label: '신규 회원 수',
                  child: TextField(
                    controller: _memberCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    ],
                    onChanged: _onMemberChanged,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: _financeInputDeco(
                        '예: 10  (1인당 ${_formatThousands(_newMemberPerHead)}원)'),
                  ),
                ),
              _DlgField(
                label: _reason == FeeReason.newMember
                    ? '금액 (자동 계산, 직접 수정 가능)'
                    : '금액 (원)',
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                    _ThousandsFormatter(),
                  ],
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  decoration: _financeInputDeco('예: 300,000'),
                ),
              ),
              _DlgField(
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
                            color: _ink,
                          )),
                      const Spacer(),
                      const Icon(Icons.calendar_today_outlined,
                          size: 15, color: Color(0xFF888888)),
                    ]),
                  ),
                ),
              ),
              _DlgField(
                label: '메모 (선택)',
                child: TextField(
                  controller: _memoCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _financeInputDeco('비워두면 자동 메모 입력'),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
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
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('저장',
                        style: TextStyle(
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

// ══════════════════════════════════════════════
// 탭2: 수입/지출
// ══════════════════════════════════════════════
class _IncomeExpenseTab extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final VoidCallback onAddTap;
  final void Function(FinanceTransaction) onItemTap;
  const _IncomeExpenseTab({
    required this.transactions,
    required this.onAddTap,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<FinanceTransaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    final txIncome =
        transactions.where((t) => t.isIncome).fold(0, (s, t) => s + t.amount);
    final txExpense =
        transactions.where((t) => !t.isIncome).fold(0, (s, t) => s + t.amount);

    return Column(children: [
      Container(
        color: _bannerNavyAlt,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: Stack(children: [
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onAddTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _bannerAddBtn,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ),
          Row(children: [
            Expanded(child: _BannerAmountBlock(label: '수입', amount: txIncome)),
            const SizedBox(width: 12),
            Expanded(child: _BannerAmountBlock(label: '지출', amount: txExpense)),
            const SizedBox(width: 40),
          ]),
        ]),
      ),
      Expanded(
        child: sorted.isEmpty
            ? const Center(
                child: Text('내역이 없습니다',
                    style: TextStyle(color: Color(0xFFAAAAAA))))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                itemCount: sorted.length,
                itemBuilder: (_, i) => _TransactionRow(
                  tx: sorted[i],
                  onTap: () => onItemTap(sorted[i]),
                ),
              ),
      ),
    ]);
  }
}

class _BannerAmountBlock extends StatelessWidget {
  final String label;
  final int amount;
  const _BannerAmountBlock({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.75),
                letterSpacing: -0.2,
              )),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_fmtAmt(amount),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                )),
          ),
        ],
      );
}

class _TransactionRow extends StatelessWidget {
  final FinanceTransaction tx;
  final VoidCallback? onTap;
  const _TransactionRow({required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.isIncome;
    final cardBg = isIncome ? Colors.white : _expenseCardBg;
    final cardBorder = isIncome ? _incomeBorder : _expenseBorder;
    final iconBg = isIncome ? _incomeBg : _expenseBg;
    final iconColor = isIncome ? _incomeIcon : _expenseIcon;
    final amountColor = isIncome ? _incomeFg : _expenseFg;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder, width: 1.4),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(tx.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                            letterSpacing: -0.3,
                          )),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isIncome ? '+' : '-'}${_fmtAmt(tx.amount).replaceAll('-', '')}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Text(tx.date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                        letterSpacing: -0.2,
                      )),
                  if (tx.clubName != null) ...[
                    const Text(' · ',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF666666))),
                    Text(tx.clubName!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF666666))),
                  ],
                  if (tx.tournamentName != null) ...[
                    const Text(' · ',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF666666))),
                    Flexible(
                      child: Text(tx.tournamentName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF666666))),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 탭3: 대회재정
// ══════════════════════════════════════════════
class _TournamentFinanceTab extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  const _TournamentFinanceTab({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final tournaments = SampleData.tournaments;

    int totalBudget = 0;
    int totalCitySupport = 0;
    for (final t in tournaments) {
      totalBudget += t.totalBudget;
      totalCitySupport += t.citySupportAmount;
    }

    return Column(children: [
      Container(
        color: _bannerNavy,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _AmountSummaryBlock(
                    label: '예산 총액', amount: totalBudget, color: _amountYellow)),
            const SizedBox(width: 12),
            Expanded(
                child: _AmountSummaryBlock(
                    label: '시 지원 합계',
                    amount: totalCitySupport,
                    color: const Color(0xFFB6D7FF))),
            const SizedBox(width: 12),
            Expanded(
                child: _AmountSummaryBlock(
                    label: '협회 부담',
                    amount: totalBudget - totalCitySupport,
                    color: const Color(0xFFFFD0D0))),
          ],
        ),
      ),
      Expanded(
        child: tournaments.isEmpty
            ? const Center(
                child: Text('등록된 대회가 없습니다',
                    style: TextStyle(color: Color(0xFFAAAAAA))))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                itemCount: tournaments.length,
                itemBuilder: (_, i) => _TournamentFinanceCard(
                  tournament: tournaments[i],
                  transactions: transactions,
                  shares: SampleData.clubShares,
                  donations: SampleData.donations,
                ),
              ),
      ),
    ]);
  }
}

class _TournamentFinanceCard extends StatelessWidget {
  final Tournament tournament;
  final List<FinanceTransaction> transactions;
  final List<ClubShare> shares;
  final List<Donation> donations;

  const _TournamentFinanceCard({
    required this.tournament,
    required this.transactions,
    required this.shares,
    required this.donations,
  });

  Color get _typeColor {
    switch (tournament.tournamentType) {
      case TournamentType.associationCup:
        return const Color(0xFF2563EB);
      case TournamentType.cityCup:
        return const Color(0xFF22A06B);
      case TournamentType.mediaCup:
        return const Color(0xFF7C3AED);
      case TournamentType.general:
        return const Color(0xFF737C8B);
    }
  }

  Color get _statusColor {
    switch (tournament.status) {
      case 'ongoing':
        return _incomeIcon;
      case 'completed':
        return const Color(0xFF888888);
      default:
        return _accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shareSummary =
        ClubShareSummary.from(tournament.id, tournament.name, shares);
    final donationSummary = DonationSummary.from(donations,
        tournamentId: tournament.id, tournamentName: tournament.name);

    final relatedTx =
        transactions.where((t) => t.tournamentId == tournament.id).toList();
    final actualIncome =
        relatedTx.where((t) => t.isIncome).fold<int>(0, (s, t) => s + t.amount);
    final actualExpense = relatedTx
        .where((t) => !t.isIncome)
        .fold<int>(0, (s, t) => s + t.amount);

    return GestureDetector(
      onTap: () => _showQuickDetail(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorderLight, width: 1.2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  tournament.tournamentType.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _typeColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  tournament.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _statusColor,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFFAAAAAA)),
            ]),
            const SizedBox(height: 8),
            Text(
              tournament.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${tournament.startDate}${tournament.endDate.isNotEmpty && tournament.endDate != tournament.startDate ? ' ~ ${tournament.endDate}' : ''}'
              '${tournament.region.isNotEmpty ? ' · ${tournament.region}' : ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
            if (tournament.totalBudget > 0) ...[
              const SizedBox(height: 12),
              _budgetRow(tournament),
            ],
            if (tournament.hasClubShare && shareSummary.totalCount > 0) ...[
              const SizedBox(height: 10),
              _shareRow(shareSummary),
            ],
            if (tournament.acceptsDonation &&
                donationSummary.grandTotal > 0) ...[
              const SizedBox(height: 8),
              _donationRow(donationSummary),
            ],
            if (relatedTx.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: _cardBorderLight),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _smallStat('실제 수입', actualIncome, _incomeFg),
                ),
                Expanded(
                  child: _smallStat('실제 지출', actualExpense, _expenseFg),
                ),
                Expanded(
                  child: _smallStat(
                      '잔액', actualIncome - actualExpense, _monthlyBalance),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _budgetRow(Tournament t) {
    final ratio = t.cityFundingRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('예산',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _muted)),
          const Spacer(),
          Text(t.formattedBudget,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: const Color(0xFFFFD0D0),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF6FA8E6)),
          ),
        ),
        const SizedBox(height: 3),
        Row(children: [
          if (t.citySupportAmount > 0) ...[
            const _Dot(color: Color(0xFF6FA8E6)),
            const SizedBox(width: 4),
            Text('시 ${t.formattedCitySupport}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
            const SizedBox(width: 8),
          ],
          const _Dot(color: Color(0xFFFFD0D0)),
          const SizedBox(width: 4),
          Text('협회 ${t.formattedAssociationBurden}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
        ]),
      ],
    );
  }

  Widget _shareRow(ClubShareSummary s) {
    final pct = (s.collectionRatio * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.account_balance_outlined, size: 14, color: _accent),
        const SizedBox(width: 6),
        const Text('분담금',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _accent)),
        const SizedBox(width: 8),
        Text('${s.paidCount}/${s.totalCount} 클럽 · $pct%',
            style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
        const Spacer(),
        Text('${_fmtAmt(s.collectedAmount)} / ${_fmtAmt(s.totalAmount)}',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: _ink)),
      ]),
    );
  }

  Widget _donationRow(DonationSummary d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.volunteer_activism_outlined,
            size: 14, color: Color(0xFFB7791F)),
        const SizedBox(width: 6),
        const Text('찬조',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB7791F))),
        const SizedBox(width: 8),
        Text('개인 ${d.individualCount} · 기업 ${d.corporateCount}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
        const Spacer(),
        Text(_fmtAmt(d.grandTotal),
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: _ink)),
      ]),
    );
  }

  Widget _smallStat(String label, int amount, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: _muted)),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_fmtAmt(amount),
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      );

  void _showQuickDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentFinanceScreen(tournament: tournament),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
      );
}

// ══════════════════════════════════════════════
// 탭4: 요약
// ══════════════════════════════════════════════
class _SummaryTab extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final String period;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final void Function(String, DateTime?, DateTime?) onPeriodChanged;

  const _SummaryTab({
    required this.transactions,
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onPeriodChanged,
  });

  List<FinanceTransaction> get _filtered {
    if (period == '전체') return transactions;
    return transactions.where((t) {
      try {
        final d = DateTime.parse(t.date);
        return !d.isBefore(rangeStart) && !d.isAfter(rangeEnd);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final income =
        list.where((t) => t.isIncome).fold(0, (s, t) => s + t.amount);
    final expense =
        list.where((t) => !t.isIncome).fold(0, (s, t) => s + t.amount);
    final balance = income - expense;

    final Map<String, int> mIncome = {};
    final Map<String, int> mExpense = {};
    for (final t in list) {
      if (t.date.length < 7) continue;
      final ym = t.date.substring(0, 7);
      if (t.isIncome) {
        mIncome[ym] = (mIncome[ym] ?? 0) + t.amount;
      } else {
        mExpense[ym] = (mExpense[ym] ?? 0) + t.amount;
      }
    }
    final months = {...mIncome.keys, ...mExpense.keys}.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _PeriodSelector(
          current: period,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          onChanged: onPeriodChanged,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: _balanceNavy,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            const Text('현재 잔액',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: -0.2,
                )),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_fmtAmt(balance),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.8,
                    height: 1.1,
                  )),
            ),
            const SizedBox(height: 2),
            Text(_toKoreanFull(balance),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  letterSpacing: -0.2,
                )),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _SummaryAmtCard(
                  label: '총 수입',
                  amount: income,
                  color: _summaryIncomeFg,
                  bgColor: _summaryIncomeBg,
                  icon: Icons.arrow_upward_rounded)),
          const SizedBox(width: 8),
          Expanded(
              child: _SummaryAmtCard(
                  label: '총 지출',
                  amount: expense,
                  color: _summaryExpenseFg,
                  bgColor: _summaryExpenseBg,
                  icon: Icons.arrow_downward_rounded)),
        ]),
        const SizedBox(height: 16),
        const Text('월별 수입/지출',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _monthlyTitle,
              letterSpacing: -0.3,
            )),
        const SizedBox(height: 8),
        if (months.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorderLight),
            ),
            child: const Text('선택한 기간의 내역이 없습니다.',
                style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
          )
        else
          ...months.map((ym) {
            final inc = mIncome[ym] ?? 0;
            final exp = mExpense[ym] ?? 0;
            final bal = inc - exp;
            final parts = ym.split('-');
            return _MonthlyRow(
              label: '${parts[0]}년 ${int.parse(parts[1])}월',
              income: inc,
              expense: exp,
              balance: bal,
            );
          }),
      ],
    );
  }
}

class _SummaryAmtCard extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final Color bgColor;
  final IconData icon;
  const _SummaryAmtCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.2,
                  )),
            ]),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(_fmtAmt(amount),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5,
                  )),
            ),
          ],
        ),
      );
}

class _MonthlyRow extends StatelessWidget {
  final String label;
  final int income, expense, balance;
  const _MonthlyRow({
    required this.label,
    required this.income,
    required this.expense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorderLight),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _monthlyTitle,
                  letterSpacing: -0.3,
                )),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _MonthItem(
                      label: '수입', amount: income, color: _incomeIcon)),
              Expanded(
                  child: _MonthItem(
                      label: '지출', amount: expense, color: _summaryExpenseFg)),
              Expanded(
                  child: _MonthItem(
                      label: '잔액',
                      amount: balance,
                      color:
                          balance >= 0 ? _monthlyBalance : _summaryExpenseFg)),
            ]),
          ],
        ),
      );
}

class _MonthItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  const _MonthItem(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color.withOpacity(0.7),
                letterSpacing: -0.2,
              )),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_fmtAmt(amount),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                )),
          ),
        ],
      );
}

class _PeriodSelector extends StatelessWidget {
  final String current;
  final DateTime rangeStart, rangeEnd;
  final void Function(String, DateTime?, DateTime?) onChanged;
  const _PeriodSelector({
    required this.current,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rangeLabel =
        '${rangeStart.year}.${rangeStart.month.toString().padLeft(2, '0')} ~ '
        '${rangeEnd.year}.${rangeEnd.month.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('기간 선택',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
                letterSpacing: -0.2,
              )),
          const SizedBox(height: 10),
          Row(children: [
            for (final p in ['전체', '이번달', '직접선택']) ...[
              GestureDetector(
                onTap: () async {
                  if (p == '직접선택') {
                    final range = await showDateRangePicker(
                      context: context,
                      initialDateRange:
                          DateTimeRange(start: rangeStart, end: rangeEnd),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (range != null) onChanged(p, range.start, range.end);
                  } else if (p == '이번달') {
                    final now = DateTime.now();
                    onChanged(p, DateTime(now.year, now.month, 1),
                        DateTime(now.year, now.month + 1, 0));
                  } else {
                    onChanged(p, null, null);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: current == p ? _accent : _periodActiveBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: current == p ? _accent : const Color(0xFFD5DAE1),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(p,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: current == p
                            ? Colors.white
                            : const Color(0xFF555555),
                      )),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ]),
          if (current == '직접선택') ...[
            const SizedBox(height: 8),
            Text(rangeLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: _accent,
                  fontWeight: FontWeight.w600,
                )),
          ],
          if (current == '이번달') ...[
            const SizedBox(height: 8),
            Text('${rangeStart.year}년 ${rangeStart.month}월',
                style: const TextStyle(
                  fontSize: 13,
                  color: _accent,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ],
      ),
    );
  }
}

// ── 회비납부 탭 보조 위젯 ────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color? bgColor;
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor ?? color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.2,
              )),
          const SizedBox(width: 5),
          Text('$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.2,
              )),
        ]),
      );
}

class _AmountSummaryBlock extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  const _AmountSummaryBlock({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.78),
                letterSpacing: -0.2,
              )),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_fmtAmt(amount),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.4,
                )),
          ),
        ],
      );
}

// ══════════════════════════════════════════════
// 항목 추가 다이얼로그
// ══════════════════════════════════════════════
String _todayStr() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

InputDecoration _financeInputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF5F81A7), width: 1.5),
      ),
    );

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

class _DlgField extends StatelessWidget {
  final String label;
  final Widget child;
  const _DlgField({required this.label, required this.child});

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

class _TransactionDialog extends StatefulWidget {
  final FinanceTransaction? initial;
  final void Function(FinanceTransaction) onSave;
  final VoidCallback? onDelete;
  final void Function(String) onSnack;
  const _TransactionDialog({
    this.initial,
    required this.onSave,
    this.onDelete,
    required this.onSnack,
  });

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
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
    _date = init?.date ?? _todayStr();
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
                    TextStyle(color: _expenseFg, fontWeight: FontWeight.w700)),
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
                    color: _ink,
                  )),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _typeBtn('수입', true, _incomeIcon)),
                const SizedBox(width: 8),
                Expanded(child: _typeBtn('지출', false, _summaryExpenseFg)),
              ]),
              const SizedBox(height: 10),
              _DlgField(
                label: '항목명',
                child: TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: _financeInputDeco('예: 대관료'),
                ),
              ),
              _DlgField(
                label: '금액 (원)',
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                    _ThousandsFormatter(),
                  ],
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: _financeInputDeco('입력'),
                ),
              ),
              _DlgField(
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
                            color: _ink,
                          )),
                      const Spacer(),
                      const Icon(Icons.calendar_today_outlined,
                          size: 15, color: Color(0xFF888888)),
                    ]),
                  ),
                ),
              ),
              _DlgField(
                label: '메모',
                child: TextField(
                  controller: _memoCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _financeInputDeco('예: 자체대회'),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                if (_isEdit) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _confirmDelete,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _expenseBorder),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('삭제',
                          style: TextStyle(
                              color: _expenseFg, fontWeight: FontWeight.w700)),
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
                      backgroundColor: _accent,
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

// ══════════════════════════════════════════════
// 협회비 납부 내역 시트
// ══════════════════════════════════════════════
class _FeePaymentSheet extends StatefulWidget {
  final Club club;
  final VoidCallback onAdd;
  final void Function(AssociationFeePayment) onDelete;
  final VoidCallback onChanged;

  const _FeePaymentSheet({
    required this.club,
    required this.onAdd,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_FeePaymentSheet> createState() => _FeePaymentSheetState();
}

class _FeePaymentSheetState extends State<_FeePaymentSheet> {
  ClubFeeSummary get _summary => ClubFeeSummary.from(
      widget.club.id, widget.club.name, SampleData.feePayments);

  Future<void> _confirmDelete(AssociationFeePayment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('납부 내역 삭제',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${p.reason.label} · ${p.formattedAmount}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(p.date, style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 10),
            const Text(
              '이 납부 내역을 삭제하시겠습니까?\n(연결된 수입/지출 거래도 함께 삭제됩니다)',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF555555))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제',
                style:
                    TextStyle(color: _expenseFg, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.onDelete(p);
      setState(() {});
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E4EC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.club.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (s.totalPaid > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5EE),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '누적 ${_fmtAmt(s.totalPaid)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _incomeFg,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEB),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          '미납',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _expenseFg,
                          ),
                        ),
                      ),
                    if (s.paymentCount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${s.paymentCount}건 납부'
                        '${s.additionalCount > 0 ? ' (정기 ${s.regularCount} · 추가 ${s.additionalCount})' : ''}',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            const Divider(height: 1, color: _cardBorderLight),
            Flexible(
              child: s.payments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 36, color: Color(0xFFCCCCCC)),
                          SizedBox(height: 8),
                          Text('납부 내역이 없습니다',
                              style: TextStyle(fontSize: 13, color: _muted)),
                          SizedBox(height: 4),
                          Text('아래 버튼으로 첫 납부를 등록하세요',
                              style: TextStyle(fontSize: 11, color: _muted)),
                        ]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: s.payments.length,
                      itemBuilder: (_, i) => _PaymentTile(
                        payment: s.payments[i],
                        onLongPress: () => _confirmDelete(s.payments[i]),
                      ),
                    ),
            ),
            const Divider(height: 1, color: _cardBorderLight),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('납부 추가'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final AssociationFeePayment payment;
  final VoidCallback onLongPress;

  const _PaymentTile({
    required this.payment,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isRefund = payment.reason == FeeReason.refund;
    final amountColor = isRefund ? _expenseFg : _incomeFg;

    return InkWell(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Color(payment.reason.bgColor),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                payment.reason.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(payment.reason.fgColor),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (payment.memberDelta != null &&
                          payment.memberDelta != 0)
                        Text(
                          payment.memberDeltaLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Text(
                        payment.formattedAmount,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(
                      payment.date,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF666666)),
                    ),
                    if (payment.memo.isNotEmpty) ...[
                      const Text(' · ',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF666666))),
                      Flexible(
                        child: Text(
                          payment.memo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF666666)),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
