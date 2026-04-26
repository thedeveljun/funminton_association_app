import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum BadgeType { green, red, blue, amber, purple, gray }

class AppBadge extends StatelessWidget {
  final String text;
  final BadgeType type;

  const AppBadge(this.text, {super.key, this.type = BadgeType.gray});

  factory AppBadge.status(String status) {
    BadgeType t;
    switch (status) {
      case '활성':
      case '납부':
      case '완납':
      case '정회원':
      case '진행중':
      case '납부완료':
        t = BadgeType.green;
        break;
      case '미납':
      case '비활성':
        t = BadgeType.red;
        break;
      case '예정':
      case '신규':
        t = BadgeType.blue;
        break;
      case '완료':
        t = BadgeType.gray;
        break;
      case '일부납부':
        t = BadgeType.amber;
        break;
      case '준회원':
        t = BadgeType.purple;
        break;
      default:
        t = BadgeType.gray;
    }
    return AppBadge(status, type: t);
  }

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (type) {
      case BadgeType.green:
        bg = AppColors.green3;
        fg = AppColors.green;
        break;
      case BadgeType.red:
        bg = AppColors.red3;
        fg = AppColors.red;
        break;
      case BadgeType.blue:
        bg = AppColors.primaryLight;
        fg = AppColors.primaryMid;
        break;
      case BadgeType.amber:
        bg = AppColors.amber2;
        fg = AppColors.amber;
        break;
      case BadgeType.purple:
        bg = AppColors.purple2;
        fg = AppColors.purple;
        break;
      case BadgeType.gray:
        bg = AppColors.bg;
        fg = AppColors.muted;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class GradeBadge extends StatelessWidget {
  final String grade;
  const GradeBadge(this.grade, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.gradeBackground(grade),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(grade,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      );
}
