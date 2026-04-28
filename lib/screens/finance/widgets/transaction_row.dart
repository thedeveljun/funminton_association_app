// lib/screens/finance/widgets/transaction_row.dart
//
// 수입/지출 탭의 개별 거래 행 위젯.
// 거래 한 건을 카드 형태로 표시 (수입은 흰색, 지출은 연빨강 카드).

import 'package:flutter/material.dart';

import '../../../models/finance_transaction.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';

/// 수입/지출 탭의 개별 거래 행.
///
/// 표시 내용:
/// - 좌측: 화살표 아이콘 (수입↑ 초록 / 지출↓ 빨강)
/// - 본문: 제목 + 금액 + 날짜/시간/클럽/대회 정보 + (옵션) 메모
/// - 카드 배경: 수입은 흰색, 지출은 연한 빨강
class TransactionRow extends StatelessWidget {
  final FinanceTransaction tx;
  final VoidCallback? onTap;

  const TransactionRow({super.key, required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.isIncome;
    final cardBg = isIncome ? Colors.white : kExpenseCardBg;
    final cardBorder = isIncome ? kIncomeBorder : kExpenseBorder;
    final iconBg = isIncome ? kIncomeBg : kExpenseBg;
    final iconColor = isIncome ? kIncomeIcon : kExpenseIcon;
    final amountColor = isIncome ? kIncomeFg : kExpenseFg;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorder, width: 1.4),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 8),
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
                            color: kInk,
                            letterSpacing: -0.3,
                            height: 1.1,
                          )),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isIncome ? '+' : '-'}${fmtAmt(tx.amount).replaceAll('-', '')}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Row(children: [
                  Text(tx.date,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        letterSpacing: -0.2,
                      )),
                  if (extractTimeFromId(tx.id).isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(extractTimeFromId(tx.id),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                  // 클럽명: 협회비 거래는 title에 이미 클럽명이 있으니 메타에서 생략
                  if (tx.clubName != null && tx.category != '협회비') ...[
                    const Text(' · ',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF666666))),
                    Text(tx.clubName!,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF666666))),
                  ],
                  if (tx.tournamentName != null) ...[
                    const Text(' · ',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF666666))),
                    Flexible(
                      child: Text(tx.tournamentName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF666666))),
                    ),
                  ],
                ]),
                // 메모 표시 (있는 경우만)
                if (tx.memo != null && tx.memo!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 12, color: Color(0xFFB7791F)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            tx.memo!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8B6914),
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
