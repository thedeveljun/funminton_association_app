import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/player.dart';
import '../common/grade_pastel.dart';

const _subText = Color(0xFF5A6068);

/// 참가자 선택 아이템 (체크박스 + 우측 3-dot 메뉴로 수정/삭제).
class PlayerSelectItem extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback onTap;

  /// 3-dot 메뉴의 '수정' / '삭제' 콜백. 둘 중 하나라도 null 아니면 메뉴 노출.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PlayerSelectItem({
    super.key,
    required this.player,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasMenu = onEdit != null || onDelete != null;
    return InkWell(
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
            if (hasMenu) ...[
              const SizedBox(width: 2),
              // 행 높이가 부풀지 않도록 24×24 로 강제 — Material PopupMenuButton 의
              // 기본 minSize(~48) 가 ListItem 행간을 늘리는 문제 방지.
              SizedBox(
                width: 24,
                height: 24,
                child: PopupMenuButton<String>(
                  tooltip: '더보기',
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: AppColors.muted),
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined,
                              size: 18, color: Color(0xFF1E3A8A)),
                          SizedBox(width: 8),
                          Text('수정',
                              style: TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: Color(0xFFB91C1C)),
                          SizedBox(width: 8),
                          Text('삭제',
                              style: TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 일반 선수 리스트 아이템
class PlayerListItem extends StatelessWidget {
  final Player player;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const PlayerListItem(
      {super.key,
      required this.player,
      required this.index,
      this.onTap,
      this.onDelete});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              color: AppColors.text)),
                      const SizedBox(width: 4),
                      Text('(${player.gender}) ${player.age}세',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                              color: _subText)),
                    ]),
                    const SizedBox(height: 1),
                    Text(player.clubName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                            color: _subText)),
                  ])),
              // 급수 칩만 표시 (전화번호 제거 + 세로 중앙 정렬)
              Center(child: GradePastelChip(player.grade)),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Color(0xFFB91C1C)),
                  tooltip: '삭제',
                ),
              ],
            ],
          ),
        ),
      );
}
