import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// ══════════════════════════════════════════════
// AppHeader — 공통 상단 헤더
// ══════════════════════════════════════════════
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: onBack != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: onBack,
              color: AppColors.text2,
            )
          : null,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      centerTitle: true,
      actions: trailing != null ? [trailing!, const SizedBox(width: 8)] : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.gray2),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// GradeBadge — 급수 뱃지
// ══════════════════════════════════════════════
class GradeBadge extends StatelessWidget {
  final String grade;

  const GradeBadge(this.grade, {super.key});

  Color get _bg {
    switch (grade) {
      case 'A':
        return AppColors.gradeABg;
      case 'B':
        return AppColors.gradeBBg;
      case 'C':
        return AppColors.gradeCBg;
      case 'D':
        return AppColors.gradeDBg;
      default:
        return AppColors.gradeIBg;
    }
  }

  Color get _text {
    switch (grade) {
      case 'A':
        return AppColors.gradeATxt;
      case 'B':
        return AppColors.gradeBTxt;
      case 'C':
        return AppColors.gradeCTxt;
      case 'D':
        return AppColors.gradeDTxt;
      default:
        return AppColors.gradeITxt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        grade,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _text,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// StatusBadge — 상태 뱃지 (납부/미납/진행중 등)
// ══════════════════════════════════════════════
class StatusBadge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  factory StatusBadge.paid() => const StatusBadge(
      label: '납부', bgColor: AppColors.green3, textColor: AppColors.gradeBTxt);

  factory StatusBadge.unpaid() => const StatusBadge(
      label: '미납', bgColor: AppColors.red3, textColor: AppColors.gradeITxt);

  factory StatusBadge.active() => const StatusBadge(
      label: '활성', bgColor: AppColors.green3, textColor: AppColors.gradeBTxt);

  factory StatusBadge.ongoing() => const StatusBadge(
      label: '진행중', bgColor: AppColors.green3, textColor: AppColors.gradeBTxt);

  factory StatusBadge.upcoming() => const StatusBadge(
      label: '예정', bgColor: AppColors.blue3, textColor: AppColors.gradeATxt);

  factory StatusBadge.completed() => const StatusBadge(
      label: '완료', bgColor: AppColors.gray2, textColor: AppColors.text2);

  factory StatusBadge.primary() => const StatusBadge(
      label: '정회원', bgColor: AppColors.green3, textColor: AppColors.gradeBTxt);

  factory StatusBadge.associate() => const StatusBadge(
      label: '준회원', bgColor: AppColors.gray2, textColor: AppColors.text2);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// FilterChipRow — 필터 칩 가로 스크롤
// ══════════════════════════════════════════════
class FilterChipRow extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onChanged;

  const FilterChipRow({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((item) {
            final isOn = item == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onChanged(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOn ? AppColors.blue2 : AppColors.gray,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOn ? AppColors.blue2 : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isOn ? Colors.white : AppColors.text2,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// StatCard — 통계 카드
// ══════════════════════════════════════════════
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(.1)),
          ),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? Colors.white,
                )),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(.7),
                )),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// SectionHeader — 섹션 제목
// ══════════════════════════════════════════════
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
                letterSpacing: .5,
              )),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.blue2,
                    fontWeight: FontWeight.w600,
                  )),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// DetailRow — 상세 정보 행
// ══════════════════════════════════════════════
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.gray2)),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ?? AppColors.text,
              )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// EmptyView — 데이터 없을 때
// ══════════════════════════════════════════════
class EmptyView extends StatelessWidget {
  final String emoji;
  final String message;
  final String? subMessage;

  const EmptyView({
    super.key,
    this.emoji = '📭',
    required this.message,
    this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2)),
            if (subMessage != null) ...[
              const SizedBox(height: 6),
              Text(subMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ],
        ),
      ),
    );
  }
}
