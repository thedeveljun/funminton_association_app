// lib/screens/finance/widgets/fee_tab.dart
//
// 협회비 탭 전체 화면.
//
// 구성:
//   - 상단 네이비 배너: 전체 통계 (납부 인원, 납부 금액)
//   - 상태 칩: 완납/일부 납부/미납 클럽 수
//   - 클럽 리스트: 각 클럽별 납부 현황 카드 (FeeClubRow)
//
// 클럽 카드 탭 시 onRowTap 콜백 호출 → 부모 화면이 협회비 납부 시트를 띄움.

import 'package:flutter/material.dart';

import '../../../models/club.dart';
import '../../../models/player_fee_payment.dart';
import '../../../services/sample_data.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';
import 'small_widgets.dart';

class FeeTab extends StatelessWidget {
  final void Function(Club) onRowTap;
  const FeeTab({required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    final clubs = SampleData.clubs;
    final payments = SampleData.playerFeePayments;
    final allPlayers = SampleData.players;

    // 클럽별 회원수 집계 (Player 모델의 clubId 기준)
    final clubMemberCounts = <String, int>{};
    for (final p in allPlayers) {
      clubMemberCounts[p.clubId] = (clubMemberCounts[p.clubId] ?? 0) + 1;
    }

    // 클럽별 협회비 납부 현황
    final summaries = {
      for (final c in clubs)
        c.id: ClubFeeSummary.from(
          clubId: c.id,
          clubName: c.name,
          totalPlayers: clubMemberCounts[c.id] ?? c.memberCount,
          allPayments: payments,
        ),
    };

    // 상단 배너 통계
    int fullyPaidClubs = 0;
    int partiallyPaidClubs = 0;
    int unpaidClubs = 0;
    int totalPaidAmount = 0;
    int totalPlayers = 0;
    int totalPaidPlayers = 0;

    for (final c in clubs) {
      final s = summaries[c.id]!;
      totalPlayers += s.totalPlayers;
      totalPaidPlayers += s.paidPlayers;
      totalPaidAmount += s.totalPaid;

      if (s.isFullyPaid) {
        fullyPaidClubs++;
      } else if (s.isPartiallyPaid) {
        partiallyPaidClubs++;
      } else {
        unpaidClubs++;
      }
    }

    return Column(children: [
      Container(
        color: kBannerNavy,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              StatusChip(
                  label: '완납', count: fullyPaidClubs, color: kStatusPaidColor),
              const SizedBox(width: 6),
              StatusChip(
                label: '일부',
                count: partiallyPaidClubs,
                color: const Color(0xFFFFB347),
                bgColor: const Color(0x33FFB347),
              ),
              const SizedBox(width: 6),
              StatusChip(
                label: '미납',
                count: unpaidClubs,
                color: kStatusUnpaidColor,
                bgColor: const Color(0x33AAAAAA),
              ),
              const SizedBox(width: 6),
              StatusChip(
                  label: '전체', count: clubs.length, color: kStatusAllColor),
            ]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: AmountSummaryBlock(
                      label: '납부 인원',
                      amount: totalPaidPlayers,
                      color: kAmountYellow,
                      suffix: ' / $totalPlayers명',
                      showWon: false)),
              const SizedBox(width: 16),
              Expanded(
                  child: AmountSummaryBlock(
                      label: '납부 총액',
                      amount: totalPaidAmount,
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
            return FeeClubRow(
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

class FeeClubRow extends StatelessWidget {
  final Club club;
  final ClubFeeSummary summary;
  final VoidCallback onTap;

  const FeeClubRow({
    required this.club,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFully = summary.isFullyPaid;
    final isPartial = summary.isPartiallyPaid;
    final isUnpaid = summary.isUnpaid;

    // 상태별 색상
    final Color cardBg;
    final Color borderColor;
    final Color badgeBg;
    final Color badgeFg;
    final String badgeLabel;

    if (isFully) {
      cardBg = Colors.white;
      borderColor = const Color(0xFFD5DAE1);
      badgeBg = const Color(0xFFE8F5EE);
      badgeFg = kIncomeIcon;
      badgeLabel = '완납';
    } else if (isPartial) {
      cardBg = const Color(0xFFFFFBF0);
      borderColor = const Color(0xFFFFD89A);
      badgeBg = const Color(0xFFFFF1D6);
      badgeFg = const Color(0xFFB7791F);
      badgeLabel = '일부';
    } else {
      cardBg = const Color(0xFFFFFAFA);
      borderColor = const Color(0xFFE8A0A0);
      badgeBg = const Color(0xFFFFEBEB);
      badgeFg = kExpenseIcon;
      badgeLabel = '미납';
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: badgeFg,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                      letterSpacing: -0.3,
                      height: 1.1,
                    )),
                if (_subtitleText().isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    _subtitleText(),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF555555),
                        height: 1.1),
                  ),
                ],
              ],
            ),
          ),
          // 우측 인원/금액
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${summary.paidPlayers}/${summary.totalPlayers}명',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isUnpaid ? const Color(0xFF888888) : kInk,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
              if (!isUnpaid) ...[
                const SizedBox(height: 1),
                Text(
                  fmtAmt(summary.totalPaid),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kIncomeFg,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
              ],
            ],
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
    }
    if (summary.isPartiallyPaid) {
      final pct = (summary.ratio * 100).toStringAsFixed(0);
      parts.add('$pct% 진행');
    }
    return parts.join(' · ');
  }
}
