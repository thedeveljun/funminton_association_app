// lib/screens/finance/widgets/ledger_dialogs.dart
//
// 장부 연동 안내·확인 창 — 펀클럽(funminton_club_app) 재정관리의
// '납부를 푸는 까닭은?', '이 돈을 돌려줬나요?', 반납 짝 안내, 연동 줄 안내를 옮겼다.

import 'package:flutter/material.dart';

import '../../../models/finance_transaction.dart';
import '../../../services/finance_ledger.dart';
import '../../../services/finance_log.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';

const _titleStyle =
    TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kInk);
const _bodyStyle = TextStyle(fontSize: 14, height: 1.45, color: kInk);

RoundedRectangleBorder get _shape =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

/// 납부를 풀 때 까닭을 묻는다. 그만두면 널.
/// - 돌려줬어요 → 반납으로 적는다(받은 기록 + 돌려준 기록)
/// - 잘못 눌렀어요 → 받은 기록을 장부에서 걷어낸다
Future<UnpayChoice?> askUnpayReason(
    BuildContext context, String who, int amount) {
  return showDialog<UnpayChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: _shape,
      title: const Text('납부를 푸는 까닭은?', style: _titleStyle),
      content: Text(
        '$who ${fmtAmt(amount)}\n\n'
        '· 돌려줬어요 — 재정관리에 반납(지출)으로 적습니다.\n'
        '· 잘못 눌렀어요 — 받은 기록을 지웁니다.',
        style: _bodyStyle,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소', style: TextStyle(color: Color(0xFF555555))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, UnpayChoice.mistake),
          child: const Text('잘못 눌렀어요'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, UnpayChoice.refunded),
          child: const Text('돌려줬어요',
              style: TextStyle(color: kExpenseFg, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

/// 낸 사람·대상을 지울 때 돈을 돌려줬는지 묻는다. 그만두면 널.
/// - 돌려줌 → 반납으로 적는다
/// - 안 돌려줌 → 받은 돈을 보통 수입으로 그대로 남긴다
Future<UnpayChoice?> askPaidRemoval(BuildContext context,
    {required String title,
    required String who,
    required int amount,
    required String action}) {
  return showDialog<UnpayChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: _shape,
      title: Text(title, style: _titleStyle),
      content: Text(
        '$who ${fmtAmt(amount)}을 냈습니다.\n이 돈을 돌려줬나요?\n\n'
        '· 돌려줌 — 재정관리에 반납으로 적습니다.\n'
        '· 안 돌려줌 — 받은 돈을 수입으로 그대로 남깁니다.',
        style: _bodyStyle,
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소', style: TextStyle(color: Color(0xFF555555))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, UnpayChoice.keep),
          child: Text('안 돌려줌 · $action'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, UnpayChoice.refunded),
          child: Text('돌려줌 · $action',
              style: const TextStyle(
                  color: kExpenseFg, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

/// 반납이 끝난 짝을 눌렀을 때 — 손댈 수 없다고 알리고, 되돌릴 수 있으면 버튼을 준다.
Future<void> showSettledDialog(BuildContext context, FinanceTransaction tx,
    {required VoidCallback onUndone}) async {
  final blocker = FinanceLedger.undoBlocker(tx);
  final label = FinanceLedger.undoLabelOf(tx);
  final undo = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: _shape,
      title: const Text('손댈 수 없는 기록입니다', style: _titleStyle),
      content: Text(
        '${tx.title}\n\n${FinanceLedger.lockedReason}'
        '${blocker == null ? "\n\n되돌리려면 아래 '$label'를 누르세요.\n받은 기록과 돌려준 기록을 함께 걷어내고 낸 것으로 되돌립니다." : '\n\n$blocker'}',
        style: _bodyStyle,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('확인')),
        if (blocker == null)
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF2A5FCC), fontWeight: FontWeight.w800)),
          ),
      ],
    ),
  );
  if (undo == true && await FinanceLedger.undoRefund(tx)) onUndone();
}

/// 협회비·분담금·찬조와 이어진 줄을 눌렀을 때 — 원래 화면에서 고치라고 안내.
Future<void> showLinkedDialog(BuildContext context, FinanceTransaction tx) {
  final kind = FinanceLedger.liveKind(tx) ?? '';
  final where = FinanceLedger.whereOf(kind);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: _shape,
      title: Text(tx.title, style: _titleStyle),
      content: Text(
        '$where 화면에서 온 기록입니다.\n'
        '금액·이름·날짜는 $where 화면에서 고쳐 주세요.\n\n'
        '${kind == '찬조' ? '이 줄을 지우면 대회의 찬조 목록에서도 빠집니다.' : '돈을 돌려줬으면 이 줄을 왼쪽으로 밀어 지우세요 — 반납으로 기록됩니다.'}',
        style: _bodyStyle,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
      ],
    ),
  );
}

/// 손으로 적은 거래를 추가·수정했을 때 이력에 남긴다. 바뀐 것이 없으면 남기지 않는다.
/// 메모·전화번호·사진만 바뀐 것은 남기지 않는다(펀클럽과 같은 기준).
Future<void> logTransactionChange(
    FinanceTransaction? before, FinanceTransaction after) {
  String kindOf(FinanceTransaction t) => t.isIncome ? '수입' : '지출';
  if (before == null) {
    return FinanceLog.add('${kindOf(after)} 추가', after.title,
        '${fmtAmt(after.amount)} · ${fmtStamp(after.date)}');
  }
  final parts = <String>[
    if (before.isIncome != after.isIncome)
      '${kindOf(before)} → ${kindOf(after)}',
    if (before.title != after.title) '이름 ${before.title} → ${after.title}',
    if (before.amount != after.amount)
      '${fmtAmt(before.amount)} → ${fmtAmt(after.amount)}',
    if (before.date != after.date)
      '날짜 ${fmtStamp(before.date)} → ${fmtStamp(after.date)}',
  ];
  if (parts.isEmpty) return Future.value();
  return FinanceLog.add('${kindOf(after)} 수정', after.title, parts.join(' · '));
}
