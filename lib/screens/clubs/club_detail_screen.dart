import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/club.dart';
import '../../models/player.dart';
import '../../services/sample_data.dart';
import '../../widgets/common/section_header.dart';
import '../players/player_list_screen.dart';

class ClubDetailScreen extends StatelessWidget {
  final Club club;
  const ClubDetailScreen({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppBar(
        title: const Text('클럽 상세'),
        actions: [
          TextButton(
            onPressed: () {},
            child:
                const Text('편집', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          // ── 헤더 (원형 아바타 제거) ────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 클럽명 +2pt → 20pt
                Text(club.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                      letterSpacing: -0.5,
                    )),
                const SizedBox(height: 4),
                Text(club.memberType,
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── 기본 정보 ──────────────────────────
          Container(
            color: AppColors.white,
            child: Column(children: [
              const SectionHeader('기본 정보'),
              // 회장 +2pt → 15pt, 전화 검정 +1pt → 14pt
              _InfoRow('회장', club.presidentName, fontSize: 15),
              _InfoRow('회장 연락처', club.presidentPhone,
                  fontSize: 18, textColor: AppColors.text),
              _InfoRow('총무', club.secretaryName, fontSize: 15),
              _InfoRow('총무 연락처', club.secretaryPhone,
                  fontSize: 18, textColor: AppColors.text),
              _InfoRow('창단일', club.foundedAt),
              _InfoRow('회원수', '${club.memberCount}명'),
              _InfoRow('연습 장소', club.venue),
              _InfoRow('연습 요일', club.practiceDay),
            ]),
          ),
          const SizedBox(height: 8),
          // ── 급수별 현황 ────────────────────────
          Container(
            color: AppColors.white,
            child: Column(children: [
              const SectionHeader('소속 선수 급수 현황'),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  _GradeBox('A조', club.countA, const Color(0xFF1E4FC2)),
                  const SizedBox(width: 6),
                  _GradeBox('B조', club.countB, const Color(0xFF1A6B3C)),
                  const SizedBox(width: 6),
                  _GradeBox('C조', club.countC, const Color(0xFF92400E)),
                  const SizedBox(width: 6),
                  _GradeBox('D조', club.countD, const Color(0xFF4C1D95)),
                  const SizedBox(width: 6),
                  _GradeBox('초심', club.countBeginner, const Color(0xFF9BA8BB)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          // ── 회원 목록 ──────────────────────────
          Container(
            color: AppColors.white,
            child: Column(children: [
              const SectionHeader('회원 목록'),
              ..._memberRows(club),
            ]),
          ),
          const SizedBox(height: 8),
          // ── 납부 관리 버튼들 ────────────────────
          Container(
            color: AppColors.white,
            child: Column(children: [
              const SectionHeader('납부 관리'),
              _PayNavRow(
                icon: Icons.receipt_long,
                label: '협회비 관리',
                desc: '연간 협회 등록비',
                color: const Color(0xFF1E4FC2),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _AssocFeeScreen(club: club))),
              ),
              _PayNavRow(
                icon: Icons.event_note,
                label: '클럽 분담금',
                desc: '대회별 클럽 부담금 (복수 납부)',
                color: const Color(0xFF1A6B3C),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _ShareFeeScreen(club: club))),
              ),
              _PayNavRow(
                icon: Icons.groups,
                label: '이사회비',
                desc: '회장·총무 이사회 참가비',
                color: const Color(0xFF4C1D95),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _BoardFeeScreen(club: club))),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // ── 버튼 ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PlayerListScreen())),
                      child: const Text('선수 목록'))),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton(
                      onPressed: () {}, child: const Text('대회 기록'))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────

List<Widget> _memberRows(Club club) {
  final members =
      SampleData.players.where((p) => p.clubId == club.id).toList();
  return [
    for (var i = 0; i < members.length; i++)
      _MemberRow(player: members[i], index: i + 1),
  ];
}

Color _memberPastelBg(String grade) {
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

Color _memberPastelFg(String grade) {
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

class _MemberRow extends StatelessWidget {
  final Player player;
  final int index;
  const _MemberRow({required this.player, required this.index});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Row(children: [
          SizedBox(
              width: 28,
              child: Text('$index',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted),
                  textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(player.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        height: 1.25)),
                const SizedBox(width: 4),
                Text('(${player.gender}) ${player.age}세',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        height: 1.25)),
              ]),
              const SizedBox(height: 2),
              Text(player.clubName,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A1A),
                      height: 1.25)),
            ],
          )),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _memberPastelBg(player.grade),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(player.grade,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _memberPastelFg(player.grade))),
              ),
              const SizedBox(height: 2),
              Text(player.phone,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A))),
            ],
          ),
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final double fontSize;
  final Color? textColor;
  const _InfoRow(this.label, this.value, {this.fontSize = 13, this.textColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: const BoxDecoration(
            border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5))),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? AppColors.text)),
        ]),
      );
}

class _GradeBox extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _GradeBox(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ]),
        ),
      );
}

class _PayNavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final Color color;
  final VoidCallback onTap;
  const _PayNavRow(
      {required this.icon,
      required this.label,
      required this.desc,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.divider, width: 0.5))),
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: color.withOpacity(.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
                Text(desc,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            )),
            const Icon(Icons.chevron_right, color: AppColors.gray3, size: 18),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════
// 협회비 관리 화면
// ══════════════════════════════════════════════
class _AssocFeeScreen extends StatelessWidget {
  final Club club;
  const _AssocFeeScreen({required this.club});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.gray,
        appBar: AppBar(title: Text('${club.name} · 협회비')),
        body: Column(children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('2026년 협회비',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color:
                          club.assocFeePaid ? AppColors.green3 : AppColors.red3,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(club.assocFeePaid ? '납부완료' : '미납',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: club.assocFeePaid
                              ? AppColors.green
                              : AppColors.red)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () {}, child: const Text('납부 처리'))),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════
// 클럽 분담금 화면 (복수 납부 가능)
// ══════════════════════════════════════════════
class _ShareFeeScreen extends StatefulWidget {
  final Club club;
  const _ShareFeeScreen({required this.club});
  @override
  State<_ShareFeeScreen> createState() => _ShareFeeScreenState();
}

class _ShareFeeScreenState extends State<_ShareFeeScreen> {
  final List<_FeeRecord> _records = [
    _FeeRecord(
        title: '2026 협회장배 분담금', amount: 50000, date: '2026-04-10', paid: true),
    _FeeRecord(
        title: '2026 봄 친선전 분담금',
        amount: 30000,
        date: '2026-03-20',
        paid: false),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.gray,
        appBar: AppBar(
          title: Text('${widget.club.name} · 분담금'),
          actions: [
            TextButton.icon(
                onPressed: () => _showAdd(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가')),
          ],
        ),
        body: _records.isEmpty
            ? const Center(
                child: Text('납부 내역이 없습니다.',
                    style: TextStyle(color: AppColors.muted)))
            : ListView.builder(
                itemCount: _records.length,
                itemBuilder: (_, i) {
                  final r = _records[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: const BoxDecoration(
                        color: AppColors.white,
                        border: Border(
                            bottom: BorderSide(
                                color: AppColors.divider, width: 0.5))),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text)),
                          const SizedBox(height: 2),
                          Text('${r.date} · ${_fmt(r.amount)}원',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                        ],
                      )),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: r.paid ? AppColors.green3 : AppColors.red3,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(r.paid ? '납부' : '미납',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: r.paid
                                      ? AppColors.green
                                      : AppColors.red))),
                    ]),
                  );
                },
              ),
      );

  void _showAdd(BuildContext ctx) {
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('분담금 추가',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
              controller: titleCtrl,
              decoration:
                  const InputDecoration(labelText: '항목명 (예: 협회장배 분담금)')),
          const SizedBox(height: 10),
          TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '금액 (원)')),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final amt = int.tryParse(amtCtrl.text.trim()) ?? 0;
                    if (title.isNotEmpty && amt > 0) {
                      setState(() => _records.add(_FeeRecord(
                          title: title,
                          amount: amt,
                          date: DateTime.now().toString().substring(0, 10),
                          paid: false)));
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('추가'))),
        ]),
      ),
    );
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _FeeRecord {
  final String title;
  final int amount;
  final String date;
  final bool paid;
  _FeeRecord(
      {required this.title,
      required this.amount,
      required this.date,
      required this.paid});
}

// ══════════════════════════════════════════════
// 이사회비 화면
// ══════════════════════════════════════════════
class _BoardFeeScreen extends StatelessWidget {
  final Club club;
  const _BoardFeeScreen({required this.club});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.gray,
        appBar: AppBar(title: Text('${club.name} · 이사회비')),
        body: Column(children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _row('회장 이사회비', club.boardFeePaid),
              const SizedBox(height: 8),
              _row('총무 이사회비', club.boardFeePaid),
            ]),
          ),
          const SizedBox(height: 16),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () {}, child: const Text('납부 처리')))),
        ]),
      );

  Widget _row(String label, bool paid) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text)),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: paid ? AppColors.green3 : AppColors.red3,
                borderRadius: BorderRadius.circular(8)),
            child: Text(paid ? '납부완료' : '미납',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: paid ? AppColors.green : AppColors.red))),
      ]);
}
