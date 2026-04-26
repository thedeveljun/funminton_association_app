import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/club.dart';
import '../common/app_badge.dart';

class ClubListItem extends StatelessWidget {
  final Club club;
  final VoidCallback onTap;
  const ClubListItem({super.key, required this.club, required this.onTap});

  static const _colors = [
    [Color(0xFFBEE3F8), Color(0xFF1A365D)],
    [Color(0xFFC6F6D5), Color(0xFF1C4532)],
    [Color(0xFFFED7D7), Color(0xFF742A2A)],
    [Color(0xFFE9D8FD), Color(0xFF322659)],
    [Color(0xFFFEEBC8), Color(0xFF744210)],
  ];

  @override
  Widget build(BuildContext context) {
    final idx = club.id.hashCode.abs() % _colors.length;
    final bg = _colors[idx][0];
    final fg = _colors[idx][1];

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Row(children: [
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Center(
                  child: Text(club.initials,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: fg)))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(club.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                  const SizedBox(width: 6),
                  AppBadge.status(club.memberType),
                ]),
                const SizedBox(height: 3),
                Text('회장: ${club.presidentName}  ${club.presidentPhone}',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
                Text('총무: ${club.secretaryName}  ${club.secretaryPhone}',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            AppBadge.status(club.feePaid ? '납부' : '미납'),
            const SizedBox(height: 5),
            Text('${club.memberCount}명',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blue)),
          ]),
        ]),
      ),
    );
  }
}
