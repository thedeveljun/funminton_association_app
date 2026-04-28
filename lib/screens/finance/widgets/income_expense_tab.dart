// lib/screens/finance/widgets/income_expense_tab.dart
//
// 수입/지출 탭 화면.
//
// 구성:
//   - 상단 네이비 배너: 총 수입 / 총 지출 + 항목 추가 버튼
//   - 거래 리스트: 협회비는 (클럽 + 날짜 + 시간 2분 이내) 단위로 그룹화
//   - 단일 거래는 TransactionRow, 그룹은 GroupedFeeRow로 표시
//
// 정렬:
//   - 1차: 날짜 내림차순
//   - 2차: 같은 날짜 내에서는 timestamp(ID) 기준 최신순

import 'package:flutter/material.dart';

import '../../../models/finance_transaction.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';
import 'grouped_fee_row.dart';
import 'small_widgets.dart';
import 'transaction_row.dart';

class IncomeExpenseTab extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final VoidCallback onAddTap;
  final void Function(FinanceTransaction) onItemTap;
  const IncomeExpenseTab({
    required this.transactions,
    required this.onAddTap,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    // ── 표시용 그룹핑 ──
    // 협회비를 클럽별로 분리 후, 같은 클럽이라도 2분 이상 떨어진 거래는 별도 그룹으로 처리
    // → 같은 날 여러 번 일괄 납부 시 각 회차가 분리되어 표시됨
    const groupGapThresholdMs = 2 * 60 * 1000; // 2분

    /// 거래 ID에서 microsecondsSinceEpoch 추출 (정렬용)
    int extractTimestamp(String id) {
      final match = RegExp(r'(\d{13,})').firstMatch(id);
      if (match == null) return 0;
      final raw = int.tryParse(match.group(1)!) ?? 0;
      // 16자리 이상이면 microsecond, 아니면 millisecond
      return match.group(1)!.length >= 16 ? raw ~/ 1000 : raw;
    }

    // 1. 협회비/기타 분리
    final feesByClubDate = <String, List<FinanceTransaction>>{};
    final others = <FinanceTransaction>[];
    for (final t in transactions) {
      // 협회비 카테고리이면서 수입(납부)인 거래만 그룹화 대상
      // → 협회비 환불 등의 지출은 일반 거래로 표시
      if (t.category == '협회비' &&
          t.isIncome &&
          t.clubId != null &&
          t.clubId!.isNotEmpty) {
        final key = '${t.clubId}__${t.date}';
        feesByClubDate.putIfAbsent(key, () => []).add(t);
      } else {
        others.add(t);
      }
    }

    // 2. 각 (클럽+날짜) 묶음 안에서 시간 간격이 5분 넘으면 분리
    final feeBatches = <List<FinanceTransaction>>[];
    for (final txs in feesByClubDate.values) {
      // 시간 오름차순 정렬 후 그룹화
      final sorted = [...txs]..sort(
          (a, b) => extractTimestamp(a.id).compareTo(extractTimestamp(b.id)));
      List<FinanceTransaction> currentBatch = [sorted.first];
      int lastTs = extractTimestamp(sorted.first.id);
      for (int i = 1; i < sorted.length; i++) {
        final ts = extractTimestamp(sorted[i].id);
        // 둘 다 timestamp가 있고 차이가 5분 이내 → 같은 배치
        if (lastTs > 0 &&
            ts > 0 &&
            (ts - lastTs).abs() <= groupGapThresholdMs) {
          currentBatch.add(sorted[i]);
        } else {
          feeBatches.add(currentBatch);
          currentBatch = [sorted[i]];
        }
        lastTs = ts;
      }
      feeBatches.add(currentBatch);
    }

    // 3. 표시 항목으로 변환
    final items = <DisplayItem>[];
    for (final t in others) {
      items.add(DisplayItem.single(t));
    }
    for (final batch in feeBatches) {
      if (batch.length == 1) {
        items.add(DisplayItem.single(batch.first));
      } else {
        items.add(DisplayItem.feeGroup(batch));
      }
    }
    // 정렬: 1차 날짜 내림차순 → 2차 timestamp 내림차순 (ID 접두사 무관, 숫자만 비교)
    items.sort((a, b) {
      final dateCmp = b.date.compareTo(a.date);
      if (dateCmp != 0) return dateCmp;
      // 그룹의 가장 최신 timestamp 비교 (microsecondsSinceEpoch 기반)
      final aMax = a.sourceTransactions
          .map((t) => extractTimestamp(t.id))
          .reduce((x, y) => x > y ? x : y);
      final bMax = b.sourceTransactions
          .map((t) => extractTimestamp(t.id))
          .reduce((x, y) => x > y ? x : y);
      return bMax.compareTo(aMax);
    });

    final txIncome =
        transactions.where((t) => t.isIncome).fold(0, (s, t) => s + t.amount);
    final txExpense =
        transactions.where((t) => !t.isIncome).fold(0, (s, t) => s + t.amount);

    return Column(children: [
      Container(
        color: kBannerNavyAlt,
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
                  color: kBannerAddBtn,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ),
          Row(children: [
            Expanded(child: BannerAmountBlock(label: '수입', amount: txIncome)),
            const SizedBox(width: 12),
            Expanded(child: BannerAmountBlock(label: '지출', amount: txExpense)),
            const SizedBox(width: 40),
          ]),
        ]),
      ),
      Expanded(
        child: items.isEmpty
            ? const Center(
                child: Text('내역이 없습니다',
                    style: TextStyle(color: Color(0xFFAAAAAA))))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  if (item.isGroup) {
                    return GroupedFeeRow(item: item);
                  }
                  final tx = item.sourceTransactions.first;
                  return TransactionRow(
                    tx: tx,
                    onTap: () => onItemTap(tx),
                  );
                },
              ),
      ),
    ]);
  }
}
