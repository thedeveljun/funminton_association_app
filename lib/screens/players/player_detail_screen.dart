import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/player.dart';
import '../../services/sample_data.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/app_badge.dart';

class PlayerDetailScreen extends StatefulWidget {
  final Player player;
  const PlayerDetailScreen({super.key, required this.player});

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  late List<String> _awards;

  @override
  void initState() {
    super.initState();
    _awards = List<String>.from(widget.player.awards);
  }

  Future<void> _saveAwards() async {
    final idx = SampleData.players.indexWhere((p) => p.id == widget.player.id);
    if (idx >= 0) {
      final old = SampleData.players[idx];
      SampleData.players[idx] = Player(
        id: old.id,
        name: old.name,
        gender: old.gender,
        birthDate: old.birthDate,
        grade: old.grade,
        clubId: old.clubId,
        clubName: old.clubName,
        phone: old.phone,
        regNumber: old.regNumber,
        age: old.age,
        awards: _awards,
      );
      await SampleData.savePlayers();
    }
  }

  Future<void> _addAward() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        title: const Text('수상 이력 추가',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: '예: 2026 협회장배 혼복 A급 우승',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('추가'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _awards.add(result));
      await _saveAwards();
    }
  }

  Future<void> _editAward(int index) async {
    final ctrl = TextEditingController(text: _awards[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        title: const Text('수상 이력 수정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: '예: 2026 협회장배 혼복 A급 우승',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _awards[index] = result);
      await _saveAwards();
    }
  }

  Future<void> _deleteAward(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('수상 이력 삭제',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content:
            const Text('이 수상 이력을 삭제하시겠습니까?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제',
                style: TextStyle(
                    color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _awards.removeAt(index));
      await _saveAwards();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppBar(
          title: const Text('선수 상세'),
          actions: [TextButton(onPressed: () {}, child: const Text('편집'))]),
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                const SizedBox(height: 2),
                Text(
                    '${player.gender} · ${player.age}세 · ${player.decadeLabel}',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 6),
                Row(children: [
                  GradeBadge(player.grade),
                  const SizedBox(width: 5),
                  AppBadge(player.clubName, type: BadgeType.blue)
                ]),
              ],
            ),
          ),
          const SizedBox(height: 6),
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
                _Row('급수', player.gradeShort + '급'),
              ])),
          const SizedBox(height: 6),
          Container(
              color: AppColors.white,
              child: Column(children: [
                // 섹션 헤더 + 추가 버튼
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceAlt,
                    border: Border(
                      top: BorderSide(color: AppColors.divider),
                      bottom: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('대회 수상 이력',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                              letterSpacing: 0.8)),
                      TextButton.icon(
                        onPressed: _addAward,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('추가'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_awards.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('수상 이력 없음',
                        style: TextStyle(color: AppColors.muted, fontSize: 14)),
                  )
                else
                  ..._awards.asMap().entries.map((e) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: AppColors.divider, width: 0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('🏅', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(e.value,
                                    style: const TextStyle(
                                        fontSize: 14, color: AppColors.text))),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _editAward(e.key),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFFBFDBFE),
                                          width: 1),
                                    ),
                                    child: const Text('수정',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2563EB))),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _deleteAward(e.key),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFFFECACA),
                                          width: 1),
                                    ),
                                    child: const Text('삭제',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFB91C1C))),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
              ])),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool isPhone;
  const _Row(this.label, this.value, {this.isPhone = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
