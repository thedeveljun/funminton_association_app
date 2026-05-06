import 'package:flutter/material.dart';
import 'package:badminton_association/screens/players/player_list_screen.dart';
import '../../services/auth_service.dart';
import '../../services/sample_data.dart';
import '../clubs/club_list_screen.dart';
import '../tournaments/tournament_list_screen.dart';
import '../tournaments/tournament_schedule_screen.dart';
import '../finance/finance_screen.dart';
import '../admin/admin_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const HomeScreen({super.key, this.onLogout});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ============================================================
  // 새 디자인 컬러 (그림2 스타일)
  // ============================================================
  static const Color _navyDark = Color(0xFF071833);
  static const Color _gold = Color(0xFFFFC72C);
  static const Color _blueAccent = Color(0xFF4A90E2);
  static const Color _cardBg = Color(0xFF0A1F45);

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  void _go(Widget s) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => s));

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠습니까? 다시 사용하려면 비밀번호 입력이 필요합니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('로그아웃')),
        ],
      ),
    );
    if (ok == true) widget.onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F7),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ▼ NEW: 통합 히어로 (배경이미지 + 헤더 + 헤드라인 + 통계카드)
          _heroWithStats(),
          const SizedBox(height: 16),

          // ▼ 이하 메뉴 카드 / 최근 활동 (기존 그대로)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                SizedBox(
                  height: 116,
                  child: Row(
                    children: [
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.apartment_rounded,
                          title: '클럽관리',
                          subtitle: '등록 · 임원 · 인원',
                          iconColor: const Color(0xFF2563EB),
                          iconBgColor: const Color(0xFFDBEAFE),
                          subtitleColor: const Color(0xFF2563EB),
                          onTap: () => _go(const ClubListScreen()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.groups_rounded,
                          title: '선수관리',
                          subtitle: '등록 · 급수 · 이력',
                          iconColor: const Color(0xFF22A06B),
                          iconBgColor: const Color(0xFFD1FAE5),
                          subtitleColor: const Color(0xFF22A06B),
                          onTap: () => _go(const PlayerListScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 116,
                  child: Row(
                    children: [
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.emoji_events_rounded,
                          title: '대회운영',
                          subtitle: '생성 · 대진 · 결과',
                          iconColor: const Color(0xFFE07B3C),
                          iconBgColor: const Color(0xFFFFEDD8),
                          subtitleColor: const Color(0xFFE07B3C),
                          onTap: () => _go(const TournamentListScreen()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.credit_card_rounded,
                          title: '재정관리',
                          subtitle: '협회비 · 수입지출',
                          iconColor: const Color(0xFF7C3AED),
                          iconBgColor: const Color(0xFFEDE9FE),
                          subtitleColor: const Color(0xFF7C3AED),
                          onTap: () => _go(const FinanceScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: 116,
              child: Row(
                children: [
                  Expanded(
                    child: _MenuCard(
                      icon: Icons.event_note_rounded,
                      title: '대회일정',
                      subtitle: '연간 · 월별 · 상태',
                      iconColor: const Color(0xFF0891B2),
                      iconBgColor: const Color(0xFFCFFAFE),
                      subtitleColor: const Color(0xFF0891B2),
                      onTap: () => _go(const TournamentScheduleScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MenuCard(
                      icon: Icons.account_balance_rounded,
                      title: '협회행정',
                      subtitle: '공지 · 이사회 · 공문',
                      iconColor: const Color(0xFF1F2937),
                      iconBgColor: const Color(0xFFE5E7EB),
                      subtitleColor: const Color(0xFF3730A3),
                      onTap: () => _go(const AdminScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
            child: _recent(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NEW: 통합 히어로 + 통계 카드 (그림2 스타일, Stack 기반)
  // ============================================================
  Widget _heroWithStats() {
    final ongoingCount =
        SampleData.tournaments.where((t) => t.status == 'ongoing').length;

    return Container(
      width: double.infinity,
      color: _navyDark,
      child: Stack(
        children: [
          // ── 1) 셔틀콕 배경 이미지 (오른쪽에 작게 + 아래로 내림) ──
          Positioned(
            right: -20, // 살짝 오른쪽으로 빼서 화면 밖으로 흘리는 느낌
            top: 30,
            bottom: 0,
            width: 220,
            child: Image.asset(
              'assets/images/bg_shuttlecock.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              // 이미지 못 찾을 때 에러 대신 그냥 빈 공간으로 fallback
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          // ── 2) 좌→우 그라데이션 (왼쪽 텍스트 가독성 확보) ──
          //    오른쪽은 완전 투명으로 두어 셔틀콕이 또렷하게 보이도록
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    _navyDark,
                    _navyDark.withValues(alpha: 0.85),
                    _navyDark.withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.40, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // ── 3) 콘텐츠 ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(),
                  const SizedBox(height: 26),

                  // 메인 헤드라인 1줄
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '협회 운영을',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 메인 헤드라인 2줄 (골드 강조)
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '더 스마트하게',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: _gold,
                        height: 1.2,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '클럽 · 선수 · 대회 · 재정 통합 관리',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.82),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 통계 카드 (실제 데이터)
                  _buildStatsCard(ongoingCount),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        // 로고 (기존 icon.png + 블루 글로우)
        Container(
          width: 42,
          height: 42,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: _blueAccent.withValues(alpha: 0.45),
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/icon.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        // 협회명 (동적)
        Expanded(
          child: Text(
            AuthService.associationName.isEmpty
                ? '배드민턴 협회'
                : AuthService.associationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 로그아웃 버튼 (기존 기능 그대로)
        IconButton(
          tooltip: '로그아웃',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: _confirmLogout,
          icon: const Icon(
            Icons.logout_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(int ongoingCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        // 상단에 빛이 들어오는 듯한 하이라이트로 입체감
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            _cardBg.withValues(alpha: 0.65),
            _cardBg.withValues(alpha: 0.65),
          ],
          stops: const [0.0, 0.15, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.groups,
              iconColor: _blueAccent,
              value: _formatNumber(SampleData.clubs.length),
              label: '소속클럽',
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.person,
              iconColor: _blueAccent,
              value: _formatNumber(SampleData.players.length),
              label: '등록선수',
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.emoji_events,
              iconColor: _gold,
              value: _formatNumber(ongoingCount),
              label: '진행대회',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 최근 활동 (기존 그대로)
  // ============================================================
  Widget _recent() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                '최근 활동',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.4,
                ),
              ),
            ),
            _act(
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFFE07B3C),
              iconBg: const Color(0xFFFFEDD8),
              title: '2026 협회장배 대회 진행 중',
              sub: '참가 71명 · 65% 완료',
              tag: '진행중',
              tagBg: const Color(0xFFDDF5E8),
              tagFg: const Color(0xFF22A06B),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _act(
              icon: Icons.payments_rounded,
              iconColor: const Color(0xFF22A06B),
              iconBg: const Color(0xFFDDF5E8),
              title: '중앙클럽 협회비 납부',
              sub: '2026-04-19 · 300,000원',
              trail: '+300,000원',
              trailColor: const Color(0xFF22A06B),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _act(
              icon: Icons.person_add_alt_1_rounded,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFFDCEBFF),
              title: '신규 선수 등록 3명',
              sub: '서초 셔틀콕 클럽',
              tag: '신규',
              tagBg: const Color(0xFFDCEBFF),
              tagFg: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _act({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String sub,
    String? tag,
    Color? tagBg,
    Color? tagFg,
    String? trail,
    Color? trailColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF737C8B),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          if (tag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tagBg,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: tagFg,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          if (trail != null)
            Text(
              trail,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: trailColor,
                letterSpacing: -0.3,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// 메뉴 카드 (기존 그대로)
// ============================================================
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color iconBgColor;
  final Color subtitleColor;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.iconColor,
    required this.iconBgColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFC7D5F0),
              width: 1.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                    height: 1.1,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                  height: 1.25,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 통계 아이템 (NEW: 아이콘 추가)
// ============================================================
class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: iconColor.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.65),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
