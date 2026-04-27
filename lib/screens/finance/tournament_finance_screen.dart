// lib/screens/finance/tournament_finance_screen.dart

import 'package:flutter/material.dart';
import '../../models/tournament.dart';
import '../../models/club_share.dart';
import '../../models/donation.dart';
import '../../models/finance_transaction.dart';
import '../../services/sample_data.dart';

const _bgPage = Color(0xFFF6F7FA);
const _ink = Color(0xFF111111);
const _muted = Color(0xFF888888);
const _accent = Color(0xFF5B8ABB);
const _bannerNavy = Color.fromARGB(255, 10, 36, 92);
const _cardBorderLight = Color(0xFFE0E4EC);
const _incomeFg = Color(0xFF2A7A4A);
const _incomeIcon = Color(0xFF4A9E6B);
const _expenseFg = Color(0xFFCC2222);
const _expenseIcon = Color(0xFFCC4444);
const _amountYellow = Color(0xFFFFC300);

String _fmtAmt(int n) {
  final s = n.abs().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return n < 0 ? '-${s}원' : '${s}원';
}

// ══════════════════════════════════════════════
// 메인 화면
// ══════════════════════════════════════════════
class TournamentFinanceScreen extends StatefulWidget {
  final Tournament tournament;
  const TournamentFinanceScreen({super.key, required this.tournament});

  @override
  State<TournamentFinanceScreen> createState() =>
      _TournamentFinanceScreenState();
}

class _TournamentFinanceScreenState extends State<TournamentFinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  late List<ClubShare> _shares;
  late List<Donation> _donations;
  late List<FinanceTransaction> _transactions;

  Tournament get _t => widget.tournament;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _shares =
          SampleData.clubShares.where((s) => s.tournamentId == _t.id).toList();
      _donations =
          SampleData.donations.where((d) => d.tournamentId == _t.id).toList();
      _transactions = SampleData.transactions
          .where((t) => t.tournamentId == _t.id)
          .toList();
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── 분담금 토글 ────────────────────────────
  void _toggleSharePaid(ClubShare share) {
    final idx = SampleData.clubShares.indexWhere((s) => s.id == share.id);
    if (idx < 0) return;

    final today =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    if (share.paid) {
      // 납부 → 미납 (연결된 거래도 삭제)
      if (share.txId != null) {
        SampleData.transactions.removeWhere((t) => t.id == share.txId);
      }
      SampleData.clubShares[idx] = share.markUnpaid();
      _snack('${share.clubName} 분담금을 미납으로 변경했습니다.');
    } else {
      // 미납 → 납부 (연결 거래 자동 생성)
      final txId = 'tx_share_${DateTime.now().microsecondsSinceEpoch}';
      SampleData.transactions.add(FinanceTransaction(
        id: txId,
        title: '${share.clubName} 분담금',
        amount: share.amount,
        isIncome: true,
        category: '분담금',
        date: today,
        clubId: share.clubId,
        clubName: share.clubName,
        tournamentId: share.tournamentId,
        tournamentName: share.tournamentName,
      ));
      SampleData.clubShares[idx] = share.markPaid(paidDate: today, txId: txId);
      _snack('${share.clubName} 분담금을 납부 처리했습니다.');
    }
    _refresh();
  }

  // ── 찬조 감사 토글 ──────────────────────────
  void _toggleAcknowledged(Donation donation) {
    final idx = SampleData.donations.indexWhere((d) => d.id == donation.id);
    if (idx < 0) return;
    SampleData.donations[idx] =
        donation.copyWith(acknowledged: !donation.acknowledged);
    _snack(donation.acknowledged
        ? '${donation.donorName} 감사 표시를 해제했습니다.'
        : '${donation.donorName} 감사 표시를 완료했습니다.');
    _refresh();
  }

  // ── FAB 액션 시트 ──────────────────────────
  void _showFabSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E4EC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (_t.hasClubShare)
                _fabItem(
                  ctx,
                  icon: Icons.account_balance_outlined,
                  iconColor: _accent,
                  title: '분담금 추가',
                  subtitle: '대회에 참여하는 클럽에 분담금 부과',
                  onTap: () {
                    Navigator.pop(ctx);
                    _snack('분담금 등록 화면은 다음 단계에서 연결됩니다.');
                  },
                ),
              if (_t.acceptsDonation)
                _fabItem(
                  ctx,
                  icon: Icons.volunteer_activism_outlined,
                  iconColor: const Color(0xFFB7791F),
                  title: '찬조 추가',
                  subtitle: '개인·기업 현금/물품 찬조 등록',
                  onTap: () {
                    Navigator.pop(ctx);
                    _snack('찬조 등록 화면은 다음 단계에서 연결됩니다.');
                  },
                ),
              _fabItem(
                ctx,
                icon: Icons.receipt_long_outlined,
                iconColor: _incomeIcon,
                title: '거래내역 추가',
                subtitle: '이 대회의 일반 수입/지출 등록',
                onTap: () {
                  Navigator.pop(ctx);
                  _snack('거래내역 추가는 재정관리 메인 화면에서 가능합니다.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fabItem(BuildContext ctx,
      {required IconData icon,
      required Color iconColor,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
      subtitle:
          Text(subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        title: const Text('대회 재정',
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, color: _ink)),
      ),
      body: Column(children: [
        // ── 헤더 카드 (대회 + 예산 요약) ──
        _HeaderCard(tournament: _t),
        // ── 탭 ─────────────────────────
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tc,
            isScrollable: false,
            labelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            labelColor: _accent,
            unselectedLabelColor: const Color(0xFF888888),
            indicatorColor: _accent,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: '현황'),
              Tab(text: '분담금'),
              Tab(text: '찬조'),
              Tab(text: '거래'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: [
              _OverviewTab(
                tournament: _t,
                shares: _shares,
                donations: _donations,
                transactions: _transactions,
              ),
              _ShareTab(
                tournament: _t,
                shares: _shares,
                onToggle: _toggleSharePaid,
              ),
              _DonationTab(
                tournament: _t,
                donations: _donations,
                onToggleAcknowledged: _toggleAcknowledged,
              ),
              _TxTab(transactions: _transactions),
            ],
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFabSheet,
        backgroundColor: _accent,
        elevation: 2,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 헤더 카드 — 대회 + 예산 요약
// ══════════════════════════════════════════════
class _HeaderCard extends StatelessWidget {
  final Tournament tournament;
  const _HeaderCard({required this.tournament});

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

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Container(
      color: _bannerNavy,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.25),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _typeColor, width: 1),
              ),
              child: Text(
                t.tournamentType.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                t.statusLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(t.name,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text(
            '${t.startDate}${t.endDate.isNotEmpty && t.endDate != t.startDate ? ' ~ ${t.endDate}' : ''}'
            '${t.region.isNotEmpty ? ' · ${t.region}' : ''}'
            '${t.venue.isNotEmpty ? ' · ${t.venue}' : ''}',
            style:
                TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75)),
          ),
          if (t.totalBudget > 0) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _budgetBlock('총 예산', t.formattedBudget, _amountYellow),
              ),
              const SizedBox(width: 10),
              if (t.citySupportAmount > 0) ...[
                Expanded(
                  child: _budgetBlock(
                      '시 지원', t.formattedCitySupport, const Color(0xFFB6D7FF)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _budgetBlock('협회 부담', t.formattedAssociationBurden,
                    const Color(0xFFFFD0D0)),
              ),
            ]),
            if (t.citySupportAmount > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: t.cityFundingRatio,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFFFD0D0),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF6FA8E6)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '시 지원 ${(t.cityFundingRatio * 100).toStringAsFixed(0)}%'
                '${t.citySupportNote.isNotEmpty ? ' · ${t.citySupportNote}' : ''}',
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withOpacity(0.75)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _budgetBlock(String label, String amount, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.75))),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(amount,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.4)),
          ),
        ],
      );
}

// ══════════════════════════════════════════════
// 탭1: 현황 (예산 vs 실적)
// ══════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final Tournament tournament;
  final List<ClubShare> shares;
  final List<Donation> donations;
  final List<FinanceTransaction> transactions;

  const _OverviewTab({
    required this.tournament,
    required this.shares,
    required this.donations,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final shareSum =
        ClubShareSummary.from(tournament.id, tournament.name, shares);
    final donSum = DonationSummary.from(donations,
        tournamentId: tournament.id, tournamentName: tournament.name);

    final actualIncome = transactions
        .where((t) => t.isIncome)
        .fold<int>(0, (s, t) => s + t.amount);
    final actualExpense = transactions
        .where((t) => !t.isIncome)
        .fold<int>(0, (s, t) => s + t.amount);
    final balance = actualIncome - actualExpense;

    final budgetRemaining = tournament.totalBudget - actualExpense;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ── 분담금 진행 ──
        if (tournament.hasClubShare && shareSum.totalCount > 0)
          _progressCard(
            title: '분담금 납부 현황',
            icon: Icons.account_balance_outlined,
            iconColor: _accent,
            stat1Label: '납부 완료',
            stat1Value: '${shareSum.paidCount}/${shareSum.totalCount} 클럽',
            stat2Label: '수금액',
            stat2Value: _fmtAmt(shareSum.collectedAmount),
            progress: shareSum.collectionRatio,
            progressLabel:
                '${(shareSum.collectionRatio * 100).toStringAsFixed(0)}% · 미수금 ${_fmtAmt(shareSum.pendingAmount)}',
          ),

        // ── 찬조 합계 ──
        if (tournament.acceptsDonation && donSum.grandTotal > 0) ...[
          if (tournament.hasClubShare && shareSum.totalCount > 0)
            const SizedBox(height: 10),
          _statCard(
            title: '찬조 현황',
            icon: Icons.volunteer_activism_outlined,
            iconColor: const Color(0xFFB7791F),
            children: [
              _row('개인 찬조',
                  '${donSum.individualCount}건 · ${_fmtAmt(donSum.individualTotal)}'),
              _row('기업 찬조',
                  '${donSum.corporateCount}건 · ${_fmtAmt(donSum.corporateTotal)}'),
              const Divider(height: 14, color: _cardBorderLight),
              _row('현금 합계', _fmtAmt(donSum.cashTotal), bold: true),
              _row('물품 합계 (평가액)', _fmtAmt(donSum.itemTotal), bold: true),
              _row('총 찬조액', _fmtAmt(donSum.grandTotal),
                  bold: true, color: _accent),
            ],
          ),
        ],

        // ── 예산 vs 실적 ──
        if (tournament.totalBudget > 0) ...[
          const SizedBox(height: 10),
          _statCard(
            title: '예산 vs 실적',
            icon: Icons.assessment_outlined,
            iconColor: const Color(0xFF7C3AED),
            children: [
              _row('계획 예산', _fmtAmt(tournament.totalBudget)),
              _row('실제 지출', _fmtAmt(actualExpense), color: _expenseFg),
              const Divider(height: 14, color: _cardBorderLight),
              _row(
                budgetRemaining >= 0 ? '예산 잔여' : '예산 초과',
                _fmtAmt(budgetRemaining.abs()),
                bold: true,
                color: budgetRemaining >= 0 ? _incomeFg : _expenseFg,
              ),
            ],
          ),
        ],

        // ── 거래 합계 ──
        const SizedBox(height: 10),
        _statCard(
          title: '거래 합계',
          icon: Icons.swap_vert_rounded,
          iconColor: _incomeIcon,
          children: [
            _row('수입', _fmtAmt(actualIncome), color: _incomeFg),
            _row('지출', _fmtAmt(actualExpense), color: _expenseFg),
            const Divider(height: 14, color: _cardBorderLight),
            _row('잔액', _fmtAmt(balance),
                bold: true, color: balance >= 0 ? _incomeFg : _expenseFg),
          ],
        ),

        if (transactions.isEmpty && shares.isEmpty && donations.isEmpty)
          _emptyHint(),
      ],
    );
  }

  Widget _progressCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String stat1Label,
    required String stat1Value,
    required String stat2Label,
    required String stat2Value,
    required double progress,
    required String progressLabel,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: iconColor)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat1Label,
                        style: const TextStyle(fontSize: 11, color: _muted)),
                    const SizedBox(height: 2),
                    Text(stat1Value,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _ink)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat2Label,
                        style: const TextStyle(fontSize: 11, color: _muted)),
                    const SizedBox(height: 2),
                    Text(stat2Value,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _ink)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFEFF2F7),
                valueColor: AlwaysStoppedAnimation(iconColor),
              ),
            ),
            const SizedBox(height: 5),
            Text(progressLabel,
                style: const TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
      );

  Widget _statCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: iconColor)),
            ]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  Widget _row(String label, String value, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: bold ? _ink : _muted)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color ?? _ink)),
          ],
        ),
      );

  Widget _emptyHint() => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorderLight),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_outlined, size: 36, color: _muted),
            SizedBox(height: 8),
            Text('아직 등록된 재정 정보가 없습니다.',
                style: TextStyle(fontSize: 13, color: _muted)),
            SizedBox(height: 4),
            Text('우측 하단 + 버튼으로 추가해보세요.',
                style: TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
      );
}

// ══════════════════════════════════════════════
// 탭2: 분담금
// ══════════════════════════════════════════════
class _ShareTab extends StatelessWidget {
  final Tournament tournament;
  final List<ClubShare> shares;
  final void Function(ClubShare) onToggle;

  const _ShareTab({
    required this.tournament,
    required this.shares,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (!tournament.hasClubShare) {
      return _emptyState('이 대회는 분담금이 적용되지 않습니다.', icon: Icons.block_outlined);
    }
    if (shares.isEmpty) {
      return _emptyState('등록된 분담금이 없습니다.\n+ 버튼으로 추가하세요.',
          icon: Icons.account_balance_outlined);
    }

    final summary =
        ClubShareSummary.from(tournament.id, tournament.name, shares);

    return Column(children: [
      // 상단 요약
      Container(
        color: const Color(0xFFF1F7FE),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
          _summaryItem('대상', '${summary.totalCount} 클럽', _accent),
          _vDiv(),
          _summaryItem('납부', '${summary.paidCount} 클럽', _incomeFg),
          _vDiv(),
          _summaryItem('수금률',
              '${(summary.collectionRatio * 100).toStringAsFixed(0)}%', _ink),
          _vDiv(),
          _summaryItem('수금액', _fmtAmt(summary.collectedAmount), _ink,
              large: true),
        ]),
      ),
      // 리스트
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
          itemCount: shares.length,
          itemBuilder: (_, i) {
            final s = shares[i];
            return _ShareTile(share: s, onToggle: () => onToggle(s));
          },
        ),
      ),
    ]);
  }

  Widget _summaryItem(String label, String value, Color color,
          {bool large = false}) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontSize: large ? 13 : 14,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ],
        ),
      );

  Widget _vDiv() => Container(
        width: 1,
        height: 24,
        color: const Color(0xFFCFD8E6),
      );
}

class _ShareTile extends StatelessWidget {
  final ClubShare share;
  final VoidCallback onToggle;
  const _ShareTile({required this.share, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final paid = share.paid;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: paid ? Colors.white : const Color(0xFFFFFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: paid ? const Color(0xFFD5DAE1) : const Color(0xFFE8A0A0),
              width: 1.2),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: paid ? const Color(0xFFE8F5EE) : const Color(0xFFFFEBEB),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              share.statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: paid ? _incomeIcon : _expenseIcon,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(share.clubName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _ink)),
                const SizedBox(height: 2),
                Text(
                  paid && share.paidDate != null
                      ? '납부일 ${share.paidDate}'
                      : '미납',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
          Text(share.formattedAmount,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: paid ? _incomeFg : _muted)),
          const SizedBox(width: 4),
          Icon(
            paid ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: paid ? _incomeIcon : const Color(0xFFAAAAAA),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 탭3: 찬조
// ══════════════════════════════════════════════
class _DonationTab extends StatelessWidget {
  final Tournament tournament;
  final List<Donation> donations;
  final void Function(Donation) onToggleAcknowledged;

  const _DonationTab({
    required this.tournament,
    required this.donations,
    required this.onToggleAcknowledged,
  });

  @override
  Widget build(BuildContext context) {
    if (!tournament.acceptsDonation) {
      return _emptyState('이 대회는 찬조를 받지 않습니다.', icon: Icons.block_outlined);
    }
    if (donations.isEmpty) {
      return _emptyState('등록된 찬조가 없습니다.\n+ 버튼으로 추가하세요.',
          icon: Icons.volunteer_activism_outlined);
    }

    final summary = DonationSummary.from(donations,
        tournamentId: tournament.id, tournamentName: tournament.name);

    // 정렬: 미감사 먼저, 그 다음 금액 큰 순
    final sorted = List<Donation>.from(donations)
      ..sort((a, b) {
        if (a.acknowledged != b.acknowledged) {
          return a.acknowledged ? 1 : -1;
        }
        return b.amount.compareTo(a.amount);
      });

    return Column(children: [
      // 상단 요약 (2x2 그리드)
      Container(
        color: const Color(0xFFFFF7E6),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(children: [
          Row(children: [
            _gridItem(
                '개인 현금', summary.individualCashTotal, summary.individualCount),
            const SizedBox(width: 8),
            _gridItem('개인 물품', summary.individualItemTotal, null),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            _gridItem(
                '기업 현금', summary.corporateCashTotal, summary.corporateCount),
            const SizedBox(width: 8),
            _gridItem('기업 물품', summary.corporateItemTotal, null),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFB7791F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('총 찬조액',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text(_fmtAmt(summary.grandTotal),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
        ]),
      ),
      // 리스트
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
          itemCount: sorted.length,
          itemBuilder: (_, i) => _DonationTile(
            donation: sorted[i],
            onTap: () => onToggleAcknowledged(sorted[i]),
          ),
        ),
      ),
    ]);
  }

  Widget _gridItem(String label, int amount, int? count) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _muted)),
                if (count != null) ...[
                  const Spacer(),
                  Text('${count}건',
                      style: const TextStyle(fontSize: 9, color: _muted)),
                ],
              ]),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_fmtAmt(amount),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _ink)),
              ),
            ],
          ),
        ),
      );
}

class _DonationTile extends StatelessWidget {
  final Donation donation;
  final VoidCallback onTap;
  const _DonationTile({required this.donation, required this.onTap});

  Color get _kindColor {
    if (donation.kind == DonationKind.cash) {
      return donation.type == DonationType.individual
          ? _incomeFg
          : const Color(0xFF7C3AED);
    }
    return const Color(0xFFB7791F);
  }

  Color get _kindBg {
    if (donation.kind == DonationKind.cash) {
      return donation.type == DonationType.individual
          ? const Color(0xFFE8F5EE)
          : const Color(0xFFEDE9FE);
    }
    return const Color(0xFFFFEDD8);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD5DAE1), width: 1.2),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kindBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              donation.combinedLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _kindColor,
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
                    child: Text(
                      donation.donorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _ink),
                    ),
                  ),
                  if (donation.acknowledged) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle_rounded,
                        size: 13, color: _incomeIcon),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  [
                    if (donation.kind == DonationKind.item &&
                        donation.itemDescription.isNotEmpty)
                      donation.itemDescription,
                    if (donation.donorClubName != null &&
                        donation.donorClubName!.isNotEmpty)
                      donation.donorClubName!,
                    if (donation.date.isNotEmpty) donation.date,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11, color: _muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(donation.formattedAmount,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 탭4: 거래
// ══════════════════════════════════════════════
class _TxTab extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  const _TxTab({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return _emptyState('이 대회와 관련된 거래내역이 없습니다.',
          icon: Icons.receipt_long_outlined);
    }
    final sorted = List<FinanceTransaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final tx = sorted[i];
        final isIncome = tx.isIncome;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isIncome ? Colors.white : const Color(0xFFFFF8F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isIncome
                    ? const Color(0xFF9BB5D0)
                    : const Color(0xFFE8A0A0),
                width: 1.2),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isIncome
                    ? const Color(0xFFE8F5EE)
                    : const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                size: 18,
                color: isIncome ? _incomeIcon : _expenseIcon,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _ink)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isIncome ? '+' : '-'}${_fmtAmt(tx.amount).replaceAll('-', '')}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isIncome ? _incomeFg : _expenseFg),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF2F7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(tx.category,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _muted)),
                    ),
                    const SizedBox(width: 6),
                    Text(tx.date,
                        style: const TextStyle(fontSize: 11, color: _muted)),
                    if (tx.clubName != null) ...[
                      const Text(' · ',
                          style: TextStyle(fontSize: 11, color: _muted)),
                      Text(tx.clubName!,
                          style: const TextStyle(fontSize: 11, color: _muted)),
                    ],
                  ]),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════
// 공용 빈 상태
// ══════════════════════════════════════════════
Widget _emptyState(String message, {required IconData icon}) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFFCCCCCC)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted)),
          ],
        ),
      ),
    );
