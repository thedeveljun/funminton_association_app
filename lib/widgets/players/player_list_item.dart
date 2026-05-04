import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/player.dart';
import '../common/grade_pastel.dart';

const _subText = Color(0xFF5A6068);

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Row(children: [
                      Text(player.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              color: AppColors.text)),
                      const SizedBox(width: 4),
                      Text('(${player.gender}) ${player.age}세',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                              color: _subText)),
                    ]),
                    const SizedBox(height: 1),
                    Text(player.clubName,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                            color: _subText)),
                  ])),
              GradePastelChip(player.grade),
            ],
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                  width: 28,
                  child: Text('$index',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                          color: AppColors.muted))),
              const SizedBox(width: 4),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Row(children: [
                      Text(player.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              color: AppColors.text)),
                      const SizedBox(width: 4),
                      Text('(${player.gender}) ${player.age}세',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                              color: _subText)),
                    ]),
                    const SizedBox(height: 1),
                    Text(player.clubName,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                            color: _subText)),
                  ])),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GradePastelChip(player.grade),
                    const SizedBox(height: 2),
                    Text(player.phone,
                        style: const TextStyle(
                            fontSize: 11,
                            height: 1.1,
                            color: AppColors.blue2)),
                  ]),
            ],
          ),
        ),
      );
}
