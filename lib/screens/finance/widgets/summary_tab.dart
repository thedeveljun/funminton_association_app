// lib/screens/finance/widgets/summary_tab.dart
//
// 요약 탭 화면 + 관련 보조 위젯들.
//
// 구성:
//   - PeriodSelector: 전체/이번달/직접선택 기간 선택
//   - 잔액 카드: 네이비 배경 + 큰 숫자 + 한글 표기
//   - 수입/지출 요약 카드 2개
//   - 월별 수입/지출 리스트
//
// 포함 클래스:
//   - SummaryTab (메인)
//   - SummaryAmtCard, MonthlyRow, MonthItem, PeriodSelector (보조)

import 'package:flutter/material.dart';

import '../../../models/finance_transaction.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';

// ══════════════════════════════════════════════
// 탭4: 요약
// ══════════════════════════════════════════════
class SummaryTab extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final String period;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final void Function(String, DateTime?, DateTime?) onPeriodChanged;

  const SummaryTab({
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
        PeriodSelector(
          current: period,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          onChanged: onPeriodChanged,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: kBalanceNavy,
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
              child: Text(fmtAmt(balance),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.8,
                    height: 1.1,
                  )),
            ),
            const SizedBox(height: 2),
            Text(toKoreanFull(balance),
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
              child: SummaryAmtCard(
                  label: '총 수입',
                  amount: income,
                  color: kSummaryIncomeFg,
                  bgColor: kSummaryIncomeBg,
                  icon: Icons.arrow_upward_rounded)),
          const SizedBox(width: 8),
          Expanded(
              child: SummaryAmtCard(
                  label: '총 지출',
                  amount: expense,
                  color: kSummaryExpenseFg,
                  bgColor: kSummaryExpenseBg,
                  icon: Icons.arrow_downward_rounded)),
        ]),
        const SizedBox(height: 16),
        const Text('월별 수입/지출',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: kMonthlyTitle,
              letterSpacing: -0.3,
            )),
        const SizedBox(height: 8),
        if (months.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kCardBorderLight),
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
            return MonthlyRow(
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

class SummaryAmtCard extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final Color bgColor;
  final IconData icon;
  const SummaryAmtCard({
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
              child: Text(fmtAmt(amount),
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

class MonthlyRow extends StatelessWidget {
  final String label;
  final int income, expense, balance;
  const MonthlyRow({
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
          border: Border.all(color: kCardBorderLight),
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
                  color: kMonthlyTitle,
                  letterSpacing: -0.3,
                )),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: MonthItem(
                      label: '수입', amount: income, color: kIncomeIcon)),
              Expanded(
                  child: MonthItem(
                      label: '지출', amount: expense, color: kSummaryExpenseFg)),
              Expanded(
                  child: MonthItem(
                      label: '잔액',
                      amount: balance,
                      color:
                          balance >= 0 ? kMonthlyBalance : kSummaryExpenseFg)),
            ]),
          ],
        ),
      );
}

class MonthItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  const MonthItem(
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
            child: Text(fmtAmt(amount),
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

class PeriodSelector extends StatelessWidget {
  final String current;
  final DateTime rangeStart, rangeEnd;
  final void Function(String, DateTime?, DateTime?) onChanged;
  const PeriodSelector({
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
        border: Border.all(color: kCardBorderLight),
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
                    color: current == p ? kAccent : kPeriodActiveBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: current == p ? kAccent : const Color(0xFFD5DAE1),
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
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                )),
          ],
          if (current == '이번달') ...[
            const SizedBox(height: 8),
            Text('${rangeStart.year}년 ${rangeStart.month}월',
                style: const TextStyle(
                  fontSize: 13,
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ],
      ),
    );
  }
}
