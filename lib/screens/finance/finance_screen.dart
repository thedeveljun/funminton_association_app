// lib/screens/finance/finance_screen.dart
//
// 재정 관리 메인 화면 (4-탭 구조).
//
// 탭 구성:
//   1) 협회비 (FeeTab)         - 클럽별 협회비 납부 현황
//   2) 수입/지출 (IncomeExpenseTab) - 거래 내역 + 항목 추가/수정
//   3) 대회재정 (TournamentFinanceTab) - 대회별 예산/실적
//   4) 요약 (SummaryTab)        - 기간별 통계
//
// 모든 자식 위젯/헬퍼/상수는 widgets/widgets.dart (barrel)에서 가져옵니다.

import 'package:flutter/material.dart';

import '../../core/constants/app_config.dart';
import '../../models/club.dart';
import '../../models/club_share.dart';
import '../../models/finance_transaction.dart';
import '../../models/player.dart';
import '../../models/player_fee_payment.dart';
import '../../models/tournament.dart';
import '../../services/sample_data.dart';
import 'widgets/widgets.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  String _summaryPeriod = '전체';
  late DateTime _rangeStart;
  late DateTime _rangeEnd;

  /// SampleData.transactions를 직접 참조하는 게터.
  /// → 모든 추가/수정/삭제가 즉시 영구 반영되어 화면 전환 후에도 유지됨
  List<FinanceTransaction> get _transactions => SampleData.transactions;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, 1, 1);
    _rangeEnd = now;
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showAddDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransactionDialog(
        onSnack: _snack,
        onSave: (tx) => setState(() => _transactions.add(tx)),
      ),
    );
  }

  Future<void> _showEditDialog(FinanceTransaction tx) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransactionDialog(
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FeePaymentSheet(
        club: club,
        onPay: (player) {
          // 선수 1명 납부 처리: PlayerFeePayment + FinanceTransaction 동시 생성
          final ts = DateTime.now().microsecondsSinceEpoch;
          final paymentId = 'pfp_$ts';
          final txId = 'tx_$paymentId';
          final today =
              '${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
          final memo = '${DateTime.now().year}년 협회비';

          final payment = PlayerFeePayment(
            id: paymentId,
            playerId: player.id,
            playerName: player.name,
            clubId: player.clubId,
            clubName: player.clubName,
            year: DateTime.now().year,
            amount: AppConfig.playerFeeUnit,
            date: today,
            txId: txId,
            memo: memo,
          );

          final tx = FinanceTransaction(
            id: txId,
            title: '${player.clubName} - ${player.name}',
            amount: AppConfig.playerFeeUnit,
            isIncome: true,
            category: '협회비',
            date: today,
            clubId: player.clubId,
            clubName: player.clubName,
            memo: memo,
          );

          SampleData.playerFeePayments.add(payment);
          _transactions.add(tx);
          setState(() {});
        },
        onCancel: (player) {
          // 선수 납부 취소: 해당 선수의 올해 납부 + 연결 거래 삭제
          final yr = DateTime.now().year;
          final removed = SampleData.playerFeePayments
              .where((p) => p.playerId == player.id && p.year == yr)
              .toList();
          for (final p in removed) {
            if (p.txId != null) {
              _transactions.removeWhere((t) => t.id == p.txId);
            }
          }
          SampleData.playerFeePayments
              .removeWhere((p) => p.playerId == player.id && p.year == yr);
          setState(() {});
        },
      ),
    );
  }

  // ── 분담금 추가/수정 ──────────────────────
  Future<void> _showShareForm(Tournament tournament,
      {ClubShare? editing}) async {
    final result = await showModalBottomSheet<ClubShareFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClubShareFormSheet(
        tournament: tournament,
        existingShares: SampleData.clubShares,
        editing: editing,
      ),
    );

    if (result == null) return;

    setState(() {
      switch (result.action) {
        case ClubShareFormAction.add:
          SampleData.clubShares.add(result.share);
          // 납부 체크된 상태로 등록되면 거래도 같이 생성
          if (result.share.paid) {
            final txId = result.share.txId ??
                'tx_cs_${DateTime.now().microsecondsSinceEpoch}';
            _transactions.add(_buildShareTx(result.share, txId));
            // 거래 ID를 분담금에 연결 (replace)
            final idx = SampleData.clubShares
                .indexWhere((s) => s.id == result.share.id);
            if (idx != -1) {
              SampleData.clubShares[idx] =
                  SampleData.clubShares[idx].copyWith(txId: txId);
            }
          }
          _snack('${result.share.clubName} 분담금 등록 완료');
          break;

        case ClubShareFormAction.update:
          final idx =
              SampleData.clubShares.indexWhere((s) => s.id == result.share.id);
          if (idx == -1) break;
          final old = SampleData.clubShares[idx];

          // 기존 거래가 있으면 일단 제거
          if (old.txId != null) {
            _transactions.removeWhere((t) => t.id == old.txId);
          }

          // 새 거래 생성 (납부 상태일 때만)
          ClubShare updated = result.share;
          if (updated.paid) {
            final newTxId =
                old.txId ?? 'tx_cs_${DateTime.now().microsecondsSinceEpoch}';
            _transactions.add(_buildShareTx(updated, newTxId));
            updated = updated.copyWith(txId: newTxId);
          } else {
            // 미납으로 바뀐 경우 txId 끊기 — copyWith는 null을 보존하지 못하므로 직접 생성
            updated = ClubShare(
              id: updated.id,
              tournamentId: updated.tournamentId,
              tournamentName: updated.tournamentName,
              clubId: updated.clubId,
              clubName: updated.clubName,
              amount: updated.amount,
              paid: updated.paid,
              paidDate: updated.paidDate,
              txId: null,
              memo: updated.memo,
            );
          }
          SampleData.clubShares[idx] = updated;
          _snack('${updated.clubName} 분담금 수정 완료');
          break;

        case ClubShareFormAction.delete:
          // 연결된 거래도 함께 제거
          if (result.share.txId != null) {
            _transactions.removeWhere((t) => t.id == result.share.txId);
          }
          SampleData.clubShares.removeWhere((s) => s.id == result.share.id);
          _snack('${result.share.clubName} 분담금 삭제됨');
          break;
      }
    });
  }

  /// 분담금 → FinanceTransaction 변환
  FinanceTransaction _buildShareTx(ClubShare s, String txId) {
    return FinanceTransaction(
      id: txId,
      title: '${s.tournamentName} - ${s.clubName}',
      amount: s.amount,
      isIncome: true,
      category: '분담금',
      date: s.paidDate ?? todayStr(),
      clubId: s.clubId,
      clubName: s.clubName,
      tournamentId: s.tournamentId,
      tournamentName: s.tournamentName,
      memo: s.memo,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBgPage,
        appBar: AppBar(
          backgroundColor: kBgPage,
          surfaceTintColor: kBgPage,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: -4,
          leadingWidth: 34,
          leading: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: kInk),
          ),
          title: const Text(
            '재정관리',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded, size: 22, color: kAccent),
            ),
          ],
          bottom: TabBar(
            controller: _tc,
            isScrollable: false,
            labelStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            labelColor: kBannerNavy,
            unselectedLabelColor: const Color(0xFF333333),
            indicatorColor: kBannerNavy,
            indicatorWeight: 2.5,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: const [
              Tab(text: '협회비'),
              Tab(text: '수입/지출'),
              Tab(text: '대회재정'),
              Tab(text: '요약'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tc,
          children: [
            FeeTab(onRowTap: _showFeeDialog),
            IncomeExpenseTab(
              transactions: _transactions,
              onAddTap: _showAddDialog,
              onItemTap: _showEditDialog,
            ),
            TournamentFinanceTab(
              transactions: _transactions,
              onShareAdd: (t) => _showShareForm(t),
              onShareEdit: (t) => _showShareForm(t),
            ),
            SummaryTab(
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
