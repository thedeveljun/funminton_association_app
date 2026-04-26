import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/match.dart';

class MatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback onTap;

  const MatchCard({super.key, required this.match, required this.onTap});

  Color get _typeBg {
    switch (match.type) {
      case MatchType.sameGrade:
        return const Color(0xFFBEE3F8);
      case MatchType.balanced:
        return const Color(0xFFC6F6D5);
      case MatchType.free:
        return const Color(0xFFFEFCBF);
    }
  }

  Color get _typeFg {
    switch (match.type) {
      case MatchType.sameGrade:
        return const Color(0xFF1A365D);
      case MatchType.balanced:
        return const Color(0xFF1C4532);
      case MatchType.free:
        return const Color(0xFF744210);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Column(children: [
          // 경기 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 7, 13, 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: _typeBg,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${match.gameIndex}경기 · ${match.type.label}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _typeFg))),
                  if (match.day == 2) ...[
                    const SizedBox(width: 5),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.amber2,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('2일차',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.amber))),
                  ],
                ]),
                _StatusDot(match.status),
              ],
            ),
          ),
          // 팀 vs 팀
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 3, 13, 9),
            child: Row(children: [
              // A팀
              Expanded(
                  child: _TeamBox(
                names: match.teamANames,
                grades: match.teamAGrades,
                isWinner: match.teamAWins,
                align: CrossAxisAlignment.start,
              )),
              // 점수
              _ScoreBox(match: match),
              // B팀
              Expanded(
                  child: _TeamBox(
                names: match.teamBNames,
                grades: match.teamBGrades,
                isWinner: match.teamBWins,
                align: CrossAxisAlignment.end,
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TeamBox extends StatelessWidget {
  final String names;
  final String grades;
  final bool isWinner;
  final CrossAxisAlignment align;
  const _TeamBox(
      {required this.names,
      required this.grades,
      required this.isWinner,
      required this.align});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: align,
        children: [
          Text(names,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isWinner ? FontWeight.w800 : FontWeight.w500,
                  color: isWinner ? AppColors.blue2 : AppColors.text),
              textAlign: align == CrossAxisAlignment.end
                  ? TextAlign.right
                  : TextAlign.left),
          const SizedBox(height: 2),
          Text(grades,
              style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ],
      );
}

class _ScoreBox extends StatelessWidget {
  final Match match;
  const _ScoreBox({required this.match});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            _sv(match.scoreA?.toString() ?? '-', match.teamAWins, match.isDone),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 3),
                child: Text(':',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700))),
            _sv(match.scoreB?.toString() ?? '-', match.teamBWins, match.isDone),
          ]),
          const SizedBox(height: 3),
          Text(match.isDone ? '완료' : 'VS',
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _sv(String v, bool win, bool done) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
            color: win
                ? AppColors.blue2
                : done
                    ? AppColors.gray2
                    : AppColors.gray,
            borderRadius: BorderRadius.circular(6)),
        child: Center(
            child: Text(v,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: win
                        ? Colors.white
                        : done
                            ? AppColors.muted
                            : AppColors.text))),
      );
}

class _StatusDot extends StatelessWidget {
  final MatchStatus status;
  const _StatusDot(this.status);

  Color get _color {
    switch (status) {
      case MatchStatus.done:
        return AppColors.green2;
      case MatchStatus.ongoing:
        return AppColors.amber;
      case MatchStatus.waiting:
        return AppColors.gray3;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle));
}

/// 코트 블록 헤더
class CourtBlockHeader extends StatelessWidget {
  final String title;
  final int done;
  final int total;
  final String colorHex;

  const CourtBlockHeader({
    super.key,
    required this.title,
    required this.done,
    required this.total,
    required this.colorHex,
  });

  Color get _bg {
    final hex = colorHex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        color: _bg,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Text('$done/$total완료',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      );
}
