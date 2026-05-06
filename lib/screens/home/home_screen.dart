import 'package:flutter/material.dart';
import 'package:badminton_association/screens/players/player_list_screen.dart';
import '../../models/player_fee_payment.dart';
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

  Future<void> _go(Widget s) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => s));
    if (mounted) setState(() {}); // 돌아왔을 때 최근 활동 등 재계산
  }

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
      // 로그인→홈 전환 시 키보드가 남아있어도 본문이 압축되지 않도록
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // ▼ NEW: 통합 히어로 (배경이미지 + 헤더 + 헤드라인 + 통계카드)
          _heroWithStats(),
          const SizedBox(height: 16),

          // ▼ 메뉴 카드 (3 × 2 그리드)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                SizedBox(
                  height: 100,
                  child: Row(
                    children: [
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.apartment_rounded,
                          title: '클럽관리',
                          subtitle: '등록, 조회',
                          iconColor: const Color(0xFF2563EB),
                          iconBgColor: const Color(0xFFDBEAFE),
                          subtitleColor: const Color(0xFF2563EB),
                          onTap: () => _go(const ClubListScreen()),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.groups_rounded,
                          title: '선수관리',
                          subtitle: '급수, 조회',
                          iconColor: const Color(0xFF22A06B),
                          iconBgColor: const Color(0xFFD1FAE5),
                          subtitleColor: const Color(0xFF22A06B),
                          onTap: () => _go(const PlayerListScreen()),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.emoji_events_rounded,
                          title: '대회운영',
                          subtitle: '신청, 대진표',
                          iconColor: const Color(0xFFE07B3C),
                          iconBgColor: const Color(0xFFFFEDD8),
                          subtitleColor: const Color(0xFFE07B3C),
                          onTap: () => _go(const TournamentListScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 100,
                  child: Row(
                    children: [
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.credit_card_rounded,
                          title: '재정관리',
                          subtitle: '협회 수입지출',
                          iconColor: const Color(0xFF7C3AED),
                          iconBgColor: const Color(0xFFEDE9FE),
                          subtitleColor: const Color(0xFF7C3AED),
                          onTap: () => _go(const FinanceScreen()),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.event_note_rounded,
                          title: '대회일정',
                          subtitle: '월별, 연간',
                          iconColor: const Color(0xFF0891B2),
                          iconBgColor: const Color(0xFFCFFAFE),
                          subtitleColor: const Color(0xFF0891B2),
                          onTap: () => _go(const TournamentScheduleScreen()),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.account_balance_rounded,
                          title: '협회행정',
                          subtitle: '공지 이사회',
                          iconColor: const Color(0xFF1F2937),
                          iconBgColor: const Color(0xFFE5E7EB),
                          subtitleColor: const Color(0xFF3730A3),
                          onTap: () => _go(const AdminScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  14, 16, 14, 20 + MediaQuery.of(context).padding.bottom),
              child: _recent(),
            ),
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
    final items = _buildRecentItems();
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.4,
                ),
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Text(
                  '최근 활동 내역이 없습니다.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                ),
              )
            else
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                _act(
                  icon: items[i].icon,
                  iconColor: items[i].iconColor,
                  iconBg: items[i].iconBg,
                  title: items[i].title,
                  sub: items[i].sub,
                  tag: items[i].tag,
                  tagBg: items[i].tagBg,
                  tagFg: items[i].tagFg,
                  trail: items[i].trail,
                  trailColor: items[i].trailColor,
                ),
              ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// 최근 활동 항목 빌더 — SampleData에서 실시간 집계 (날짜 내림차순, 최대 10건)
  List<_RecentItem> _buildRecentItems() {
    final items = <_RecentItem>[];

    // 1) 진행중 대회 (모두)
    final ongoing = SampleData.tournaments
        .where((t) => t.status == 'ongoing')
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    for (final t in ongoing) {
      items.add(_RecentItem(
        sortKey: DateTime.tryParse(t.startDate) ?? DateTime(2000),
        icon: Icons.emoji_events_rounded,
        iconColor: const Color(0xFFE07B3C),
        iconBg: const Color(0xFFFFEDD8),
        title: '${t.name} 진행 중',
        sub: '${t.startDate} ~ ${t.endDate}',
        tag: '진행중',
        tagBg: const Color(0xFFDDF5E8),
        tagFg: const Color(0xFF22A06B),
      ));
    }

    // 2) 협회비 납부 — 클럽+날짜로 묶어 최근 5건
    //    재정관리 항목이므로 정렬키는 그룹 내 가장 최근에 실행(생성)된
    //    납부의 ID 타임스탬프(마이크로초)로 잡아 "최근 실행순"이 되도록 한다.
    final byClubDate = <String, List<PlayerFeePayment>>{};
    for (final p in SampleData.playerFeePayments) {
      byClubDate.putIfAbsent('${p.clubName}|${p.date}', () => []).add(p);
    }
    final grouped = byClubDate.values.map((list) {
      final total = list.fold<int>(0, (s, p) => s + p.amount);
      final clubName = list.first.clubName;
      final date = list.first.date;
      DateTime latest = DateTime.tryParse(date) ?? DateTime(2000);
      for (final p in list) {
        final m = RegExp(r'(\d{13,})').firstMatch(p.id);
        if (m == null) continue;
        final raw = m.group(1)!;
        final n = int.tryParse(raw);
        if (n == null) continue;
        final dt = raw.length >= 16
            ? DateTime.fromMicrosecondsSinceEpoch(n)
            : DateTime.fromMillisecondsSinceEpoch(n);
        if (dt.isAfter(latest)) latest = dt;
      }
      return _RecentItem(
        sortKey: latest,
        icon: Icons.payments_rounded,
        iconColor: const Color(0xFF22A06B),
        iconBg: const Color(0xFFDDF5E8),
        title: '$clubName 협회비 납부',
        sub: '$date · ${list.length}명',
        trail: '+${_formatNumber(total)}원',
        trailColor: const Color(0xFF22A06B),
      );
    }).toList()
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    items.addAll(grouped.take(5));

    // 3) 최근 공지 3건
    final recentNotices = [...SampleData.notices]
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final n in recentNotices.take(3)) {
      final isImportant = n.type == '중요';
      items.add(_RecentItem(
        sortKey: DateTime.tryParse(n.date) ?? DateTime(2000),
        icon: Icons.campaign_rounded,
        iconColor: const Color(0xFF7C3AED),
        iconBg: const Color(0xFFEDE9FE),
        title: '공지: ${n.title}',
        sub: n.date,
        tag: isImportant ? '중요' : null,
        tagBg: isImportant ? const Color(0xFFFEE2E2) : null,
        tagFg: isImportant ? const Color(0xFFB91C1C) : null,
      ));
    }

    // 4) 가장 최근 이사회 2건
    final boards = [...SampleData.boards]
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final b in boards.take(2)) {
      final isDone = b.status == '완료';
      items.add(_RecentItem(
        sortKey: DateTime.tryParse(b.date) ?? DateTime(2000),
        icon: Icons.groups_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFDCEBFF),
        title: '이사회: ${b.title}',
        sub: '${b.date}${b.place.isEmpty ? '' : ' · ${b.place}'}',
        tag: b.status,
        tagBg: isDone ? const Color(0xFFE5E7EB) : const Color(0xFFDCEBFF),
        tagFg: isDone ? const Color(0xFF555555) : const Color(0xFF2563EB),
      ));
    }

    items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return items.take(10).toList();
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFDEE5EE)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            // 위쪽 라이트 하이라이트
            BoxShadow(
              color: Color(0xFFFFFFFF),
              offset: Offset(0, -1),
              blurRadius: 0,
              spreadRadius: 0,
            ),
            // 메인 그림자 (깊은 깊이감)
            BoxShadow(
              color: Color(0x29000000),
              offset: Offset(0, 8),
              blurRadius: 18,
              spreadRadius: -3,
            ),
            // 타이트 컨택 그림자
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 3),
              blurRadius: 6,
              spreadRadius: 0,
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      height: 1.1,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
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

// ============================================================
// 최근 활동 항목 데이터 (실데이터 집계용 PoD)
// ============================================================
class _RecentItem {
  final DateTime sortKey;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String sub;
  final String? tag;
  final Color? tagBg;
  final Color? tagFg;
  final String? trail;
  final Color? trailColor;

  const _RecentItem({
    required this.sortKey,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.sub,
    this.tag,
    this.tagBg,
    this.tagFg,
    this.trail,
    this.trailColor,
  });
}
