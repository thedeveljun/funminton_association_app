// lib/screens/finance/widgets/transaction_row.dart
//
// 수입/지출 탭의 개별 거래 행 위젯.
// 거래 한 건을 카드 형태로 표시 (수입은 흰색, 지출은 연빨강, 반납은 파랑 되돌림 아이콘).
//
// 펀클럽(funminton_club_app) 장부 행을 옮겨 왔다:
// - 영수증 사진이 붙어 있으면 왼쪽 상자에 작은 사진
// - 날짜·시각 표시(예전 자료는 거래 ID 의 시각)
// - 오른쪽→왼쪽으로 밀면 삭제/반납 확인. 반납이 끝난 짝은 지울 수 없다고 알림

import 'package:flutter/material.dart';

import '../../../models/finance_transaction.dart';
import '../../../services/finance_ledger.dart';
import '../../../services/receipt/receipt_scanner.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';

const Color _refundIcon = Color(0xFF3A7BD5);
const Color _refundBg = Color(0xFFE3EEFF);
const Color _refundFg = Color(0xFF2A5FCC);

class TransactionRow extends StatelessWidget {
  final FinanceTransaction tx;
  final VoidCallback? onTap;

  /// 밀어서 확인을 누르면 부른다. 널이면 밀기 꺼짐.
  final void Function(FinanceTransaction)? onDelete;

  const TransactionRow({super.key, required this.tx, this.onTap, this.onDelete});

  Future<bool> _confirm(BuildContext context) async {
    final action = FinanceLedger.actionOf(tx);
    final locked = action == LedgerAction.locked;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(FinanceLedger.titleOf(action, tx),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: kInk)),
        content: Text(
          locked
              ? '${tx.title}\n\n${FinanceLedger.lockedReason}\n\n되돌리려면 이 줄을 눌러 주세요.'
              : action == LedgerAction.refund
                  ? '${tx.title} ${fmtAmt(tx.amount)}\n\n'
                      '받은 기록은 남기고 같은 금액을 지출(반납)로 적습니다.\n'
                      '${FinanceLedger.liveKind(tx)} 납부는 미납으로 돌아갑니다.'
                  : action == LedgerAction.donation
                      ? '${tx.title} ${fmtAmt(tx.amount)}\n\n대회의 찬조 목록에서도 빠집니다.'
                      : '${tx.title} ${fmtAmt(tx.amount)}',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: locked
            ? [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('확인')),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소',
                      style: TextStyle(color: Color(0xFF555555))),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(FinanceLedger.confirmLabelOf(action),
                      style: const TextStyle(
                          color: kExpenseFg, fontWeight: FontWeight.w800)),
                ),
              ],
      ),
    );
    if (ok == true) onDelete?.call(tx);
    // 줄은 스스로 사라지지 않는다 — 목록이 다시 그린다.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.isIncome;
    final isRefund = FinanceLedger.isRefund(tx);
    final cardBg = isIncome || isRefund ? Colors.white : kExpenseCardBg;
    final cardBorder = isIncome || isRefund ? kIncomeBorder : kExpenseBorder;
    final iconBg = isIncome ? kIncomeBg : (isRefund ? _refundBg : kExpenseBg);
    final iconColor =
        isIncome ? kIncomeIcon : (isRefund ? _refundIcon : kExpenseIcon);
    final amountColor =
        isIncome ? kIncomeFg : (isRefund ? _refundFg : kExpenseFg);
    final icon = isIncome
        ? Icons.arrow_upward
        : (isRefund ? Icons.undo : Icons.arrow_downward);

    // 시각: 새 자료는 도장에, 예전 자료는 ID 에 들어 있다.
    final when = tx.date.length >= 16
        ? fmtStamp(tx.date)
        : [tx.date, extractTimeFromId(tx.id)]
            .where((s) => s.isNotEmpty)
            .join(' ');

    final iconBox = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: iconColor),
    );

    final card = GestureDetector(
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
          if (tx.imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ReceiptScanner.thumb(tx.imagePath!,
                  size: 32, fallback: iconBox),
            )
          else
            iconBox,
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
                  Text(when,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        letterSpacing: -0.2,
                      )),
                  // 클럽명: 협회비/분담금 거래는 title에 이미 클럽명이 있으니 메타에서 생략
                  if (tx.clubName != null &&
                      tx.clubName!.isNotEmpty &&
                      tx.category != '협회비' &&
                      tx.category != '분담금') ...[
                    const Text(' · ',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF666666))),
                    Flexible(
                      child: Text(tx.clubName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF666666))),
                    ),
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

    if (onDelete == null) return card;
    return Dismissible(
      key: ValueKey('tx_${tx.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirm(context),
      background: Container(
        margin: const EdgeInsets.only(bottom: 1),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEEE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.undo, color: kExpenseFg),
      ),
      child: card,
    );
  }
}
