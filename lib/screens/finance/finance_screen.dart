// lib/screens/finance/finance_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/club.dart';
import '../../models/finance_transaction.dart';
import '../../services/sample_data.dart';

const _bgPage = Color(0xFFF6F7FA);
const _ink = Color(0xFF111111);
const _accent = Color(0xFF5B8ABB);
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

class _FeeRecord {
  bool paid;
  int amount;
  _FeeRecord({this.paid = false, this.amount = 300000});
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  String _summaryPeriod = '전체';
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  late List<FinanceTransaction> _transactions;
  late Map<String, _FeeRecord> _feeRecords;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, 1, 1);
    _rangeEnd = now;
    _transactions = List<FinanceTransaction>.from(SampleData.transactions);
    _feeRecords = {
      for (final c in SampleData.clubs)
        c.id: _FeeRecord(paid: c.feePaid, amount: 300000),
    };
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  int get _totalIncome {
    int sum = 0;
    for (final t in _transactions) {
      if (t.isIncome) sum += t.amount;
    }
    return sum;
  }

  int get _totalExpense {
    int sum = 0;
    for (final t in _transactions) {
      if (!t.isIncome) sum += t.amount;
    }
    return sum;
  }

  int get _balance => _totalIncome - _totalExpense;

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

  Future<void> _showFeeDialog(Club club) async {
    final rec = _feeRecords[club.id]!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FeeDialog(
        clubName: club.name,
        initialPaid: rec.paid,
        initialAmount: rec.amount,
        onSnack: _snack,
        onSave: (paid, amount) => setState(() {
          rec.paid = paid;
          rec.amount = amount;
        }),
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
            labelStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            labelColor: _accent,
            unselectedLabelColor: const Color(0xFF888888),
            indicatorColor: _accent,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: '협회비 납부'),
              Tab(text: '수입/지출'),
              Tab(text: '요약'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tc,
          children: [
            _FeeTab(records: _feeRecords, onRowTap: _showFeeDialog),
            _IncomeExpenseTab(
              transactions: _transactions,
              onAddTap: _showAddDialog,
              onItemTap: _showEditDialog,
            ),
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
  final Map<String, _FeeRecord> records;
  final void Function(Club) onRowTap;
  const _FeeTab({required this.records, required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    final clubs = SampleData.clubs;
    int paid = 0;
    int paidTotal = 0;
    int unpaidTotal = 0;
    for (final c in clubs) {
      final r = records[c.id];
      if (r == null) continue;
      if (r.paid) {
        paid++;
        paidTotal += r.amount;
      } else {
        unpaidTotal += r.amount;
      }
    }
    final unpaid = clubs.length - paid;

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
                      label: '미납총액',
                      amount: unpaidTotal,
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
            final r = records[c.id]!;
            return GestureDetector(
              onTap: () => onRowTap(c),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: r.paid ? Colors.white : const Color(0xFFFFFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: r.paid
                          ? const Color(0xFFD5DAE1)
                          : const Color(0xFFE8A0A0),
                      width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 2,
                        offset: Offset(0, 1)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: r.paid
                          ? const Color(0xFFE8F5EE)
                          : const Color(0xFFFFEBEB),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      r.paid ? '납부' : '미납',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: r.paid ? _incomeIcon : _expenseIcon,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                              letterSpacing: -0.3,
                            )),
                        const SizedBox(height: 2),
                        Text(c.memberType,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF666666))),
                      ],
                    ),
                  ),
                  Text(
                    r.paid ? _fmtAmt(r.amount) : '-',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: r.paid ? _incomeFg : const Color(0xFFAAAAAA),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: Color(0xFFAAAAAA)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
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
// 탭3: 요약
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
// 협회비 납부 수정 다이얼로그
// ══════════════════════════════════════════════
class _FeeDialog extends StatefulWidget {
  final String clubName;
  final bool initialPaid;
  final int initialAmount;
  final void Function(bool paid, int amount) onSave;
  final void Function(String) onSnack;
  const _FeeDialog({
    required this.clubName,
    required this.initialPaid,
    required this.initialAmount,
    required this.onSave,
    required this.onSnack,
  });

  @override
  State<_FeeDialog> createState() => _FeeDialogState();
}

class _FeeDialogState extends State<_FeeDialog> {
  late bool _paid;
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _paid = widget.initialPaid;
    final s = widget.initialAmount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    _amountCtrl = TextEditingController(text: buf.toString());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final amount = int.tryParse(
            _amountCtrl.text.replaceAll(',', '').replaceAll('원', '').trim()) ??
        0;
    if (amount < 0) {
      widget.onSnack('금액을 다시 입력해주세요.');
      return;
    }
    widget.onSave(_paid, amount);
    Navigator.pop(context);
  }

  Widget _statusBtn(String label, bool paidKind, Color activeColor) {
    final selected = _paid == paidKind;
    return GestureDetector(
      onTap: () => setState(() => _paid = paidKind),
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
              const Text('협회비 납부 수정',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  )),
              const SizedBox(height: 8),
              Text(widget.clubName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  )),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _statusBtn('납부', true, _incomeIcon)),
                const SizedBox(width: 8),
                Expanded(child: _statusBtn('미납', false, _summaryExpenseFg)),
              ]),
              const SizedBox(height: 10),
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
                  decoration: _financeInputDeco('예: 300,000'),
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
