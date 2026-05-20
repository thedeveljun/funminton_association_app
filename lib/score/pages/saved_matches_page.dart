import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badminton_association/score/l10n/app_strings.dart';
import 'package:badminton_association/score/l10n/locale_controller.dart';
import 'package:badminton_association/score/models/saved_match_record.dart';
import 'package:badminton_association/score/models/result_models.dart';
import 'package:badminton_association/score/utils/share_match.dart';

class SavedMatchesPage extends StatefulWidget {
  final String savedMatchesKey;
  final List<SavedMatchRecord> initialMatches;

  const SavedMatchesPage({
    super.key,
    required this.savedMatchesKey,
    required this.initialMatches,
  });

  @override
  State<SavedMatchesPage> createState() => _SavedMatchesPageState();
}

class _SavedMatchesPageState extends State<SavedMatchesPage> {
  late List<SavedMatchRecord> _savedMatches;
  final Set<int> _selectedIndexes = {};
  bool _changed = false;
  bool _isClosing = false;

  S get _s => S(LocaleController.notifier.value);

  @override
  void initState() {
    super.initState();
    _savedMatches = List<SavedMatchRecord>.from(widget.initialMatches);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  String _formatSavedAt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $hh:$mm';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _persistMatches() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _savedMatches.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(widget.savedMatchesKey, encoded);
  }

  Future<void> _deleteAllSavedMatches() async {
    final s = _s;
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.deleteAll),
            content: Text(s.deleteAllConfirm),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(s.confirm)),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(widget.savedMatchesKey);

    if (!mounted) return;
    setState(() {
      _savedMatches = [];
      _selectedIndexes.clear();
      _changed = true;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_s.deleteAllDone),
          duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _deleteSelectedSavedMatches() async {
    final s = _s;
    if (_selectedIndexes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(s.nothingToDelete),
            duration: const Duration(seconds: 1)),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.deleteSelected),
            content: Text(s.deleteSelectedConfirm(_selectedIndexes.length)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(s.confirm)),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete || !mounted) return;

    setState(() {
      _savedMatches = [
        for (int i = 0; i < _savedMatches.length; i++)
          if (!_selectedIndexes.contains(i)) _savedMatches[i],
      ];
      _selectedIndexes.clear();
      _changed = true;
    });

    await _persistMatches();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_s.deleteSelectedDone),
          duration: const Duration(seconds: 1)),
    );
  }

  void _closePage() {
    if (_isClosing) return;
    _isClosing = true;
    Navigator.pop(
      context,
      SavedMatchesPageResult(savedMatches: _savedMatches, changed: _changed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final allSelected = _savedMatches.isNotEmpty &&
        _selectedIndexes.length == _savedMatches.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closePage();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.4,
          centerTitle: false,
          leading: IconButton(
            onPressed: _closePage,
            icon: const Icon(Icons.arrow_back, color: Colors.black),
          ),
          titleSpacing: 0,
          title: Text(
            s.savedMatchesTitle,
            style: const TextStyle(
                color: Colors.black, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(
              onPressed: _savedMatches.isEmpty ? null : _deleteAllSavedMatches,
              child: Text(s.deleteAll),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ── 상단 선택/삭제 바 ─────────────────────────────────────
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: TextButton(
                              onPressed: _savedMatches.isEmpty
                                  ? null
                                  : () {
                                      setState(() {
                                        if (allSelected) {
                                          _selectedIndexes.clear();
                                        } else {
                                          _selectedIndexes
                                            ..clear()
                                            ..addAll(List.generate(
                                                _savedMatches.length,
                                                (i) => i));
                                        }
                                      });
                                    },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                allSelected ? s.deselectAll : s.selectAll,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: TextButton(
                              onPressed: _savedMatches.isEmpty
                                  ? null
                                  : _deleteSelectedSavedMatches,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                s.deleteSelected,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.selectedCount(_selectedIndexes.length),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── 목록 ─────────────────────────────────────────────────
              Expanded(
                child: _savedMatches.isEmpty
                    ? Center(
                        child: Text(
                          s.noSavedRecords,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
                        itemCount: _savedMatches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 3),
                        itemBuilder: (context, index) {
                          final item = _savedMatches[index];
                          final isSelected = _selectedIndexes.contains(index);

                          final String myTeam = item.myTeamSide;
                          final int myScore = myTeam == 'left'
                              ? item.scoreA
                              : myTeam == 'right'
                                  ? item.scoreB
                                  : -1;
                          final int oppScore = myTeam == 'left'
                              ? item.scoreB
                              : myTeam == 'right'
                                  ? item.scoreA
                                  : -1;

                          final String resultText;
                          final Color resultColor;
                          if (myTeam == 'none') {
                            resultText = '-';
                            resultColor = Colors.grey;
                          } else if (myScore > oppScore) {
                            resultText = s.win;
                            resultColor = const Color(0xFF1565C0);
                          } else if (myScore < oppScore) {
                            resultText = s.loss;
                            resultColor = const Color(0xFFD32F2F);
                          } else {
                            resultText = s.draw;
                            resultColor = Colors.grey;
                          }

                          final String myTeamLabel = myTeam == 'left'
                              ? '${s.localizedPlayerName(item.leftPlayer1)}/${s.localizedPlayerName(item.leftPlayer2)}'
                              : myTeam == 'right'
                                  ? '${s.localizedPlayerName(item.rightPlayer1)}/${s.localizedPlayerName(item.rightPlayer2)}'
                                  : '';

                          final String matchupLabel =
                              '${s.localizedPlayerName(item.leftPlayer1)}/${s.localizedPlayerName(item.leftPlayer2)}  vs  ${s.localizedPlayerName(item.rightPlayer1)}/${s.localizedPlayerName(item.rightPlayer2)}';

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIndexes.remove(index);
                                } else {
                                  _selectedIndexes.add(index);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFEAF3FF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF68A0F0)
                                      : const Color(0xFFE4E7EB),
                                  width: isSelected ? 1.4 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 체크박스
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Checkbox(
                                      value: isSelected,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedIndexes.add(index);
                                          } else {
                                            _selectedIndexes.remove(index);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // 텍스트 영역
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 선수명 (대진)
                                        Text(
                                          matchupLabel,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87),
                                        ),
                                        const SizedBox(height: 2),
                                        // 나의 팀 이름 + 점수 + [승/패]
                                        Row(
                                          children: [
                                            if (myTeamLabel.isNotEmpty)
                                              Flexible(
                                                child: Text(
                                                  '$myTeamLabel  ',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: resultColor,
                                                  ),
                                                ),
                                              ),
                                            Text(
                                              '${item.scoreA} : ${item.scoreB}',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black87),
                                            ),
                                            if (myTeam != 'none') ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '[$resultText]',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: resultColor),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        // 날짜
                                        Text(
                                          _formatSavedAt(item.savedAt),
                                          style: const TextStyle(
                                              fontSize: 13.5,
                                              color: Colors.black45,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 공유 버튼
                                  IconButton(
                                    onPressed: () => ShareMatch.share(
                                      context: context,
                                      record: item,
                                      s: s,
                                    ),
                                    icon: const Icon(Icons.ios_share_rounded),
                                    color: const Color(0xFF1565C0),
                                    iconSize: 20,
                                    tooltip: s.share,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(
                                        minWidth: 36, minHeight: 36),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
