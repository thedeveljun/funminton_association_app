// lib/screens/finance/widgets/small_widgets.dart
//
// 재정 화면에서 쓰이는 작은 공용 위젯 모음.
//   - StatusChip: 협회비 탭의 납부/미납 상태 칩
//   - AmountSummaryBlock: 대회재정 탭 상단 금액 블록 (라벨 + 금액)
//   - BannerAmountBlock: 수입/지출 탭 상단 배너 금액 블록
//   - Dot: 진행률 표시용 작은 점

import 'package:flutter/material.dart';

import 'finance_helpers.dart';

// ══════════════════════════════════════════════
// StatusChip — 회비납부 탭의 상태 칩
// ══════════════════════════════════════════════

/// 협회비 탭 등에서 "납부 5", "미납 12" 같은 상태와 카운트를 표시.
class StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color? bgColor;

  const StatusChip({
    super.key,
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

// ══════════════════════════════════════════════
// AmountSummaryBlock — 대회재정 탭 상단 금액 블록
// ══════════════════════════════════════════════

/// 대회재정 탭 상단의 (예산 총액 / 시 보조금 합계 / 협회 부담) 같은 금액 블록.
/// 흰색 라벨 + 강조 색상 금액 (네이비 배너 위에 올라감).
class AmountSummaryBlock extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final String? suffix;
  final bool showWon;

  const AmountSummaryBlock({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    this.suffix,
    this.showWon = true,
  });

  String _formatted() {
    if (showWon) return fmtAmt(amount);
    final s = amount.abs().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return amount < 0 ? '-$s' : s;
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.78),
                letterSpacing: -0.2,
              )),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('${_formatted()}${suffix ?? ''}',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.4,
                )),
          ),
        ],
      );
}

// ══════════════════════════════════════════════
// BannerAmountBlock — 수입/지출 탭 상단 배너의 금액 블록
// ══════════════════════════════════════════════

/// 수입/지출 탭 상단 네이비 배너에 올라가는 (수입 / 지출) 금액 블록.
/// 흰색 라벨 + 흰색 큰 금액.
class BannerAmountBlock extends StatelessWidget {
  final String label;
  final int amount;

  const BannerAmountBlock({
    super.key,
    required this.label,
    required this.amount,
  });

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
            child: Text(fmtAmt(amount),
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

// ══════════════════════════════════════════════
// Dot — 진행률 표시용 작은 점
// ══════════════════════════════════════════════

/// 6×6 컬러 원. 대회재정 카드의 진행 바 범례 등에서 사용.
class Dot extends StatelessWidget {
  final Color color;

  const Dot({super.key, required this.color});

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
