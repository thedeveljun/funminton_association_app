import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/player.dart';
import '../common/app_badge.dart';

/// 참가자 선택 아이템 (체크박스)
class PlayerSelectItem extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback onTap;
  const PlayerSelectItem(
      {super.key,
      required this.player,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: isSelected ? const Color(0xFFF0F7FF) : AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                  color: isSelected ? AppColors.blue2 : AppColors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: isSelected ? AppColors.blue2 : AppColors.gray2,
                      width: 2)),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 10),
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.gradeBackground(player.grade),
                    shape: BoxShape.circle),
                child: Center(
                    child: Text(player.name[0],
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gradeText(player.grade))))),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(player.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                    const SizedBox(width: 4),
                    Text('(${player.gender}) ${player.age}세',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ]),
                  const SizedBox(height: 2),
                  Text(player.clubName,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ])),
            GradeBadge(player.grade),
          ]),
        ),
      );
}

/// 일반 선수 리스트 아이템
class PlayerListItem extends StatelessWidget {
  final Player player;
  final int index;
  final VoidCallback? onTap;
  const PlayerListItem(
      {super.key, required this.player, required this.index, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(children: [
            SizedBox(
                width: 28,
                child: Text('$index',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted))),
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: AppColors.gradeBackground(player.grade),
                    shape: BoxShape.circle),
                child: Center(
                    child: Text(player.name[0],
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gradeText(player.grade))))),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(player.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    const SizedBox(width: 4),
                    Text('(${player.gender}) ${player.age}세',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ]),
                  const SizedBox(height: 2),
                  Text(player.clubName,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              GradeBadge(player.grade),
              const SizedBox(height: 4),
              Text(player.phone,
                  style: const TextStyle(fontSize: 11, color: AppColors.blue2)),
            ]),
          ]),
        ),
      );
}
