import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/sample_data.dart';
import '../../widgets/common/filter_chips.dart';

const _rankingInk = Color(0xFF0D1B3E);

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});
  @override
  State<RankingsScreen> createState() => _State();
}

class _State extends State<RankingsScreen> {
  String _grade = '전체';
  String _gender = '전체';

  @override
  Widget build(BuildContext context) {
    var players = SampleData.players;
    if (_grade != '전체')
      players = players.where((p) => p.grade == _grade).toList();
    if (_gender != '전체')
      players = players.where((p) => p.gender == _gender).toList();

    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        titleSpacing: -4,
        leadingWidth: 34,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: _rankingInk),
        ),
        title: const Text(
          '랭킹 / 성적관리',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: _rankingInk,
          ),
        ),
      ),
      body: Column(children: [
        FilterChipRow(
            options: const ['전체', 'A급', 'B급', 'C급', 'D급', '초심'],
            selected: _grade,
            onSelect: (v) => setState(() => _grade = v.replaceAll('급', ''))),
        FilterChipRow(
            options: const ['전체', '남', '여'],
            selected: _gender,
            onSelect: (v) => setState(() => _gender = v)),
        Expanded(
            child: ListView.builder(
          itemCount: players.length,
          itemBuilder: (_, i) {
            final p = players[i];
            final rank = i + 1;
            final medals = ['🥇', '🥈', '🥉'];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(bottom: BorderSide(color: AppColors.divider))),
              child: Row(children: [
                SizedBox(
                    width: 32,
                    child: Text(rank <= 3 ? medals[rank - 1] : '$rank',
                        style: TextStyle(
                            fontSize: rank <= 3 ? 18 : 14,
                            fontWeight: FontWeight.w700,
                            color: rank == 1
                                ? AppColors.amber
                                : rank == 2
                                    ? AppColors.gray3
                                    : rank == 3
                                        ? const Color(0xFF9C4221)
                                        : AppColors.muted),
                        textAlign: TextAlign.center)),
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: AppColors.gradeBackground(p.grade),
                        shape: BoxShape.circle),
                    child: Center(
                        child: Text(p.name[0],
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gradeText(p.grade))))),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Text(p.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                        const SizedBox(width: 4),
                        Text('(${p.gender}) ${p.grade}급',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                      ]),
                      Text(p.clubName,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                    ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${(15 - i) * 30 + 100}점',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blue)),
                  Text('${15 - i}승 ${i}패',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.muted)),
                ]),
              ]),
            );
          },
        )),
      ]),
    );
  }
}
