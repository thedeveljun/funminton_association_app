// lib/screens/finance/widgets/tournament_finance_tab.dart
//
// 대회재정 탭 전체 화면 + 대회 카드 위젯.
//
// 구성:
//   - 상단 네이비 배너: 예산 총액 / 시 보조금 합계 / 협회 부담
//   - 대회 카드 리스트: 각 대회의 예산, 분담금, 찬조, 실제 수입/지출 표시
//
// 카드 탭 시 TournamentFinanceScreen으로 이동 (대회별 상세 화면).

import 'package:flutter/material.dart';

import '../../../models/club_share.dart';
import '../../../models/donation.dart';
import '../../../models/finance_transaction.dart';
import '../../../models/tournament.dart';
import '../../../services/sample_data.dart';
import '../tournament_finance_screen.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';
import 'small_widgets.dart';

class TournamentFinanceTab extends StatelessWidget {
  final List<FinanceTransaction> transactions;

  /// "+ 분담금" 버튼 탭 시 호출
  final void Function(Tournament)? onShareAdd;

  /// 분담금 박스 탭 시 호출 (수정 진입)
  final void Function(Tournament)? onShareEdit;

  /// 카드 ⋮ 메뉴 → 대회 수정 시 호출
  final void Function(Tournament)? onEdit;

  const TournamentFinanceTab({
    required this.transactions,
    this.onShareAdd,
    this.onShareEdit,
    this.onEdit,
  });

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
        color: kBannerNavy,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: AmountSummaryBlock(
                    label: '예산 총액', amount: totalBudget, color: kAmountYellow)),
            const SizedBox(width: 12),
            Expanded(
                child: AmountSummaryBlock(
                    label: '시 보조금',
                    amount: totalCitySupport,
                    color: const Color(0xFFB6D7FF))),
            const SizedBox(width: 12),
            Expanded(
                child: AmountSummaryBlock(
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
                itemBuilder: (_, i) => TournamentFinanceCard(
                  tournament: tournaments[i],
                  transactions: transactions,
                  shares: SampleData.clubShares,
                  donations: SampleData.donations,
                  onShareAdd: onShareAdd,
                  onShareEdit: onShareEdit,
                  onEdit: onEdit,
                ),
              ),
      ),
    ]);
  }
}

class TournamentFinanceCard extends StatelessWidget {
  final Tournament tournament;
  final List<FinanceTransaction> transactions;
  final List<ClubShare> shares;
  final List<Donation> donations;

  /// "+ 분담금" 버튼 탭 시 호출. null이면 버튼 표시 안 함.
  final void Function(Tournament)? onShareAdd;

  /// 분담금 박스 탭 시 호출 (수정 모드 진입 등). null이면 무시.
  final void Function(Tournament)? onShareEdit;

  /// 카드 우상단 ⋮ 메뉴 → "대회 수정" 선택 시 호출. null이면 메뉴 표시 안 함.
  final void Function(Tournament)? onEdit;

  const TournamentFinanceCard({
    required this.tournament,
    required this.transactions,
    required this.shares,
    required this.donations,
    this.onShareAdd,
    this.onShareEdit,
    this.onEdit,
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
        return kIncomeIcon;
      case 'completed':
        return const Color(0xFF888888);
      default:
        return kAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shareSummary =
        ClubShareSummary.from(tournament.id, tournament.name, shares);

    // 이 대회의 거래 목록.
    // 대회가 분담금을 적용하지 않으면 '분담금' 카테고리 거래는 제외 (연결된 분담금 데이터가 있어도 카드 통계에 반영 안 됨).
    final relatedTx = transactions.where((t) {
      if (t.tournamentId != tournament.id) return false;
      if (!tournament.hasClubShare && t.category == '분담금') return false;
      return true;
    }).toList();
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
          border: Border.all(
            color: _typeColor.withOpacity(0.35),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _typeColor.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
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
              if (onEdit != null)
                _CardMenuButton(onEdit: () => onEdit!(tournament))
              else
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: Color(0xFFAAAAAA)),
            ]),
            const SizedBox(height: 8),
            Text(
              tournament.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kInk,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${tournament.startDate}${tournament.endDate.isNotEmpty && tournament.endDate != tournament.startDate ? ' ~ ${tournament.endDate}' : ''}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            if (tournament.totalBudget > 0) ...[
              const SizedBox(height: 12),
              _budgetRow(tournament),
            ],
            if (tournament.hasClubShare) ...[
              const SizedBox(height: 10),
              if (shareSummary.totalCount > 0)
                GestureDetector(
                  onTap: onShareEdit == null
                      ? null
                      : () => onShareEdit!(tournament),
                  behavior: HitTestBehavior.opaque,
                  child: _shareRow(shareSummary),
                ),
              if (onShareAdd != null) ...[
                if (shareSummary.totalCount > 0) const SizedBox(height: 6),
                _shareAddButton(context),
              ],
            ],
            if (relatedTx.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: kCardBorderLight),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _smallStat('실제 수입', actualIncome, kIncomeFg),
                ),
                Expanded(
                  child: _smallStat('실제 지출', actualExpense, kExpenseFg),
                ),
                Expanded(
                  child: _smallStat(
                      '잔액', actualIncome - actualExpense, kMonthlyBalance),
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
                  fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          const Spacer(),
          Text(t.formattedBudget,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: kInk)),
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
            const Dot(color: Color(0xFF6FA8E6)),
            const SizedBox(width: 4),
            Text('보조 ${t.formattedCitySupport}',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF555555),
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
          ],
          const Dot(color: Color(0xFFFFD0D0)),
          const SizedBox(width: 4),
          Text('협회 ${t.formattedAssociationBurden}',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF555555),
                  fontWeight: FontWeight.w500)),
        ]),
      ],
    );
  }

  Widget _shareAddButton(BuildContext context) {
    return InkWell(
      onTap: () => onShareAdd!(tournament),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F7FE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: kAccent.withOpacity(0.4),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_circle_outline, size: 16, color: kAccent),
            SizedBox(width: 6),
            Text(
              '분담금 추가',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kAccent,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareRow(ClubShareSummary s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.account_balance_outlined, size: 16, color: kAccent),
        const SizedBox(width: 6),
        const Text('분담금',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kAccent)),
        const Spacer(),
        Text('${fmtAmt(s.collectedAmount)} / ${fmtAmt(s.totalAmount)}',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: kInk)),
      ]),
    );
  }

  Widget _smallStat(String label, int amount, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(fmtAmt(amount),
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

// ── 카드 우상단 ⋮ 메뉴 버튼 ─────────────────
class _CardMenuButton extends StatelessWidget {
  final VoidCallback onEdit;
  const _CardMenuButton({required this.onEdit});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 28,
        height: 28,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF888888)),
          tooltip: '메뉴',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onSelected: (v) {
            if (v == 'edit') onEdit();
          },
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              value: 'edit',
              height: 40,
              child: Row(
                children: const [
                  Icon(Icons.edit_outlined, size: 18, color: kInk),
                  SizedBox(width: 8),
                  Text('대회 수정',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
}
