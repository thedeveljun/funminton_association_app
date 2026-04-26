import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/tournament.dart';
import '../../services/sample_data.dart';
import '../../widgets/common/app_badge.dart';
import 'tournament_form_screen.dart';
import 'bracket_screen.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});
  @override
  State<TournamentListScreen> createState() => _State();
}

class _State extends State<TournamentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  List<Tournament> _filtered(String status) =>
      SampleData.tournaments.where((t) => t.status == status).toList();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.gray,
        appBar: AppBar(
          title: const Text('대회운영'),
          actions: [
            TextButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TournamentFormScreen())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('대회',
                    style: TextStyle(fontWeight: FontWeight.w700))),
          ],
          bottom: TabBar(controller: _tc, tabs: const [
            Tab(text: '진행중'),
            Tab(text: '예정'),
            Tab(text: '완료'),
          ]),
        ),
        body: TabBarView(
          controller: _tc,
          children: [
            _TourneyList(items: _filtered('ongoing')),
            _TourneyList(items: _filtered('upcoming')),
            _TourneyList(items: _filtered('completed')),
          ],
        ),
      );
}

class _TourneyList extends StatelessWidget {
  final List<Tournament> items;
  const _TourneyList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return const Center(
          child: Text('대회가 없습니다.', style: TextStyle(color: AppColors.muted)));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _TourneyCard(t: items[i]),
    );
  }
}

class _TourneyCard extends StatelessWidget {
  final Tournament t;
  const _TourneyCard({required this.t});

  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gray2, width: .5)),
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Text(t.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text))),
            AppBadge.status(t.statusLabel),
          ]),
          const SizedBox(height: 4),
          Text('${t.startDate} ~ ${t.endDate}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 5, runSpacing: 4, children: [
            _tag(t.eventType),
            _tag(t.venue),
            _tag('참가 ${t.participantCount}명'),
            _tag('참가비 ${_fmt(t.entryFee)}원'),
          ]),
          if (t.status == 'ongoing') ...[
            Container(
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: AppColors.gray2,
                    borderRadius: BorderRadius.circular(3)),
                child: FractionallySizedBox(
                    widthFactor: t.progressPercent / 100,
                    child: Container(
                        decoration: BoxDecoration(
                            color: AppColors.blue2,
                            borderRadius: BorderRadius.circular(3))))),
            Text('${t.progressPercent}% 진행',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            // ★ 대진표 버튼 — BracketScreen으로 이동
            Expanded(
                child: ElevatedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BracketScreen(tournament: t))),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10)),
                    child: const Text('대진표', style: TextStyle(fontSize: 13)))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10)),
                    child: Text(t.status == 'upcoming' ? '참가 신청' : '결과 보기',
                        style: const TextStyle(fontSize: 13)))),
          ]),
        ]),
      );

  Widget _tag(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: AppColors.gray, borderRadius: BorderRadius.circular(8)),
      child: Text(t,
          style: const TextStyle(fontSize: 11, color: AppColors.text2)));
}
