import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/tournament.dart';
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

  // ────────────────────────────────────────────────────────────
  // 더미 데이터 — 실제 운영 시 Service/Repository로 교체
  // ────────────────────────────────────────────────────────────
  List<Tournament> get _dummy => const [
        Tournament(
          id: 't1',
          name: '2026 과천시배드민턴협회장기대회',
          region: '과천시',
          tournamentType: TournamentType.associationCup,
          startDate: '2026-05-15',
          endDate: '2026-05-16',
          venue: '과천시민체육관',
          entryFee: 0,
          participantCount: 0,
          status: 'upcoming',
        ),
        Tournament(
          id: 't2',
          name: '2026 과천시장기대회',
          region: '과천시',
          tournamentType: TournamentType.cityCup,
          startDate: '2026-07-10',
          endDate: '2026-07-11',
          venue: '과천시민체육관, 과천종합운동장',
          entryFee: 0,
          participantCount: 0,
          status: 'upcoming',
        ),
        Tournament(
          id: 't3',
          name: '2026 과천시/경인일보대회',
          region: '과천시',
          tournamentType: TournamentType.mediaCup,
          startDate: '2026-09-20',
          endDate: '2026-09-21',
          venue: '과천시민체육관, 과천종합운동장, 관문체육공원',
          entryFee: 0,
          participantCount: 0,
          status: 'upcoming',
        ),
        Tournament(
          id: 't4',
          name: '2026 라온누리대회',
          region: '과천시',
          tournamentType: TournamentType.general,
          startDate: '2026-11-05',
          endDate: '2026-11-05',
          venue: '과천시민체육관',
          entryFee: 30000,
          participantCount: 24,
          status: 'upcoming',
        ),
      ];

  List<Tournament> _filterBy(String status) =>
      _dummy.where((t) => t.status == status).toList();

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
      MaterialPageRoute(builder: (_) => BracketScreen(tournament: t)),
    );
  }

  void _onApply(Tournament t) {}
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

  const _TournamentCard({
    required this.tournament,
    required this.onBracket,
    required this.onApply,
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
          // 제목
          Text(
            t.name,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              height: 1.1,
            ),
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
              if (t.targetGrade.isNotEmpty && t.targetGrade != '전체')
                _GradeTag(grade: t.targetGrade),
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
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
