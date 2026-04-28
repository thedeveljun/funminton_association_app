// lib/screens/finance/finance_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_config.dart';
import '../../models/club.dart';
import '../../models/finance_transaction.dart';
import '../../models/tournament.dart';
import '../../models/club_share.dart';
import '../../models/donation.dart';
import '../../models/player.dart';
import '../../models/player_fee_payment.dart';
import '../../services/sample_data.dart';
import 'tournament_finance_screen.dart';

const _bgPage = Color(0xFFF6F7FA);
const _ink = Color(0xFF111111);
const _accent = Color(0xFF5B8ABB);
const _muted = Color(0xFF888888);
const _bannerNavy = Color.fromARGB(255, 10, 36, 92);
const _bannerNavyAlt = Color(0xFF0F2B5F);
const _balanceNavy = Color.fromARGB(255, 12, 37, 102);
const _bannerAddBtn = Color(0xFF2A5A8A);
const _cardBorderLight = Color(0xFFE0E4EC);
const _periodActiveBg = Color(0xFFF5F7FA);

const _incomeFg = Color(0xFF2A7A4A);
const _incomeIcon = Color(0xFF4A9E6B);
const _incomeBg = Color(0xFFE8F5EE);
const _incomeBorder = Color(0xFF9BB5D0);

const _expenseFg = Color(0xFFCC2222);
const _expenseIcon = Color(0xFFCC4444);
const _expenseBg = Color(0xFFFFF0F0);
const _expenseBorder = Color(0xFFE8A0A0);
const _expenseCardBg = Color(0xFFFFF8F8);

const _summaryIncomeFg = Color(0xFF217D46);
const _summaryIncomeBg = Color(0xFFEAF5EE);
const _summaryExpenseFg = Color(0xFFB05B5B);
const _summaryExpenseBg = Color(0xFFFFF0F0);
const _monthlyTitle = Color(0xFF222222);
const _monthlyBalance = Color(0xFF1A3A5C);

const _statusPaidColor = Color(0xFF4A9E6B);
const _statusUnpaidColor = Color(0xFFAAAAAA);
const _statusAllColor = Color(0xFF9DC3E6);
const _amountYellow = Color(0xFFFFC300);

String _fmtAmt(int n) {
  final s = n.abs().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return n < 0 ? '-${s}원' : '${s}원';
}

String _toKoreanFull(int amount) {
  if (amount == 0) return '영원';
  final units = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
  final pos = ['', '십', '백', '천'];
  final bigPos = ['', '만', '억', '조'];
  String result = '';
  int bigIdx = 0;
  int n = amount.abs();
  while (n > 0) {
    final chunk = n % 10000;
    if (chunk != 0) {
      String chunkStr = '';
      int c = chunk;
      for (int i = 0; c > 0; i++) {
        final digit = c % 10;
        if (digit != 0) {
          final d = (digit == 1 && i > 0) ? '' : units[digit];
          chunkStr = '$d${pos[i]}$chunkStr';
        }
        c ~/= 10;
      }
      result = '$chunkStr${bigPos[bigIdx]}$result';
    }
    bigIdx++;
    n ~/= 10000;
  }
  if (amount < 0) result = '마이너스$result';
  return '${result}원';
}

/// 거래 ID에서 시간 추출 (예: 'tx_pfp_1714276823456789' → '14:32')
/// microsecondsSinceEpoch 기반 ID에서만 동작. 추출 실패 시 빈 문자열 반환.
String _extractTimeFromId(String id) {
  // ID에 들어있는 마지막 숫자 시퀀스 찾기 (>= 13자리 = 밀리초 이상)
  final match = RegExp(r'(\d{13,})').firstMatch(id);
  if (match == null) return '';
  final num = int.tryParse(match.group(1)!);
  if (num == null) return '';
  try {
    // microsecondsSinceEpoch (16자리 정도) 또는 millisecondsSinceEpoch (13자리)
    final dt = match.group(1)!.length >= 16
        ? DateTime.fromMicrosecondsSinceEpoch(num)
        : DateTime.fromMillisecondsSinceEpoch(num);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  } catch (_) {
    return '';
  }
}

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
      builder: (_) => _TransactionDialog(
        onSnack: _snack,
        onSave: (tx) => setState(() => _transactions.add(tx)),
      ),
    );
  }

  Future<void> _showEditDialog(FinanceTransaction tx) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransactionDialog(
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
      builder: (_) => _FeePaymentSheet(
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

  @override
  Widget build(BuildContext context) => Scaffold(
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
          title: const Text(
            '재정관리',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded, size: 22, color: _accent),
            ),
          ],
          bottom: TabBar(
            controller: _tc,
            isScrollable: false,
            labelStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            labelColor: _accent,
            unselectedLabelColor: const Color(0xFF888888),
            indicatorColor: _accent,
            indicatorWeight: 2.5,
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
            _FeeTab(onRowTap: _showFeeDialog),
            _IncomeExpenseTab(
              transactions: _transactions,
              onAddTap: _showAddDialog,
              onItemTap: _showEditDialog,
            ),
            _TournamentFinanceTab(transactions: _transactions),
            _SummaryTab(
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

// ══════════════════════════════════════════════
// 탭1: 협회비 납부 (선수별 체크 시스템)
// ══════════════════════════════════════════════
class _FeeTab extends StatelessWidget {
  final void Function(Club) onRowTap;
  const _FeeTab({required this.onRowTap});

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
        color: _bannerNavy,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _StatusChip(
                  label: '완납', count: fullyPaidClubs, color: _statusPaidColor),
              const SizedBox(width: 6),
              _StatusChip(
                label: '일부',
                count: partiallyPaidClubs,
                color: const Color(0xFFFFB347),
                bgColor: const Color(0x33FFB347),
              ),
              const SizedBox(width: 6),
              _StatusChip(
                label: '미납',
                count: unpaidClubs,
                color: _statusUnpaidColor,
                bgColor: const Color(0x33AAAAAA),
              ),
              const SizedBox(width: 6),
              _StatusChip(
                  label: '전체', count: clubs.length, color: _statusAllColor),
            ]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: _AmountSummaryBlock(
                      label: '납부 인원',
                      amount: totalPaidPlayers,
                      color: _amountYellow,
                      suffix: ' / $totalPlayers명',
                      showWon: false)),
              const SizedBox(width: 16),
              Expanded(
                  child: _AmountSummaryBlock(
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
            return _FeeClubRow(
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

class _FeeClubRow extends StatelessWidget {
  final Club club;
  final ClubFeeSummary summary;
  final VoidCallback onTap;

  const _FeeClubRow({
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
      badgeFg = _incomeIcon;
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
      badgeFg = _expenseIcon;
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
                      color: _ink,
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
                  color: isUnpaid ? const Color(0xFF888888) : _ink,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
              if (!isUnpaid) ...[
                const SizedBox(height: 1),
                Text(
                  _fmtAmt(summary.totalPaid),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _incomeFg,
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

// ══════════════════════════════════════════════
// 탭2: 수입/지출 (협회비는 클럽+날짜로 그룹핑)
// ══════════════════════════════════════════════
class _IncomeExpenseTab extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final VoidCallback onAddTap;
  final void Function(FinanceTransaction) onItemTap;
  const _IncomeExpenseTab({
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
    final items = <_DisplayItem>[];
    for (final t in others) {
      items.add(_DisplayItem.single(t));
    }
    for (final batch in feeBatches) {
      if (batch.length == 1) {
        items.add(_DisplayItem.single(batch.first));
      } else {
        items.add(_DisplayItem.feeGroup(batch));
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
        color: _bannerNavyAlt,
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
                  color: _bannerAddBtn,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ),
          Row(children: [
            Expanded(child: _BannerAmountBlock(label: '수입', amount: txIncome)),
            const SizedBox(width: 12),
            Expanded(child: _BannerAmountBlock(label: '지출', amount: txExpense)),
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
                    return _GroupedFeeRow(item: item);
                  }
                  final tx = item.sourceTransactions.first;
                  return _TransactionRow(
                    tx: tx,
                    onTap: () => onItemTap(tx),
                  );
                },
              ),
      ),
    ]);
  }
}

class _BannerAmountBlock extends StatelessWidget {
  final String label;
  final int amount;
  const _BannerAmountBlock({required this.label, required this.amount});

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
            child: Text(_fmtAmt(amount),
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

class _TransactionRow extends StatelessWidget {
  final FinanceTransaction tx;
  final VoidCallback? onTap;
  const _TransactionRow({required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.isIncome;
    final cardBg = isIncome ? Colors.white : _expenseCardBg;
    final cardBorder = isIncome ? _incomeBorder : _expenseBorder;
    final iconBg = isIncome ? _incomeBg : _expenseBg;
    final iconColor = isIncome ? _incomeIcon : _expenseIcon;
    final amountColor = isIncome ? _incomeFg : _expenseFg;

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
                            color: _ink,
                            letterSpacing: -0.3,
                            height: 1.1,
                          )),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isIncome ? '+' : '-'}${_fmtAmt(tx.amount).replaceAll('-', '')}',
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
                        fontSize: 12,
                        color: Color(0xFF666666),
                        letterSpacing: -0.2,
                      )),
                  if (_extractTimeFromId(tx.id).isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(_extractTimeFromId(tx.id),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF888888),
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                  if (tx.clubName != null) ...[
                    const Text(' · ',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF666666))),
                    Text(tx.clubName!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF666666))),
                  ],
                  if (tx.tournamentName != null) ...[
                    const Text(' · ',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF666666))),
                    Flexible(
                      child: Text(tx.tournamentName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF666666))),
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
                            size: 11, color: Color(0xFFB7791F)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            tx.memo!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
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

// ── 수입/지출 표시용 항목 ────────────────────────
class _DisplayItem {
  final String date;
  final List<FinanceTransaction> sourceTransactions;
  final bool isGroup;

  // 그룹 전용
  final String? groupClubName;
  final int? groupTotal;
  final int? groupCount;

  _DisplayItem._({
    required this.date,
    required this.sourceTransactions,
    required this.isGroup,
    this.groupClubName,
    this.groupTotal,
    this.groupCount,
  });

  factory _DisplayItem.single(FinanceTransaction tx) => _DisplayItem._(
        date: tx.date,
        sourceTransactions: [tx],
        isGroup: false,
      );

  factory _DisplayItem.feeGroup(List<FinanceTransaction> txs) {
    final first = txs.first;
    final total = txs.fold<int>(0, (s, t) => s + t.amount);
    return _DisplayItem._(
      date: first.date,
      sourceTransactions: txs,
      isGroup: true,
      groupClubName: first.clubName,
      groupTotal: total,
      groupCount: txs.length,
    );
  }
}

// ── 협회비 그룹 행 ──────────────────────────────
class _GroupedFeeRow extends StatelessWidget {
  final _DisplayItem item;
  const _GroupedFeeRow({required this.item});

  /// 거래 title("중앙 배드민턴 클럽 - 강건우")에서 선수 이름만 추출.
  /// 과거 형식("... 협회비")도 호환 처리.
  String _extractPlayerName(FinanceTransaction tx) {
    final parts = tx.title.split(' - ');
    if (parts.length >= 2) {
      final last = parts.last;
      if (last.endsWith(' 협회비')) {
        return last.substring(0, last.length - ' 협회비'.length);
      }
      return last;
    }
    return tx.title;
  }

  /// ID 문자열에서 timestamp 추출 (정렬용, 접두사 무관)
  int _extractTimestamp(String id) {
    final match = RegExp(r'(\d{13,})').firstMatch(id);
    if (match == null) return 0;
    final raw = int.tryParse(match.group(1)!) ?? 0;
    return match.group(1)!.length >= 16 ? raw ~/ 1000 : raw;
  }

  /// 그룹 내 가장 최근 거래의 시간 추출 (timestamp 기반)
  String _groupLatestTime() {
    if (item.sourceTransactions.isEmpty) return '';
    // timestamp가 가장 큰 거래의 ID에서 시간 추출
    final latest = item.sourceTransactions.reduce(
        (a, b) => _extractTimestamp(a.id) > _extractTimestamp(b.id) ? a : b);
    return _extractTimeFromId(latest.id);
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final txs = item.sourceTransactions;
        final names = txs.map(_extractPlayerName).toList()..sort();
        final maxHeight = MediaQuery.of(context).size.height * 0.7;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E4EC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.groupClubName ?? '',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.4,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      '${item.date} · ${item.groupCount}명 납부 · ${_fmtAmt(item.groupTotal ?? 0)}',
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _cardBorderLight),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: names.length,
                  itemBuilder: (_, i) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF1F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF555555),
                            )),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(names[i],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                              letterSpacing: -0.3,
                            )),
                      ),
                      Text(
                        '+${_fmtAmt(AppConfig.playerFeeUnit).replaceAll('-', '')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _incomeFg,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _incomeBorder, width: 1.4),
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
              color: _incomeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.groups_rounded, size: 18, color: _incomeIcon),
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
                      child: Text(
                        item.groupClubName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${_fmtAmt(item.groupTotal ?? 0).replaceAll('-', '')}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _incomeFg,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Row(children: [
                  Text(item.date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                        letterSpacing: -0.2,
                      )),
                  if (_groupLatestTime().isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(_groupLatestTime(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF888888),
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                  const Text(' · ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.groupCount}명 납부',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _incomeFg,
                      ),
                    ),
                  ),
                ]),
                // 메모: "{년도}년 협회비" 노란 배지
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
                          size: 11, color: Color(0xFFB7791F)),
                      const SizedBox(width: 3),
                      Text(
                        '${DateTime.now().year}년 협회비',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8B6914),
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.expand_more_rounded,
              size: 18, color: Color(0xFFAAAAAA)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 탭3: 대회재정
// ══════════════════════════════════════════════
class _TournamentFinanceTab extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  const _TournamentFinanceTab({required this.transactions});

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
        color: _bannerNavy,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _AmountSummaryBlock(
                    label: '예산 총액', amount: totalBudget, color: _amountYellow)),
            const SizedBox(width: 12),
            Expanded(
                child: _AmountSummaryBlock(
                    label: '시 지원 합계',
                    amount: totalCitySupport,
                    color: const Color(0xFFB6D7FF))),
            const SizedBox(width: 12),
            Expanded(
                child: _AmountSummaryBlock(
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
                itemBuilder: (_, i) => _TournamentFinanceCard(
                  tournament: tournaments[i],
                  transactions: transactions,
                  shares: SampleData.clubShares,
                  donations: SampleData.donations,
                ),
              ),
      ),
    ]);
  }
}

class _TournamentFinanceCard extends StatelessWidget {
  final Tournament tournament;
  final List<FinanceTransaction> transactions;
  final List<ClubShare> shares;
  final List<Donation> donations;

  const _TournamentFinanceCard({
    required this.tournament,
    required this.transactions,
    required this.shares,
    required this.donations,
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
        return _incomeIcon;
      case 'completed':
        return const Color(0xFF888888);
      default:
        return _accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shareSummary =
        ClubShareSummary.from(tournament.id, tournament.name, shares);
    final donationSummary = DonationSummary.from(donations,
        tournamentId: tournament.id, tournamentName: tournament.name);

    final relatedTx =
        transactions.where((t) => t.tournamentId == tournament.id).toList();
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
          border: Border.all(color: _cardBorderLight, width: 1.2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
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
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFFAAAAAA)),
            ]),
            const SizedBox(height: 8),
            Text(
              tournament.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${tournament.startDate}${tournament.endDate.isNotEmpty && tournament.endDate != tournament.startDate ? ' ~ ${tournament.endDate}' : ''}'
              '${tournament.region.isNotEmpty ? ' · ${tournament.region}' : ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
            if (tournament.totalBudget > 0) ...[
              const SizedBox(height: 12),
              _budgetRow(tournament),
            ],
            if (tournament.hasClubShare && shareSummary.totalCount > 0) ...[
              const SizedBox(height: 10),
              _shareRow(shareSummary),
            ],
            if (tournament.acceptsDonation &&
                donationSummary.grandTotal > 0) ...[
              const SizedBox(height: 8),
              _donationRow(donationSummary),
            ],
            if (relatedTx.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: _cardBorderLight),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _smallStat('실제 수입', actualIncome, _incomeFg),
                ),
                Expanded(
                  child: _smallStat('실제 지출', actualExpense, _expenseFg),
                ),
                Expanded(
                  child: _smallStat(
                      '잔액', actualIncome - actualExpense, _monthlyBalance),
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
                  fontSize: 11, fontWeight: FontWeight.w700, color: _muted)),
          const Spacer(),
          Text(t.formattedBudget,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
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
            const _Dot(color: Color(0xFF6FA8E6)),
            const SizedBox(width: 4),
            Text('시 ${t.formattedCitySupport}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
            const SizedBox(width: 8),
          ],
          const _Dot(color: Color(0xFFFFD0D0)),
          const SizedBox(width: 4),
          Text('협회 ${t.formattedAssociationBurden}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
        ]),
      ],
    );
  }

  Widget _shareRow(ClubShareSummary s) {
    final pct = (s.collectionRatio * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.account_balance_outlined, size: 14, color: _accent),
        const SizedBox(width: 6),
        const Text('분담금',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _accent)),
        const SizedBox(width: 8),
        Text('${s.paidCount}/${s.totalCount} 클럽 · $pct%',
            style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
        const Spacer(),
        Text('${_fmtAmt(s.collectedAmount)} / ${_fmtAmt(s.totalAmount)}',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: _ink)),
      ]),
    );
  }

  Widget _donationRow(DonationSummary d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.volunteer_activism_outlined,
            size: 14, color: Color(0xFFB7791F)),
        const SizedBox(width: 6),
        const Text('찬조',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB7791F))),
        const SizedBox(width: 8),
        Text('개인 ${d.individualCount} · 기업 ${d.corporateCount}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
        const Spacer(),
        Text(_fmtAmt(d.grandTotal),
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: _ink)),
      ]),
    );
  }

  Widget _smallStat(String label, int amount, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: _muted)),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_fmtAmt(amount),
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

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

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

// ══════════════════════════════════════════════
// 탭4: 요약
// ══════════════════════════════════════════════
class _SummaryTab extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final String period;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final void Function(String, DateTime?, DateTime?) onPeriodChanged;

  const _SummaryTab({
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
        _PeriodSelector(
          current: period,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          onChanged: onPeriodChanged,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: _balanceNavy,
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
              child: Text(_fmtAmt(balance),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.8,
                    height: 1.1,
                  )),
            ),
            const SizedBox(height: 2),
            Text(_toKoreanFull(balance),
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
              child: _SummaryAmtCard(
                  label: '총 수입',
                  amount: income,
                  color: _summaryIncomeFg,
                  bgColor: _summaryIncomeBg,
                  icon: Icons.arrow_upward_rounded)),
          const SizedBox(width: 8),
          Expanded(
              child: _SummaryAmtCard(
                  label: '총 지출',
                  amount: expense,
                  color: _summaryExpenseFg,
                  bgColor: _summaryExpenseBg,
                  icon: Icons.arrow_downward_rounded)),
        ]),
        const SizedBox(height: 16),
        const Text('월별 수입/지출',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _monthlyTitle,
              letterSpacing: -0.3,
            )),
        const SizedBox(height: 8),
        if (months.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cardBorderLight),
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
            return _MonthlyRow(
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

class _SummaryAmtCard extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final Color bgColor;
  final IconData icon;
  const _SummaryAmtCard({
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
              child: Text(_fmtAmt(amount),
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

class _MonthlyRow extends StatelessWidget {
  final String label;
  final int income, expense, balance;
  const _MonthlyRow({
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
          border: Border.all(color: _cardBorderLight),
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
                  color: _monthlyTitle,
                  letterSpacing: -0.3,
                )),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _MonthItem(
                      label: '수입', amount: income, color: _incomeIcon)),
              Expanded(
                  child: _MonthItem(
                      label: '지출', amount: expense, color: _summaryExpenseFg)),
              Expanded(
                  child: _MonthItem(
                      label: '잔액',
                      amount: balance,
                      color:
                          balance >= 0 ? _monthlyBalance : _summaryExpenseFg)),
            ]),
          ],
        ),
      );
}

class _MonthItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  const _MonthItem(
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
            child: Text(_fmtAmt(amount),
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

class _PeriodSelector extends StatelessWidget {
  final String current;
  final DateTime rangeStart, rangeEnd;
  final void Function(String, DateTime?, DateTime?) onChanged;
  const _PeriodSelector({
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
        border: Border.all(color: _cardBorderLight),
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
                    color: current == p ? _accent : _periodActiveBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: current == p ? _accent : const Color(0xFFD5DAE1),
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
                  color: _accent,
                  fontWeight: FontWeight.w600,
                )),
          ],
          if (current == '이번달') ...[
            const SizedBox(height: 8),
            Text('${rangeStart.year}년 ${rangeStart.month}월',
                style: const TextStyle(
                  fontSize: 13,
                  color: _accent,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ],
      ),
    );
  }
}

// ── 회비납부 탭 보조 위젯 ────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color? bgColor;
  const _StatusChip({
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

class _AmountSummaryBlock extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final String? suffix;
  final bool showWon;

  const _AmountSummaryBlock({
    required this.label,
    required this.amount,
    required this.color,
    this.suffix,
    this.showWon = true,
  });

  String _formatted() {
    if (showWon) return _fmtAmt(amount);
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
                fontSize: 12,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.4,
                )),
          ),
        ],
      );
}

// ══════════════════════════════════════════════
// 항목 추가 다이얼로그
// ══════════════════════════════════════════════
String _todayStr() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

InputDecoration _financeInputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF5F81A7), width: 1.5),
      ),
    );

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _DlgField extends StatelessWidget {
  final String label;
  final Widget child;
  const _DlgField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5F6B7A),
                )),
            const SizedBox(height: 5),
            child,
          ],
        ),
      );
}

class _TransactionDialog extends StatefulWidget {
  final FinanceTransaction? initial;
  final void Function(FinanceTransaction) onSave;
  final VoidCallback? onDelete;
  final void Function(String) onSnack;
  const _TransactionDialog({
    this.initial,
    required this.onSave,
    this.onDelete,
    required this.onSnack,
  });

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  late bool _isIncome;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _memoCtrl;
  late String _date;

  bool get _isEdit => widget.initial != null;

  String _formatThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _isIncome = init?.isIncome ?? true;
    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _amountCtrl = TextEditingController(
        text: init != null ? _formatThousands(init.amount) : '');
    _memoCtrl = TextEditingController(text: init?.memo ?? '');
    _date = init?.date ?? _todayStr();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  DateTime _parseDate(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final amount = int.tryParse(
            _amountCtrl.text.replaceAll(',', '').replaceAll('원', '').trim()) ??
        0;
    if (title.isEmpty) {
      widget.onSnack('항목명을 입력해주세요.');
      return;
    }
    if (amount <= 0) {
      widget.onSnack('금액을 입력해주세요.');
      return;
    }
    final init = widget.initial;
    final tx = FinanceTransaction(
      id: init?.id ?? 'u_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      amount: amount,
      isIncome: _isIncome,
      category: init?.category ?? '기타',
      date: _date,
      clubId: init?.clubId,
      clubName: init?.clubName,
      tournamentId: init?.tournamentId,
      tournamentName: init?.tournamentName,
      memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
    );
    widget.onSave(tx);
    Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('항목 삭제',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: const Text('이 내역을 삭제하시겠습니까?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF555555))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제',
                style:
                    TextStyle(color: _expenseFg, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.onDelete?.call();
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _typeBtn(String label, bool incomeKind, Color activeColor) {
    final selected = _isIncome == incomeKind;
    return GestureDetector(
      onTap: () => setState(() => _isIncome = incomeKind),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        decoration: BoxDecoration(
          color: selected ? activeColor : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF888888),
            )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? '항목 수정' : '항목 추가',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  )),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _typeBtn('수입', true, _incomeIcon)),
                const SizedBox(width: 8),
                Expanded(child: _typeBtn('지출', false, _summaryExpenseFg)),
              ]),
              const SizedBox(height: 10),
              _DlgField(
                label: '항목명',
                child: TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: _financeInputDeco('예: 대관료'),
                ),
              ),
              _DlgField(
                label: '금액 (원)',
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                    _ThousandsFormatter(),
                  ],
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: _financeInputDeco('입력'),
                ),
              ),
              _DlgField(
                label: '날짜',
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _parseDate(_date),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _date =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                    }
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFB8BEC9)),
                    ),
                    child: Row(children: [
                      Text(_date,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _ink,
                          )),
                      const Spacer(),
                      const Icon(Icons.calendar_today_outlined,
                          size: 15, color: Color(0xFF888888)),
                    ]),
                  ),
                ),
              ),
              _DlgField(
                label: '메모',
                child: TextField(
                  controller: _memoCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _financeInputDeco('예: 자체대회'),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                if (_isEdit) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _confirmDelete,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _expenseBorder),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('삭제',
                          style: TextStyle(
                              color: _expenseFg, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFB6BCC8)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('취소',
                        style: TextStyle(color: Color(0xFF555555))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(_isEdit ? '저장' : '추가',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════
// 협회비 선수별 납부 체크 시트 (가나다순 정렬)
// ══════════════════════════════════════════════
class _FeePaymentSheet extends StatefulWidget {
  final Club club;
  final void Function(Player) onPay;
  final void Function(Player) onCancel;

  const _FeePaymentSheet({
    required this.club,
    required this.onPay,
    required this.onCancel,
  });

  @override
  State<_FeePaymentSheet> createState() => _FeePaymentSheetState();
}

class _FeePaymentSheetState extends State<_FeePaymentSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  /// 선택된 선수들의 ID Set (미납자 중에서만 선택 가능)
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 클럽 소속 선수 리스트 (이름 가나다순 정렬)
  List<Player> get _clubPlayers {
    final list =
        SampleData.players.where((p) => p.clubId == widget.club.id).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// 검색 필터링된 선수 리스트
  List<Player> get _filteredPlayers {
    if (_query.trim().isEmpty) return _clubPlayers;
    final q = _query.trim().toLowerCase();
    return _clubPlayers.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.gradeShort.toLowerCase().contains(q) ||
          p.phone.contains(q);
    }).toList();
  }

  /// 검색 결과 중 미납자 (선택 가능한 대상)
  List<Player> get _filteredUnpaid =>
      _filteredPlayers.where((p) => !_isPaid(p)).toList();

  /// 전체 선택 상태:
  /// - 검색 결과의 미납자 모두 선택됨 → true
  /// - 일부만 선택됨 → null (indeterminate)
  /// - 아무도 선택 안됨 → false
  bool? get _selectAllState {
    final unpaid = _filteredUnpaid;
    if (unpaid.isEmpty) return false;
    final selectedInView =
        unpaid.where((p) => _selectedIds.contains(p.id)).length;
    if (selectedInView == 0) return false;
    if (selectedInView == unpaid.length) return true;
    return null; // 일부 선택
  }

  /// 특정 선수의 올해 납부 여부
  bool _isPaid(Player player) {
    final yr = DateTime.now().year;
    return SampleData.playerFeePayments
        .any((p) => p.playerId == player.id && p.year == yr);
  }

  /// 클럽 전체 납부 현황 집계
  ClubFeeSummary get _summary {
    final players = _clubPlayers;
    return ClubFeeSummary.from(
      clubId: widget.club.id,
      clubName: widget.club.name,
      totalPlayers: players.length,
      allPayments: SampleData.playerFeePayments,
    );
  }

  /// 미납 선수 행 탭 → 선택 토글
  void _toggleSelection(Player player) {
    if (_isPaid(player)) return; // 이미 납부된 선수는 토글 안함
    setState(() {
      if (_selectedIds.contains(player.id)) {
        _selectedIds.remove(player.id);
      } else {
        _selectedIds.add(player.id);
      }
    });
  }

  /// 전체 선택/해제 (검색 결과의 미납자 대상)
  void _toggleSelectAll() {
    final unpaid = _filteredUnpaid;
    if (unpaid.isEmpty) return;
    setState(() {
      final state = _selectAllState;
      if (state == true) {
        // 전체 해제 (검색 결과의 미납자만)
        for (final p in unpaid) {
          _selectedIds.remove(p.id);
        }
      } else {
        // 전체 선택 (검색 결과의 미납자만)
        for (final p in unpaid) {
          _selectedIds.add(p.id);
        }
      }
    });
  }

  /// 선택 전체 해제 (검색 무관, 모두 해제)
  void _clearAllSelection() {
    setState(() => _selectedIds.clear());
  }

  /// 이미 납부된 선수 길게 눌러서 → 납부 취소
  Future<void> _onLongPressPaidPlayer(Player player) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('납부 취소',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${player.name} (${player.gradeShort}조)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '납부를 취소하시겠습니까?\n(연결된 수입 거래도 함께 삭제됩니다)',
              style: TextStyle(fontSize: 13, color: _ink),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('아니오', style: TextStyle(color: Color(0xFF555555))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('취소하기',
                style:
                    TextStyle(color: _expenseFg, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.onCancel(player);
      if (mounted) setState(() {});
    }
  }

  /// 선택된 선수들 일괄 납부 처리
  Future<void> _payAllSelected() async {
    final selectedPlayers =
        _clubPlayers.where((p) => _selectedIds.contains(p.id)).toList();
    if (selectedPlayers.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('일괄 납부',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
          '선택된 선수 ${selectedPlayers.length}명을 납부 처리하시겠습니까?\n'
          '총 ${_fmtAmt(selectedPlayers.length * AppConfig.playerFeeUnit)}',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF555555))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('납부 처리',
                style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      for (final p in selectedPlayers) {
        widget.onPay(p);
      }
      if (mounted) {
        setState(() => _selectedIds.clear());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final filtered = _filteredPlayers;
    final selectAll = _selectAllState;
    final selectedCount = _selectedIds.length;
    final selectedAmount = selectedCount * AppConfig.playerFeeUnit;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E4EC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── 헤더 (납부인원 + 납부금액) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.club.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_bannerNavy, _bannerNavyAlt],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '납부 인원',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.75),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${s.paidPlayers}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: _amountYellow,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / ${s.totalPlayers}명',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.85),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.18),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '납부 금액',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.75),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _fmtAmt(s.totalPaid),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),

            // ── 전체 선택 바 ⭐ NEW ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: InkWell(
                onTap: _toggleSelectAll,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFD5DAE1), width: 1),
                  ),
                  child: Row(children: [
                    // 전체 선택 체크박스 (3-state)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selectAll == true
                            ? _accent
                            : (selectAll == null
                                ? _accent.withOpacity(0.3)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: selectAll == false
                              ? const Color(0xFFB8BEC9)
                              : _accent,
                          width: 1.6,
                        ),
                      ),
                      child: selectAll == true
                          ? const Icon(Icons.check,
                              size: 15, color: Colors.white)
                          : selectAll == null
                              ? const Icon(Icons.remove,
                                  size: 15, color: Colors.white)
                              : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '전체 선택',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selectAll == false
                            ? const Color(0xFF555555)
                            : _accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(미납자 ${_filteredUnpaid.length}명)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF555555),
                      ),
                    ),
                    const Spacer(),
                    if (selectedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$selectedCount명 선택',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),

            // ── 검색창 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 15, height: 1.0),
                  decoration: InputDecoration(
                    hintText: '선수 이름 검색',
                    hintStyle: const TextStyle(
                        fontSize: 14, color: Color(0xFFAAAAAA), height: 1.0),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: Color(0xFF888888)),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.clear,
                                size: 18, color: Color(0xFF888888)),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF5F6F8),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _accent, width: 1.4),
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: _cardBorderLight),

            // ── 선수 리스트 ──
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(children: [
                          const Icon(Icons.person_search_outlined,
                              size: 36, color: Color(0xFFCCCCCC)),
                          const SizedBox(height: 8),
                          Text(
                            _query.isEmpty ? '소속 선수가 없습니다' : '검색 결과가 없습니다',
                            style: const TextStyle(fontSize: 13, color: _muted),
                          ),
                        ]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        final paid = _isPaid(p);
                        return _PlayerCheckTile(
                          player: p,
                          paid: paid,
                          selected: _selectedIds.contains(p.id),
                          unitFee: AppConfig.playerFeeUnit,
                          onTap: () => paid
                              ? _onLongPressPaidPlayer(p)
                              : _toggleSelection(p),
                          onLongPress:
                              paid ? () => _onLongPressPaidPlayer(p) : null,
                        );
                      },
                    ),
            ),

            const Divider(height: 1, color: _cardBorderLight),

            // ── 하단 액션 영역 ⭐ 변경 ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 10, 20, 10 + MediaQuery.of(context).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 선택 정보
                  if (selectedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '선택 ${selectedCount}명',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            _fmtAmt(selectedAmount),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _incomeFg,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 버튼들
                  Row(children: [
                    // 선택 해제 버튼 (선택된 게 있을 때만 활성)
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed:
                            selectedCount > 0 ? _clearAllSelection : null,
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('선택 해제'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: selectedCount > 0
                                  ? const Color(0xFFB6BCC8)
                                  : const Color(0xFFE0E4EC)),
                          foregroundColor: selectedCount > 0
                              ? const Color(0xFF555555)
                              : const Color(0xFFAAAAAA),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 납부 처리 버튼
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: selectedCount > 0 ? _payAllSelected : null,
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(selectedCount > 0
                            ? '${selectedCount}명 납부 처리'
                            : '선수 선택 후 납부'),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE0E4EC),
                          disabledForegroundColor: const Color(0xFF888888),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 선수별 체크 행 (3가지 상태: 미납/선택중/납부완료)
class _PlayerCheckTile extends StatelessWidget {
  final Player player;
  final bool paid;
  final bool selected;
  final int unitFee;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PlayerCheckTile({
    required this.player,
    required this.paid,
    required this.selected,
    required this.unitFee,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // 3가지 상태 색상
    final Color tileBg;
    final Color checkBg;
    final Color checkBorder;
    final IconData? checkIcon;

    if (paid) {
      // 납부 완료: 연한 초록
      tileBg = const Color(0xFFF6FBF7);
      checkBg = _incomeIcon;
      checkBorder = _incomeIcon;
      checkIcon = Icons.check;
    } else if (selected) {
      // 선택 중: 연한 파랑
      tileBg = const Color(0xFFEFF5FB);
      checkBg = _accent;
      checkBorder = _accent;
      checkIcon = Icons.check;
    } else {
      // 미납: 흰색
      tileBg = Colors.transparent;
      checkBg = Colors.white;
      checkBorder = const Color(0xFFB8BEC9);
      checkIcon = null;
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        color: tileBg,
        child: Row(
          children: [
            // 체크박스
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: checkBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: checkBorder, width: 1.6),
              ),
              child: checkIcon != null
                  ? Icon(checkIcon, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            // 선수 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: paid ? const Color(0xFF555555) : _ink,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF1F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        player.gradeShort,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF555555),
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      player.gender,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 1),
                  Text(
                    player.regNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            // 우측 상태
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  paid ? '납부' : (selected ? '선택' : '미납'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: paid
                        ? _incomeFg
                        : (selected ? _accent : const Color(0xFF666666)),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  paid || selected
                      ? _fmtAmt(unitFee).replaceAll('-', '')
                      : '${unitFee.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: paid
                        ? _incomeFg
                        : (selected ? _accent : const Color(0xFF555555)),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
