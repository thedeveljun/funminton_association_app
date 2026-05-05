import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/tournament.dart';
import '../../services/sample_data.dart';
import 'bracket_screen.dart';
import 'tournament_form_screen.dart';

/// 대회운영 화면 (협회 단위)
/// - 진행중 / 예정 / 완료 탭
/// - 카드: 제목·상태 / 일정 / 경기장·참가·참가비 / 대진표·참가신청
/// - 경기장이 여러 개일 경우 「○○○ 외 N개소」 형태로 표시
/// - 카드 보더는 TournamentType 별 파스텔 톤
class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 1); // 예정
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<Tournament> _filterBy(String status) =>
      SampleData.tournaments.where((t) => t.status == status).toList();

  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildList(_filterBy('ongoing'), '진행중인 대회가 없습니다'),
                _buildList(_filterBy('upcoming'), '예정된 대회가 없습니다'),
                _buildList(_filterBy('completed'), '완료된 대회가 없습니다'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: AppColors.text),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: const Text(
        '대회운영',
        style: TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _onAddTournament,
          icon: const Icon(Icons.add, size: 18, color: AppColors.primaryMid),
          label: const Text(
            '대회',
            style: TextStyle(
              color: AppColors.primaryMid,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tab,
        labelColor: AppColors.primaryMid,
        unselectedLabelColor: AppColors.muted,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        indicatorColor: AppColors.primaryMid,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2.5,
        dividerColor: AppColors.divider,
        tabs: const [
          Tab(text: '대회진행중'),
          Tab(text: '대회예정'),
          Tab(text: '대회종료'),
        ],
      ),
    );
  }

  Widget _buildList(List<Tournament> items, String emptyText) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      );
    }
    // 카드 사이 간격
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        20 + MediaQuery.of(context).padding.bottom, // 시스템 제스처 바 영역 확보
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _TournamentCard(
        tournament: items[i],
        onBracket: () => _onBracket(items[i]),
        onApply: () => _onApply(items[i]),
        onEdit: () => _onEditTournament(items[i]),
        onDuplicate: () => _onDuplicateTournament(items[i]),
        onDelete: () => _onDeleteTournament(items[i]),
      ),
    );
  }

  // 액션 핸들러
  Future<void> _onAddTournament() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TournamentFormScreen()),
    );
    if (mounted) setState(() {});
  }

  void _onBracket(Tournament t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BracketScreen(
          tournament: t,
          initialTabIndex: 2, // 대진표 탭
        ),
      ),
    );
  }

  void _onApply(Tournament t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BracketScreen(
          tournament: t,
          initialTabIndex: 0, // 참가자 탭
        ),
      ),
    );
  }

  // 카드 ⋮ 메뉴 액션 — 수정
  Future<void> _onEditTournament(Tournament t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TournamentFormScreen(initial: t)),
    );
    if (mounted) setState(() {});
  }

  // 카드 ⋮ 메뉴 액션 — 복제
  Future<void> _onDuplicateTournament(Tournament t) async {
    final cloned = t.copyWith(
      name: '${t.name} (복사본)',
      status: 'upcoming',
      participantCount: 0,
      progressPercent: 0,
    );
    // copyWith 는 id 변경을 지원하지 않으므로 새 id 로 재구성
    final duplicate = Tournament(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      name: cloned.name,
      region: cloned.region,
      tournamentType: cloned.tournamentType,
      startDate: cloned.startDate,
      endDate: cloned.endDate,
      eventType: cloned.eventType,
      targetGrade: cloned.targetGrade,
      entryFee: cloned.entryFee,
      status: 'upcoming',
      participantCount: 0,
      description: cloned.description,
      progressPercent: 0,
      totalBudget: cloned.totalBudget,
      citySupportAmount: cloned.citySupportAmount,
      citySupportNote: cloned.citySupportNote,
      hasClubShare: cloned.hasClubShare,
      acceptsDonation: cloned.acceptsDonation,
      ageGroups: List<String>.from(cloned.ageGroups),
      gradeGroups: List<String>.from(cloned.gradeGroups),
      venues: List.from(cloned.venues),
    );
    SampleData.tournaments.add(duplicate);
    await SampleData.saveTournaments();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('대회가 복제되었습니다. 이름과 날짜를 수정해주세요.')),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentFormScreen(initial: duplicate),
      ),
    );
    if (mounted) setState(() {});
  }

  // 카드 ⋮ 메뉴 액션 — 삭제
  Future<void> _onDeleteTournament(Tournament t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${t.name} 삭제',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: const Text(
          '이 대회를 삭제하시겠습니까?\n\n'
          '참가자 정보, 대진표, 성적이 모두 함께 삭제됩니다.\n'
          '이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제',
                style: TextStyle(
                    color: AppColors.red2, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // 연관 데이터 수동 정리 (ON DELETE CASCADE 미사용 — finance_screen 패턴)
    final shareTxIds = SampleData.clubShares
        .where((s) => s.tournamentId == t.id && s.txId != null)
        .map((s) => s.txId!)
        .toSet();
    final donationTxIds = SampleData.donations
        .where((d) => d.tournamentId == t.id && d.txId != null)
        .map((d) => d.txId!)
        .toSet();

    SampleData.tournaments.removeWhere((x) => x.id == t.id);
    SampleData.clubShares.removeWhere((s) => s.tournamentId == t.id);
    SampleData.donations.removeWhere((d) => d.tournamentId == t.id);
    SampleData.transactions.removeWhere((tx) =>
        tx.tournamentId == t.id ||
        shareTxIds.contains(tx.id) ||
        donationTxIds.contains(tx.id));

    await SampleData.saveTournaments();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${t.name} 이(가) 삭제되었습니다.')),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  대회 종류별 파스텔 보더 색상
// ══════════════════════════════════════════════════════════════
Color _pastelBorder(TournamentType type) {
  switch (type) {
    case TournamentType.associationCup:
      return const Color(0xFFB8C9F0); // 미디엄 블루 파스텔
    case TournamentType.cityCup:
      return const Color(0xFFA7D9B8); // 미디엄 그린 파스텔
    case TournamentType.mediaCup:
      return const Color(0xFFC4B8E8); // 미디엄 퍼플 파스텔
    case TournamentType.general:
      return const Color(0xFFF0D680); // 미디엄 앰버 파스텔
  }
}

// ══════════════════════════════════════════════════════════════
//  대회 카드
// ══════════════════════════════════════════════════════════════
class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final VoidCallback onBracket;
  final VoidCallback onApply;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _TournamentCard({
    required this.tournament,
    required this.onBracket,
    required this.onApply,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  List<String> get _venues => tournament.venue
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  String _formatFee(int fee) {
    final s = fee.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '참가비 ${s}원';
  }

  Widget _buildMoreMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '메뉴',
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.muted),
      padding: EdgeInsets.zero,
      splashRadius: 18,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      onSelected: (v) {
        switch (v) {
          case 'edit':
            onEdit();
            break;
          case 'duplicate':
            onDuplicate();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'edit',
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18, color: AppColors.text2),
            SizedBox(width: 10),
            Text('수정',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'duplicate',
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(Icons.copy_outlined, size: 18, color: AppColors.text2),
            SizedBox(width: 10),
            Text('복제',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
          ]),
        ),
        PopupMenuDivider(height: 6),
        PopupMenuItem<String>(
          value: 'delete',
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: AppColors.red2),
            SizedBox(width: 10),
            Text('삭제',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.red2)),
          ]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = tournament;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        // 파스텔 보더 (대회 종류별 색상)
        border: Border.all(
          color: _pastelBorder(t.tournamentType),
          width: 2.5,
        ),
      ),
      // 카드 내부 패딩
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 + ⋮ 메뉴
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  t.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildMoreMenu(context),
            ],
          ),
          const SizedBox(height: 2),

          // 일정 — 1pt 크게 + 진하게
          Text(
            '${t.startDate} ~ ${t.endDate}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.text2,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),

          // 태그 (급수, 경기장, 참가, 참가비) — '전체' 급수는 숨김
          Wrap(
            spacing: 6,
            runSpacing: 3,
            children: [
              if (t.targetGrade.isNotEmpty &&
                  t.targetGrade != '전체' &&
                  t.targetGradeList.length < Tournament.allTargetGrades.length)
                _GradeTag(grade: t.targetGradeList.join(', ')),
              _VenueTag(venues: _venues),
              _Tag('참가 ${t.participantCount}명'),
              _Tag(_formatFee(t.entryFee)),
            ],
          ),
          const SizedBox(height: 8),

          // 액션 버튼
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onBracket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMid,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  child: const Text('대진표'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onApply,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryMid,
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(
                      color: AppColors.primaryMid,
                      width: 1.4,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  child: const Text('참가 신청'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  태그 — 일반 / 경기장 (외 N개소 강조)
// ══════════════════════════════════════════════════════════════
class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.text2,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      ),
    );
  }
}

class _VenueTag extends StatelessWidget {
  final List<String> venues;
  const _VenueTag({required this.venues});

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) return const _Tag('경기장 미정');
    if (venues.length == 1) return _Tag(venues.first);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: venues.first,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.text2,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
            TextSpan(
              text: '  외 ${venues.length - 1}개소',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primaryMid,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  급수 파스텔 팔레트 — 선수관리 화면과 동일
//  (TODO: 추후 widgets/common/grade_pastel.dart로 추출 권장)
// ══════════════════════════════════════════════════════════════
Color _gradePastelBg(String grade) {
  switch (grade) {
    case 'A조':
      return const Color(0xFFDBEAFE);
    case 'B조':
      return const Color(0xFFD1FAE5);
    case 'C조':
      return const Color(0xFFFEF3C7);
    case 'D조':
      return const Color(0xFFFFE4E6);
    case '초심조':
      return const Color(0xFFF3E8FF);
    case 'S조':
      return const Color(0xFFE0F2FE);
    default:
      return const Color(0xFFF1F5F9);
  }
}

Color _gradePastelFg(String grade) {
  switch (grade) {
    case 'A조':
      return const Color(0xFF1E40AF);
    case 'B조':
      return const Color(0xFF065F46);
    case 'C조':
      return const Color(0xFF92400E);
    case 'D조':
      return const Color(0xFF9F1239);
    case '초심조':
      return const Color(0xFF6B21A8);
    case 'S조':
      return const Color(0xFF075985);
    default:
      return const Color(0xFF6B7A99);
  }
}

class _GradeTag extends StatelessWidget {
  final String grade;
  const _GradeTag({required this.grade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _gradePastelBg(grade),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        grade,
        style: TextStyle(
          fontSize: 13,
          color: _gradePastelFg(grade),
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}
