import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/player.dart';
import '../../services/sample_data.dart';
import '../../widgets/common/filter_chips.dart';
import '../../widgets/players/player_list_item.dart';
import '../clubs/upload_screen.dart';
import 'player_detail_screen.dart';
import 'player_form_screen.dart';

const _searchInk = Color(0xFF0D1B3E);
const _searchMuted = Color(0xFF9BA8BB);
const _searchAccent = Color(0xFF22A06B);

class PlayerListScreen extends StatefulWidget {
  const PlayerListScreen({super.key});
  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen> {
  String _gradeFilter = '전체';
  String _genderFilter = '전체';
  final _ctrl = TextEditingController();

  List<Player> get _filtered {
    var list = SampleData.players.toList();
    if (_gradeFilter != '전체') {
      list = list.where((p) => p.grade == _gradeFilter).toList();
    }
    if (_genderFilter != '전체') {
      list = list.where((p) => p.gender == _genderFilter).toList();
    }
    final q = _ctrl.text.trim();
    if (q.isNotEmpty) {
      list = list
          .where((p) => p.name.contains(q) || p.clubName.contains(q))
          .toList();
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        titleSpacing: -4,
        leadingWidth: 34,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.maybePop(context),
          icon:
              const Icon(Icons.arrow_back_ios_new, size: 20, color: _searchInk),
        ),
        title: const Text(
          '선수/동호인 관리',
          style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.w700, color: _searchInk),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => UploadScreen(type: UploadType.player),
                ),
              );
              if (result == true) {
                setState(() {});
                await SampleData.savePlayers();
              }
            },
            icon: const Icon(Icons.upload_file_rounded, color: _searchAccent),
            tooltip: '엑셀 업로드',
          ),
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PlayerFormScreen()));
              setState(() {});
              await SampleData.savePlayers();
            },
            icon: const Icon(Icons.add, size: 18),
            label:
                const Text('등록', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: SizedBox(
            height: 37,
            child: TextField(
              controller: _ctrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _searchInk,
                  letterSpacing: -0.3),
              decoration: InputDecoration(
                hintText: '선수명, 클럽명 검색',
                hintStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _searchMuted),
                prefixIcon: const Icon(Icons.person_search_rounded,
                    size: 18, color: _searchAccent),
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
                    borderSide:
                        const BorderSide(color: _searchAccent, width: 1.4)),
                filled: true,
                fillColor: const Color(0xFFF0F4FB),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: _searchMuted),
                        onPressed: () => setState(() => _ctrl.clear()),
                      )
                    : null,
              ),
            ),
          ),
        ),
        FilterChipRow(
          options: const ['전체', 'A조', 'B조', 'C조', 'D조', '초심조'],
          selected: _gradeFilter,
          onSelect: (v) => setState(() => _gradeFilter = v),
        ),
        FilterChipRow(
          options: const ['전체', '남', '여'],
          selected: _genderFilter,
          onSelect: (v) => setState(() => _genderFilter = v),
        ),
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(children: [
            Text(
                '총 ${filtered.length.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}명',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => PlayerListItem(
              player: filtered[i],
              index: i + 1,
              onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => PlayerDetailScreen(player: filtered[i]))),
            ),
          ),
        ),
      ]),
    );
  }
}
