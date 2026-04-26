// ══════════════════════════════════════════════
//  TournamentListScreen
// ══════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/tournament.dart';
import '../../models/player.dart';
import '../../models/finance.dart';
import '../../services/sample_data.dart';
import '../../widgets/common/common_widgets.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  List<Tournament> _byStatus(String status) =>
      SampleData.tournaments.where((t) => t.status == status).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppHeader(
        title: '대회운영',
        onBack: () => Navigator.pop(context),
        trailing: TextButton(
          onPressed: () {},
          child: const Text('＋ 대회',
            style: TextStyle(color: AppColors.blue2, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.blue,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.blue,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [Tab(text: '진행중'), Tab(text: '예정'), Tab(text: '완료')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _TournamentTab(list: _byStatus('ongoing')),
                _TournamentTab(list: _byStatus('upcoming')),
                _TournamentTab(list: _byStatus('completed')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentTab extends StatelessWidget {
  final List<Tournament> list;
  const _TournamentTab({required this.list});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return const EmptyView(emoji: '🏆', message: '대회가 없습니다',
        subMessage: '＋ 대회 버튼으로 새 대회를 등록하세요');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: list.map((t) => _TourneyCard(t: t)).toList(),
    );
  }
}

class _TourneyCard extends StatelessWidget {
  final Tournament t;
  const _TourneyCard({required this.t});

  @override
  Widget build(BuildContext context) {
    StatusBadge badge;
    switch (t.status) {
      case 'ongoing':   badge = StatusBadge.ongoing(); break;
      case 'upcoming':  badge = StatusBadge.upcoming(); break;
      default:          badge = StatusBadge.completed();
    }

    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray2, width: .5),
        ),
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(t.name,
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
            ),
            badge,
          ]),
          const SizedBox(height: 4),
          Text('${t.startDate} ~ ${t.endDate}',
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _tag(t.eventType),
            _tag(t.venue),
            _tag('참가 ${t.participantCount}명'),
            if (t.entryFee > 0)
              _tag('참가비 ${_fmt(t.entryFee)}원'),
          ]),
          if (t.status == 'ongoing') ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: t.progressPercent / 100,
                backgroundColor: AppColors.gray2,
                color: AppColors.blue2,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${t.progressPercent}% 진행',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ),
          ],
          if (t.status == 'upcoming') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('참가 신청 관리'),
              ),
            ),
          ],
          if (t.status == 'completed') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('결과 / 성적 보기'),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.gray, borderRadius: BorderRadius.circular(8)),
    child: Text(text,
      style: const TextStyle(fontSize: 11, color: AppColors.text2)),
  );

  String _fmt(int n) => n.toString()
    .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ══════════════════════════════════════════════
//  FinanceScreen
// ══════════════════════════════════════════════
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _txFilter = '전체';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  int get _totalIncome => sampleTransactions
    .where((t) => t.isIncome).fold(0, (s, t) => s + t.amount);
  int get _totalExpense => sampleTransactions
    .where((t) => !t.isIncome).fold(0, (s, t) => s + t.amount);
  int get _balance => _totalIncome - _totalExpense;

  String _fmt(int n) => n.toString()
    .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppHeader(title: '재정관리', onBack: () => Navigator.pop(context)),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.blue,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.blue,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [Tab(text: '협회비 납부'), Tab(text: '수입/지출'), Tab(text: '요약')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _ClubFeeTab(),
                _IncomeExpenseTab(income: _totalIncome, expense: _totalExpense,
                  filter: _txFilter, onFilter: (v) => setState(() => _txFilter = v)),
                _SummaryTab(income: _totalIncome, expense: _totalExpense,
                  balance: _balance, fmt: _fmt),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 협회비 납부 탭 ────────────────────────────
class _ClubFeeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sampleClubs = SampleData.clubs;
    final paidCount = sampleClubs.where((c) => c.feePaid).length;
    final unpaidCount = sampleClubs.length - paidCount;

    return ListView(
      children: [
        Container(
          color: AppColors.blue,
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              _statChip('납부 ${paidCount}개', AppColors.green2),
              const SizedBox(width: 8),
              _statChip('미납 ${unpaidCount}개', AppColors.gray3),
              const SizedBox(width: 8),
              _statChip('전체 ${sampleClubs.length}개', AppColors.blue2),
            ]),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('납부총액',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
                  Text('${paidCount * 300000 ~/ 10000}만원',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: Colors.white)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('미납총액',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
                  Text('${unpaidCount * 300000 ~/ 10000}만원',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: Color(0xFFFC8181))),
                ]),
              ],
            ),
          ]),
        ),
        ...sampleClubs.map((club) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.gray2))),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: club.feePaid ? AppColors.green3 : AppColors.gray2,
                shape: BoxShape.circle),
              child: Center(
                child: Text(club.initials,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: club.feePaid ? AppColors.gradeBTxt : AppColors.text2))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(club.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${club.venue} · ${club.memberCount}명',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              club.feePaid ? StatusBadge.paid() : StatusBadge.unpaid(),
              const SizedBox(height: 4),
              Text('300,000원',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: club.feePaid ? AppColors.green2 : AppColors.red)),
            ]),
          ]),
        )),
      ],
    );
  }

  Widget _statChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color, borderRadius: BorderRadius.circular(12)),
    child: Text(text,
      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

// ── 수입/지출 탭 ──────────────────────────────
class _IncomeExpenseTab extends StatelessWidget {
  final int income, expense;
  final String filter;
  final ValueChanged<String> onFilter;

  const _IncomeExpenseTab({
    required this.income, required this.expense,
    required this.filter, required this.onFilter});

  String _fmt(int n) => n.toString()
    .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  List<FinanceTransaction> get _filtered {
    if (filter == '수입') return sampleTransactions.where((t) => t.isIncome).toList();
    if (filter == '지출') return sampleTransactions.where((t) => !t.isIncome).toList();
    return sampleTransactions;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 배너
        Container(
          color: AppColors.blue,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('수입', style: TextStyle(fontSize: 11, color: Colors.white70)),
              Text('${_fmt(income)}원',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('지출', style: TextStyle(fontSize: 11, color: Colors.white70)),
              Text('${_fmt(expense)}원',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: Color(0xFFFC8181))),
            ])),
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppColors.blue2, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add, color: Colors.white, size: 22)),
            ),
          ]),
        ),
        // 필터
        FilterChipRow(
          items: ['전체', '수입', '지출'],
          selected: filter,
          onChanged: onFilter,
        ),
        // 리스트
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (ctx, i) {
              final tx = _filtered[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.gray2))),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: tx.isIncome ? AppColors.green3 : AppColors.red3,
                      shape: BoxShape.circle),
                    child: Center(
                      child: Text(tx.isIncome ? '↑' : '↓',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: tx.isIncome ? AppColors.green : AppColors.red))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tx.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(tx.date,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ])),
                  Text(tx.formattedAmount,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: tx.isIncome ? AppColors.green2 : AppColors.red)),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── 요약 탭 ──────────────────────────────────
class _SummaryTab extends StatelessWidget {
  final int income, expense, balance;
  final String Function(int) fmt;

  const _SummaryTab({
    required this.income, required this.expense,
    required this.balance, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 기간 선택
        Container(
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gray2, width: .5)),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('기간 선택',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text2)),
            const SizedBox(height: 10),
            Row(children: [
              _periodBtn('전체', true),
              const SizedBox(width: 8),
              _periodBtn('이번달', false),
              const SizedBox(width: 8),
              _periodBtn('직접선택', false),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        // 잔액
        Container(
          decoration: BoxDecoration(
            color: AppColors.blue, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Text('현재 잔액',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 6),
            Text('${fmt(balance)}원',
              style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _summaryCard('↑ 총 수입', fmt(income), AppColors.green3, AppColors.green2)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('↓ 총 지출', fmt(expense), AppColors.red3, AppColors.red)),
        ]),
      ],
    );
  }

  Widget _periodBtn(String label, bool isActive) => GestureDetector(
    onTap: () {},
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isActive ? AppColors.blue2 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? AppColors.blue2 : AppColors.gray2)),
      child: Text(label,
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: isActive ? Colors.white : AppColors.text2)),
    ),
  );

  Widget _summaryCard(String label, String value, Color bg, Color fg) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('${value}원', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
    ]),
  );
}

// ══════════════════════════════════════════════
//  RankingsScreen
// ══════════════════════════════════════════════
class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  String _grade = '전체';
  String _gender = '전체';

  List<Player> get _filtered {
    var list = SampleData.players;
    if (_grade != '전체') list = list.where((p) => p.grade == _grade).toList();
    if (_gender != '전체') list = list.where((p) => p.gender == _gender).toList();
    // 포인트 임의 정렬 (실제는 경기 결과 기반)
    list = List.from(list)..shuffle();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _filtered;
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppHeader(title: '랭킹 / 성적관리', onBack: () => Navigator.pop(context)),
      body: Column(
        children: [
          FilterChipRow(
            items: ['전체', 'A급', 'B급', 'C급', 'D급', '초심'],
            selected: _grade == '전체' ? '전체' : '${_grade}급',
            onChanged: (v) => setState(() =>
              _grade = v == '전체' ? '전체' : v.replaceAll('급','')),
          ),
          FilterChipRow(
            items: ['전체', '남자', '여자'],
            selected: _gender == '전체' ? '전체' : (_gender == '남' ? '남자' : '여자'),
            onChanged: (v) => setState(() =>
              _gender = v == '전체' ? '전체' : (v == '남자' ? '남' : '여')),
          ),
          Expanded(
            child: ranked.isEmpty
                ? const EmptyView(emoji: '⭐', message: '데이터가 없습니다')
                : ListView.builder(
                    itemCount: ranked.length,
                    itemBuilder: (ctx, i) {
                      final p = ranked[i];
                      final pts = 840 - (i * 30);
                      final wins = 28 - (i * 2).clamp(0, 25);
                      final losses = 4 + (i ~/ 2);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: AppColors.gray2))),
                        child: Row(children: [
                          SizedBox(width: 28,
                            child: Text('${i+1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800,
                                color: i == 0 ? const Color(0xFFB7791F)
                                    : i == 1 ? AppColors.gray3
                                    : i == 2 ? const Color(0xFF9C4221)
                                    : AppColors.muted))),
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: i == 0 ? AppColors.amber2
                                  : i == 1 ? AppColors.gray2
                                  : i == 2 ? AppColors.red3
                                  : AppColors.blue3,
                              shape: BoxShape.circle),
                            child: Center(child: Text(p.name[0],
                              style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(p.name,
                                  style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 5),
                                GradeBadge(p.grade),
                              ]),
                              Text('${p.clubName} · $wins승 $losses패',
                                style: const TextStyle(
                                  fontSize: 11, color: AppColors.muted)),
                            ],
                          )),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${pts.clamp(0, 840)}',
                              style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800,
                                color: AppColors.blue)),
                            const Text('점',
                              style: TextStyle(fontSize: 10, color: AppColors.muted)),
                          ]),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  AdminScreen
// ══════════════════════════════════════════════
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notices = [
      {'title': '2026년 협회 등록 클럽 공문', 'date': '2026-04-20', 'type': '공문'},
      {'title': '협회장배 심판 교육 안내', 'date': '2026-04-15', 'type': '안내'},
      {'title': '4월 이사회 일정 공지', 'date': '2026-04-10', 'type': '이사회'},
      {'title': '2026년 대회 일정표 배포', 'date': '2026-04-05', 'type': '공지'},
      {'title': '클럽 협회비 납부 독촉', 'date': '2026-03-28', 'type': '협회비'},
    ];

    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppHeader(
        title: '협회 행정',
        onBack: () => Navigator.pop(context),
        trailing: TextButton(
          onPressed: () {},
          child: const Text('＋ 작성',
            style: TextStyle(color: AppColors.blue2, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ),
      body: ListView(
        children: [
          // 빠른 메뉴
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _quickBtn('📄', '공문 작성'),
              const SizedBox(width: 8),
              _quickBtn('📅', '이사회 일정'),
              const SizedBox(width: 8),
              _quickBtn('📣', '공지 등록'),
            ]),
          ),
          // 공지 목록
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: '최근 공문 / 공지'),
                ...notices.map((n) => _NoticeItem(
                  title: n['title']!,
                  date: n['date']!,
                  type: n['type']!,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(String icon, String label) => Expanded(
    child: GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray2, width: .5)),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(label,
            style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text2)),
        ]),
      ),
    ),
  );
}

class _NoticeItem extends StatelessWidget {
  final String title, date, type;
  const _NoticeItem({required this.title, required this.date, required this.type});

  Color get _tagColor {
    switch (type) {
      case '공문': return AppColors.blue2;
      case '이사회': return AppColors.purple;
      case '협회비': return AppColors.amber;
      default: return AppColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.gray2))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _tagColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(type,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _tagColor)),
              ),
              const SizedBox(width: 8),
              Text(date, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.gray3, size: 20),
      ]),
    );
  }
}
