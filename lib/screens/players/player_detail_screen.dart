import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/player.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/app_badge.dart';

class PlayerDetailScreen extends StatelessWidget {
  final Player player;
  const PlayerDetailScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.gray,
        appBar: AppBar(
            title: const Text('선수 상세'),
            actions: [TextButton(onPressed: () {}, child: const Text('편집'))]),
        body: SingleChildScrollView(
          child: Column(children: [
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.name,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text(
                      '${player.gender} · ${player.age}세 · ${player.decadeLabel}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  Row(children: [
                    GradeBadge(player.grade),
                    const SizedBox(width: 5),
                    AppBadge(player.clubName, type: BadgeType.blue)
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
                color: AppColors.white,
                child: Column(children: [
                  const SectionHeader('등록 정보'),
                  _Row('협회 등록번호', player.regNumber),
                  _Row('소속 클럽', player.clubName),
                  _Row(
                      '생년월일',
                      player.birthDate.isEmpty
                          ? '-'
                          : '${player.birthDate.substring(0, 2)}년 ${player.birthDate.substring(2, 4)}월 ${player.birthDate.substring(4, 6)}일생'),
                  _Row('전화번호', player.phone, isPhone: true),
                  _Row('급수', player.grade),
                ])),
            const SizedBox(height: 8),
            Container(
                color: AppColors.white,
                child: Column(children: [
                  const SectionHeader('대회 수상 이력'),
                  if (player.awards.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('수상 이력 없음',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 14)),
                    )
                  else
                    ...player.awards.map((a) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(children: [
                            const Text('🏅', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(a,
                                    style: const TextStyle(
                                        fontSize: 14, color: AppColors.text))),
                          ]),
                        )),
                ])),
            const SizedBox(height: 24),
          ]),
        ),
      );
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool isPhone;
  const _Row(this.label, this.value, {this.isPhone = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider))),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPhone ? AppColors.blue2 : AppColors.text)),
        ]),
      );
}
