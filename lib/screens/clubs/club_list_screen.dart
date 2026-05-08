import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/player.dart';
import '../../services/sample_data.dart';
import 'club_detail_screen.dart';
import 'club_form_screen.dart';
import 'upload_screen.dart';

const _primary = Color(0xFF2563EB);
const _secondary = Color(0xFF22A06B);
const _ink = Color(0xFF0D1B3E);
const _muted = Color(0xFF9BA8BB);
const _soft = Color(0xFFF4F6FA);

class ClubListScreen extends StatefulWidget {
  const ClubListScreen({super.key});
  @override
  State<ClubListScreen> createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  final _clubCtrl = TextEditingController();
  final _memberCtrl = TextEditingController();
  final Set<String> _expanded = {};
  late List<Club> _clubs;

  @override
  void initState() {
    super.initState();
    _clubs = List.from(SampleData.clubs);
  }

  @override
  void dispose() {
    _clubCtrl.dispose();
    _memberCtrl.dispose();
    super.dispose();
  }

  bool get _hasClubQ => _clubCtrl.text.trim().isNotEmpty;
  bool get _hasMemberQ => _memberCtrl.text.trim().isNotEmpty;

  List<Club> get _filteredClubs {
    final q = _clubCtrl.text.trim();
    final mq = _memberCtrl.text.trim();
    var list = _clubs;
    if (q.isNotEmpty) list = list.where((c) => c.name.contains(q)).toList();
    if (mq.isNotEmpty) {
      list = list.where((c) {
        return SampleData.players
            .any((p) => p.clubId == c.id && p.name.contains(mq));
      }).toList();
    }
    return list;
  }

  List<Player> _membersOf(String clubId) {
    final all = SampleData.players.where((p) => p.clubId == clubId).toList();
    all.sort((a, b) => a.name.compareTo(b.name)); // 가나다 순 정렬
    final mq = _memberCtrl.text.trim();
    if (mq.isEmpty) return all;
    return all.where((p) => p.name.contains(mq)).toList();
  }

  bool _isExpanded(String clubId) {
    if (_hasMemberQ) return _membersOf(clubId).isNotEmpty;
    return _expanded.contains(clubId);
  }

  Future<void> _editClub(Club club) async {
    final updated = await Navigator.push<Club>(
      context,
      MaterialPageRoute(builder: (_) => ClubFormScreen(initial: club)),
    );
    if (updated != null) {
      setState(() {
        // 로컬 리스트 업데이트
        final idx = _clubs.indexWhere((c) => c.id == club.id);
        if (idx >= 0) _clubs[idx] = updated;
        // SampleData에도 반영
        final sIdx = SampleData.clubs.indexWhere((c) => c.id == club.id);
        if (sIdx >= 0) SampleData.clubs[sIdx] = updated;
      });
      // 영구 저장 (휴대폰 저장소에 기록)
      await SampleData.saveClubs();
    }
  }

  Future<void> _deleteClub(Club club) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('클럽 삭제',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text('\'${club.name}\'을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
            style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF555555))),
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
      setState(() {
        _clubs.removeWhere((c) => c.id == club.id);
        SampleData.clubs.removeWhere((c) => c.id == club.id);
        _expanded.remove(club.id);
      });
      await SampleData.saveClubs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\'${club.name}\'이(가) 삭제되었습니다.')),
        );
      }
    }
  }

  void _showMenu(BuildContext ctx, Club club, Offset offset) async {
    final result = await showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(
          offset.dx, offset.dy, offset.dx + 1, offset.dy + 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: const [
            Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('수정', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: const [
            Icon(Icons.delete_outline_rounded,
                size: 18, color: Color(0xFFB91C1C)),
            SizedBox(width: 10),
            Text('삭제',
                style: TextStyle(
                    color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    );
    if (result == 'edit') _editClub(club);
    if (result == 'delete') _deleteClub(club);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _soft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: -4,
        leadingWidth: 34,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _ink),
        ),
        title: const Text('클럽관리',
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, color: _ink)),
        actions: [
          // ── 📤 엑셀 업로드 ──────────────────────
          IconButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const UploadScreen(type: UploadType.club),
                ),
              );
              if (result == true) {
                setState(() => _clubs = List.from(SampleData.clubs));
                await SampleData.saveClubs();
              }
            },
            icon: const Icon(Icons.upload_file_rounded, color: _primary),
            tooltip: '엑셀 업로드',
          ),
          // ── ➕ 직접 등록 ─────────────────────────
          TextButton.icon(
            onPressed: () async {
              final result = await Navigator.push<Club>(
                context,
                MaterialPageRoute(builder: (_) => const ClubFormScreen()),
              );
              if (result != null) {
                setState(() {
                  _clubs.add(result);
                  SampleData.clubs.add(result);
                });
                await SampleData.saveClubs();
              }
            },
            icon: const Icon(Icons.add_rounded, size: 20, color: _primary),
            label: const Text('등록',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _primary,
                    fontSize: 14)),
          ),
        ],
      ),
      body: Column(
        children: [
          _searchBox(),
          const Divider(height: 1, color: Color(0xFFE4E8F0)),
          Expanded(child: _clubListReorder()),
        ],
      ),
    );
  }

  Widget _searchBox() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(children: [
          Expanded(
              child: _searchField(
                  controller: _clubCtrl,
                  hint: '클럽명 검색',
                  icon: Icons.corporate_fare_rounded,
                  accent: _primary)),
          const SizedBox(width: 8),
          Expanded(
              child: _searchField(
                  controller: _memberCtrl,
                  hint: '회원명 검색',
                  icon: Icons.person_search_rounded,
                  accent: _secondary)),
        ]),
      );

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color accent,
  }) =>
      SizedBox(
        height: 37,
        child: TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _ink,
              letterSpacing: -0.3),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: _muted),
            prefixIcon: Icon(icon, size: 18, color: accent),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 34, minHeight: 34),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: accent, width: 1.4)),
            filled: true,
            fillColor: const Color(0xFFF0F4FB),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: _muted),
                    onPressed: () => setState(() => controller.clear()),
                  )
                : null,
          ),
        ),
      );

  Widget _clubListReorder() {
    final isSearching = _hasClubQ || _hasMemberQ;
    if (isSearching) {
      final clubs = _filteredClubs;
      if (clubs.isEmpty) {
        return const Center(
            child: Text('검색 결과가 없습니다.',
                style: TextStyle(fontSize: 14, color: _muted)));
      }
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: clubs.length,
        itemBuilder: (_, i) => _buildCard(clubs[i], i, draggable: false),
      );
    }
    return ReorderableListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      buildDefaultDragHandles: false,
      itemCount: _clubs.length,
      proxyDecorator: (child, __, animation) => Material(
        color: Colors.transparent,
        elevation: 10,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
      onReorder: (oldIdx, newIdx) async {
        setState(() {
          if (newIdx > oldIdx) newIdx -= 1;
          final item = _clubs.removeAt(oldIdx);
          _clubs.insert(newIdx, item);
        });
        SampleData.clubs
          ..clear()
          ..addAll(_clubs);
        await SampleData.saveClubs();
      },
      itemBuilder: (_, i) => ReorderableDelayedDragStartListener(
        key: ValueKey(_clubs[i].id),
        index: i,
        child: _buildCard(_clubs[i], i, draggable: true),
      ),
    );
  }

  Widget _buildCard(Club club, int listIdx, {required bool draggable}) {
    final isOpen = _isExpanded(club.id);
    final members = _membersOf(club.id);
    final totalMembers =
        SampleData.players.where((p) => p.clubId == club.id).length;

    return Container(
      key: ValueKey('card_${club.id}'),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF3F7FE)],
        ),
        border: Border.all(
          color: _primary.withOpacity(isOpen ? 0.55 : 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(isOpen ? 0.18 : 0.12),
            blurRadius: isOpen ? 14 : 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() {
            isOpen ? _expanded.remove(club.id) : _expanded.add(club.id);
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(club.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color.fromARGB(255, 16, 40, 102),
                              letterSpacing: -0.4,
                              height: 1.05)),
                      const SizedBox(height: 5),
                      _personRow(
                          label: '회장',
                          name: club.presidentName,
                          phone: club.presidentPhone,
                          accent: _primary,
                          icon: Icons.person_rounded),
                      const SizedBox(height: 2),
                      _personRow(
                          label: '총무',
                          name: club.secretaryName,
                          phone: club.secretaryPhone,
                          accent: _secondary,
                          icon: Icons.badge_rounded),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          '총 ${SampleData.players.where((p) => p.clubId == club.id).length}명',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F2557),
                            letterSpacing: -0.3,
                          )),
                      const SizedBox(width: 2),
                      Builder(
                        builder: (ctx) => GestureDetector(
                          onTapDown: (d) =>
                              _showMenu(ctx, club, d.globalPosition),
                          child: Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            child: const Icon(Icons.more_vert_rounded,
                                size: 20, color: _muted),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Icon(
                      isOpen
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 22,
                      color: _primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isOpen) ...[
          const Divider(height: 1, color: Color(0xFFDCE4F0)),
          InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ClubDetailScreen(club: club))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: Colors.white,
              child: Row(children: [
                Text('검색된 회원 ${members.length}명',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A))),
                Text('  /  전체 $totalMembers명',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A))),
                const Spacer(),
                const Text('클럽 상세',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A))),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: _muted),
              ]),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEAEEF5)),
          if (members.isEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: const Text('검색된 회원이 없습니다',
                  style: TextStyle(fontSize: 12, color: _muted)),
            )
          else
            ...members.map((p) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        bottom:
                            BorderSide(color: Color(0xFFF0F2F7), width: 0.5)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 30,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _gc(p.grade).withOpacity(0.13),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(p.grade.replaceAll('조', ''),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _gc(p.grade),
                                height: 1.0)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Row(children: [
                        Text(p.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                                height: 1.0)),
                        const SizedBox(width: 5),
                        Text('(${p.gender}) ${p.age}세',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1A1A1A),
                                height: 1.0)),
                      ]),
                    ),
                    Text(p.phone,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A),
                            height: 1.0)),
                  ]),
                )),
        ],
      ]),
    );
  }

  Widget _personRow({
    required String label,
    required String name,
    required String phone,
    required Color accent,
    required IconData icon,
  }) =>
      Row(children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 12, color: accent),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.2,
                height: 1.0)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF000000),
                  letterSpacing: -0.3,
                  height: 1.0)),
        ),
        const SizedBox(width: 8),
        Text(phone,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF000000),
                letterSpacing: -0.2,
                height: 1.0)),
      ]);

  Widget _memberBadge(int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFDCEBFF), Color(0xFFBED6FF)]),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _primary.withOpacity(0.2), width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.people_alt_rounded, size: 14, color: _primary),
          const SizedBox(width: 4),
          Text('총 $count명',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                  letterSpacing: -0.3)),
        ]),
      );

  Color _gc(String g) {
    switch (g) {
      case '자강조':
        return const Color(0xFF0F2557);
      case 'S조':
        return _primary;
      case 'A조':
        return _secondary;
      case 'B조':
        return const Color(0xFF0E7490);
      case 'C조':
        return const Color(0xFF92400E);
      case 'D조':
        return const Color(0xFF4C1D95);
      default:
        return const Color(0xFF6B7A99);
    }
  }
}
